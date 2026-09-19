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

    public init(timestamp: TimeInterval) {
        self.timestamp = timestamp
    }

    public var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
}