//
//  ChatMessageFooter.swift · Wenshu · refactor chat-mvvm-3layer C-8e
//
//  Apple MVVM canonical leaf view for the sealed-message footer
//  (= the metadata row below each chat bubble that shows timestamp +
//  token count + cost + NEW chip). Lifted out of ChatMessageView
//  (= 902 lines today) so:
//
//  - ChatMessageView body shrinks further.
//  - The footer formatting helpers (= formatTokenCount / formatCost
//    / fullTimestampTooltip / fullTokenCountTooltip / comboFooterTooltip)
//    live next to the view that uses them.
//  - The hover-state for the timestamp expansion lives on the leaf
//    (= each message tracks its own footer state independently).
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  UI-only (= no business logic). The token count comes from
//  ChatMessage.tokens (= LLM API usage.total_tokens = input + output).
//  The cost is derived (= estimated USD = $3/M input + $15/M output
//  heuristic = the Claude Sonnet 4.5 pricing tier; = the order-of-
//  magnitude estimate is right; = exact cost requires per-model
//  pricing which the wenshu connector doesn't surface today).
//
//  hermes 1:1 (= status.tsx + assistant-message.tsx footer):
//  hermes shows just the timestamp (= no token count, no cost).
//  wenshu adds tokens + cost + NEW badge as macOS-desktop extras
//  (= power-user visibility; = not in hermes but documented per
//  AGENTS.md §11 = wenshu-side design divergence).
//

import SwiftUI

/// Leaf view: the sealed-message footer row showing timestamp +
/// token count + estimated cost + NEW badge. Rendered below each
/// chat bubble's body (= Apple HIG metadata convention).
public struct ChatMessageFooter: View {
    /// Timestamp displayed in the footer (= chat message creation time).
    let timestamp: Date
    /// LLM API usage.total_tokens (= nil for user messages).
    /// Hidden when nil or 0 (= no LLM usage to report).
    let tokens: Int?
    /// Whether the message is sealed (= streamState == .sealed).
    /// Controls the divider + NEW chip visibility.
    let isSealed: Bool
    /// The hover-state binding for the timestamp expansion
    /// (= "14:32" → "14:32 · 9月18日" on hover, per T26).
    /// Owned by the parent view (= each message tracks its own
    /// hover state independently).
    @Binding var isTimestampHovered: Bool

    public init(
        timestamp: Date,
        tokens: Int?,
        isSealed: Bool,
        isTimestampHovered: Binding<Bool>
    ) {
        self.timestamp = timestamp
        self.tokens = tokens
        self.isSealed = isSealed
        self._isTimestampHovered = isTimestampHovered
    }

    public var body: some View {
        HStack(spacing: 6) {
            // T65-CLOCK-PREFIX: clock icon before the timestamp text.
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.quaternary)
            // T84-DELIVERED-CHECK: checkmark after the timestamp
            // (= Apple Messages read-receipts affordance).
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.quaternary)
            // T26-HOVER-TIMESTAMP: compact form by default
            // (= "14:32"); expanded on hover (= "14:32 · 9月18日").
            Text(timestamp, format: timestampDisplayFormat)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .onHover { hovering in
                    isTimestampHovered = hovering
                }
                // T50-TIMESTAMP-TOOLTIP: macOS native tooltip with
                // full ISO-format date (= shows year + seconds).
                .help(Self.fullTimestampTooltip(for: timestamp))
            // T72-FRESH-CHIP: "NEW" badge next to the timestamp
            // when the message was sealed less than 60s ago.
            if isSealed, Date().timeIntervalSince(timestamp) < 60 {
                Text("· NEW")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
            }
            // T25-TOKEN-FOOTER: token count footer
            // (= LLM API usage.total_tokens = input + output).
            // Hidden when tokens is nil OR 0.
            if let tokens, tokens > 0 {
                // T63-TOKEN-ICON: "number" SF Symbol prefix.
                Image(systemName: "number")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                Text(Self.formatTokenCount(tokens))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    // T52-TOKEN-TOOLTIP: full-precision token count.
                    .help(Self.fullTokenCountTooltip(for: tokens))
                // T62-TOKEN-COST: estimated USD cost
                // (= heuristic: $3/M input + $15/M output).
                // T64-DOLLAR-ICON: "$" SF Symbol prefix.
                Image(systemName: "dollarsign.circle")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                Text(Self.formatTokenCost(tokens))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.top, 2)
        // v1.65-cleanup E6: vertical 2 PT top (= row separator gap;
        // = matches Apple HIG caption2 metadata vertical gap).
        .frame(maxWidth: .infinity, alignment: .leading)
        // T53-FOOTER-COMBO-TOOLTIP: combined tooltip on the
        // entire footer HStack (= "1,500 tokens · 2026-09-18 14:32:05").
        .help(Self.comboFooterTooltip(timestamp: timestamp, tokens: tokens))
        // T55-FOOTER-DIVIDER: hairline above the footer
        // (= Apple HIG secondary chrome). Hidden when both
        // timestamp + token are absent (= the divider would
        // float without context).
        .overlay(alignment: .top) {
            if isSealed && (tokens ?? 0) > 0 {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 0.5)
                    .offset(y: -2)
            }
        }
    }

    /// Date format: compact "14:32" by default; expanded on hover.
    private var timestampDisplayFormat: Date.FormatStyle {
        if isTimestampHovered {
            return .dateTime
                .hour().minute()
                .day().month()
        }
        return .dateTime.hour().minute()
    }

    // MARK: - Formatting helpers (= moved from ChatMessageView)

    /// T25-TOKEN-FOOTER: "1.5k tokens" / "234 tokens" / "12.3k tokens".
    /// nonisolated so tests can call without instantiating the view.
    nonisolated static func formatTokenCount(_ count: Int) -> String {
        if count < 1_000 {
            return "\(count) tokens"
        }
        if count < 10_000 {
            let k = Double(count) / 1_000.0
            return String(format: "%.1fk tokens", k)
        }
        if count < 1_000_000 {
            let k = count / 1_000
            return "\(k)k tokens"
        }
        let m = Double(count) / 1_000_000.0
        return String(format: "%.1fM tokens", m)
    }

    /// T62-TOKEN-COST: estimated USD cost label.
    /// Heuristic: $3/M input + $15/M output (= Claude Sonnet 4.5
    /// pricing tier; = order-of-magnitude is right; = exact cost
    /// requires per-model pricing).
    nonisolated static func formatTokenCost(_ count: Int) -> String {
        // Approximate split: half input + half output.
        let inputTokens = Double(count) / 2.0
        let outputTokens = Double(count) / 2.0
        let cost = (inputTokens * 3.0 + outputTokens * 15.0) / 1_000_000.0
        if cost < 0.01 {
            return "≈ $0.001"
        }
        return String(format: "≈ $%.3f", cost)
    }

    /// T52-TOKEN-TOOLTIP: full token count string for the .help()
    /// tooltip (= "1,500 tokens" with locale-aware digit grouping).
    nonisolated static func fullTokenCountTooltip(for count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: count)) ?? String(count)
        return "\(formatted) tokens"
    }

    /// T50-TIMESTAMP-TOOLTIP: full ISO-format date string.
    nonisolated static func fullTimestampTooltip(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// T53-FOOTER-COMBO-TOOLTIP: combined tooltip for the entire
    /// sealed footer (= "1,500 tokens · 2026-09-18 14:32:05").
    nonisolated static func comboFooterTooltip(timestamp: Date, tokens: Int?) -> String {
        var parts: [String] = []
        if let tokens, tokens > 0 {
            parts.append(fullTokenCountTooltip(for: tokens))
        }
        parts.append(fullTimestampTooltip(for: timestamp))
        return parts.joined(separator: " · ")
    }
}
