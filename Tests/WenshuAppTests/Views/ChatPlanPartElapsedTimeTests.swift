//
//  ChatPlanPartElapsedTimeTests.swift · Wenshu · T32-PLAN-ELAPSED (2026-09-18)
//
//  Verifies the relative-time chip in ChatPlanPartView (= the
//  "3s ago" / "2m ago" / "1h ago" affordance). Strategy: source
//  inspection (= SwiftUI @ViewBuilder is not introspectable at
//  runtime; = we assert the format-style wiring is in place).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatPlanPartView elapsed time (T32)")
struct ChatPlanPartElapsedTimeTests {

    /// T32 contract: ChatPlanPartView source contains the
    /// .relative(presentation: .named) Text view.
    @Test func source_uses_relative_format() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            encoding: .utf8
        )
        #expect(source.contains("Text(plan.createdAt, format: .relative(presentation: .named))"))
    }

    /// T32 contract: relative-time chip uses .caption2 + .quaternary
    /// (= more muted than the model id = visually subordinate to
    /// the connector + model primary info).
    @Test func chip_uses_quaternary_foreground() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            encoding: .utf8
        )
        #expect(source.contains(".font(.caption2)"))
        #expect(source.contains(".foregroundStyle(.quaternary)"))
    }

    /// T32 contract: relative-time Text is placed AFTER the
    /// model id (= last in the connector name HStack = visually
    /// grouped as the most secondary info).
    @Test func chip_is_after_model_id() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            encoding: .utf8
        )
        // The relative-time Text comes after the model id block
        // (= "Text(model)" block ends; = then the elapsed chip).
        let modelTextEnd = source.range(of: ".font(.system(.caption2, design: .monospaced))\n                            .foregroundStyle(.tertiary)\n                    }")
        let elapsedText = source.range(of: "Text(plan.createdAt, format: .relative(presentation: .named))")
        #expect(modelTextEnd != nil)
        #expect(elapsedText != nil)
        // modelEnd < elapsedText (= elapsed comes after model in the file).
        #expect(modelTextEnd!.upperBound < elapsedText!.upperBound)
    }
}