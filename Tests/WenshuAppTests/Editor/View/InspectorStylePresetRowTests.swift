//
//  InspectorStylePresetRowTests.swift · Wenshu
//
//  The two sets a book can be set to, = drawn as the rows they are: =
//  the set the book is at carries a mark, = the one it is not at carries
//  nothing, = and the name is painted once.
//
//  WHY THIS IS MEASURED IN WHAT IS DRAWN
//
//  The row is a `Button`, = and a `Button` publishes NOTHING to the
//  accessibility tree of an offscreen hosting view (= measured against a
//  `Menu`, = which publishes its label: = a button's label, = identifier
//  and value all read empty there). = So the mark is proven by the ink it
//  puts on the row (= the same reading the tab strip's close button is
//  held by), = which is also the only way to answer the complaint the
//  row was rewritten for: = a name painted three times in one line.
//
//  WHY IT IS A SUITE OF ITS OWN
//
//  It renders ONE ROW, = not the page, = and holds AGENTS.md 6.6's
//  ceiling beside the page's own suite.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Inspector style page, the set rows", .serialized)
struct InspectorStylePresetRowTests {
    /// The page marks the set the book is at, = and only that one.
    ///
    /// WHY THIS IS MEASURED IN WHAT IS DRAWN
    ///
    /// The set's row is a `Button` now, = and a `Button` publishes
    /// NOTHING to the accessibility tree of an offscreen hosting view
    /// (= measured against a `Menu`, = which publishes its label: = the
    /// four variants of a button's label, = identifier and value all
    /// read empty). = So the mark is proven by the ink it puts on the
    /// row, = which is also the only thing the boss's complaint can be
    /// answered with: = the name painted once, = and one mark.
    @Test("the page marks the set the book is at")
    func thePageMarksTheSetTheBookIsAt() throws {
        let marked = drawnInk(isCurrent: true)
        let unmarked = drawnInk(isCurrent: false)

        #expect(!marked.isEmpty && !unmarked.isEmpty, "both rows drew (= no ink at all is a broken fixture)")
        #expect(
            marked.count > unmarked.count,
            "the set the book is at carries a mark, = and the set it is not at carries nothing (= \(marked.count) inked columns against \(unmarked.count))"
        )
        //  The left of the row is the set's NAME, = painted once and in
        //  one place: = marked or not, the columns before the mark's
        //  must be identical (= a name written twice, = or pushed along
        //  by the mark, = fails here).
        let before = Self.markEdge
        #expect(
            unmarked.filter { $0 < before } == marked.filter { $0 < before },
            "the set's name is painted once, = and the mark does not move it"
        )
    }

    /// The x-column where the mark begins.
    ///
    /// The row is drawn `Self.rowWidth` POINTS wide, = and the bitmap
    /// is 2× (= 2 pixels to a point), = so the whole row is twice that
    /// many pixels wide, = and its middle is `rowWidth` pixels in. = The
    /// mark rides the trailing edge, = so everything left of the middle
    /// is the set's name.
    private static let markEdge = rowWidth

    /// One set row, drawn at the width the inspector's column gives it,
    /// as the x-columns that carry ink.
    private func drawnInk(isCurrent: Bool) -> [Int] {
        let host = NSHostingView(rootView: AnyView(
            InspectorStylePresetView(preset: .general, isCurrent: isCurrent) { _ in }
                .frame(width: CGFloat(InspectorStylePresetRowTests.rowWidth),
                       height: CGFloat(InspectorStylePresetRowTests.rowHeight))
        ))
        host.frame = NSRect(
            x: 0, y: 0,
            width: CGFloat(InspectorStylePresetRowTests.rowWidth),
            height: CGFloat(InspectorStylePresetRowTests.rowHeight)
        )
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            Issue.record("the set row gave no bitmap to read")
            return []
        }
        rep.size = host.bounds.size
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.bitmapData else {
            Issue.record("the set row's bitmap carried no bytes")
            return []
        }
        //  The offscreen cache holds the page's own transparency, = so
        //  the glyphs are exactly the pixels that carry alpha (= the
        //  same reading the tab strip's close-button test reads).
        var inked: Set<Int> = []
        for y in 0 ..< rep.pixelsHigh {
            for x in 0 ..< rep.pixelsWide {
                let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
                if Int(data[offset + 3]) > 20 {
                    inked.insert(x)
                }
            }
        }
        return inked.sorted()
    }

    /// The width a set row is drawn at (= the inspector's column, less
    /// its own padding), and its height.
    private static let rowWidth = 252
    private static let rowHeight = 20

    /// The marked row's label, = and the unmarked row's, = for a reader.
    ///
    /// The row is a `Button`, = and a `Button` is what the format page's
    /// commands are too (= the page's commands are proven the same way:
    /// = the label is carried for VoiceOver, = and the drawing proves
    /// what the offscreen tree cannot read). = The mark is a tick in the
    /// label, = so a reader hears WHERE the book stands and not only
    /// WHAT the row is called, = and no new word is invented for the
    /// state (= neither mark showing is the book being fine-tuned off
    /// both sets, = which the page leaves unnamed).
    @Test("a set row names itself, and the mark with it")
    func aSetRowNamesItselfAndTheMarkWithIt() throws {
        let code = try InspectorAXTree.code(of: String(
            contentsOf: Self.presetSourceURL(),
            encoding: .utf8
        ))
        #expect(
            code.contains("if isCurrent {"),
            "the mark is carried by the row the book is at (= and only that row)"
        )
        #expect(
            code.contains("\\(preset.displayName) ✓"),
            "the published label carries the mark, = and the set's own name (= once)"
        )
        #expect(
            !code.contains("Menu {"),
            "a set is a row, = not a drop-down (= two sets is nothing to drop down)"
        )
    }

    /// The set row's own source file (= where its mark is written).
    private static func presetSourceURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorStylePresetView.swift")
    }
}
