//
//  EmptyStateView.swift
//  wenshu
//
// Unified empty-state component (= single source
//  of truth for every "no content" zone in the wenshu workspace).
//  All 12 specialized tool tabs use this component via
//  `EmptyStateView(icon:title:body:)` (= same visual treatment
//  across every tab; = no hand-rolled VStack { Text + Text }
//  duplicates).
//
// SF Symbols 6 drawOn animation via
//  `.symbolEffect(.drawOn.individually, options: .nonRepeating)`
//  HIDES the icon entirely on macOS 27. SDK research
//  (= MacOSX.sdk/Symbols.framework/Symbols.swiftinterface):
//    - `symbolEffect(_:options:isActive:)` overload takes
//      `IndefiniteSymbolEffect` (= sustained = the icon should
//      stay drawn; = the modifier renders via
//      `_IndefiniteSymbolEffectModifier` body = .never).
//    - `symbolEffect(_:options:value:)` overload takes
//      `DiscreteSymbolEffect` (= value-bound = one-shot);
//      `DrawOnSymbolEffect` is NOT a `DiscreteSymbolEffect`.
//    - `.transition(.symbolEffect(...))` requires a mount /
//      unmount boundary; = the empty-state icon is permanently
//      mounted; = the transition never fires.
//  Drop the symbolEffect modifier and
//  keep the monochrome tint. The icon renders correctly
//  (= no animation, but visible). The draw-on animation is
//  deferred to a future ticket (= will require either a macOS
//  SDK fix or wrapping the icon in a structural .transition
//  boundary).
//
//  Design contract (= what each caller MUST honor):
//
//  Layout: centered VStack filling the entire available space
//  (= caller wraps in any frame). Icon at top, title + body
//  below (= no header bar; = pure empty state).
//
//  Icon (= SF Symbols 6):
//    - SF Symbol 6 identifier (= Apple SF Symbol
//      name; = dot.case form like 'books.vertical')
//    - size: 76 PT (= 2x the canonical '2x size'
//      directive)
//    - color: .secondary (= adapts to dark/light mode; =
//      Apple's 2-step hierarchy for empty-state icons)
//
//  Title:
//    - .font(.headline)
//    - .foregroundStyle(.secondary)
//    - 1 line, no truncation
//
//  Body:
//    - .font(.callout)
//    - .foregroundStyle(DesignTokens.statusForeground = .tertiary)
//    - multilineTextAlignment(.center)
//    - maxWidth: 360 (= wraps on small inspector columns)
//
//  Spacing:
//    - icon -> title: DesignTokens.spacingSection (= the
//      product standard ContentUnavailableView measured value;
//      = the literal number isn't Apple-default = Apple doesn't
//      expose this value publicly; = we use a semantic token instead)
//    - title -> body: chromePaddingSmall (= product standard for
//      title->caption spacing)
//    - body maxWidth: DesignTokens.guardrailSheetWidth (= 360 PT
//      = product modal sheet width = the empty-state body
//      should wrap to the same width as a standard modal sheet)
//    - icon size: IconStyle.emptyStateHero (= 76 PT
//      = 2x the canonical empty-state
//      icon size; = not a magic number = semantic token)

import SwiftUI

/// Unified empty-state component for ALL "no content" zones in
/// the wenshu workspace (= 12 specialized tool tabs + editor
/// zone + PreviewPane + future zones). Caller provides the icon
/// (= SF Symbols 6 name; = e.g. "book.pages" for a book-themed
/// empty state; = any valid SF Symbol 6 identifier).
/// Caller also supplies title (= String) and body (= String).
///
/// Usage:
///
/// ```swift
/// EmptyStateView(
///     icon: "doc.text",  // SF Symbols 6 name
///     title: String(localized: "foreshadowingview.empty.title"),
///     body: String(localized: "foreshadowingview.empty.body")
/// )
/// ```
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
struct EmptyStateView: View {
    let icon: String
    let titleText: String?
    let detail: String
    /// Caller-supplied custom title view (= AnyView so the two
    /// init flavors can store different concrete types in the
    /// same property). nil when the plain-text title init was used.
    let titleView: AnyView?

    /// Plain-text title init (= the common case).
    init(icon: String, title: String, body: String) {
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
    init<V: View>(
        icon: String,
        titleView: V,
        body: String
    ) {
        self.icon = icon
        self.titleText = nil
        self.detail = body
        self.titleView = AnyView(titleView)
    }

    var body: some View {
        VStack(spacing: 0) {
            // The empty state's glyph is a zone, not a label: `emptyStateHero`
            // is the size an empty state reads at and the factory draws it at
            // the uniform weight every other glyph in the app gets.
            //
            // A large outline symbol has to name its rendering mode. Left
            // unset, SF Symbols falls back to the filled variant, and a filled
            // glyph at this size reads as a solid blob rather than a picture of
            // the thing that is missing.
            //
            // No `symbolEffect` on this glyph: the indefinite effect path
            // leaves a monochrome symbol in this zone unreadable.
            SFIcon(icon, style: .emptyStateHero, color: IconColor.secondary)
            .padding(.bottom, DesignTokens.spacingSection)
            VStack(spacing: DesignTokens.spacingTight) {
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
                // The detail line is the callout role in a
                // tertiary tone, centered: one supporting line,
                // not a second body.
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: DesignTokens.guardrailSheetWidth)
            }
        }
    }
}
