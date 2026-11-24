//
//  ChatPlanPartHeaderTypographyTests.swift · WenshuAppTests
//
//  The plan card's header: the title outranks the provenance strip it
//  sits in, and the strip is its own row.
//
//  A plan card has one title and one provenance strip, and the two are
//  ranked: the title is a heading, larger and heavier, and the strip is
//  caption-scale and gets its own row. These tests read the shipped
//  source rather than the rendered pixels, because both claims are
//  properties of the layout the file declares.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatPlanPartView header typography")
struct ChatPlanPartHeaderTypographyTests {

    /// A card's title has to be a heading. The rank is Apple's: the
    /// headline role is the emphasized one and the caption2 role is the
    /// smallest caption, so the pair needs no size kept by the app.
    @Test("The plan title outranks its chrome")
    func planTitleOutranksItsChrome() throws {
        #expect(WenshuTextStyle.headline.font == .headline
                && WenshuTextStyle.caption2.font == .caption2,
                "the two rows name Apple's emphasized role and Apple's smallest caption role (= the app keeps no size table of its own to be outranked by)")

        let content = try Self.source()
        #expect(Self.fontLine(after: ##"Text("Plan: \(plan.query)")"##, in: content) == ".font(.headline.monospaced())",
                "the plan title wears the headline style (= monospaced keeps the query's own face)")
        #expect(content.contains("matchingText: .headline"),
                "the symbol beside the title wears the title's style (= a caption-scale glyph next to a headline reads as chrome, not as a title)")

        // The provenance strip stays on the smallest caption role: it is
        // subordinate to the title by role, so the two cannot meet again.
        let chrome = Self.fontLines(in: content).filter { $0.hasPrefix(".font(.caption2") }
        #expect(chrome.count >= 4,
                "the step count, the provider, the model id and the elapsed time stay caption2 (= the rank is one title over a strip, not four more sizes)")
    }

    /// Six items on one line is a header that trades the query away: the
    /// title, its glyph and the step count need the row, and the provider,
    /// the model id and the plan's age do not belong to that sentence.
    @Test("The plan's provenance is its own row under the title")
    func provenanceKeepsItsOwnRow() throws {
        let lines = Self.lines(try Self.source())
        let title = lines.firstIndex { $0.hasPrefix(#"Text("Plan:"#) }
        let chip = lines.firstIndex { $0.hasPrefix(#"Text("(N steps)""#) }
        let connector = lines.firstIndex { $0.contains("Self.connectorIcon(plan.connectorID)") }
        let provider = lines.firstIndex { $0.hasPrefix("Text(Provider.by") }
        let elapsed = lines.firstIndex { $0.hasPrefix("Text(plan.createdAt") }
        #expect([title, chip, connector, provider, elapsed].allSatisfy { $0 != nil },
                "the header still draws all five items (= the row split moved them, it did not drop them)")
        #expect(title! < chip! && chip! < connector! && connector! < provider! && provider! < elapsed!,
                "the title row closes before the provenance strip opens")

        // A row boundary separates them, not a Spacer: a Spacer between two
        // items is one row pushing its own items apart. So the region between
        // the step chip and the connector glyph has to END with the title
        // row's own push and the close that ends it, and then open a row.
        let between = lines[(chip! + 1)..<connector!].filter { !$0.isEmpty && !$0.hasPrefix("//") }
        #expect(between.last?.hasPrefix("HStack(") == true,
                "the strip's row is the last thing opened before its connector glyph")
        #expect(Array(between.suffix(3).dropLast()) == ["Spacer(minLength: 0)", "}"],
                "the title's row ends with its own push and its own close (= the provenance is a second row, not a third item squeezed into the first)")

        // The strip pushes exactly once, and the item it pushes to the
        // trailing edge is the plan's age: how fresh a plan is, is read last.
        let pushes = lines[(connector! + 1)..<elapsed!].filter { $0.hasPrefix("Spacer(") }
        #expect(pushes.count == 1, "the strip breaks exactly once (= two rows each push once; a second push is a third item grouping)")
        let afterElapsed = lines[(elapsed! + 1)...].first { !$0.isEmpty && !$0.hasPrefix(".") }
        #expect(afterElapsed == "}",
                "the plan's age is the strip's last item (= nothing is drawn after it in that row)")
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

