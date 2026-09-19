//
//  ChatMessageDayDivider.swift · Wenshu · T36-DATE-DIVIDERS (2026-09-18)
//
//  A small "Today" / "Yesterday" / "Mon 9/14" header rendered
//  above a chat message when the calendar day changes (= the
//  Apple Messages behavior; = lets users quickly see when
//  yesterday's conversation ended).
//
//  Token-efficient:
//    - Pure value type (= no @State, no @Observable, no actor)
//    - Plain SwiftUI Text (= no fancy border, no animation)
//    - Centered, .caption, .secondary tone (= Apple HIG section
//      header convention)
//
//  Formatter:
//    - Today        → "Today"
//    - Yesterday    → "Yesterday"
//    - <7 days ago  → "Mon" / "Tue" (= short weekday)
//    - Same year    → "Mon 9/14"
//    - Different yr → "Mon 9/14/26"
//
//  i18n:
//    - The five labels are localized via WenshuI18n.t
//    - Date numbers use the user's current locale
//    (= DateFormatter with currentLocale).
//

import SwiftUI

/// T36-DATE-DIVIDERS (2026-09-18): small centered header that
/// marks the boundary between two consecutive messages whose
/// calendar days differ (= Apple Messages convention).
public struct ChatMessageDayDivider: View {
    public let timestamp: TimeInterval

/// T68-COUNT-DIVIDER (2026-09-18): a public init that
    /// accepts an optional message-count. When the caller
    /// passes a count, the divider's label suffix shows
    /// " · N" (= the Apple HIG secondary chrome pattern
    /// for "section header + count"; = matches Finder's
    /// "Today · 5 items" affordance).
    public let messageCount: Int?

    public init(timestamp: TimeInterval, messageCount: Int? = nil) {
        self.timestamp = timestamp
        self.messageCount = messageCount
    }

    /// T68-COUNT-DIVIDER (2026-09-18): backward-compatible init
    /// (= preserves the T36/T39/T56/T57/T60 callers that don't
    /// pass a count).
    public init(timestamp: TimeInterval) {
        self.init(timestamp: timestamp, messageCount: nil)
    }

    /// T68-COUNT-DIVIDER (2026-09-18): a divider that displays
    /// only the message count (= used when the caller wants
    /// the count chip without a date label; = forward-flexibility).
    public static func countOnly(_ count: Int) -> ChatMessageDayDivider {
        ChatMessageDayDivider(timestamp: 0, messageCount: count)
    }

    public var body: some View {
        HStack(spacing: 6) {
            // T56-DAY-ICON (2026-09-18): a small SF Symbol calendar
            // icon prefix for the day-divider label (= "📅
            // Today" / "📅 Mon 9/14"). The icon uses .secondary
            // tone (= matches the label's tone) and .caption2
            // (= slightly smaller than the label's .caption).
            // Provides a visual cue that the divider is a
            // date marker (= the SF Symbol is the canonical
            // Apple HIG date affordance).
            //
            // T57-TODAY-ACCENT (2026-09-18): when the label is
            // "Today" (= the calendar day is the current day),
            // the icon gets .accentColor tint (= visual
            // emphasis = today is the "active" day). The label
            // text stays .secondary (= matching the icon's
            // normal-state tone; = the icon is the visual cue,
            // not the label).
            //
            // T60-TODAY-STAR (2026-09-18): when isTodayLabel,
            // a small .star.fill SF Symbol overlay appears on
            // top-right of the calendar icon (= the "today"
            // day-divider is visually marked as special with
            // a star = matches Apple HIG "current day"
            // affordance). Hidden when not today.
            ZStack(alignment: .topTrailing) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(isTodayLabel ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                if isTodayLabel {
                    Image(systemName: "star.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.yellow)
                        .offset(x: 3, y: -2)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            // T68-COUNT-DIVIDER (2026-09-18): a small " · N"
            // suffix when the caller passes a message count.
            // Hidden when count is nil (= preserves the
            // existing T36/T39/T56/T57/T60 affordance = the
            // date-only label).
            if let count = messageCount {
                Text("· \(count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, DesignTokens.chromePaddingLeading)
        // T39-DIVIDER-MATERIAL (2026-09-18): give the divider a thin
        // background material so it visually anchors against the
        // surrounding chat zone (= the divider text alone can blend
        // into a busy scroll position). Uses Material.ultraThin =
        // the standard Apple HIG sidebar / toolbar material that
        // adapts to light + dark mode automatically.
        //   - Background tint = Color.clear (= the material itself
        //     supplies the chrome).
        //   - Shape = Capsule (= rounded ends matching the Apple
        //     HIG date-pill affordance).
        //   - Padding = 16 horizontal = the divider text gets
        //     breathing room inside the capsule.
        .background(.clear)
        .padding(.horizontal, 16)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal, -16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chat day separator: \(label)")
    }

    /// Compute the localized label for the given timestamp.
    /// "Today" / "Yesterday" / "Mon" / "Mon 9/14" / "Mon 9/14/26".
    private var label: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return WenshuI18n.t("chatview.day_divider.today")
        }
        if calendar.isDateInYesterday(date) {
            return WenshuI18n.t("chatview.day_divider.yesterday")
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current

        // Compute the day delta
        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        let weekday = calendar.dateComponents([.weekday], from: date).weekday ?? 0

        if daysAgo < 7 && daysAgo >= 0 {
            // Short weekday name: "Mon", "Tue", ...
            formatter.setLocalizedDateFormatFromTemplate("E")
            return formatter.string(from: date)
        }

        // Longer than 7 days ago (or future date). Include the date.
        let isSameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
        formatter.setLocalizedDateFormatFromTemplate(isSameYear ? "MMMd" : "yMMMd")
        return formatter.string(from: date)
    }

    /// T57-TODAY-ACCENT (2026-09-18): true when the label is the
    /// "Today" localized string (= drives the icon's accent
    /// color tint). Uses the resolved label (= the same string
    /// the body shows) for the comparison = no risk of
    /// locale drift breaking the accent.
    private var isTodayLabel: Bool {
        let todayKey = WenshuI18n.t("chatview.day_divider.today")
        return label == todayKey
    }
}