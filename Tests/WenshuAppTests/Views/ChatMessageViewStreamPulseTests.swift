//
//  ChatMessageViewStreamPulseTests.swift · Wenshu · v1.65 MC9
//
//  Verifies the hermes真值 `StatusPulse` (= status-pulse.tsx
//  PULSE_DURATION_MS=400 + PULSE_PERIOD_MS=5000) replaces the
//  previous T87-STREAM-PULSE scale+opacity breathing animation.
//  boss 2026-09-21 '思考中的那个效果不是 hermes 的效果':
//  the wenshu placeholder indicator now matches hermes真值
//  1:1 (= 3×3 PT rounded-2 square, opacity pulse 400 ms every
//  5 s; = NOT a continuous breathing animation).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView stream pulse (v1.65 MC9)")
struct ChatMessageViewStreamPulseTests {

    /// MC9 contract: hermes真值 StatusPulse struct exists.
    @Test func status_pulse_struct_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("private struct StatusPulse: View"))
    }

    /// MC9 contract: StatusPulse = 3×3 PT rounded-2PT square (= hermes
    /// `size-3 rounded-[2px]`).
    @Test func status_pulse_shape_3pt_rounded_2() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("RoundedRectangle(cornerRadius: 2, style: .continuous)"))
        #expect(src.contains(".frame(width: 3, height: 3)"))
    }

    /// MC9 contract: StatusPulse pulses opacity (= 1 → 0.5 → 1) over
    /// 400 ms ease-in-out (= hermes PULSE_DURATION_MS=400).
    @Test func status_pulse_opacity_400ms() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".opacity(isPulsing ? 0.5 : 1.0)"))
        #expect(src.contains(".easeInOut(duration: Self.pulseDuration)"))
        #expect(src.contains("private static let pulseDuration: Double = 0.4"))
    }

    /// MC9 contract: pulse period = 5 seconds (= hermes
    /// PULSE_PERIOD_MS=5000); = NOT a continuous breathing animation.
    @Test func status_pulse_period_5s() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("private static let pulsePeriod: TimeInterval = 5.0"))
        #expect(src.contains("TimelineView(.periodic(from: .now, by: Self.pulsePeriod))"))
    }

    /// MC9 contract: previous T87 scale+opacity breathing animation removed.
    @Test func previous_t87_scale_animation_removed() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(!src.contains(".scaleEffect(message.isPlaceholder ? 1.0 : 1.0)"))
        #expect(!src.contains(".easeInOut(duration: 1.6).repeatForever(autoreverses: true)"))
    }

    /// MC9 contract: T58 elapsed-time TimelineView preserved.
    @Test func t58_elapsed_time_preserved() throws {
        // The elapsed-time TimelineView (= 0.5s cadence; = different
        // from the StatusPulse 5s pulsePeriod) lives in
        // ChatMessagePlaceholderRow after C-8c refactor.
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessagePlaceholderRow.swift",
            encoding: .utf8
        )
        #expect(src.contains("TimelineView(.periodic(from: .now, by: 0.5))"))
        #expect(src.contains("Self.formatElapsed(elapsed)"))
    }

    /// MC9 contract: previous T87 ProgressView spinner removed (=
    /// hermes真值 uses a status pulse dot, not a spinner).
    @Test func previous_t87_progress_view_removed() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // ProgressView only appears in the user message attachment chip
        // (= unchanged from MC1); the placeholder indicator no longer
        // uses one. Verify by counting: there should be at most 1
        // ProgressView() in ChatMessageView.swift, down from 2.
        let progressCount = src.components(separatedBy: "ProgressView()").count - 1
        #expect(progressCount <= 1)
    }
}
