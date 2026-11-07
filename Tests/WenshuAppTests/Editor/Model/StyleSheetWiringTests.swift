//
//  StyleSheetWiringTests.swift · Wenshu
//
//  The sheet's WIRING, held where it cannot be measured through a
//  window.
//
//  WHY THESE ARE SOURCE CHECKS
//
//  Five of the sheet's joins live inside a SwiftUI view's own action
//  or identity (= the knob's menu hands a value over, = the page's own
//  write-back, = the engine view is keyed by a fingerprint, = the
//  sidebar's click names a book, = and the write-back's save), = and
//  none of them is reachable from a test's own call: = a test can read
//  the MODEL's field, = but the JOIN is in the view.
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

    /// THE EDITOR HANDS THE SHEET'S TWO NEW VOICES OVER.
    ///
    /// = The roles exist in the engine (= `configuration.footnotes` and
    /// `configuration.captions`), = and the sheet's sizes reach them
    /// only if the editor WRITES them into the configuration it gives
    /// the engine. = So the hand-over itself is a join, = and a join in
    /// a view's own body is a source check (= the house's own idiom for
    /// this seam, = = the engine keying above).
    ///
    /// MUTATION: = the editor's `adjustedConfiguration` leaves the two
    /// knobs at the engine's default (= the sheet's sizes never reach
    /// the screen) = = and the bridge's own mapping tests stay green
    /// (= they measure the mapping, = not the hand-over).
    func testTheEditorHandsTheContentRolesOver() throws {
        let code = try Self.code(of: "Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        XCTAssertTrue(
            code.contains("config.footnotes = EngineStyleSheetBridge.footnoteStyle(for: styleSheet)"),
            "the editor must hand the sheet's note voice to the engine (= a footnote that wears no voice of its own)"
        )
        XCTAssertTrue(
            code.contains("config.captions = EngineStyleSheetBridge.captionStyle(for: styleSheet)"),
            "the editor must hand the sheet's caption sizes to the engine (= a caption that wears no size of its own)"
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

    /// The body of ONE function, = scoped by brace balance.
    ///
    /// = A whole-file source-text assertion holds a PREFIX, = and a
    /// prefix is satisfied by a DECOY anywhere in the file (= the same
    /// hole, = one level up). = So an assertion about what a function
    /// does is read from that function's OWN body, = and the body is
    /// found by counting braces from the declaration.
    private static func body(of code: String, of declaration: String) throws -> String {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.contains(declaration) }) else {
            throw NSError(
                domain: "StyleSheetWiringTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "no declaration names \(declaration)"]
            )
        }
        var depth = 0
        var body: [String] = []
        for index in start ..< lines.count {
            let line = lines[index]
            body.append(line)
            for character in line {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                }
            }
            // = The declaration's own braces are balanced, = so the
            // body ends at the line that closes them.
            if index > start, depth <= 0 {
                break
            }
        }
        return body.joined(separator: "\n")
    }

    /// THE PAGE'S OWN CALL WRITES THE BOOK IT IS SHOWING.
    ///
    /// MUTATION: = the call removed (= the knob writes nothing at all),
    /// = or `to: bookStore.books.first?.id ?? bookID` (= a knob moved on
    /// one book writes ANOTHER book's sheet, = and the write-back's own
    /// guard passes, = because that book IS in the store).
    func testThePageWritesTheBookItIsShowing() throws {
        let code = try Self.code(of: "Sources/WenshuApp/Features/Editor/View/InspectorStylePageView.swift")
        XCTAssertTrue(
            code.contains("try BookStyleSheetWriteBack.apply("),
            "the page must write the sheet back (= the knobs are not read-only)"
        )
        XCTAssertTrue(
            code.contains("to: bookID,"),
            "the page must write the book it is showing (= the store's first book is not the page's book)"
        )
        // The call site spells the id, = but the BINDING decides which
        // book that name carries: = a page that binds the store's first
        // book writes ANOTHER book's sheet, = and the write-back's own
        // guard passes it (= that book IS in the store).
        // = The BINDING decides which book that name carries, = and a
        // whole-file `contains` holds a PREFIX, = not the binding: =
        // `let bookID = currentBookID ?? bookStore.books.first?.id`
        // keeps the anchored prefix, = so the page would write the
        // store's FIRST book while showing another (= and the
        // write-back's own guard passes it, = because that book IS in
        // the store).
        //
        // = So the assertion is scoped to `moveKnob`'s OWN body, = and
        // it holds the WHOLE binding: = exactly ONE `let bookID =` in
        // that body, = and it is exactly `currentBookID`. = A second,
        // unrelated `let bookID = currentBookID` elsewhere in the file
        // satisfies a whole-file `contains` (= the decoy), = so the
        // count is part of the guard.
        let moveKnob = try Self.body(of: code, of: "private func moveKnob(")
        let bindings = moveKnob
            .split(separator: "\n")
            .filter { $0.contains("let bookID =") }
        XCTAssertEqual(
            bindings.count,
            1,
            "the page binds the book it shows EXACTLY ONCE (= a second binding is a decoy that satisfies a whole-file contains)"
        )
        XCTAssertTrue(
            bindings.first?.trimmingCharacters(in: .whitespaces)
                == "let bookID = currentBookID",
            "the book the page writes must be the book it SHOWS (= the binding must be exactly currentBookID, = with no fallback that names another book)"
        )
    }

    /// THE WRITE-BACK REPORTS ITS FAILURE INSTEAD OF SWALLOWING IT.
    ///
    /// MUTATION: = `try store.sidebarSaveBook(book)` -> `try?` (= the
    /// failure is swallowed, = so a book that did not reach the disk is
    /// reported as written).
    func testTheWriteBackReportsItsFailure() throws {
        let code = try Self.code(of: "Sources/WenshuApp/Features/Library/Service/BookStyleSheetWriteBack.swift")
        XCTAssertTrue(
            code.contains("try store.sidebarSaveBook(book)"),
            "the write-back must let the save's failure through (= a write that could not reach the disk is not a write)"
        )
        XCTAssertFalse(
            code.contains("try? store.sidebarSaveBook(book)"),
            "a swallowed failure reports success for a book that did not change"
        )
        // `try` alone does not prove the failure ESCAPES: = a `catch`
        // right below it swallows the failure just as well, = and the
        // string above is still in the file.
        XCTAssertFalse(
            code.contains("catch"),
            "the write-back must not catch the save's failure (= a failure caught here is a failure the caller never sees)"
        )
    }
}
