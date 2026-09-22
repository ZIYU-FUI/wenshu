//
//  ChatPartViewTextFadeInTests.swift · Wenshu · T49-TEXT-FADEIN (2026-09-18)
//
//  Verifies that the .text case in ChatPartRow's switch ALSO
//  applies the wenshuThinkingAppear transition (= T49 extends
//  the fade-in pattern from T40 reasoning + T41 tool to text
//  parts as well).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatPartView text fade-in (T49)")
struct ChatPartViewTextFadeInTests {

    /// T49 contract: .text case applies .transition(.wenshuThinkingAppear()).
    @Test func text_case_applies_transition() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        let textCaseIdx = src.range(of: "case .text(let s):")!
        let nextCaseIdx = src.range(of: "case .reasoning(let s):",
                                    range: textCaseIdx.upperBound..<src.endIndex)!
        let textBlock = src[textCaseIdx.lowerBound..<nextCaseIdx.lowerBound]
        #expect(textBlock.contains(".transition(.wenshuThinkingAppear())"))
    }

    /// T49 contract: T40 reasoning case still applies transition.
    @Test func reasoning_case_still_applies_transition() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        let reasoningIdx = src.range(of: "case .reasoning(let s):")!
        let nextCaseIdx = src.range(of: "case .toolUse(let tu):",
                                    range: reasoningIdx.upperBound..<src.endIndex)!
        let reasoningBlock = src[reasoningIdx.lowerBound..<nextCaseIdx.lowerBound]
        #expect(reasoningBlock.contains(".transition(.wenshuThinkingAppear())"))
    }

    /// T49 contract: T41 tool cases still apply transitions.
    @Test func tool_cases_still_apply_transitions() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        let toolUseIdx = src.range(of: "case .toolUse(let tu):")!
        let nextCaseIdx = src.range(of: "case .toolResult(let tr):",
                                    range: toolUseIdx.upperBound..<src.endIndex)!
        let toolUseBlock = src[toolUseIdx.lowerBound..<nextCaseIdx.lowerBound]
        #expect(toolUseBlock.contains(".transition(.wenshuThinkingAppear())"))
    }

    /// T49 contract: total transition count in ChatPartRow
    /// switch is now 4 (= reasoning + toolUse + toolResult + text).
    @Test func transition_applied_to_four_cases() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        let rowBodyStart = src.range(of: "switch part.kind {")!
        let rowBodyEnd = src.range(of: "    }", range: rowBodyStart.upperBound..<src.endIndex)
        guard let rowBodyEnd else { return }
        let rowBody = src[rowBodyStart.lowerBound..<rowBodyEnd.lowerBound]
        let count = rowBody.components(separatedBy: ".transition(.wenshuThinkingAppear())").count - 1
        #expect(count == 4, "expected 4 transitions (= text + reasoning + toolUse + toolResult); got \(count)")
    }

    /// T49 contract: T42 streaming cursor on text part preserved.
    @Test func t42_stream_cursor_preserved() throws {
        // The streaming cursor TimelineView lives in ChatTextPartView
        // (not in ChatPartView's switch case).
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("TimelineView(.periodic(from: .now, by: 0.5))"))
    }
}