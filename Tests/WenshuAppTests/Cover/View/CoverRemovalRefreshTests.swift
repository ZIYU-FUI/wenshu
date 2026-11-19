//
//  CoverRemovalRefreshTests.swift · Wenshu
//
//  Proves that a card ASKS THE DISK AGAIN after its cover is removed.
//
//  The removal itself is proved elsewhere (= `CardCoverServiceTests`:
//  the clip goes and the picture stays). What was missing is the
//  other half, and it is what the boss met on 2026-11-19: the file
//  went away and the card went on showing the motion, because nothing
//  told the card to ask again. Making a clip has an in-flight phase a
//  card watches (= `isMakingVideo`); removing one has none.
//
//  Method: the real grid is hosted in a real `NSHostingView`, over a
//  throwaway library whose cover holds a picture and a clip. ⇒ The
//  witness is the cover cache: a card that renders reads its entry
//  and the entry is then held, so an entry that is held AGAIN after
//  the removal evicted it is a card that asked the disk again. ⇒ A
//  property assertion would not prove the claim: the defect was a
//  behaviour of the view, and a behaviour is measured on the view
//  that has it.
//
//  The removal is asked for through ANOTHER service than the pane
//  holds, on purpose: the card that has to ask again is not the one
//  that asked for the removal, so a signal that lived on one service
//  instance would pass only by an accident of wiring.
//

import AppKit
import Foundation
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("Cover removal refresh")
@MainActor
struct CoverRemovalRefreshTests {
    /// A throwaway library root, so the cover directory resolves and
    /// the test never touches the developer's own library.
    private func makeLibraryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "wenshu-cover-refresh-test-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Let the view's own queued work run.
    ///
    /// ⇒ ⇒ ⇒ A RUN-LOOP PUMP, = NOT A SLEEP: = the library root this
    /// test hands the app is a TASK-LOCAL, = and a sleep would free
    /// the main thread, = so SwiftUI could take its own turn in its
    /// own job, = where the override is not set, = and the card would
    /// render against no library at all. = ⇒ ⇒ ⇒ Pumping the run loop
    /// from HERE runs those turns inside this task, = where the card
    /// sees the throwaway library the way the test means it to.
    private func settle(host: NSView, window: NSWindow) {
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    @Test("The card asks the disk again after its moving cover is removed")
    func theCardAsksAgainAfterTheClipIsRemoved() async throws {
        let root = try makeLibraryRoot()
        let reference = Reference(title: "A card with a moving cover")
        let target = CardCoverTarget.reference(reference.id)
        let key = target.coverKey

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let store = CardCoverService()
            // A picture and a clip: the state a card shows the motion
            // mark for.
            try store.saveImage(
                Data([0x01, 0x02, 0x03]),
                forKey: key,
                kind: WSCardCoverKind.reference
            )
            try store.saveVideo(Data([0x00, 0x00, 0x00, 0x18]), forKey: key)
            // The grid reads what is on the disk, not what a previous
            // test left in memory.
            CoverEntryCache.shared.evict(forKey: key)

            let pane = PreviewPane(
                scope: .referenceScope(nil),
                onDoubleClick: { _ in },
                previewSortOrder: .constant(.pinyinFirstLetter)
            )
            let host = NSHostingView(
                rootView: AnyView(pane.overviewGrid(allEntities: [reference]))
            )
            host.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
            // The window sits far outside the screen (= offscreen, =
            // so nothing shows on the writer's desktop) and is ordered
            // front (= AppKit lays the tree out during a display
            // pass).
            let window = NSWindow(
                contentRect: host.frame,
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
            window.contentView = host
            window.orderFront(nil)

            settle(host: host, window: window)
            // The card rendered, and the cover it rendered had a clip.
            let before = CoverEntryCache.shared.entry(forKey: key)
            #expect(before?.videoURL != nil)

            // The removal, asked for through ANOTHER service than the
            // pane's own.
            CoverVideoService.live().removeVideo(for: target)
            // The removal dropped the held entry: the next question
            // goes to the disk.
            #expect(CoverEntryCache.shared.entry(forKey: key) == nil)

            settle(host: host, window: window)
            // THE WITNESS: the entry is held again, so the card asked
            // the disk again, and the answer it got has no clip in it.
            let after = CoverEntryCache.shared.entry(forKey: key)
            #expect(after != nil)
            #expect(after?.videoURL == nil)
            // The entry holds the picture, so the re-read happened
            // against the library: a card that asked the disk again
            // got the cover that is still there.
            #expect(after?.imageURL != nil)
            // The picture the user liked is still on the disk: the
            // removal took the motion, not the cover.
            let pictureOnDisk = root
                .appendingPathComponent("assets", isDirectory: true)
                .appendingPathComponent("covers", isDirectory: true)
                .appendingPathComponent(key, isDirectory: true)
                .appendingPathComponent("cover.heic")
            #expect(FileManager.default.fileExists(atPath: pictureOnDisk.path))

            window.orderOut(nil)
        }
        try? FileManager.default.removeItem(at: root)
    }
}
