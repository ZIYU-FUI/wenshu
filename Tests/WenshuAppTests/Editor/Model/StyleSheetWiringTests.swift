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

    /// The write-back calls in a body that carry the given argument labels.
    ///
    /// A call is a `BookStyleSheetWriteBack.apply(` with its arguments
    /// spanning to the matching close. = = A call is identified by the
    /// LABELS it carries (= = `knob:` and `position:` are the knob's own),
    /// = = NOT by a spelling of its target: = = so a second path that
    /// happens to write the same book the same way is a different call,
    /// = = and the knob's own call is still found.
    private static func calls(
        in body: String,
        carrying labels: [String]
    ) -> [(target: String, text: String, line: Int, depth: Int)] {
        var found: [(target: String, text: String, line: Int, depth: Int)] = []
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let depths = Self.braceDepths(of: lines)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard line.contains("BookStyleSheetWriteBack.apply(") else {
                index += 1
                continue
            }
            // = = the call's arguments span to the line that closes it = =
            var text = line
            var cursor = index
            while !text.contains(")"), cursor + 1 < lines.count {
                cursor += 1
                text += "\n" + lines[cursor]
            }
            let carries = labels.allSatisfy { text.contains($0) }
            if carries {
                // = = the `to:` argument's VALUE, = = with the argument's
                // = = trailing comma removed (= = `to: bookID,` names the
                // = = book `bookID`). = = The value must be the bare name:
                // = = `bookID.first` or `bookID ?? other` would name
                // = = something else.
                let target = text
                    .split(separator: "\n")
                    .compactMap { line -> String? in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("to:") else { return nil }
                        var value = String(trimmed.dropFirst("to:".count))
                        while value.last == "," || value.last == " " {
                            value.removeLast()
                        }
                        while value.first == " " {
                            value.removeFirst()
                        }
                        return value
                    }
                    .first ?? ""
                found.append((target, text, index, depths[index]))
            }
            index = cursor + 1
        }
        return found
    }

    /// The brace depth at the START of each line.
    ///
    /// A depth is the number of scopes OPEN at that line, = = so a
    /// declaration and the call it feeds sit at the same depth when they
    /// share a scope, = = and a nested path's own declaration sits deeper.
    /// This is what separates the knob's OWN binding from a second path's:
    /// the first SHADOWS the knob's write (= = and must be counted), = =
    /// the second is that path's own (= = and must not be).
    private static func braceDepths(of lines: [String]) -> [Int] {
        var depths: [Int] = []
        var depth = 0
        for line in lines {
            depths.append(depth)
            for character in line {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                }
            }
        }
        return depths
    }

    /// The SCOPE CHAIN of every line: = = the list of scope IDs the
    /// line sits in, = = outermost first.
    ///
    /// WHY A CHAIN AND NOT A DEPTH: = = a depth is a NUMBER and a scope
    /// is an IDENTITY, = = and two scopes at the same depth can be
    /// SIBLINGS (= = a `catch` block beside the `do` block that holds
    /// the call). = = The measurement that failed read a depth, = = so a
    /// sibling scope looked like the call's own. = = A chain says WHICH
    /// scopes enclose the line, = = so a sibling is not an ancestor.
    ///
    /// A scope's ID is the index of the line that opened it, = = so two
    /// scopes at the same depth are still different scopes.
    private static func scopeChains(of lines: [String]) -> [[Int]] {
        var chains: [[Int]] = []
        var stack: [Int] = []
        for (index, line) in lines.enumerated() {
            chains.append(stack)
            // A line's own braces open scopes AFTER it: = = the line
            // belongs to the scope it is written in, = = and the scope
            // it opens belongs to what follows.
            var characters = Array(line)
            // A string literal's braces are not scopes. = = The tree's
            // own shapes put no braces in the literals this reads, = =
            // but a `"}"` inside a string would otherwise close a scope
            // that never opened.
            var inString = false
            var escaped = false
            var index2 = 0
            while index2 < characters.count {
                let character = characters[index2]
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString.toggle()
                } else if !inString {
                    if character == "{" {
                        stack.append(index)
                    } else if character == "}" {
                        if !stack.isEmpty { stack.removeLast() }
                    }
                }
                index2 += 1
            }
        }
        return chains
    }

    /// The scope chain a BINDING introduces, = = and the line it is
    /// written on.
    ///
    /// A plain `let` / `var` binds in the scope it is written in. = = An
    /// `if let` / `guard let` / `while let` binds in the scope its BODY
    /// opens (= = Swift's rule: = = the optional binding shadows the
    /// outer name FOR THE BODY, = = and not outside it). = = So the
    /// optional binding's scope is the `{` that follows it, = = and that
    /// is the scope that encloses a call the binding can shadow.
    private static func bindingScope(
        of lines: [String],
        at line: Int,
        chains: [[Int]],
        opensBody: Bool
    ) -> [Int] {
        if !opensBody {
            return chains[line]
        }
        // The scope the body opens = = the next `{` after this line.
        var index = line + 1
        while index < lines.count {
            if lines[index].contains("{") {
                return chains[index] + [index]
            }
            index += 1
        }
        return chains[line]
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
            "the page must write the sheet back at all (= the knobs are not read-only)"
        )
        // = = THE KNOB'S OWN CALL, = = NOT A SPELLING. = =
        // = =
        // = = The last round measured this failing: = = a count of the
        // = = lines carrying `to: bookID,` is satisfied by a SECOND
        // = = write-back inside the body that spells the same thing, = =
        // = = while the knob's real call names the store's FIRST book. = =
        // = = And the same count turns a legitimate second path RED when
        // = = that path happens to spell its target the same way. = = So
        // = = the outcome depended on the NAME a path used, = = not on
        // = = what it did.
        // = =
        // = = The anchor is the knob's OWN call: = = the one that carries
        // = = the knob's arguments (`knob:` and `position:`). = = There
        // = = must be exactly ONE such call in `moveKnob`'s body, = = and
        // = = THAT call's `to:` must be exactly `bookID`.
        let knobBody = try Self.body(of: code, of: "private func moveKnob(")
        let knobCalls = Self.calls(in: knobBody, carrying: ["knob:", "position:"])
        XCTAssertEqual(
            knobCalls.count,
            1,
            "the knob must make EXACTLY ONE write-back of its own (= a second one is a second path, = = and the knob's own write is the one that decides which book it writes)"
        )
        XCTAssertEqual(
            knobCalls.first?.target,
            "bookID",
            "the knob's own write-back must name the book it SHOWS (= the store's first book is not the page's book)"
        )
        // = = And the page does write the sheet back at all: = = the knob's
        // = = own call is what this test now reads, = = so the file-wide
        // = = check stays as the page-level statement it is.
        XCTAssertTrue(
            code.contains("try BookStyleSheetWriteBack.apply("),
            "the page must write the sheet back at all (= the knobs are not read-only)"
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
        // = = THE KNOB'S OWN BINDING, = = READ BY SCOPE. = =
        // = = = =
        // = = A binding is the knob's own when the scope it sits in
        // = = ENCLOSES the knob's own write-back. = = Two arms follow from
        // = = that, = = and both were measured by the round-7 review:
        // = = = =
        // = = = = A declaration in the CALL'S OWN scope SHADOWS the knob's
        // = = = = write (= = Swift's scoping is the mechanism), = = so the
        // = = = = knob writes ANOTHER book's sheet = = and it must be
        // = = = = COUNTED (= = the page binds twice = = red).
        // = = = = A nested path's own declaration is DEEPER than the call,
        // = = = = so it is that path's own (= = a real path, = = writing a
        // = = = = real book) = = and it must NOT be counted (= = green).
        // = = = =
        // = = And a DECLARATION is not an OPTIONAL BINDING: = = `if let
        // = = = = bookID = currentBookID` is Swift's optional binding, = =
        // = = = = and it introduces a shadow in an inner scope. = = So the
        // = = = = line must BEGIN with `let bookID =`.
        // = = = =
        // = = So the anchor reads the DECLARATIONS whose scope encloses the
        // = = knob's own call, = = and NOT every line that matches a text
        // = = pattern. = = The last round measured what a text pattern
        // = = costs: = = a conjunct that read `currentBookID` dropped a
        // = = = = harmful declaration from the count (= = green), = = and
        // = = = = kept a legitimate one in (= = red), = = so the verdict
        // = = = = followed the NAME a path used, = = not what it did.
        let moveKnob = try Self.body(of: code, of: "private func moveKnob(")
        let knobLines = moveKnob
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        // = = the knob's OWN call is found by the LABELS in its argument
        // = = block (= = the same rule the call-site anchor reads), = = so
        // = = a decoy `apply(` before it cannot be mistaken for it.
        guard let knobCall = knobCalls.first else {
            XCTFail("the knob makes no write-back of its own, = = so its binding cannot be read")
            return
        }
        // = = THE BINDING IS FOUND BY THE NAME IT BINDS AND THE FORM OF
        // = = THE BINDING, = = NOT BY A PREFIX ON THE WHOLE LINE.
        // = =
        // = = A prefix misses every harm that spells the same binding
        // = = differently: = = a type annotation (= = `let bookID: UUID
        // = = =`), = = two spaces (= = `let  bookID =`), = = a `var`,
        // = = and an optional binding (= = `if let bookID = ...`) that
        // = = ENCLOSES the knob's own call. = = All four shadow the
        // = = knob's write-back, = = and all four were GREEN.
        let knobChains = Self.scopeChains(of: knobLines)
        let callChain = knobChains[knobCall.line]
        let bindings = knobLines.enumerated().compactMap { index, line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // = = the FORM of the binding, = = and the NAME it binds.
            let opensBody: Bool? =
                if trimmed.range(of: #"\b(if|guard|while)\s+let\s+bookID\b"#, options: .regularExpression) != nil {
                    (true)
                } else if trimmed.range(of: #"\b(let|var)\s+bookID\b"#, options: .regularExpression) != nil {
                    (false)
                } else {
                    nil
                }
            guard let opensBody else { return nil }
            // = = the binding's own scope, = = by IDENTITY and not by
            // = = depth: = = an optional binding binds in the scope its
            // = = body opens, = = and a plain one binds where it is
            // = = written.
            let bindChain = Self.bindingScope(
                of: knobLines, at: index, chains: knobChains, opensBody: opensBody
            )
            // = = VISIBLE = = the binding's scope is an ANCESTOR of the
            // = = call's scope, = = or the SAME scope. = = A scope that
            // = = merely has the same DEPTH (= = a sibling, = = like a
            // = = `catch` block beside the `do` block that holds the
            // = = call) is not an ancestor, = = and must not count.
            guard bindChain.count <= callChain.count else { return nil }
            guard Array(callChain.prefix(bindChain.count)) == bindChain else { return nil }
            // = = in the SAME scope, = = the binding must come BEFORE
            // = = the call: = = a declaration after it cannot shadow it.
            if bindChain.count == callChain.count, index > knobCall.line { return nil }
            return trimmed
        }
        XCTAssertEqual(
            bindings.count,
            1,
            "the page binds the book it shows EXACTLY ONCE (= a second binding in the knob's own scope shadows its write)"
        )
        XCTAssertTrue(
            bindings.first == "let bookID = currentBookID",
            "the book the page writes must be the book it SHOWS (= the binding must be exactly currentBookID, = = and no fallback to the store's first book)"
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
