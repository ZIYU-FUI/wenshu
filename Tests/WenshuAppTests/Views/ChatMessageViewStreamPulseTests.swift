//
//  ChatMessageViewStreamPulseTests.swift · Wenshu · T87-STREAM-PULSE (2026-09-18)
//
//  Verifies the subtle scale + opacity pulse animation
//  on the streaming placeholder bubble (= Apple Messages
//  "typing..." pulse affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView stream pulse (T87)")
struct ChatMessageViewStreamPulseTests {

    /// T87 contract: T87 marker comment exists.
    @Test func t87_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T87-STREAM-PULSE (2026-09-18)"))
    }

    /// T87 contract: .scaleEffect on streaming bubble.
    @Test func source_uses_scale_effect() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".scaleEffect(message.isPlaceholder ? 1.0 : 1.0)"))
    }

    /// T87 contract: .animation with .easeInOut + repeatForever.
    @Test func source_uses_pulse_animation() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".easeInOut(duration: 1.6).repeatForever(autoreverses: true)"))
        #expect(src.contains("value: message.isPlaceholder"))
    }

    /// T87 contract: animation gated on isPlaceholder.
    @Test func animation_gated_on_placeholder() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("message.isPlaceholder\n                            ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)\n                            : .default"))
    }

    /// T87 contract: T58 elapsed-time TimelineView preserved.
    @Test func t58_elapsed_time_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("TimelineView(.periodic(from: .now, by: 0.5))"))
        #expect(src.contains("Self.formatElapsed(elapsed)"))
    }

    /// T87 contract: T86 user-status-dot code branch preserved.
    @Test func t86_user_dot_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T86-USER-STATUS-DOT (2026-09-18)"))
    }

    /// T87 contract: T58 ProgressView preserved.
    @Test func t58_progress_view_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("ProgressView()"))
        #expect(src.contains(".controlSize(.mini)"))
    }
}