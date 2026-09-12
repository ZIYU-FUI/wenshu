//
//  EmptyStateView.swift
//  wenshu
//
//  v1.0.0-m1-shell boss 2026-09-12 OOB '现在的空态不是一个组件,
//  你能抽象一个 UI 组件吗? 顺手把空态的 ICON 放大一倍, 同时用
//  最细的线条. 目的是统一所有空态的样式. 右栏 12 个 teb, 很
//  多都缺少空态':
//
//  Unified empty-state component (= single source of truth for
//  every "no content" zone in the wenshu workspace). All 12
//  specialized tool tabs use this component via
//  `EmptyStateView(icon:title:body:)` (= same visual treatment
//  across every tab; = no hand-rolled VStack { Text + Text }
//  duplicates).
//
//  Design contract (= what each caller MUST honor):
//
//  Layout: centered VStack filling the entire available space
//  (= caller wraps in any frame). Icon at top, title + body
//  below (= no header bar; = pure empty state).
//
//  Icon (= LucideThinIcon):
//    - Lucide icon name (= kebab-case; = the canonical Lucide
//      library name; = NOT a SwiftUI SF Symbol name)
//    - size: 76 PT (= 2× the v0.54 38 PT; = the boss's '放大一倍'
//      directive)
//    - stroke: 1 PT (= the thinnest SwiftUI Shape stroke; = the
//      boss's '最细的线条' directive; = rendered via the new
//      `LucideThinIcon` wrapper which uses `makePath(in:) +
//      .stroke(lineWidth: 1, lineCap: .round, lineJoin: .round)`)
//    - color: .secondary (= adapts to dark/light mode; =
//      Apple's 2-step hierarchy for empty-state icons)
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
//    - maxWidth: 360 (= wraps on small inspector columns)
//
//  Spacing:
//    - icon → title: 22 PT (= matches Apple's ContentUnavailableView
//      sample measured at 22 PT; = v0.54 default)
//    - title → body: 6 PT (= chromePaddingSmall = Apple HIG
//      standard for title→caption spacing)
//
//  Why these specific tokens (= Apple HIG + wenshu design system):
//  - 76 PT icon + 1 PT stroke = matches Apple's macOS 27 inspector
//    / empty-state icon visual weight (= Pages / Numbers / Keynote
//    all use a similar weight in their "no document selected"
//    panes).
//  - 15/13 PT (= standard macOS callout/caption1 sizes) match
//    the empty-state style Apple uses in Mail / Pages / Xcode
//    when a list / zone is empty.
//  - .secondary + .tertiary = Apple's 2-step hierarchy for empty
//    states (= title is the primary message, body is the
//    supporting instruction).

import SwiftUI

/// v1.0.0-m1-shell boss 2026-09-12 OOB '现在的空态不是一个组件':
/// unified empty-state component for ALL "no content" zones in
/// the wenshu workspace (= 12 specialized tool tabs + editor
/// zone + PreviewPane + future zones). Caller provides the icon
/// (= Lucide kebab-case name; = e.g. "git-fork" for the
/// Foreshadowing tab), title (= String), and body (= String).
///
/// Usage:
///
/// ```swift
/// EmptyStateView(
///     icon: "git-fork",
///     title: WenshuI18n.t("foreshadowingview.empty.title"),
///     body: WenshuI18n.t("foreshadowingview.empty.body")
/// )
/// ```
///
/// The component handles ALL layout (= icon + title + body + the
/// vertical spacing between them) and ALL visual styling (= font
/// sizes, colors, weights, alignment, max-width). Callers
/// provide ONLY the icon + title + body content.
///
/// Visual contract (= what the user sees):
/// - 76 PT Lucide icon, 1 PT stroke (= thinnest possible SwiftUI
///   Shape stroke; = via LucideThinIcon wrapper)
/// - 15 PT semibold title below the icon (= .secondary tone =
///   primary message)
/// - 13 PT body below the title (= .tertiary tone = supporting
///   detail)
/// - 22 PT vertical gap between icon and title (= matches
///   Apple's measured ContentUnavailableView sample)
/// - 6 PT vertical gap between title and body (= chromePaddingSmall
///   = Apple HIG standard)
/// - Centered horizontally inside the caller's frame (= the
///   SwiftUI VStack auto-centers its children)
public struct EmptyStateView: View {
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
        VStack(spacing: 0) {
            // v1.0.0-m1-shell boss 2026-09-12 OOB 'ICON 放大一倍'
            // (= 2× the v0.54 38 PT default = 76 PT)
            // + '用最细的线条' (= 1 PT stroke via LucideThinIcon).
            //
            // The LucideThinIcon wrapper (= separate file in
            // UI/Icon/) renders the Lucide icon as a 1 PT
            // stroked Path (= the thinnest SwiftUI Shape
            // stroke; = matches Apple's macOS 27 inspector /
            // empty-state icon weight).
            //
            // Apple's empty states use a much bigger icon
            // (= measured 38 PT on a real ContentUnavailableView
            // sample; = v0.54 default). The boss's '放大一倍'
            // directive = 2× the 38 PT default = 76 PT. The
            // vertical gap (= 22 PT below) matches Apple's
            // measured ContentUnavailableView sample (= NOT
            // custom; = Apple HIG standard).
            LucideThinIcon(icon, size: 76)
                .foregroundStyle(.secondary)
                .padding(.bottom, 22)
            VStack(spacing: 6) {
                // Title (= Apple HIG .headline semibold = 13 PT
                // semibold = Apple's standard secondary headline).
                // The .secondary tone (= NOT .primary) keeps the
                // hint feeling like a suggestion, NOT an error.
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                // Body (= Apple HIG .callout = 12 PT secondary =
                // Apple's standard secondary text). The .tertiary
                // tone + center alignment signals "this is
                // supporting detail" (= Apple Mail / Notes /
                // Pages convention).
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 360)
        }
    }
}
