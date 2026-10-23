//
//  SFSymbolResolutionTests.swift · WenshuAppTests
//
//  Every SF Symbol name the app renders must EXIST in the system
//  symbol set.
//
//  WHY THIS TEST EXISTS
//  The main window's toolbar crashed the app with EXC_BREAKPOINT when
//  the app's preferences changed. The chain (from the crash report's
//  asiBacktraces) was:
//
//    NSHostingView.preferencesDidChange
//      -> AppKitWindowController.hostingView(_:didChangePreferences:)
//      -> updateToolbarBridge(hosting:preferences:)
//      -> AppKitToolbarStrategy.willReturnUpdates(preferences:)
//      -> Toolbar.LocationStorage.updated(...)
//      -> NSHostingView.setNeedsUpdateConstraints
//      -> -[NSView _informContainerThatSubviewsNeedUpdateConstraints]
//      -> -[NSWindow(NSDisplayCycle) _postWindowNeedsUpdateConstraints]
//         -> NSGenericException -> SIGTRAP
//
//  The preference change re-rendered the main window's toolbar, and the
//  toolbar's inspector toggle carried the symbol name "sidebar-right".
//  That name does not exist: the system symbol is "sidebar.right" (a
//  dot). AppKit resolves the name on every render, so an unresolvable
//  name is re-resolved on every layout pass, and the toolbar item's
//  size never settles. The window then kept asking for another
//  "Update Constraints in Window" pass until AppKit's budget (the
//  number of views in the window) ran out and AppKit raised.
//
//  The single-letter typo was invisible in review because the compiler
//  cannot check a string literal against the system symbol set. THIS
//  test is that check: it resolves every symbol name the app renders
//  against the live system symbol set, so a name that does not exist
//  fails here instead of in a crash report.
//
//  WHAT IT COVERS
//  1. Every literal passed to SFIcon / Image(systemName:) /
//     Label(systemImage:) across Sources/ resolves.
//  2. The inspector toggle in particular names a symbol that exists
//     (the regression this test was written for).
//  3. The app renders no symbol name whose only difference from a real
//     one is a hyphen where the real one has a dot (= the exact shape
//     of this bug).
//

import AppKit
import Foundation
import Testing
@testable import WenshuApp

@Suite("SF Symbols resolve against the system symbol set")
struct SFSymbolResolutionTests {

    // MARK: - Helpers

    /// The live system symbol set. `NSImage(systemSymbolName:)` returns
    /// nil for a name the system does not know, which is exactly the
    /// condition AppKit logs as "No symbol named '...' found in system
    /// symbol set".
    private static func systemSymbolExists(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    /// Every `.swift` file under Sources/WenshuApp.
    private static func sourceFiles() throws -> [URL] {
        let sourcesRoot = SourceLocator.url("Sources/WenshuApp")
        guard let walker = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }
        var files: [URL] = []
        for case let entry as URL in walker where entry.pathExtension == "swift" {
            files.append(entry)
        }
        return files.sorted { $0.path < $1.path }
    }

    /// Extracts the symbol-name literals that reach the system symbol
    /// set, with the file and line that declared each.
    ///
    /// The three call shapes that resolve a name:
    ///   SFIcon(<name>, ...)            (the central factory)
    ///   Image(systemName: <name>)      (AppKit's own lookup)
    ///   Label("text", systemImage: <name>)
    ///
    /// The SFIcon first argument can be an expression rather than a bare
    /// literal (= the inspector toggle picks between two names with a
    /// ternary), so the scan reads the whole first argument and takes
    /// every string literal inside it.
    ///
    /// A fourth shape is an accessor that RETURNS the name (= the
    /// inspector page's `var icon`), where the literal never appears at
    /// the call site. Those are collected by `iconAccessorNames`.
    private static func renderedSymbolNames() throws -> [(name: String, file: String, line: Int)] {
        var found: [(name: String, file: String, line: Int)] = []
        let literalPattern = #""([^"]+)""#

        for url in try sourceFiles() {
            let text = try String(data: Data(contentsOf: url), encoding: .utf8) ?? ""
            let relative = url.path.replacingOccurrences(
                of: SourceLocator.repoRoot.path + "/", with: ""
            )
            let lines = text.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // A comment is documentation, not a rendered symbol.
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") { continue }

                // (a) The positional forms: the name is the argument right
                //     after the label, so the capture is exact.
                let positionalPatterns = [
                    #"Image\(\s*systemName:\s*"([^"]+)""#,
                    #"systemImage:\s*"([^"]+)""#,
                ]
                for pattern in positionalPatterns {
                    guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                    let range = NSRange(line.startIndex..<line.endIndex, in: line)
                    for match in regex.matches(in: line, range: range) {
                        guard let capture = Range(match.range(at: 1), in: line) else { continue }
                        found.append((String(line[capture]), relative, index + 1))
                    }
                }

                // (b) SFIcon's first argument, whatever shape it has.
                guard let call = try? NSRegularExpression(
                    pattern: #"SFIcon\(\s*([^,()]*)"#
                ) else { continue }
                let lineRange = NSRange(line.startIndex..<line.endIndex, in: line)
                for callMatch in call.matches(in: line, range: lineRange) {
                    guard let callRange = Range(callMatch.range(at: 1), in: line) else { continue }
                    let argument = String(line[callRange])
                    guard let literal = try? NSRegularExpression(pattern: literalPattern) else { continue }
                    let literalRange = NSRange(argument.startIndex..<argument.endIndex, in: argument)
                    for literalMatch in literal.matches(in: argument, range: literalRange) {
                        guard let capture = Range(literalMatch.range(at: 1), in: argument) else { continue }
                        found.append((String(argument[capture]), relative, index + 1))
                    }
                }
            }
        }
        found.append(contentsOf: try iconAccessorNames())
        return found
    }

    /// The symbol names returned by an icon accessor (= `var icon: String
    /// { case .status: return "waveform.path.ecg" ... }`).
    ///
    /// These never appear at a call site, so a typo in one is invisible
    /// to the literal scan, yet it reaches the system symbol set the
    /// same way. The accessor is recognized by its declaration
    /// (`var icon` / `var iconName` / `var symbol` returning String), and
    /// its body runs until the closing brace at the same indent.
    private static func iconAccessorNames() throws -> [(name: String, file: String, line: Int)] {
        var found: [(name: String, file: String, line: Int)] = []
        let declaration = try NSRegularExpression(
            pattern: #"var\s+(icon|iconName|symbol|systemImage)\s*:\s*String\s*\{"#
        )
        let literalPattern = #"return\s+"([^"]+)""#

        for url in try sourceFiles() {
            let text = try String(data: Data(contentsOf: url), encoding: .utf8) ?? ""
            let relative = url.path.replacingOccurrences(
                of: SourceLocator.repoRoot.path + "/", with: ""
            )
            let lines = text.components(separatedBy: "\n")
            // UTF-16 offset of each line's start, so a body can be
            // addressed as a range in the ORIGINAL text.
            var lineOffsets: [Int] = [0]
            for line in lines.dropLast() {
                lineOffsets.append(lineOffsets[lineOffsets.count - 1] + line.utf16.count + 1)
            }
            let textRange = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in declaration.matches(in: text, range: textRange) {
                guard let declRange = Range(match.range, in: text) else { continue }
                let startLine = text[..<declRange.lowerBound].components(separatedBy: "\n").count - 1
                // The body's closing brace sits at the declaration's own
                // indent, so scan forward to the first line that is
                // exactly that indent plus a closing brace.
                let declIndent = lines[startLine].prefix { $0 == " " }.count
                var bodyEnd = startLine + 1
                while bodyEnd < lines.count {
                    let line = lines[bodyEnd]
                    if line == String(repeating: " ", count: declIndent) + "}" { break }
                    bodyEnd += 1
                }
                guard bodyEnd < lines.count else { continue }
                let bodyStart = lineOffsets[startLine]
                let bodyEndOffset = lineOffsets[bodyEnd]
                let bodyRange = NSRange(location: bodyStart, length: bodyEndOffset - bodyStart)
                guard let literal = try? NSRegularExpression(pattern: literalPattern) else { continue }
                for literalMatch in literal.matches(in: text, range: bodyRange) {
                    guard let capture = Range(literalMatch.range(at: 1), in: text) else { continue }
                    // The match's lower bound is a UTF-16 offset, so the
                    // line is found by locating that offset among the
                    // line starts.
                    let offset = literalMatch.range.lowerBound
                    let lineIndex = lineOffsets.lastIndex { $0 <= offset } ?? startLine
                    found.append((String(text[capture]), relative, lineIndex + 1))
                }
            }
        }
        return found
    }

    // MARK: - Tests

    @Test("Every rendered SF Symbol name exists in the system symbol set")
    func everyRenderedSymbolResolves() throws {
        let rendered = try Self.renderedSymbolNames()
        #expect(!rendered.isEmpty, "the scan found no symbol names at all")

        var unresolved: [String] = []
        for entry in rendered {
            guard !Self.systemSymbolExists(entry.name) else { continue }
            unresolved.append("\(entry.file):\(entry.line) '\(entry.name)'")
        }
        #expect(
            unresolved.isEmpty,
            """
            these symbol names do not exist in the system symbol set, so AppKit \
            re-resolves them on every render and logs "No symbol named ...":
            \(unresolved.sorted().joined(separator: "\n"))
            """
        )
    }

    @Test("No symbol name differs from a real one only by a hyphen-for-dot swap")
    func noHyphenForDotSymbolNames() throws {
        let rendered = try Self.renderedSymbolNames()
        var offenders: [String] = []
        for entry in rendered {
            // A hyphen where the real symbol uses a dot is the exact
            // shape of the inspector-toggle bug ("sidebar-right" for
            // "sidebar.right").
            let dotted = entry.name.replacingOccurrences(of: "-", with: ".")
            guard dotted != entry.name else { continue }
            guard Self.systemSymbolExists(dotted) else { continue }
            // The name itself must NOT also resolve, otherwise the
            // hyphen form is a real symbol in its own right.
            guard !Self.systemSymbolExists(entry.name) else { continue }
            offenders.append("\(entry.file):\(entry.line) '\(entry.name)' -> '\(dotted)'")
        }
        #expect(
            offenders.isEmpty,
            """
            these names look like a hyphen-for-dot typo of a real symbol, so they \
            resolve to nothing:
            \(offenders.sorted().joined(separator: "\n"))
            """
        )
    }

    @Test("The inspector toggle names a symbol that exists")
    func inspectorToggleSymbolResolves() throws {
        // The regression this suite was written for: the main window's
        // toolbar crashed the app on a preference change because the
        // inspector toggle's symbol name did not exist.
        let content = try SourceLocator.read(
            "Sources/WenshuApp/Features/Editor/View/InspectorView.swift"
        )
        let names = ["sidebar.right", "sidebar.left"]
        for name in names {
            #expect(
                content.contains("\"\(name)\""),
                "InspectorView should name the existing symbol '\(name)'"
            )
        }
        #expect(
            !content.contains("\"sidebar-right\""),
            "InspectorView must not name the non-existent symbol 'sidebar-right'"
        )
        for name in names {
            #expect(
                Self.systemSymbolExists(name),
                "'\(name)' should exist in the system symbol set"
            )
        }
    }
}
