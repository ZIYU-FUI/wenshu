//
//  ChatViewCompressionRowAlwaysVisibleTests.swift · Wenshu · T33-ALWAYS-SHOW-COMPRESSION (2026-09-18)
//
//  Verifies the always-visible compression row affordance
//  (= the row is now shown whenever the conversation has any
//  messages, not only when context > threshold). Also verifies
//  the below-threshold label uses the secondary tone (= quiet
//  indicator, not the orange warning style).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatViewCompressionRow always-visible (T33)")
struct ChatViewCompressionRowAlwaysVisibleTests {

    /// T33 contract: the row visibility gate is now `hasMessages`
    /// (instead of `contextUsed >= threshold`).
    @Test func source_uses_hasMessages_gate() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatViewCompressionRow.swift",
            encoding: .utf8
        )
        #expect(source.contains("let hasMessages = !vm.messages.isEmpty"))
        #expect(source.contains("if hasMessages {"))
    }

    /// T33 contract: the old threshold-only gate is REMOVED.
    @Test func old_threshold_only_gate_removed() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatViewCompressionRow.swift",
            encoding: .utf8
        )
        // The pre-T33 line was: "let showRow = vm.contextUsed >= ..."
        // (= shows ONLY when above threshold). After T33 the
        // variable is renamed to hasMessages (= no longer gated on
        // threshold). Verify the pre-T33 variable name is gone.
        #expect(!source.contains("let showRow ="))
    }

    /// T33 contract: below-threshold label uses .secondary tone
    /// (= quiet, not the orange warning).
    @Test func below_threshold_label_uses_secondary() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatViewCompressionRow.swift",
            encoding: .utf8
        )
        #expect(source.contains("tokens used"))
        #expect(source.contains(".foregroundStyle(.secondary)"))
    }

    /// T33 contract: formatCompactTokenCount is now public on the
    /// formatter (= the below-threshold label calls it).
    @Test func compact_formatter_is_public() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatViewCompressionRow.swift",
            encoding: .utf8
        )
        #expect(source.contains("nonisolated static func formatCompactTokenCount"))
    }
}