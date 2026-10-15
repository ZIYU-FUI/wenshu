//
//  ChatToolUsePartViewStatusPulseTests.swift · Wenshu · T45-STATUS-PULSE (2026-09-18)
//
//  Verifies the pulse animation on the T44 status icon:
//    - .running → pulse via .opacity + .animation(.easeInOut.repeatForever)
//    - .complete / .error → static (no animation, opacity = 1.0)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatToolUsePartView status pulse (T45)")
struct ChatToolUsePartViewStatusPulseTests {

    /// T45 contract: source applies opacity pulse via
    /// .opacity(isRunningStatus ? runningStatusOpacity : 1.0).
    @Test func source_applies_opacity_pulse() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".opacity(isRunningStatus ? runningStatusOpacity : 1.0)"))
    }

    /// T45 contract: source uses .animation(.easeInOut.repeatForever)
    /// (= the canonical SwiftUI autoreverse pulse).
    @Test func source_uses_repeat_forever_animation() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".easeInOut(duration: 1.2).repeatForever(autoreverses: true)"))
    }

    /// T45 contract: isRunningStatus private var exists (= drives
    /// the pulse gate based on toolUse.status).
    @Test func isRunningStatus_private_var_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("private var isRunningStatus: Bool {"))
        #expect(src.contains("toolUse.status == .running"))
    }

    /// T45 contract: runningStatusOpacity = 0.5 (= dimmer than
    /// T17 reasoning pulse at 0.6 = the tool-call pulse should
    /// feel "deeper" because tools usually take longer than
    /// reasoning steps).
    @Test func runningStatusOpacity_is_half() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("private var runningStatusOpacity: Double {\n        0.5\n    }"))
    }

    /// T45 contract: T44 statusIconName(for:) helper preserved.
    @Test func t44_statusIconName_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func statusIconName(for status: ChatMessagePart.ToolUsePart.Status) -> String"))
    }
}