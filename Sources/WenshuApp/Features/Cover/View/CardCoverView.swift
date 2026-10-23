//
//  Features/Cover/View/CardCoverView.swift
//
//   : CardCoverView.
//  Draws one card's stored picture in the card's cover slot.
//
//  The picture is a local file in the library, so it is loaded with
//  `NSImage(contentsOfFile:)`. No image-loading library: the project
//  is Apple-frameworks-only, and a local file needs no cache.
//
//  The load is ASYNCHRONOUS, and that is not a nicety. The material
//  zone is a LazyVGrid that can hold dozens of cards, and a
//  synchronous disk read per card in the view body makes scrolling
//  stutter. So the view asks for the file in a Task and shows the
//  fallback until the bytes arrive.
//
//  The slot is a wide banner: 100pt tall and 216-316pt wide
//  depending on the pane's width, so the stored 768x320 (2.40:1)
//  picture fills it with `.fill` and only trims the sides.
//

import AppKit
import SwiftUI

/// A card's stored cover picture.
struct CardCoverView: View {

    /// The stored picture's URL, or nil when the card has no cover.
    let imageURL: URL?

    /// The loaded image, once it has arrived.
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Nothing yet (= the file is still loading) or nothing
                // at all (= the card has no cover). The card view
                // keeps its own gradient and symbol for that case, so
                // this is empty rather than a placeholder.
                Color.clear
            }
        }
        .task(id: imageURL) {
            await load()
        }
    }

    /// Loads the file off the main actor.
    ///
    /// The decoded picture is held in a cache, because a lazy grid
    /// builds a new view for every card that scrolls back into sight,
    /// and decoding the same picture again for every one of them is
    /// work the app has already done.
    private func load() async {
        guard let imageURL else {
            image = nil
            return
        }
        if let cached = CoverImageCache.shared.image(for: imageURL) {
            image = cached
            return
        }
        let loaded = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            NSImage(contentsOfFile: imageURL.path)
        }.value
        if let loaded {
            CoverImageCache.shared.store(loaded, for: imageURL)
        }
        // A file that was deleted between the lookup and the load must
        // degrade to the empty state, not crash and not show a broken
        // image.
        image = loaded
    }
}
