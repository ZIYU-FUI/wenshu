//
//  DesignSystemTestNamingTests.swift · Wenshu
//
//  A sweep suite's own prose is part of what it ships. A header that
//  records which pass touched which file, with which card id and which
//  quoted ruling, says nothing a reader can check and goes stale the
//  moment the tree moves: the number of sites it lists is a number nobody
//  re-counts, and the line it names has already shifted.
//
//  What this suite holds: inside the design-system directory, a header
//  states the rule a suite guards and nothing else.

import Foundation
import Testing
@testable import WenshuApp

@Suite("Design-system suite headers state a rule, not a pass record")
struct DesignSystemTestNamingTests {

    private static var directory: URL {
        SourceLocator.url("Tests/WenshuAppTests/UI/DesignSystem")
    }

    private static func files() throws -> [(name: String, text: String)] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map { url in
            (url.lastPathComponent, try String(contentsOf: url, encoding: .utf8))
        }
    }

    /// The block above a file's first import: the header a reader sees
    /// before any code.
    private static func headers() throws -> [(name: String, head: String)] {
        try Self.files().map { file in
            let lines = file.text.components(separatedBy: "\n")
            let end = lines.firstIndex(where: { $0.hasPrefix("import ") }) ?? lines.count
            return (file.name, lines[..<end].joined(separator: "\n"))
        }
    }

    /// Prose that names the pass which produced it instead of the thing it
    /// checks. A space is required so a type's own handle (= the file that
    /// committed as a sweep gate and stays a gate) is not mistaken for a
    /// sentence.
    private static let passNumber = #"\brounds? \d+|\bpass \d+|sweep \d"#

    /// A pointer a reader inside this tree cannot follow.
    private static let unreachableRef =
        #"[AQ]-?\d{2,}|\bL\d{2,}\b|[0-9a-f]{10}|OOB \u201c|OOB \""#

    /// A numbered legend: a table of the suite's own items, which the item
    /// names already carry.
    private static let numberedLegend = #"^\s*//\s*\d+\.\s"#

    @Test("Nothing in the design-system directory names a sweep pass")
    func namesDoNotCarryPassNumbers() throws {
        for file in try Self.files() {
            for line in file.text.components(separatedBy: "\n") {
                if line.contains("SourceLocator.url(") { continue }
                #expect(!Self.matches(line, Self.passNumber),
                        "\(file.name): prose says which pass found this rather than what it checks (= \(line.trimmingCharacters(in: .whitespaces)))")
            }
        }
    }

    @Test("A suite header states the rule it guards")
    func headersCarryNoPassRecord() throws {
        for file in try Self.headers() {
            for line in file.head.components(separatedBy: "\n") {
                if line.contains("@Suite") || line.contains("@Test") { continue }
                #expect(!Self.matches(line, Self.unreachableRef),
                        "\(file.name): a header points at a card id, a line number, a commit or a quotation a reader cannot follow from inside this tree (= \(line.trimmingCharacters(in: .whitespaces)))")
            }
        }
    }

    @Test("A suite header does not list its own items by number")
    func headersCarryNoNumberedLegend() throws {
        for file in try Self.headers() {
            for line in file.head.components(separatedBy: "\n") {
                #expect(!Self.matches(line, Self.numberedLegend),
                        "\(file.name): a numbered table of tests the test names already state (= \(line.trimmingCharacters(in: .whitespaces)))")
            }
        }
    }

    @Test("Every suite in the directory is covered by this rule")
    func theDirectoryIsTheScope() throws {
        let headers = try Self.headers()
        #expect(try Self.files().count == headers.count)
        #expect(headers.count >= 20,
                "the design-system directory holds the sweep suites this rule is written for; a count this low means the scan stopped finding files")
        #expect(headers.contains { $0.name == "IconStylesTests.swift" })
        #expect(headers.contains { $0.name == "FinalSweepArcClosureTests.swift" })
    }

    private static func matches(_ line: String, _ pattern: String) -> Bool {
        line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
