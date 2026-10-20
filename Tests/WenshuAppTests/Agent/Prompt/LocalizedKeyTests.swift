// LocalizedKeyTests.swift
//
// Two failures that look like one, and neither is visible in a unit test
// without these checks:
//
//   1. An interpolated key. String(localized:) takes a compile-time literal.
//      A spliced one resolves to itself, so the UI prints the key. Every key
//      exists in the catalog and the screen still shows
//      "settings.memory.backend.localMarkdown.detail".
//   2. Two catalogs. Localizable.xcstrings is the source, and the hand-written
//      .lproj/Localizable.strings beside it used to win at runtime until it
//      drifted. It is gone; this asserts it stays gone.

import Foundation
import Testing
@testable import WenshuApp
import WenshuAgent

@Suite("Localization keys")
struct LocalizedKeyTests {

    private func catalogPath() -> URL {
        URL(fileURLWithPath: SourceLocator.path("Sources/WenshuApp/Resources/Localizable.xcstrings"))
    }

    // MARK: - No interpolated keys

    @Test("no view builds a localization key by interpolation")
    func noInterpolatedKeys() throws {
        // The failure mode is silent: the key is a valid string, the lookup
        // misses, and the screen shows the key. Scanning for it is the only
        // cheap check; a runtime test would have to render every surface.
        let root = URL(fileURLWithPath: SourceLocator.path("Sources/WenshuApp"))
        let offenders = try Self.filesWithInterpolatedKeys(in: root)
        #expect(offenders.isEmpty,
                "String(localized:) needs a compile-time literal; these splice one: \(offenders)")
    }

    /// The interpolated literal inside a String(localized:) call, if any.
    ///
    /// Only the quoted argument counts. `String(localized: "export.failed") +
    /// " (\(path))"` interpolates the suffix, not the key, and is correct.
    private static func interpolatedKey(in line: String) -> String? {
        guard let call = line.range(of: "String(localized:") else { return nil }
        let rest = line[call.upperBound...]
        guard let open = rest.firstIndex(of: "\""),
              let close = rest[open...].firstIndex(of: "\""),
              close > open else { return nil }
        let literal = String(rest[rest.index(after: open)..<close])
        guard literal.contains("\\(") else { return nil }
        return literal
    }

    /// A `String(localized: "…\(…)…")` is the defect. `NSLocalizedString` with an
    /// interpolated key is fine (= it looks up at runtime by design), and a
    /// `+ " (\(path))"` concatenation is string building, not a key.
    private static func filesWithInterpolatedKeys(in root: URL) throws -> [String] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var offenders: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                guard let interpolated = Self.interpolatedKey(in: String(line)) else { continue }
                offenders.append("\(url.lastPathComponent):\(index + 1) (\(interpolated))")
            }
        }
        return offenders
    }

    // MARK: - One catalog only

    @Test("the hand-written .strings beside the catalog is gone")
    func handWrittenCatalogIsGone() {
        let resources = URL(fileURLWithPath: SourceLocator.path("Sources/WenshuApp/Resources"))
        // InfoPlist.strings stays: it localises CFBundleDisplayName and has
        // no String Catalog equivalent the build pipeline compiles.
        let stale = ["en.lproj/Localizable.strings", "zh-Hans.lproj/Localizable.strings"]
            .filter { FileManager.default.fileExists(atPath: resources.appendingPathComponent($0).path) }
        #expect(stale.isEmpty,
                "these shadow the catalog at runtime: \(stale). Localizable.xcstrings is the only source.")
    }

    @Test("the build pipeline compiles the catalog")
    func buildScriptCompilesTheCatalog() throws {
        let script = URL(fileURLWithPath: SourceLocator.path("Scripts/build-app.sh"))
        let text = try String(contentsOf: script, encoding: .utf8)
        #expect(text.contains("xcstringstool compile"),
                "SwiftPM ships .xcstrings verbatim; without this the app has no catalog")
    }

    // MARK: - The keys this feature needs

    @Test("every key the memory backend rows ask for exists")
    func memoryBackendKeysExist() throws {
        let catalog = try Self.catalog(at: catalogPath())
        let required = [
            "settings.memory.backend.title",
            "settings.memory.backend.footer",
            "settings.memory.backend.localMarkdown.detail",
            "settings.memory.backend.remoteService.detail",
            "settings.memory.backend.remote.title",
            "settings.memory.backend.remote.endpoint",
            "settings.memory.backend.remote.footer"
        ]
        for key in required {
            #expect(catalog[key] != nil, "missing \(key)")
        }
    }

    @Test("every key the agent pane asks for exists")
    func agentPaneKeysExist() throws {
        let catalog = try Self.catalog(at: catalogPath())
        var required = ["settings.pane.agent", "settings.agent.selected"]
        required += ToolCategory.allCases.map { "settings.agent.category.\($0.rawValue)" }
        for key in required {
            #expect(catalog[key] != nil, "missing \(key)")
        }
    }

    @Test("every editor format button has a tooltip key")
    func editorFormatKeysExist() throws {
        let catalog = try Self.catalog(at: catalogPath())
        for rawValue in Self.editorFormatRawValues {
            #expect(catalog["editor.format.\(rawValue).tooltip"] != nil, "missing tooltip for \(rawValue)")
            #expect(catalog["editor.format.\(rawValue).a11y"] != nil, "missing a11y label for \(rawValue)")
        }
    }

    private static let editorFormatRawValues = [
        "bold", "italic", "highlight", "strikethrough", "inlineCode", "heading",
        "blockquote", "unorderedList", "orderedList", "link", "codeBlock", "horizontalRule"
    ]

    private static func catalog(at url: URL) throws -> [String: Int] {
        struct Catalog: Decodable {
            struct Entry: Decodable { let extractionState: String? }
            let strings: [String: Entry]
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Catalog.self, from: data).strings.keys.reduce(into: [:]) {
            $0[$1] = 1
        }
    }
}