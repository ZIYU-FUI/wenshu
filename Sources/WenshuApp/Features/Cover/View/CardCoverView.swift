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

    /// The picture itself, when the caller already holds it.
    ///
    /// The URL is the normal way in. This is the seam that lets the
    /// slot's LAYOUT be measured with a real picture and no
    /// asynchronous load, which is the only way to prove that the
    /// picture does not decide how wide the card is.
    let image: NSImage?

    /// The loaded image, once it has arrived.
    @State private var loaded: NSImage?

    init(imageURL: URL?, image: NSImage? = nil) {
        self.imageURL = imageURL
        self.image = image
    }

    var body: some View {
        Group {
            if let picture = image ?? loaded {
                // The picture must NOT decide how wide the card is.
                //
                // A resizable image with an aspect ratio asks for the
                // width its own ratio implies (= 100 PT tall x 2.40 =
                // 240 PT wide), so the card would demand 240 PT even
                // when the material column is narrower, and the column
                // would cut the card's right side off. The slot takes
                // the width the column gives it, and the picture is
                // cropped to fill it (= the slot is a wide banner, and
                // the picture is 2.40:1, so the crop trims the sides
                // and never the subject).
                Color.clear
                    .overlay {
                        Image(nsImage: picture)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
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
        // An injected picture is the whole answer: there is nothing to
        // load, and nothing to clear.
        guard image == nil else { return }
        guard let imageURL else {
            loaded = nil
            return
        }
        if let cached = CoverImageCache.shared.image(for: imageURL) {
            loaded = cached
            return
        }
        let loadedImage = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            NSImage(contentsOfFile: imageURL.path)
        }.value
        if let loadedImage {
            CoverImageCache.shared.store(loadedImage, for: imageURL)
        }
        // A file that was deleted between the lookup and the load must
        // degrade to the empty state, not crash and not show a broken
        // image.
        loaded = loadedImage
    }
}
