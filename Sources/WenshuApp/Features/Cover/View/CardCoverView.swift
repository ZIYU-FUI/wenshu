//
//  Features/Cover/View/CardCoverView.swift
//
//   : CardCoverView.
//  Draws one card's stored picture in the card's cover slot.
//
//  The picture is a local file in the library. It is NEVER read from
//  here: the ask goes to `CoverImageCache.decodedImage(for:)`, which
//  answers a warm cover out of memory and reads and decodes a cold one
//  on a background task. No image-loading library: the project is
//  Apple-frameworks-only, and the cache this file needs is 100 lines.
//
//  The load is ASYNCHRONOUS, and that is not a nicety. The material
//  zone is a LazyVGrid that can hold dozens of cards, and a
//  synchronous disk read per card makes scrolling stutter. So the view
//  asks for the file and shows the fallback until the bytes arrive —
//  and a card that scrolls back into sight is answered from memory,
//  which is the half this file used to get wrong: the cache lookup
//  itself stat'd the file, so every card asked the disk something on
//  every appearance.
//
//  A card whose cover appears or changes on the disk is TOLD, not
//  re-polled: `CoverChangeSignal` is read where the grid resolves a
//  card's cover (= `PreviewPane.coverEntry`), and the picture cache is
//  dropped by the write that replaced it.
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
    /// Internal, and not private: the claim the column makes is a COUNT
    /// of the disk asks one screenful of cards makes, and a count is
    /// read at the door the view opens. The test opens THIS door (= not
    /// a copy of it), so the number it reports is the number the view
    /// pays.
    ///
    /// The whole of it is one call: the cache answers a cover it holds
    /// from memory, joins the read already running for a cover it does
    /// not, and decodes on a background task. A lazy grid builds a new
    /// view for every card that scrolls back into sight, and the new
    /// view must pay NOTHING for that.
    func load() async {
        // An injected picture is the whole answer: there is nothing to
        // load, and nothing to clear.
        guard image == nil else { return }
        guard let imageURL else {
            loaded = nil
            return
        }
        // A file that was deleted between the entry's answer and this
        // read degrades to the empty state: no crash, no broken image,
        // and the card keeps the gradient and symbol it drew before.
        loaded = await CoverImageCache.shared.decodedImage(for: imageURL)
    }
}
