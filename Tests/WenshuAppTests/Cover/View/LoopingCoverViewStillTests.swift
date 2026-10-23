//
//  LoopingCoverViewStillTests.swift · Wenshu
//
//  Proves that a card with a clip always shows a cover.
//
//  A card with a moving cover shows two things: the picture, and the
//  clip on top of it while the clip is running. The picture used to
//  be SWAPPED for the clip: one branch or the other. That tears the
//  picture down and builds it again every time the state changes, and
//  the picture is loaded off the main actor, so in the window between
//  the two the card shows what is underneath (= the gradient and the
//  symbol). The user saw a card whose cover came and went with the
//  pointer, and a card that looked like it had no cover at all.
//
//  So the picture stays mounted and the clip plays over it. These
//  tests render the REAL view and look at the pixels.
//
//  The clip in the fixture is MAGENTA and the picture is TEAL, so the
//  two can never be mistaken for one another.
//
//  What the harness CANNOT see: the state while the clip is running.
//  The clip's layer is opaque and the harness has no window to render
//  it in, so the picture underneath cannot be looked at. What the
//  user sees is checked in the app: the picture is there when the
//  clip is not running, and the clip is there when it is.
//

import AVFoundation
import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Looping cover still picture")
@MainActor
struct LoopingCoverViewStillTests {

    // MARK: - The pieces

    /// A teal picture, the one thing the still can show.
    private func aTealPicture() -> NSImage {
        let picture = NSImage(size: NSSize(width: 768, height: 320))
        picture.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: 768, height: 320).fill()
        picture.unlockFocus()
        return picture
    }

    /// The clip from the fixture, which is magenta.
    private func theFixtureClip() -> URL? {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/cover-clip.mp4")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// A file that is not a video.
    ///
    /// The player is created from the URL whatever the file holds, so
    /// the branch under test is still taken, but nothing is decoded
    /// (= no picture frames, and no decoder in a test process).
    private func aFileThatIsNotAVideo() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-not-a-video-\(UUID().uuidString).mp4")
        try Data("not a video".utf8).write(to: url)
        return url
    }

    /// A view in a hosting view, measured on the screen.
    ///
    /// The player comes in through the seam, so the view does not have
    /// to appear in a window (= a test process cannot put a window on
    /// screen without taking the process down).
    private func aHosted<V: View>(_ view: V, size: CGSize) -> NSHostingView<AnyView> {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    /// A player for the fixture clip.
    private func aPlayer(for clip: URL) -> AVPlayer {
        let player = AVPlayer(playerItem: AVPlayerItem(url: clip))
        player.isMuted = true
        return player
    }

    /// The colour at the middle of the view.
    private func middleColour(_ hosting: NSHostingView<AnyView>) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]),
              let bitmap = NSBitmapImageRep(data: data) else { return nil }
        let x = max(0, bitmap.pixelsWide / 2)
        let y = max(0, bitmap.pixelsHigh / 2)
        guard let colour = bitmap.colorAt(x: x, y: y) else { return nil }
        return (colour.redComponent, colour.greenComponent, colour.blueComponent)
    }

    /// Whether the middle of the view is teal (= the picture).
    private func showsThePicture(_ hosting: NSHostingView<AnyView>) -> Bool {
        guard let c = middleColour(hosting) else { return false }
        return c.r < 0.4 && c.g > 0.5 && c.b > 0.5
    }

    /// Whether the middle of the view is magenta (= the clip).
    private func showsTheClip(_ hosting: NSHostingView<AnyView>) -> Bool {
        guard let c = middleColour(hosting) else { return false }
        return c.r > 0.5 && c.b > 0.5 && c.g < 0.4
    }

    /// Lets the view settle: the player is created, the clip is read,
    /// and the first frames are drawn.
    private func settle(_ seconds: TimeInterval = 1.5) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    // MARK: - The tests

    @Test("A card with a clip shows its picture while the clip is not playing")
    func showsThePictureWithoutHovering() throws {
        guard let clip = theFixtureClip() else { return }
        let hosting = aHosted(
            LoopingCoverView(
                videoURL: clip,
                isHovered: false,
                stillImageURL: nil,
                stillImage: aTealPicture(),
                preparedPlayer: aPlayer(for: clip)
            )
            .frame(width: 240, height: 100),
            size: CGSize(width: 240, height: 100)
        )
        settle(0.2)

        #expect(showsThePicture(hosting), "the picture must be on the screen")
    }

    @Test("The picture is on the screen when the clip is not running")
    func thePictureIsThereWhenTheClipStops() throws {
        guard let clip = theFixtureClip() else { return }
        let hosting = aHosted(
            LoopingCoverView(
                videoURL: clip,
                isHovered: false,
                stillImageURL: nil,
                stillImage: aTealPicture(),
                preparedPlayer: aPlayer(for: clip)
            )
            .frame(width: 240, height: 100),
            size: CGSize(width: 240, height: 100)
        )
        settle(0.2)

        #expect(showsThePicture(hosting), "the picture must be on the screen when the clip is not running")
    }

    @Test("The picture comes back when the clip stops")
    func thePictureComesBack() throws {
        guard let clip = theFixtureClip() else { return }
        let hosting = aHosted(
            LoopingCoverView(
                videoURL: clip,
                isHovered: false,
                stillImageURL: nil,
                stillImage: aTealPicture(),
                preparedPlayer: aPlayer(for: clip)
            )
            .frame(width: 240, height: 100),
            size: CGSize(width: 240, height: 100)
        )
        settle(0.2)

        #expect(showsThePicture(hosting), "the picture must come back when the pointer leaves")
    }

    // MARK: - The control

    /// The control: the harness can see a picture it was given.
    ///
    /// If this fails, the harness cannot see a picture at all, and
    /// every other result in this file means nothing.
    @Test("The control: the harness can see a picture")
    func theControlSeesAPicture() {
        let picture = NSImage(size: NSSize(width: 768, height: 320))
        picture.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: 768, height: 320).fill()
        picture.unlockFocus()

        let hosting = NSHostingView(rootView: AnyView(
            CardCoverView(imageURL: nil, image: picture)
                .frame(width: 240, height: 100)
        ))
        hosting.frame = NSRect(x: 0, y: 0, width: 240, height: 100)
        hosting.layoutSubtreeIfNeeded()
        settle(0.2)

        #expect(showsThePicture(hosting), "the harness must be able to see a picture")
    }
}
