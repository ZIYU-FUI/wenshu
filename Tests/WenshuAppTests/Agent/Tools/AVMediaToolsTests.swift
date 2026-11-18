//
//  AVMediaToolsTests.swift · Wenshu · v0.18 ticket 11 (AV media tools)
//
// test AVMediaTools. estimateDuration yes (AVFoundation), .
// speak skip (sandbox).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AVMediaTools (hermes replica)")
struct AVMediaToolsTests {
    @Test("estimateDuration 默认 4 字/秒")
    func testEstimateDurationDefault() {
        let tools = AVMediaTools()
        let text = "你好世界你好世界"  // 8
        let duration = tools.estimateDuration(text: text, rate: 0.5)
        // 8 / 4 / = 2
        #expect(abs(duration - 2.0) < 0.01)
    }

    @Test("estimateDuration rate 1.0 = 8 字/秒")
    func testEstimateDurationFast() {
        let tools = AVMediaTools()
        let text = "abcdefghij"  // 10
        let duration = tools.estimateDuration(text: text, rate: 1.0)
        // 10 / 8 / = 1.25
        #expect(abs(duration - 1.25) < 0.01)
    }

    @Test("estimateDuration 空字符串 = 0")
    func testEstimateDurationEmpty() {
        let tools = AVMediaTools()
        #expect(tools.estimateDuration(text: "", rate: 0.5) == 0.0)
    }

    @Test("availableVoices 不抛错")
    func testAvailableVoices() {
        let tools = AVMediaTools()
        let voices = tools.availableVoices()
        // macOS 27 yes zh-CN + en-US wait
        #expect(voices.count >= 0)
    }

    @Test("availableVoices languagePrefix 过滤")
    func testAvailableVoicesFilter() {
        let tools = AVMediaTools()
        let zhVoices = tools.availableVoices(languagePrefix: "zh")
        // zh, yes en-US
        for voice in zhVoices {
            #expect(voice.contains("zh") || voice.contains("chinese"))
        }
    }

    // MARK: - The shadowed constant (= the defect this suite pins)

    /// A file-scope constant may not be initialized from its own name.
    ///
    /// WHY THIS SHAPE: a file-scope `let X = ... X ...` resolves the
    /// initializer's `X` to the binding itself (= the local declaration
    /// wins over the imported symbol in the file's own scope), = so the
    /// constant holds the not-yet-initialized value (= zero) instead of
    /// the symbol it names. ⇒ The tree carried exactly one: =
    /// `AVMediaTools.swift` bound Apple's own
    /// `AVSpeechUtteranceDefaultSpeechRate` (= 0.5) to a self-reference
    /// (= 0.0), = so the next `speechRate:` written in that file got
    /// silence. ⇒ Measured over the whole production tree, that line
    /// was the ONLY self-initialized file-scope constant, = so this
    /// guard is the whole class, = not one remembered spelling.
    @Test("no file-scope constant is initialized from its own name")
    func noFileScopeConstantIsSelfInitialized() throws {
        var offenders: [String] = []
        for path in try Self.productionSwiftFiles() {
            let source = try SourceLocator.read(path)
            for declaration in Self.fileScopeConstants(in: source) {
                if Self.mentions(declaration.name, in: declaration.initializer) {
                    offenders.append("\(path): \(declaration.name)")
                }
            }
        }
        #expect(
            offenders.isEmpty,
            "a file-scope constant initialized from its own name: \(offenders)"
        )
    }

    // MARK: - The guard's readers

    /// One file-scope constant: the name it binds and what it binds it to.
    private struct FileScopeConstant {
        let name: String
        let initializer: String
    }

    /// Every production Swift file, = = the five roots the product
    /// ships (= `Sources/WenshuApp/`, = = `Sources/WenshuAgent/Sources/`,
    /// = = `Sources/WenshuData/Sources/`, = = `Board/Sources/`, = =
    /// `Mobile/Sources/`), = = and not a manifest (= a `Package.swift`
    /// is a SwiftPM descriptor, = = and `let package = Package(...)` is
    /// its own idiom), = = and not a test tree (= a test may declare a
    /// constant it initializes from its own name on purpose).
    private static func productionSwiftFiles() throws -> [String] {
        let root = SourceLocator.repoRoot
        var files: [String] = []
        for directory in [
            "Sources/WenshuApp",
            "Sources/WenshuAgent/Sources",
            "Sources/WenshuData/Sources",
            "Board/Sources",
            "Mobile/Sources",
        ] {
            let base = root.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(
                at: base,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let entry as URL in walker where entry.pathExtension == "swift" {
                let relative = entry.path
                    .replacingOccurrences(of: root.path + "/", with: "")
                if relative.contains("/.build/") || relative.contains("/Tests/") {
                    continue
                }
                files.append(relative)
            }
        }
        return files.sorted()
    }

    /// The file-scope constants a Swift file declares, = = read from
    /// its CODE (= the comments and the string contents removed, = = so
    /// neither a docblock nor a string literal can fail the guard) and
    /// only the ones that START A LINE (= = a `let` inside a type is
    /// indented, = = and a member is not a file-scope binding).
    private static func fileScopeConstants(in source: String) -> [FileScopeConstant] {
        let code = codeOnly(source)
        var found: [FileScopeConstant] = []
        for line in code.split(separator: "\n", omittingEmptySubsequences: false) {
            guard !line.isEmpty, !line.hasPrefix(" ") else { continue }
            let words = line.split(separator: " ", omittingEmptySubsequences: true)
            var index = 0
            while index < words.count,
                  ["public", "private", "fileprivate", "internal", "open",
                   "static", "final", "class", "indirect"].contains(String(words[index]))
            {
                index += 1
            }
            guard index < words.count,
                  words[index] == "let" || words[index] == "var",
                  index + 1 < words.count
            else { continue }
            // The name ends at the type annotation's colon (= a name is
            // an identifier, = = and the colon belongs to the type).
            var name = String(words[index + 1])
            if let colon = name.firstIndex(of: ":") {
                name = String(name[name.startIndex ..< colon])
            }
            // The initializer starts at the declaration's own `=`.
            // Swift writes it with spaces around it, = = so ` = ` finds
            // the assignment and not an `==` inside the initializer.
            guard let equals = line.range(of: " = ") else { continue }
            found.append(
                FileScopeConstant(
                    name: name,
                    initializer: String(line[equals.upperBound...])
                )
            )
        }
        return found
    }

    /// The source with its comments AND its string contents removed.
    /// = = A `//` comment ends at the line's end and a `/* */` comment
    /// ends at the closing marker; = = a `//` inside a string is text,
    /// = = not a comment; = = and a string's CONTENT is not a name the
    /// compiler resolves (= `Package(name: "package")` does not read the
    /// constant `package`).
    private static func codeOnly(_ source: String) -> String {
        var result = ""
        var inBlockComment = false
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            var kept = ""
            var inString = false
            var escaped = false
            var index = line.startIndex
            while index < line.endIndex {
                if inBlockComment {
                    if line[index] == "*",
                       line.index(after: index) < line.endIndex,
                       line[line.index(after: index)] == "/"
                    {
                        inBlockComment = false
                        index = line.index(after: index)
                    }
                    index = line.index(after: index)
                    continue
                }
                let character = line[index]
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString.toggle()
                    kept.append(character)
                } else if inString {
                    // The content of a string is text, = = not a name.
                } else if character == "/",
                          line.index(after: index) < line.endIndex
                {
                    let next = line[line.index(after: index)]
                    if next == "/" {
                        break
                    } else if next == "*" {
                        inBlockComment = true
                        index = line.index(after: index)
                    }
                } else {
                    kept.append(character)
                }
                index = line.index(after: index)
            }
            result += kept
            result += "\n"
        }
        return result
    }

    /// Whether `text` names `name` as a whole word.
    ///
    /// ⇒ CASE-SENSITIVE, = = because Swift's name lookup is: =
    /// `let toolNameWhitelist = ToolNameWhitelist()` is a constant and
    /// its TYPE, = = not a self-reference.
    private static func mentions(_ name: String, in text: String) -> Bool {
        var search = text.startIndex
        while let found = text.range(of: name, range: search ..< text.endIndex) {
            let beforeOK = found.lowerBound == text.startIndex
                || !text[text.index(before: found.lowerBound)].isLetter
                && !text[text.index(before: found.lowerBound)].isNumber
                && text[text.index(before: found.lowerBound)] != "_"
            let afterOK = found.upperBound == text.endIndex
                || !text[found.upperBound].isLetter
                && !text[found.upperBound].isNumber
                && text[found.upperBound] != "_"
            if beforeOK, afterOK {
                return true
            }
            search = found.upperBound
        }
        return false
    }
}
