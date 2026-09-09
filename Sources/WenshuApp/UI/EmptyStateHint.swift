// Sources/WenshuApp/UI/EmptyStateHint.swift
//
//  EmptyStateHint · Wenshu · v0.40 apple-001
//
//  Canonical empty-state surface for all "no content selected"
//  zones (= editor zone, PreviewPane, specialized tool panes
//  like Foreshadowing). Boss real-device test (2026-09-07)
//  '提示的样式不统一, 有的有 ICON, 有没有, 字号有的大有的小, 把
//  规则固定下来, 统一字号': consolidate 3 inconsistent
//  empty-state patterns into 1 reusable component.
//
//  Design contract (= what each caller MUST honor):
//
//  Layout: centered VStack filling the entire available space
//  (= caller wraps in any frame). Icon at top, title + body
//  below (= no header bar; = pure empty state).
//
//  Icon:
//    - Lucide icon name (= falls back to SF Symbol on miss)
//    - size: DesignTokens.iconLargeSize (= 24 PT)
//    - color: .secondary (= adapts to dark/light mode)
//
//  Title:
//    - .font(.system(size: 15, weight: .semibold))
//    - .foregroundStyle(.secondary)
//    - 1 line, no truncation
//
//  Body:
//    - .font(.system(size: 13))
//    - .foregroundStyle(.tertiary)
//    - multilineTextAlignment(.center)
//    - maxWidth: 360 (= wrap on small zones)
//
//  Spacing:
//    - icon → title: chromePaddingLarge (= 16 PT)
//    - title → body: chromePaddingSmall (= 6 PT)
//
//  Why these specific tokens (= Apple HIG + wenshu design system):
//  - iconLargeSize matches PreviewPane's existing lucide icon
//    pattern (= same visual weight as other zone-level icons).
//  - 15/13 PT (= standard macOS callout/caption1 sizes) match
//    the empty-state style Apple uses in Mail / Pages / Xcode
//    when a list/zone is empty.
//  - .secondary + .tertiary = Apple's 2-step hierarchy for empty
//    states (= title is the primary message, body is the
//    supporting instruction).

import SwiftUI

/// v0.40 boss 9/7 OOB: unified empty-state hint for all
/// "no content" zones in the wenshu workspace. Caller provides
/// the icon (= semantic per zone = book-open for editor,
/// circle-help for info, etc.) + title + body keys. Layout,
/// fonts, colors, spacing are all canonical (= consistent
/// visual treatment across editor / preview / specialized
/// tools / future zones).
///
/// Usage:
///
/// ```swift
/// EmptyStateHint(
///     icon: "book-open",
///     title: WenshuI18n.t("workspace.empty.title"),
///     body: WenshuI18n.t("workspace.empty.body")
/// )
/// ```
public struct EmptyStateHint: View {
    let icon: String
    let title: String
    let detail: String

    public init(icon: String, title: String, body: String) {
        self.icon = icon
        self.title = title
        self.detail = body  // stored property renamed to avoid
                            // collision with SwiftUI's `body`
                            // (= the View protocol's `var body`).
    }

    public var body: some View {
        VStack(spacing: DesignTokens.chromePaddingLarge) {
            // Icon (= 24 PT = DesignTokens.iconLargeSize).
            // .secondary = Apple's mid-tier icon color
            // (= visible but not loud; = the same weight
            // Mail / Notes use for empty-state icons).
            LucideIconSystemFallback(icon, size: DesignTokens.iconLargeSize)
                .foregroundStyle(.secondary)
            VStack(spacing: DesignTokens.chromePaddingSmall) {
                // Title (= Apple HIG .headline semibold = 13 PT
                // semibold = Apple's standard secondary headline).
                // The .secondary tone (= not .primary) keeps the
                // hint feeling like a suggestion, not an error.
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                // Body (= Apple HIG .callout = 12 PT secondary =
                // Apple's standard secondary text). The .tertiary
                // tone + center alignment signals "this is
                // supporting detail" (= Apple Mail / Notes
                // convention).
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
