//
//  LucideThinIcon.swift
//  wenshu
//
//  v1.0.0-m1-shell boss 2026-09-12 OOB 'What's the thinnest Lucide can go?
//  Now that it's scaled up, the strokes look really thick': thin-line Lucide wrapper for the
//  unified EmptyStateView. Renders a Lucide glyph at a
//  configurable size (= defaults to 76 PT for the EmptyStateView
//  component = 2× the v0.54 38 PT default).
//
//  This wrapper exists to expose the boss's preferred
//  strokeWidth (= 1 PT = the thinnest Apple HIG macOS 27
//  empty-state icon weight). The wenshu-pinned lucide-swift
//  was bring-shrubbery/lucide-swift 1.25.0 (= baked filled
//  outlines; = deprecated lineWidth no-op). The boss approved
//  switching to ajaxjiang96/lucide-swift 0.9.4 (= exposes
//  strokeWidth as a parameter; = renders as stroked path =
//  truly thin lines).
//
//  API mapping:
//  - `strokeWidth: 1` (= 1 PT hairline)
//  - `absoluteStrokeWidth: true` (= keep stroke at constant
//    1 PT regardless of icon size; = boss's 'thinnest' = the same
//    thin line at every rendered size)
//
//  Per the verbatim port discipline (= only do what the boss
//  asked), this commit ONLY updates the LucideThinIcon
//  wrapper to use strokeWidth: 1. The 31 other callsites that
//  use `Lucide(name)` (= the upstream API; = the fork's
//  fallback String-name init) continue to render at the fork's
//  default strokeWidth: 2 (= out of scope for this commit
//  = the boss did NOT ask to change every Lucide icon to thin
//  = only the empty-state icon was the complaint).
//
//  Public API surface:
//  - `LucideThinIcon(_ name: String, size: CGFloat = 76)` SwiftUI
//    View = renders the named Lucide glyph at 1 PT stroke at the
//    given point size.
//  - Caller controls the color via `.foregroundStyle(...)`
//    (= the standard SwiftUI shape-tinting pattern).

import SwiftUI
import LucideSwift

/// v1.0.0-m1-shell boss 2026-09-12 OOB 'What's the thinnest Lucide can go?
/// Now that it's scaled up, the strokes look really thick': Lucide glyph rendered at 1 PT
/// stroke (= the thinnest Apple HIG macOS 27 empty-state icon
/// weight). Uses the ajaxjiang96/lucide-swift fork's
/// `strokeWidth` parameter (= the upstream bring-shrubbery fork
/// does NOT expose stroke width).
///
/// Fallback: if the named icon does not exist in LucideIconName
/// (= `LucideIcon(name:)` falls back to LucideIconName.house per
/// the fork's built-in resolver), the component renders the
/// fallback icon (= a house glyph). Callers that need a
/// guaranteed icon should pick from the LucideIconName enum
/// directly via `LucideThinIcon(.activity, size: 76)`.
struct LucideThinIcon: View {
    let iconName: String
    let size: CGFloat

    init(_ iconName: String, size: CGFloat = 76) {
        self.iconName = iconName
        self.size = size
    }

    init(_ icon: LucideIconName, size: CGFloat = 76) {
        self.iconName = icon.rawValue
        self.size = size
    }

    init(lab icon: LucideLabIconName, size: CGFloat = 76) {
        self.iconName = icon.rawValue
        self.size = size
    }

    var body: some View {
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'What's the thinnest Lucide can go?
        // Now that it's scaled up, the strokes look really thick': strokeWidth: 1 (= 1 PT hairline;
        // = the thinnest Apple HIG empty-state icon weight;
        // = matched to Apple's macOS 27 inspector / Pages /
        // Numbers inspector-tab visual rhythm).
        //
        // absoluteStrokeWidth: true (= keep stroke at constant
        // 1 PT regardless of icon size; = the boss's
        // 'the thinnest possible strokes' applies even when the icon is resized;
        // = the icon's overall outline stays crisp at every
        // size).
        //
        // color: nil (= inherits from .foregroundStyle on the
        // caller's view; = consistent with Apple's standard
        // tinted-icon pattern).
        //
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'audit every icon position and replace them all consistently':
        // route through `resolveLucideName` so the empty-state
        // icons (= git-fork, square-dashed, shield-check, etc.)
        // all resolve to the right enum case (= the fork's
        // LucideIcon(name:) accepts the rawValue as fallback,
        // but the alias table catches the 19 names that exist
        // only as camelCase enum cases in the fork).
        if let iconName = resolveLucideName(iconName) {
            LucideIcon(
                iconName,
                size: size,
                strokeWidth: 1,
                absoluteStrokeWidth: true
            )
        } else {
            // Fallback = empty Color.clear (preserves the column
            // vertical rhythm even when the icon name doesn't
            // resolve; = the boss's contract: 'if you can't find it, don't render it').
            Color.clear.frame(width: size, height: size)
        }
    }
}
