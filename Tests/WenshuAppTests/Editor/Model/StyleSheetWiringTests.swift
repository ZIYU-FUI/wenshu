//
//  StyleSheetWiringTests.swift · Wenshu
//
//  The sheet's WIRING, held where it cannot be measured through a
//  window.
//
//  WHY THESE ARE SOURCE CHECKS
//
//  Three of the sheet's joins live inside a SwiftUI view's own action
//  or identity (= the knob's menu hands a value over, = the engine
//  view is keyed by a fingerprint, = the sidebar's click names a
//  book), = and none of them is reachable from a test's own call: = a
//  test can read the MODEL's field, = but the JOIN is in the view.
//  So the join is checked where it is: = in the source that carries
//  it, = anchored on the EXACT expression, = so the mutation that
//  changes the expression turns this red.
//
//  The house pattern (= the dropped-commands check in
//  `InspectorStylePageRenderTests`) is the same shape, = and the
//  anchors are deliberately exact: = a check that the assignment
//  EXISTS would not notice that it names the WRONG book.
//
//  Each check names the mutation it holds.
//

import Foundation
@testable import WenshuApp
import XCTest

final class StyleSheetWiringTests: XCTestCase {
    /// THE KNOB'S MENU HANDS OVER THE RAW VALUE.
    ///
    /// MUTATION: = `onChoose(position.label)` = is the round-1
    /// blocker verbatim: = the sheet reads a position by its raw
    /// value, = so a display name makes every knob write a no-op, = and
    /// the write-back's own tests stay green (= they hand it raw
    /// values themselves).
    func testTheKnobsMenuHandsOverTheRawValue() throws {
        let code = try Self.code(of: "Sources/WenshuApp/Features/Editor/View/InspectorStyleKnobView.swift")
        XCTAssertTrue(
            code.contains("onChoose(position.rawValue)"),
            "the knob's menu must hand over the position's RAW value (= the sheet reads a position by that name)"
        )
        XCTAssertFalse(
            code.contains("onChoose(position.label)"),
            "a display name is not a position (= the sheet cannot read it back)"
        )
    }

    /// THE ENGINE VIEW IS KEYED BY THE SHEET'S FINGERPRINT.
    ///
    /// MUTATION: = `.id("wenshu-constant")` = computes the
    /// fingerprint and throws it away: = the engine never remounts, = so
    /// the reader's sheet change never reaches the editor, = and the
    /// bridge's own fingerprint test stays green (= it measures the
    /// fingerprint, = not the keying).
    func testTheEngineViewIsKeyedByTheFingerPrint() throws {
        let code = try Self.code(of: "Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        XCTAssertTrue(
            code.contains(".id(EngineStyleSheetBridge.fingerprint(for: styleSheet))"),
            "the engine view must be keyed by the sheet's fingerprint (= a changed sheet remounts the engine)"
        )
    }

    /// THE SIDEBAR'S CLICK NAMES THE OWNING BOOK.
    ///
    /// MUTATION: = `node.id` alone = names a folder row's own
    /// SYNTHETIC id (= `SidebarService.stableFolderId(bookId:folderName:)`),
    /// = which matches no book, = so every reader falls back to the
    /// print baseline. = So the check is on the VALUE assigned, = not
    /// on the assignment's presence.
    func testTheSidebarNamesTheOwningBook() throws {
        let code = try Self.code(of: "Sources/WenshuApp/Features/Library/View/AppleSidebarSelection.swift")
        XCTAssertTrue(
            code.contains("bookStore.selectedBookId = parent?.bookId ?? node.id"),
            "a folder row must name the book that OWNS the folder (= not the folder's own synthetic id)"
        )
    }

    /// The production source, with its comments stripped (= the house
    /// helper's shape, = so an anchor can never be satisfied by a
    /// comment).
    private static func code(of relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Model
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        let source = try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
        return source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") {
                    return ""
                }
                return String(line.replacingOccurrences(
                    of: #"(?<!:)//.*$"#,
                    with: "",
                    options: .regularExpression
                ))
            }
            .joined(separator: "\n")
    }
}
