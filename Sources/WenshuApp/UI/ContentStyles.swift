//
//  ContentStyles.swift · Wenshu · STYLES-001
//
//  Style primitives for CONTENT (= the inner content of each zone,
//  between the parent's chrome top bar and bottom bar). Companion
//  to ChromeStyles.swift (= which owns the chrome styling).
//
//  Boss 9/7 'styles can actually be unified' (= applied to the content
//  side too, not just the chrome) + boss 9/7 'UI and function separated' = the
//  content view (= each zone's actual UI) only owns FUNCTIONAL
//  wiring (= which tabs render, which buttons open which sheet,
//  which text shows). The visual styling (padding / spacing /
//  text style / button style / icon style) lives here.
//
//  Ponytail principle (= boss 2026-08-31 directive 'linrear
//  priority 7-tier ladder'): use stdlib / Apple-native / existing
//  dependencies BEFORE writing new code. Apple canonical:
//  - .contentMargins(_:for:) (= iOS 17 / macOS 14 SwiftUI standard
//    for ScrollView content insets; = the right primitive for
//    "set the content's edge-to-zone-edge inset once").
//  - .defaultScrollAnchor / .scrollContentLayout = ScrollView
//    helpers.
//  - .formStyle / .labelStyle / .buttonStyle = Apple built-in
//    styles for forms / labels / buttons.
//
//  Why this file exists separately from DesignTokens:
//  - DesignTokens = VALUES (= 18 PT, 30 PT, .controlBackgroundColor).
//  - ContentStyles = MODIFIERS (= View extensions that compose
//    those values into reusable styles).
//  - ChromeStyles = CHROME (= background + top + bottom bar).
//  - ContentStyles = CONTENT (= spacing + typography + buttons +
//    icons inside each zone).
//
//  Usage (= inside a zone's content view):
//      VStack { ... }
//          .contentInsetStyle(.standard)        // 18 PT all sides
//          .sectionTitleStyle()                   // Apple canonical title
//          .primaryActionButtonStyle()            // borderedProminent
//

import SwiftUI

// MARK: - Content insets (= boss 9/7 'test it, zones 1-2-4 are visibly too large')

/// STYLES-001 (2026-09-07): canonical content inset variants.
/// Each preset = a complete Apple-canonical edge-to-content
/// distance (= no scattered `.padding(.horizontal, 18)` calls).
///
/// Apple HIG alignment: matches `.contentMargins(_:for:)` =
/// SwiftUI standard for ScrollView content edges (iOS 17 / macOS
/// 14+). Applied as a regular `.padding(...)` modifier here
/// because we wrap non-ScrollView content too (= LazyVGrid, VStack,
/// etc. = the modifier would not apply on those).
///
/// Why multiple presets (= not one canonical value):
/// - `.standard` (= 18 PT) = the workspace default (= matches
///   the editor's 18 PT top padding, the preview zone's 18 PT
///   padding, the NSTextView/NSScrollView default content margins).
/// - `.compact` (= 12 PT) = for zones with denser content (= e.g.
///   the sidebar's tree outline, where each row is ~25 PT and a
///   18 PT top/bottom inset wastes 36 PT of vertical space).
/// - `.none` (= 0 PT) = for zones with Apple-built-in insets (=
///   e.g. List(.sidebar) has its own internal content margins;
///   = do NOT add ours on top = doubled visual inset).
/// - `.custom(value)` = escape hatch (= not magic-number-free but
///   rare).
enum ContentInset {
    case standard       // 18 PT — workspace default
    case compact        // 12 PT — dense content
    case none           // 0 PT — Apple-built-in inset only
    case custom(CGFloat)

    var value: CGFloat {
        switch self {
        case .standard:       return 18
        case .compact:        return 12
        case .none:           return 0
        case .custom(let v):  return v
        }
    }
}

extension View {
    /// STYLES-001 (2026-09-07): apply a canonical content inset to
    /// the modified view (= 4 sides by default; pass `edges:` to
    /// restrict to specific sides). Use this on every zone's
    /// content VStack/HStack so inset values are centralized here
    /// (= one token change adjusts all zones).
    ///
    /// Note (= Apple HIG alignment): this is NOT the same as
    /// `.contentMargins(_:for:)` (which only applies to
    /// ScrollView). It's a plain `.padding(_:)` modifier (= applies
    /// to anything) so zones that use LazyVGrid / VStack get the
    /// same canonical inset.
    ///
    /// Per-zone override (= Apple-built-in insets already on):
    /// pass `.none` (= e.g. List(.sidebar) has its own content
    /// margins; = do NOT add ours on top = doubled visual inset).
    @ViewBuilder
    func contentInsetStyle(
        _ preset: ContentInset = .standard,
        edges: Edge.Set = .all
    ) -> some View {
        switch preset {
        case .none:
            self
        default:
            self.padding(edges, preset.value)
        }
    }
}

// MARK: - Section styles (STYLES-001 2026-09-07) were deleted in
// the v1.27 Q99 dead-code sweep (= 0 production refs for either
// SectionTypography enum or sectionTypographyStyle extension;
// = Apple canonical .font(.title/.body/.caption) used directly in
// each zone, so the indirection added no value). The remaining
// ContentInset (still used by MemoryRetrievalPanel) and the file
// header / doc comments are preserved.

// MARK: - (button styles removed; use Apple .buttonStyle(.borderedProminent) directly)

