//
//  ChatPlanPartHeaderTypographyTests.swift · WenshuAppTests
//
//  The plan card's header: the title outranks the provenance strip it
//  sits in.
//
//  The card's own title used to be the same 11 PT caption as the model
//  id that produced the plan, so the header read as one band of chrome.
//  These tests read the shipped source rather than the rendered pixels:
//  the claim is about which style a line wears, and that is a property
//  of the layout the file declares.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatPlanPartView header typography")
struct ChatPlanPartHeaderTypographyTests {

    /// A card's title has to be a heading. The headline style is larger
    /// AND heavier than the caption-scale chrome around it, so the rank
    /// is a fact about the pair, not about one line.
    @Test("The plan title outranks its chrome")
    func planTitleOutranksItsChrome() throws {
        #expect(WenshuTextStyle.headline.pointSize > WenshuTextStyle.caption2.pointSize,
                "the ranks the header is written against (= headline 13 PT over the caption-scale provenance strip)")

        let content = try Self.source()
        #expect(Self.fontLine(after: ##"Text("Plan: \(plan.query)")"##, in: content) == ".font(.headline.monospaced())",
                "the plan title wears the headline style (= monospaced keeps the query's own face)")
        #expect(content.contains("matchingText: .headline"),
                "the symbol beside the title wears the title's style (= a caption-scale glyph next to a headline reads as chrome, not as a title)")

        // The provenance strip stays caption-scale: it is subordinate to
        // the title by size, so the two cannot meet again in the middle.
        let chrome = Self.fontLines(in: content).filter { $0.hasPrefix(".font(.caption2") }
        #expect(chrome.count >= 4,
                "the step count, the provider, the model id and the elapsed time stay caption2 (= the rank is one title over a strip, not four more sizes)")
    }

    // MARK: - Reading the shipped layout

    private static func source() throws -> String {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Chat/View/ChatPlanPartView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The trimmed lines of the source.
    private static func lines(_ content: String) -> [String] {
        content.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    /// The font modifier that immediately follows a line.
    private static func fontLine(after marker: String, in content: String) -> String? {
        let lines = Self.lines(content)
        guard let at = lines.firstIndex(where: { $0.contains(marker) }) else { return nil }
        for candidate in lines[(at + 1)...] {
            if candidate.hasPrefix(".font(") { return candidate }
            if !candidate.isEmpty { return nil }
        }
        return nil
    }

    /// Every font modifier the file applies.
    private static func fontLines(in content: String) -> [String] {
        Self.lines(content).filter { $0.hasPrefix(".font(") }
    }
}

