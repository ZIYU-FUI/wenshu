//
//  ChatMessagePlaceholderRow.swift · Wenshu · refactor chat-mvvm-3layer C-8c
//
//  Apple MVVM canonical leaf view for the "AI thinking…" placeholder
//  row that appears in the chat transcript while a streaming reply
//  is in flight (= before the first block arrives). Lifted out of
//  ChatMessageView (= 921 lines today) so:
//
//  - ChatMessageView body shrinks further.
//  - The placeholder is independently testable + Xcode-previewable.
//  - Future variants (= e.g. a "compacting context…" placeholder
//    for compression status) plug in by adding leaves next to this.
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  UI-only (= no business logic). The "what is being thought about"
//  string lives on ChatMessage.content (= the placeholder's payload;
//  = business layer owns it). The pulse animation + elapsed timer
//  are pure rendering concerns.
//
//  hermes 1:1 (= status.tsx ResponseLoadingIndicator + status-pulse.tsx):
//    - 3×3 PT rounded-2PT square that pulses opacity every 400 ms,
//      sleeping 5 s between pulses (= StatusPulse private struct in
//      ChatMessageView.swift = the canonical wenshu 1:1 impl).
//    - Followed by hint text (the ChatMessage.content payload =
//      usually "AI 思考中…").
//    - Followed by an elapsed-since-timestamp timer (= the activity
//      indicator; = updates every 0.5s).
//
//  Why generic over the pulse slot: StatusPulse is a `private struct`
//  in ChatMessageView.swift (= hermes 1:1 leaf; = not promoted to
//  shared component because it's the exact wenshu implementation
//  of hermes status-pulse.tsx). Promoting the leaf to take any
//  View via @ViewBuilder closure keeps StatusPulse as a private
//  nested type while still allowing the placeholder logic to live
//  in its own file (= same pattern as ChatMessageThinkingDisclosure).
//

import SwiftUI

/// Leaf view: the "AI thinking…" placeholder row rendered in the
/// chat transcript while a streaming reply is in flight.
public struct ChatMessagePlaceholderRow<Pulse: View>: View {
    /// The hint text shown next to the pulse (= usually "AI 思考中…").
    let hintText: String
    /// The timestamp the thinking started (= used to compute the
    /// elapsed timer).
    let timestamp: Date
    /// Caller-provided pulse label (= StatusPulse or any future
    /// animated indicator; = generic to avoid leaking the private
    /// StatusPulse type out of ChatMessageView.swift).
    @ViewBuilder let pulse: Pulse

    public init(
        hintText: String,
        timestamp: Date,
        @ViewBuilder pulse: () -> Pulse
    ) {
        self.hintText = hintText
        self.timestamp = timestamp
        self.pulse = pulse()
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Caller-provided pulse (= StatusPulse by default).
            pulse
            Text(hintText)
                .foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let elapsed = context.date.timeIntervalSince(timestamp)
                Text(Self.formatElapsed(elapsed))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        // v1.65-cleanup E6 boss 2026-09-21 '只保留 10PT, 我建议你把基它地方的全都取消掉':
        // vertical 8 PT (= Apple HIG py-2 row gap convention). Horizontal
        // padding lives on the chat transcript outer (= single source
        // of truth = ChatView.swift, not this leaf).
        .padding(.vertical, 8)
    }

    /// Format an elapsed-seconds value as "5.3s" / "1m 23s" /
    /// "1h 5m" (= hermes真值 ActivityTimerText format). Mirrors
    /// the static helper that used to live on ChatMessageView.
    nonisolated static func formatElapsed(_ seconds: TimeInterval) -> String {
        if seconds < 0 { return "0.0s" }
        if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds / 60.0)
        let remaining = Int(seconds.truncatingRemainder(dividingBy: 60.0))
        if minutes < 60 {
            return "\(minutes)m \(remaining)s"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}
