//
//  SFSymbolResolutionTests.swift · WenshuAppTests
//
//  Every SF Symbol name the app renders must exist in the system symbol
//  set.
//
//  WHY THIS TEST EXISTS
//  The main window's toolbar crashed the app with EXC_BREAKPOINT when the
//  app's preferences changed. A preference change re-renders the toolbar,
//  and one of its items carried the name "sidebar-right". That name does
//  not exist: the system symbol is "sidebar.right", with a dot.
//
//  AppKit resolves the name on every render. An unresolvable name is
//  re-resolved on every layout pass and the toolbar item's size never
//  settles, so the window keeps asking for another constraint pass until
//  AppKit's budget for that pass runs out and it raises — the exception
//  arrives as a crash report, not as a message about a symbol name.
//
//  The compiler cannot check a string literal against the system symbol
//  set, which is why a one-character typo survives review. This suite is
//  that check: it resolves every name the app renders against the live
//  symbol set, so a name that does not exist fails here instead.
//
//  WHAT IT COVERS
//  A name is read from every source file, not from the one control that
//  shipped the typo = the failure was never about which control carried
//  the name. The exact name that shipped is pinned, and so is its shape:
//  no name whose only difference from a real symbol is a hyphen where the
//  real one has a dot.
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

    @Test("No source file names the hyphen-form sidebar symbol that crashed the app")
    func noHyphenFormSidebarSymbolAnywhere() throws {
        // The regression this suite was written for: the main window's
        // toolbar crashed the app on a preference change because the
        // inspector toggle's symbol name did not exist ("sidebar-right"
        // for "sidebar.right"). The toggle button itself is gone (= the
        // boss removed it on 2026-11-10: = the window toolbar's
        // rightmost section switch is the column's visibility control
        // now), so this pin no longer reads one file's toggle: = it
        // reads EVERY source file, = because the crash was never about
        // which button carried the name (= it was about AppKit
        // re-resolving an unresolvable name on every render).
        //
        // The sweep above (= every rendered name resolves) is the
        // general form of the same property; this one pins the exact
        // typo that shipped, so a future edit that re-introduces that
        // spelling anywhere is caught by name and not only by kind.
        let typo = "sidebar-right"
        var offenders: [String] = []
        for url in try Self.sourceFiles() {
            let text = try String(contentsOf: url, encoding: .utf8) ?? ""
            guard text.contains("\"\(typo)\"") else { continue }
            let relative = url.path.replacingOccurrences(
                of: SourceLocator.repoRoot.path + "/", with: ""
            )
            offenders.append(relative)
        }
        #expect(
            offenders.isEmpty,
            """
            these files name the non-existent symbol '\(typo)', = which AppKit \
            re-resolves on every render and then aborts the window's layout:
            \(offenders.sorted().joined(separator: "\n"))
            """
        )
        #expect(
            !Self.systemSymbolExists(typo),
            "'\(typo)' must not exist in the system symbol set"
        )
    }
}
