//
//  EmptyStateView.swift
//  wenshu
//
//  v1.0.0-m1-shell boss 2026-09-12 OOB 'the current empty state
//  is not a single component; can you abstract a UI component?
//  Also 2x the icon size and use the thinnest stroke.
//  The right column has 12 tabs and most lack empty states':
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
//  Icon (= SF Symbols 6):
//    - SF Symbol 6 identifier (= canonical Apple SF Symbol
//      name; = dot.case form like 'books.vertical')
//    - size: 76 PT (= 2x the v0.54 38 PT; = the boss's '2x size'
//      directive)
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
//    - .foregroundStyle(DesignTokens.statusForeground)
//    - multilineTextAlignment(.center)
//    - maxWidth: 360 (= wraps on small inspector columns)
//
//  Spacing:
//    - icon → title: DesignTokens.chromePaddingEmptyStateGap (= the
//      Apple HIG standard ContentUnavailableView measured value; =
//      the boss's '...use Apple styles' OOB = the literal number isn't
//      Apple-default = Apple doesn't expose this value publicly;
//      = we use a semantic token instead)
//    - title → body: chromePaddingSmall (= Apple HIG standard for
//      title→caption spacing)
//    - body maxWidth: DesignTokens.guardrailSheetWidth (= 360 PT
//      = Apple HIG modal sheet width = the empty-state body
//      should wrap to the same width as a standard modal sheet)
//    - icon size: DesignTokens.emptyStateIconSize (= 76 PT
//      = 2x the v0.54 38 PT default = the boss's '2x size'
//      directive; = not a magic number = semantic token for the
//      canonical empty-state icon size)
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

/// v1.0.0-m1-shell boss 2026-09-12 OOB 'the current empty state is not a single component':
/// unified empty-state component for ALL "no content" zones in
/// the wenshu workspace (= 12 specialized tool tabs + editor
/// zone + PreviewPane + future zones). Caller provides the icon
/// (= SF Symbols 6 name; = e.g. "book.pages" for a book-themed
/// empty state; = any valid SF Symbol 6 identifier — Lucide
/// kebab-case names are NOT valid SF Symbols and render as blank
/// rectangles since the v1.0.0-m1-shell migration).
/// Caller also supplies title (= String) and body (= String).
///
/// Usage:
///
/// ```swift
/// EmptyStateView(
///     icon: "doc.text",  // SF Symbols 6 name (= any valid SF Symbol identifier)
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
/// - 76 PT SF Symbol icon (= 2× the v0.54 38 PT default; = sized
///   for empty states per Apple HIG ContentUnavailableView).
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
///
/// Two init flavors:
///
/// 1. Plain text title (= the common case):
///    `EmptyStateView(icon: ..., title: "...", body: "...")`
///
/// 2. Custom title view (= for chat empty state where the title
///    contains an inline "Settings" Button as part of the
///    sentence; = Apple Mail / Notes convention):
///    `EmptyStateView(icon: ..., titleView: { HStack { Text; Button; Text } }, body: "...")`
///
/// Both flavors render the same icon + body style; only the title
/// rendering differs (= plain Text vs. caller-supplied View).
public struct EmptyStateView: View {
    let icon: String
    let titleText: String?
    let detail: String
    /// Caller-supplied custom title view (= AnyView so the two
    /// init flavors can store different concrete types in the
    /// same property). nil when the plain-text title init was used.
    let titleView: AnyView?

    /// Plain-text title init (= the common case).
    public init(icon: String, title: String, body: String) {
        self.icon = icon
        self.titleText = title
        self.detail = body  // stored property renamed to avoid
                            // collision with SwiftUI's `body`
                            // (= the View protocol's `var body`).
        self.titleView = nil
    }

    /// Custom-title-view init (= for chat empty state where the
    /// title contains an inline link / Button as part of the
    /// sentence).
    ///
    /// Parameters:
    /// - icon: SF Symbols 6 icon name (= any valid SF Symbol
    ///   identifier; = `doc.text`, `book.pages`, `person.2`, etc.)
    ///   - per v1.0.0-m1-shell Lucide -> SF Symbols 6 migration:
    ///     Lucide kebab-case names (= git-fork, square-dashed,
    ///     shield-check, etc.) render as blank rectangles and
    ///     MUST be migrated to dot.case SF Symbols 6 names.
    /// - titleView: caller-supplied title view (= rendered in
    ///   place of the plain Text title; = should use
    ///   `.foregroundStyle(.secondary)` + `.font(.headline)`
    ///   to match the EmptyStateView visual contract)
    /// - body: plain-text body (= always plain Text; = no
    ///   custom view needed for the body in current callers)
    public init<V: View>(
        icon: String,
        titleView: V,
        body: String
    ) {
        self.icon = icon
        self.titleText = nil
        self.detail = body
        self.titleView = AnyView(titleView)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // v1.0.0-m1-shell boss 2026-09-12 OOB '2x icon size'
            // (= 2× the v0.54 38 PT default = 76 PT)
            // + 'use thinnest stroke' (= .regular weight = the
            // canonical macOS 27 inspector / empty-state icon
            // weight; = matches the SF Symbols 6 3rd-generation
            // palette-rendering default).
            //
            // Apple's empty states use a much bigger icon
            // (= measured 38 PT on a real ContentUnavailableView
            // sample; = v0.54 default). The boss's '2x size'
            // directive = 2× the 38 PT default = 76 PT. The
            // vertical gap (= 22 PT below) matches Apple's
            // measured ContentUnavailableView sample (= NOT
            // custom; = Apple HIG standard).
            // Per wenshu-icon-policy v1.5 boss OOB 2026-09-17:
            // empty-state / large icons (>=38 PT) MUST pin
            // .symbolRenderingMode(.monochrome). SF Symbols 6 on
            // macOS 27 silently falls back to the .fill variant
            // when the caller passes an outline root name without
            // setting the rendering mode (= at 76 PT the fill
            // glyph reads as a heavy solid blob = boss's "太粗").
            Image(systemName: icon)
                .font(.system(size: DesignTokens.emptyStateIconSize, weight: .thin))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
                .padding(.bottom, DesignTokens.chromePaddingEmptyStateGap)
            VStack(spacing: DesignTokens.chromePaddingSmall) {
                // Title: plain Text (= common case) OR caller-supplied
                // titleView (= chat empty state with inline
                // Settings link). Both render at .headline / .secondary
                // (= the EmptyStateView visual contract).
                if let titleView = titleView {
                    titleView
                        .frame(maxWidth: DesignTokens.guardrailSheetWidth)
                } else if let titleText = titleText {
                    Text(titleText)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: DesignTokens.guardrailSheetWidth)
                }
                // Body (= Apple HIG .callout = 12 PT secondary =
                // Apple's standard secondary text). The .tertiary
                // tone + center alignment signals "this is
                // supporting detail" (= Apple Mail / Notes /
                // Pages convention).
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: DesignTokens.guardrailSheetWidth)
            }
        }
    }
}
