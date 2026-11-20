//
//  CoverRemovalRefreshTests.swift · Wenshu
//
//  Proves that a card is TOLD its cover changed, and asks the disk
//  nothing when it does.
//
//  The removal itself is proved elsewhere (= `CardCoverServiceTests`:
//  the clip goes and the picture stays). What was missing is the
//  other half, and it is what the boss met on 2026-11-19: the file
//  went away and the card went on showing the motion, because nothing
//  told the card. Making a clip has an in-flight phase a card watches
//  (= `isMakingVideo`); removing one has none.
//
//  WHAT THE TELLING USED TO BE. b5f34f59e0 made a removal DROP the
//  card's held answer, so the next render went to the disk and got the
//  truth there. That fixed 2026-11-19 and cost the material column a
//  folder read on the main thread, once per changed card, on the very
//  frame the announcement woke (= the reading `CoverDiskReadTests`
//  carries: 3 asks on the main thread). The write that removed the
//  clip already knows the folder's new state, so it can say it:
//  `CardCoverService.removeVideo` now PUBLISHES the recomputed entry
//  instead of dropping it, and the card that wakes up is answered from
//  memory. This suite is the witness that the new shape still removes
//  the clip from what the card shows.
//
//  Method: the real grid is hosted in a real `NSHostingView`, over a
//  throwaway library whose cover holds a picture and a clip. ⇒ The
//  witness is the held entry plus the counting seam: after the removal
//  the entry holds no clip and still holds the picture, and the render
//  that the announcement wakes asks the MAIN THREAD nothing at all. ⇒
//  A property assertion alone would not prove the claim: the defect was
//  a behaviour of the view, and a behaviour is measured on the view
//  that has it.
//
//  The render half waits on a run-loop pump (= `settle`), because a
//  hosted view decides when its body runs and nothing else in the tree
//  can be told to render. The pump is not a clock budget: the counts it
//  returns are the same on a loaded machine and an idle one, since what
//  is asserted is that the number is zero, not that a wall appeared.
//
//  The removal is asked for through ANOTHER service than the pane
//  holds, on purpose: the card that has to be told is not the one
//  that was asked to remove, so a signal that lived on one service
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

    @Test("The card is told its moving cover is gone, and asks the disk nothing")
    func theCardIsToldTheClipIsGone() async throws {
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
            CoverEntryCache.shared.evict(forKey: key, root: CardCoverService.coversRoot)

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
            let before = CoverEntryCache.shared.entry(forKey: key, root: CardCoverService.coversRoot)
            #expect(before?.videoURL != nil)

            // The removal, asked for through ANOTHER service than the
            // pane's own.
            CoverVideoService.live().removeVideo(for: target)
            // The removal REPLACED the held answer rather than dropping
            // it: the clip is gone from what the column holds at the
            // moment the write returns, and no folder had to be read to
            // find that out.
            let published = CoverEntryCache.shared.entry(forKey: key, root: CardCoverService.coversRoot)
            #expect(published?.videoURL == nil)
            #expect(published?.imageURL != nil)

            // THE WITNESS: the row wakes up, the card renders, and the
            // render asks the MAIN THREAD nothing. Before the fix this
            // same render knocked on the folder twice for this card, on
            // the main thread.
            let renderTally = CoverDiskCounting.Tally()
            CoverDiskCounting.$tally.withValue(renderTally) {
                settle(host: host, window: window)
            }
            #expect(
                renderTally.onMainThread == 0,
                "the render that a cover removal wakes asked the disk \(renderTally.onMainThread) time(s) on the MAIN thread"
            )
            let after = CoverEntryCache.shared.entry(forKey: key, root: CardCoverService.coversRoot)
            #expect(after?.videoURL == nil)
            // The entry holds the picture, so the answer the card got
            // was this library's cover and not a card that kept playing
            // a file that is already gone.
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
