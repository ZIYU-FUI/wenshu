//
//  ChatPartViewThinkingFadeInTests.swift · Wenshu · T40-THINKING-FADEIN (2026-09-18)
//
//  Verifies the new fade-in transition for ChatReasoningPartView
//  (= Apple HIG "appear from above" affordance for streamed
//  reasoning parts).
//

import Testing
import SwiftUI
@testable import WenshuApp

@Suite("ChatPartView thinking fade-in (T40)")
struct ChatPartViewThinkingFadeInTests {

    /// T40 contract: ChatPartView.swift source defines
    /// AnyTransition.wenshuThinkingAppear() (= the standard
    /// fade-in + downward-slide transition for streamed reasoning).
    @Test func source_defines_wenshuThinkingAppear() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatReasoningPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("wenshuThinkingAppear"))
    }

    /// T40 contract: wenshuThinkingAppear is implemented as a
    /// static function on AnyTransition extension (= not a stored
    /// property; = satisfies Swift 6 strict concurrency).
    @Test func wenshuThinkingAppear_is_static_function() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatReasoningPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("public static func wenshuThinkingAppear() -> AnyTransition"))
    }

    /// T40 contract: the transition is asymmetric (= insertion
    /// = fade-in + slide, removal = opacity only).
    @Test func transition_is_asymmetric() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatReasoningPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".asymmetric(\n            insertion: .opacity.combined(with: .move(edge: .top)),\n            removal: .opacity"))
    }

    /// T40 contract: ChatPartRow (.reasoning case) applies the
    /// transition via .transition(.wenshuThinkingAppear()).
    @Test func reasoning_case_applies_transition() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".transition(.wenshuThinkingAppear())"))
    }

    /// T40 contract: @MainActor-isolation on the function
    /// (= Sendable-safe; = matches SwiftUI's actor model).
    @Test func wenshuThinkingAppear_is_MainActor_isolated() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatReasoningPartView.swift",
            encoding: .utf8
        )
        // The @MainActor attribute appears on the line BEFORE the
        // function declaration.
        guard let funcRange = src.range(of: "public static func wenshuThinkingAppear") else {
            Issue.record("wenshuThinkingAppear function not found")
            return
        }
        // Check the previous 200 chars for @MainActor.
        let prefixStart = src.index(funcRange.lowerBound, offsetBy: -200)
        let prefix = String(src[prefixStart..<funcRange.lowerBound])
        #expect(prefix.contains("@MainActor"))
    }
}