//
//  SidebarIconUniformityTests.swift · Wenshu · v3.0
//
//  Validates the SFLabelRow central factory shape: every sidebar
//  row renders the same icon slot (= 16 PT frame, 2 PT inner
//  inset, .regular weight, .primary color) so the tree reads as
//  one visual column. Per (see OOB.md #2026-10-08) the wenshu
//  default follows Apple Mail / Notes / Xcode / System Settings:
//  the slot is constant; the optical width of each SF Symbol
//  floats ±4 PT inside the slot because Apple keeps each
//  symbol's intrinsic optical bounds. A future sweep can
//  optionally measure + scale (see icon-policy .scaleEffect
//  recipe), but the per-frame .regular weight + .hierarchical
//  rendering already produces the column-aligned look Apple
//  uses in its first-party apps.

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Sidebar icon uniformity")
struct SidebarIconUniformityTests {
    @Test("SFLabelRow uses the central icon factory and a fixed row slot")
    func sidebarRowUsesCentralFactoryAndFixedSlot() throws {
        let source = try Self.codeOnly(Self.source("Sources/WenshuApp/Shared/UI/IconStylesViews.swift"))
        let rowSource = try Self.sourceSlice(
            from: "struct SFLabelRow: View {",
            in: "Sources/WenshuApp/Shared/UI/IconStylesViews.swift"
        )
        // Factory shape: SFLabelRow delegates to SFIcon and pins the row slot via
        // sidebarWidth / sidebarInset. The delegation is a fact about the arguments
        // the factory receives (= the row's own symbol, style and colour), so the
        // guard reads the argument list. Which column each argument sits on belongs
        // to the formatter, and a guard that charges it reddens on a re-wrap that
        // moves no behaviour.
        let factoryArguments = Self.callArguments(of: "SFIcon(", in: rowSource)
        #expect(
            factoryArguments.contains { arguments in
                arguments.count >= 3
                    && arguments[0] == "systemImage"
                    && arguments[1] == "style: iconStyle"
                    && arguments[2] == "color: IconColor.primary"
            },
            "SFLabelRow must hand the central factory the row's symbol, style and colour (= three arguments, any layout)"
        )
        #expect(source.contains("padding(.horizontal, iconStyle.sidebarInset)"))
        #expect(source.contains("width: iconStyle.sidebarWidth"))
        // The slot is 16 PT wide; we don't force a square frame
        // (= Apple keeps each symbol's intrinsic height).
        #expect(!source.contains("height: iconStyle.sidebarHeight"))
        // The rendering mode belongs to the central factory: the
        // row wrapper sets none of its own. The factory applies
        // hierarchical rendering at .regular weight = Apple HIG
        // canonical sidebar row iconography.
        #expect(!source.contains(".symbolRenderingMode("))
        // Color = .primary (= Apple Tahoe sidebar default =
        // system text color, not app accent). One tier only.
        #expect(source.contains(".foregroundStyle(Color.primary)"))
        #expect(!source.contains(".foregroundStyle(.tint)\n            .opacity(iconOpacity)"))
        // IconStyle carries a dedicated .sidebar case so the slot
        // properties (sidebarWidth / sidebarInset) are scoped to
        // the sidebar surface (= not attached to every case via
        // an extension on IconStyle).
        // The `IconStyle` enum lives in IconStyles.swift (= the
        // view file holds the views that consume the cases). The case
        // itself is unchanged: `case sidebar` is still there.
        let iconStyles = try Self.codeOnly(Self.source("Sources/WenshuApp/Shared/UI/IconStyles.swift"))
        #expect(iconStyles.contains("case sidebar") || iconStyles.contains("case .sidebar"))
        #expect(
            iconStyles.contains(".symbolRenderingMode(.hierarchical)"),
            "the central factory must own the icon rendering mode"
        )
        #expect(!rowSource.contains("Image(systemName: systemImage)"))
    }

    @Test("IconStyle.sidebar is the canonical sidebar case (= 16 PT, .regular, slot properties)")
    func sidebarCaseIsCanonical() throws {
        let source = try Self.codeOnly(Self.source("Sources/WenshuApp/Shared/UI/IconStyles.swift"))
        // 16 PT point size matches Apple Mail / Notes / Xcode
        // sidebar row leading icon (= the wenshu default per
        // Apple's HIG sidebar anatomy).
        // 16 PT is the contract, so the guard reads the number the `pointSize`
        // switch answers for `.sidebar`. A bare case label carries no number: an
        // assertion satisfied by one cannot see a retuned tier, and a guard that a
        // size change leaves green guards no size.
        #expect(
            Self.caseValue(for: ".sidebar", inside: "var pointSize: CGFloat", in: source) == "16",
            "the sidebar tier must answer 16 PT from the pointSize switch"
        )
        // slot dimensions live in the extension on IconStyle so
        // they're explicit (= not piggy-backed on every case).
        // The guard binds the VALUE, not the one-line spelling: the
        // honesty rules re-wrapped these getters into multi-line
        // bodies, and a `contains` on `{ 16 }` would pin a layout
        // the contract never promised.
        #expect(Self.getterValue(of: "var sidebarWidth: CGFloat", in: source) == "16")
        #expect(Self.getterValue(of: "var sidebarInset: CGFloat", in: source) == "2")
        // SFLabelRow defaults to .sidebarTree (not .small) so a
        // caller that doesn't pass iconStyle still hits the
        // canonical sidebar surface. The default parameter lives
        // with the view (= IconStylesViews.swift), not with the
        // enum.
        let views = try Self.codeOnly(Self.source("Sources/WenshuApp/Shared/UI/IconStylesViews.swift"))
        #expect(views.contains("iconStyle: IconStyle = .sidebarTree") || views.contains("iconStyle: IconStyle = .sidebar"))
    }

    @Test("getterValue reads a value, not a spelling (= one-line, tight, and re-wrapped bodies agree)")
    func getterValueBindsTheValueNotTheLayout() {
        // The guard these tests use must survive the formatting the honesty
        // rules now require, so each spelling of the same getter has to read
        // back the same number. The line-break constant keeps the fixtures
        // out of a multi-line string literal (= whose indentation belongs to
        // the test file, not to the getter).
        let n = "\n"
        let spelled: [(name: String, source: String)] = [
            ("multi-line body", "extension IconStyle {" + n + "    var sidebarWidth: CGFloat {" + n + "        16" + n + "    }" + n + "}"),
            ("one-line spaced", "var sidebarWidth: CGFloat { 16 }"),
            ("one-line tight", "var sidebarWidth: CGFloat {16}"),
            ("one-line inside an extension", "extension IconStyle { var sidebarWidth: CGFloat { 16 } }"),
        ]
        for fixture in spelled {
            #expect(
                Self.getterValue(of: "var sidebarWidth: CGFloat", in: fixture.source) == "16",
                "\(fixture.name) must read as the same 16 PT slot"
            )
        }
        // A changed number is still a failure, and a renamed or removed
        // property answers nil (= it cannot pass by finding nothing).
        #expect(Self.getterValue(of: "var sidebarWidth: CGFloat", in: "var sidebarWidth: CGFloat {\n 18\n}") == "18")
        #expect(Self.getterValue(of: "var sidebarWidth: CGFloat", in: "var otherWidth: CGFloat {\n 16\n}") == nil)
    }

    @Test("caseValue and callArguments read a value and an argument list, not a layout")
    func scannersBindValuesNotColumns() {
        // The two scanners the assertions above lean on must survive every wrap the
        // formatter can pick, and must still answer differently when the VALUE moves.
        // The line-break constant keeps the fixtures out of a multi-line string
        // literal (= whose indentation belongs to the test file, not to the switch).
        let n = "\n"
        let sameLine = [
            "var pointSize: CGFloat {",
            "    switch self {",
            "        case .sidebar: 16",
            "        case .sidebarTree: 18",
            "    }",
            "}",
        ].joined(separator: n)
        let arm = "case .sidebar: 16"
        let wrapped = sameLine.replacingOccurrences(of: arm, with: "case .sidebar:" + n + "            16")
        let returned = sameLine.replacingOccurrences(of: arm, with: "case .sidebar: return 16")
        let sidebar = "var pointSize: CGFloat"
        for fixture in [sameLine, wrapped, returned] {
            #expect(
                Self.caseValue(for: ".sidebar", inside: sidebar, in: fixture) == "16",
                "the three wraps of one switch arm must read as the same 16 PT"
            )
        }
        // A retuned arm reads back its own number, and a sibling label that begins
        // with the same text cannot answer for `.sidebar` (= the label carries its
        // colon). A getter with no such arm answers nil.
        #expect(
            Self.caseValue(for: ".sidebar", inside: sidebar, in: sameLine.replacingOccurrences(of: arm, with: "case .sidebar: 14")) == "14"
        )
        #expect(
            Self.caseValue(for: ".sidebar", inside: sidebar, in: wrapped.replacingOccurrences(of: "case .sidebar:", with: "case .sidebarLabel:")) == nil
        )
        let expected = ["systemImage", "style: iconStyle", "color: IconColor.primary"]
        let oneLine = "SFIcon(systemImage, style: iconStyle, color: IconColor.primary)"
        let broken = "SFIcon(" + n + "    systemImage," + n + "        style: iconStyle," + n + "  color: IconColor.primary" + n + "    )"
        let uneven = "SFIcon(\n\t\t\tsystemImage, style: iconStyle,\n\t\t\tcolor: IconColor.primary)"
        for fixture in [oneLine, broken, uneven] {
            #expect(
                Self.callArguments(of: "SFIcon(", in: fixture) == [expected],
                "one call reads as one argument list whatever columns it sits on"
            )
        }
        // An argument the factory stops receiving shows, and a comma that belongs to
        // a nested call stays inside the argument that opened that call.
        #expect(
            Self.callArguments(of: "SFIcon(", in: oneLine.replacingOccurrences(of: "style: iconStyle", with: "style: .inlineSmall")) != [expected]
        )
        #expect(
            Self.callArguments(of: "SFIcon(", in: "SFIcon(systemImage, style: tier(iconStyle, iconStyle), color: IconColor.primary)")
                == [["systemImage", "style: tier(iconStyle, iconStyle)", "color: IconColor.primary"]]
        )
        // A call that only a comment spells out answers nothing: the scanner
        // reads code, so a commented-out call cannot satisfy an assertion
        // about the arguments of a call.
        let commented = "// SFIcon(systemImage, style: iconStyle, color: IconColor.primary)"
        #expect(
            Self.callArguments(of: "SFIcon(", in: commented).isEmpty,
            "a call written only in a comment is not a call"
        )
        #expect(
            Self.callArguments(of: "SFIcon(", in: commented + "\n" + oneLine) == [expected],
            "the real call still answers with a commented-out one above it"
        )
        // The same holds for the other two scanners: a value that only a
        // comment spells out answers nil, and a real one still answers with
        // the comment present.
        let commentedGetter = "// var sidebarWidth: CGFloat {\n//   18\n// }"
        #expect(
            Self.getterValue(of: "var sidebarWidth: CGFloat", in: commentedGetter) == nil,
            "a getter that only a comment spells out is not a getter"
        )
        let commentedCase = "// case .sidebar: 18"
        #expect(
            Self.caseValue(for: ".sidebar", inside: sidebar, in: commentedCase) == nil,
            "a switch arm that only a comment spells out is not an arm"
        )
        #expect(
            Self.caseValue(for: ".sidebar", inside: sidebar, in: commentedCase + "\n" + sameLine) == "16",
            "the real arm still answers with a commented-out one above it"
        )
    }

    @Test("the files the scanners read carry no multi-line or raw string literal")
    func theReadFilesCarryNoMultiLineLiteral() throws {
        // The scanners walk the text and end a literal at the next quote, so a
        // multi-line (`"""`) or raw (`#"`) literal would end the walk early
        // and the comment-stripping would mis-read the rest of the file. That
        // assumption is checked here rather than believed.
        for relativePath in [
            "Sources/WenshuApp/Shared/UI/IconStylesViews.swift",
            "Sources/WenshuApp/Shared/UI/IconStyles.swift",
        ] {
            let text = try Self.source(relativePath)
            #expect(
                !text.contains("\"\"\"") && !text.contains("#\""),
                "\(relativePath) carries a multi-line or raw string literal, and the scanners read literals as single-line ones"
            )
        }
    }

    private static func sourceSlice(
        from start: String,
        in relativePath: String
    ) throws -> String {
        let source = try source(relativePath)
        guard let startRange = source.range(of: start) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // The slice runs to the end of the file: the declaration is
        // the last one in it, so there is no following MARK to bound
        // it.
        //
        // The slice is returned without its comments (= `codeOnly`), so a
        // commented-out line inside it cannot satisfy an assertion about it.
        return codeOnly(String(source[startRange.lowerBound...]))
    }

    /// The value a one-statement computed-property getter returns, as written
    /// in the source. Braces are counted, not searched for, so the getter's
    /// own `}` ends the value and an enclosing scope's `}` on the same line
    /// does not: the one-line form (`{ 16 }`), the tight form (`{16}`), a
    /// one-line getter inside an extension, and the multi-line body the
    /// honesty rules re-wrapped this getter into all read as the same value.
    /// A renamed or removed property answers nil (= the assertion fails)
    /// instead of silently passing.
    private static func getterValue(of declaration: String, in source: String) -> String? {
        let source = codeOnly(source)
        let head = declaration + " {"
        let lines = source.components(separatedBy: "\n")
        var body: [String] = []
        var insideGetter = false
        // `depth` counts the scopes opened INSIDE the getter's body, which
        // is what remains after the head anchor has consumed the getter's
        // own `{`. A nested `{` therefore pushes the level to 1 and only the
        // matching `}` brings it back to 0 (= the getter's own closing brace).
        var depth = 0
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            var remainder = line
            if !insideGetter {
                guard let headRange = line.range(of: head) else { continue }
                insideGetter = true
                remainder = String(line[headRange.upperBound...])
            }
            // Scan the line's own braces: depth returns to 0 only at the
            // getter's closing `}`, and the text before it is the value.
            var cut = remainder.endIndex
            var reachedEndOfGetter = false
            for index in remainder.indices {
                let character = remainder[index]
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    // The getter's own closing `}` is the one seen while no
                    // nested scope is open, so the test comes BEFORE the
                    // counter drops (a nested `}` only ever closes a level
                    // that its own `{` opened).
                    if depth == 0 {
                        cut = index
                        reachedEndOfGetter = true
                        break
                    }
                    depth -= 1
                }
            }
            body.append(String(remainder[..<cut]))
            if reachedEndOfGetter {
                return body
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
            }
        }
        return insideGetter ? body.joined(separator: " ") : nil
    }

    /// The value one `switch` arm answers for a case label, read from inside the
    /// getter named by `declaration`. The getter's body is bounded by counted braces
    /// (= `getterValue(of:in:)` above, so the enclosing scope's `}` cannot end it),
    /// then the label is located and the first word after it is the value:
    /// `case .sidebar: 16`, the same arm with its number wrapped onto the next line,
    /// and `case .sidebar: return 16` all read as `16`. The label carries its own
    /// colon, so `.sidebar` is not answered by a sibling label that begins the same
    /// way. A getter without that arm, or an arm without a value, answers nil
    /// (= the assertion fails instead of passing on nothing).
    private static func caseValue(for label: String, inside declaration: String, in source: String) -> String? {
        let source = codeOnly(source)
        guard let body = getterValue(of: declaration, in: source),
              let anchor = body.range(of: "case \(label):")
        else {
            return nil
        }
        for word in body[anchor.upperBound...].split(whereSeparator: \.isWhitespace) {
            if word == "case" || word == "}" {
                return nil
            }
            if word != "return" {
                return String(word)
            }
        }
        return nil
    }

    /// Every argument list the source passes to `call`, one entry per occurrence.
    /// An argument ends at a comma that sits at the call's own depth, and the depth
    /// counts `(`, `[` and `{`, so a nested call's commas stay inside the argument
    /// that opened it. Each argument's whitespace runs collapse to single spaces,
    /// which is what makes the columns the call wraps at invisible to the reader.
    /// Quoted text is not exempt from the split (= an argument carrying a quoted
    /// comma would split; none of the calls this suite reads does). An occurrence
    /// inside a comment yields NO list (= the comments are taken out before the
    /// scan), so a call only a comment spells out cannot answer; a real call does.
    private static func callArguments(of call: String, in source: String) -> [[String]] {
        let source = codeOnly(source)
        var lists: [[String]] = []
        var search = source[...]
        while let found = search.range(of: call) {
            var arguments: [String] = []
            var argument = ""
            var depth = 1
            var cursor = found.upperBound
            while cursor < source.endIndex {
                let character = source[cursor]
                if "([{}".contains(character) {
                    depth += 1
                } else if ")]}".contains(character) {
                    depth -= 1
                    if depth == 0 {
                        break
                    }
                } else if character == ",", depth == 1 {
                    arguments.append(String(argument.split(whereSeparator: \.isWhitespace).joined(separator: " ")))
                    argument = ""
                    source.formIndex(after: &cursor)
                    continue
                }
                argument.append(character)
                source.formIndex(after: &cursor)
            }
            let last = String(argument.split(whereSeparator: \.isWhitespace).joined(separator: " "))
            if !last.isEmpty {
                arguments.append(last)
            }
            lists.append(arguments)
            search = source[found.upperBound...]
        }
        return lists
    }

    /// The source with every comment taken out, character for character.
    ///
    /// A line comment (`//` to the end of the line) and a block comment
    /// (`/* ... */`, nested the way Swift nests them) are replaced by spaces,
    /// so the text keeps its line count AND its character positions: a
    /// scanner that counts braces, counts lines, or reports an offset still
    /// sees the same shape. A `//` inside a string literal is left alone,
    /// because the literal is code.
    ///
    /// Without this, a scanner that reads the raw text can be answered by a
    /// call that only a comment spells out: the production file names
    /// `SFIcon(` in a comment, so a commented-out call would satisfy an
    /// assertion about the arguments of a call.
    ///
    /// One assumption is made here and it is CHECKED by the suite rather than
    /// believed: a string literal in the files this suite reads is a
    /// single-line literal. A multi-line (`"""`) or raw (`#"`) literal would
    /// end this walk early, so the suite fails if either appears.
    private static func codeOnly(_ source: String) -> String {
        var result = ""
        var index = source.startIndex
        var inString = false
        var escaped = false
        var blockDepth = 0
        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            if blockDepth > 0 {
                if character == "/", next < source.endIndex, source[next] == "*" {
                    blockDepth += 1
                    result += "  "
                    index = source.index(after: next)
                    continue
                }
                if character == "*", next < source.endIndex, source[next] == "/" {
                    blockDepth -= 1
                    result += "  "
                    index = source.index(after: next)
                    continue
                }
                result += character == "\n" ? "\n" : " "
                index = next
                continue
            }
            if inString {
                result.append(character)
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
                index = next
                continue
            }
            if character == "\"" {
                inString = true
                result.append(character)
                index = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                // The rest of the line is a comment.
                while index < source.endIndex, source[index] != "\n" {
                    result.append(" ")
                    index = source.index(after: index)
                }
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "*" {
                blockDepth = 1
                result += "  "
                index = source.index(after: next)
                continue
            }
            result.append(character)
            index = next
        }
        return result
    }

    private static func source(_ relativePath: String) throws -> String {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            let package = current.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                let url = current.appendingPathComponent(relativePath)
                let data = try Data(contentsOf: url)
                // Try UTF-8 first; fall back to system encoding if it isn't valid UTF-8.
                if let s = String(data: data, encoding: .utf8) {
                    return s
                }
                return try String(contentsOf: url)
            }
            current.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
