// LucideIcon.swift · Wenshu () · v0.27
//
// Boss 2026-08-27 OOB: ' apple sf ，replace lucide，
// ，'. = replace ALL Image(systemName:) usage
// with Lucide("...") across the wenshu codebase.
//
// This file provides the central Icon helper. Call sites should use:
//
//   LucideIcon("folder")                          // direct lookup (Lucide canonical name)
//   LucideIcon.fromSystemSymbol("checkmark")      // SF Symbol name → Lucide fallback

import SwiftUI
import LucideSwift
import AppKit

/// Resolves the macOS sidebar icon size preference (= NSTableViewDefaultSizeMode
/// in NSGlobalDomain). Maps the 1/2/3 raw integer to a Point size for custom
/// Lucide icons so they adapt to the user's "Sidebar icon size" system preference
/// (= Apple HIG Sidebars: 'A sidebar's row height, text, and glyph size depend
/// on its overall size, which can be small, medium, or large.').
///
/// v0.30 boss 8/30 OOB test 'Apple Settings → General → Sidebar icon size = change
/// Small/Medium/Large sidebar yesno' = sidebar icons should adapt when
/// user changes system preference. Custom Lucide icons (= non-SF-Symbol) need
/// to manually read this setting (= SF Symbols auto-adapt via SwiftUI's
/// Label intrinsic sizing).
///
/// Mapping per Apple HIG (Finder/Mail/Notes sidebar defaults):
/// - Small  (rawValue 1) → 12 PT
/// - Medium (rawValue 2) → 14 PT (= default)
/// - Large  (rawValue 3) → 18 PT
public func wenshuSidebarIconSize() -> CGFloat {
    let raw = UserDefaults.standard.integer(forKey: "NSTableViewDefaultSizeMode")
    switch raw {
    case 1: return 12   // Small
    case 3: return 18   // Large
    default: return 14 // Medium (= 2 OR 0 unset = default fallback)
    }
}

/// Wenshu canonical icon helper. Resolves an icon name (= wenshu
/// convention = Lucide kebab-case) into a Lucide View. Falls back to
/// an empty 18x18 frame for missing icons (= followup: add the
/// correct icon name).
///
/// Usage:
/// ```swift
/// LucideIcon("folder")                          // 18 PT (= general usage)
/// LucideIcon("chevron-right", size: 12)         // 12 PT explicit override
/// LucideIcon.sidebar("folder")                  // 14 PT (= sidebar icon size,
///                                               //  adapts to NSTableViewDefaultSizeMode)
/// LucideIcon.fromSystemSymbol("checkmark")      // SF 'checkmark' → Lucide 'check'
/// ```
/// v1.0.0-m1-shell boss 2026-09-12 OOB 'Lucide 最细的多少?
/// 现在放大了, 线条好粗': ajaxjiang96/lucide-swift fork exposes
/// `LucideIcon(name:)` directly (= no more internal `Lucide(name)`
/// returning optional). The LucideIcon helper below now wraps
/// `LucideIcon(name: String, size: CGFloat)` (= the fork's public
/// non-optional init). The default strokeWidth: 2 (= the fork's
/// default for LucideIconName) is used (= the same visual
/// rendering as the old bring-shrubbery fork's baked fills).
/// v1.0.0-m1-shell boss 2026-09-12 OOB '排查所有 icon 位置, 统一替换'
/// (= a few of the Lucide icon names that wenshu was using under
/// the bring-shrubbery/lucide-swift 1.25.0 fork don't exist as
/// LucideIconName cases in the ajaxjiang96/lucide-swift 0.9.4 fork;
///
/// e.g. 'book-plus' (bring-shrubbery) is exposed as '.bookPlus' in
/// the fork (= camelCase enum case). Without an alias, the wenshu
/// wrapper's `LucideIconName(rawValue: name)` check returns nil
/// for these names and the wrapper renders an empty Color.clear
/// placeholder (= no visible icon at the callsite).
///
/// The alias table below catches the 19 known affected kebab-case
/// names and maps them to the corresponding fork enum case. Order
/// matters: more specific (suffix-stripped) matches first (= 'trash-2'
/// = '.trash', not '.trash2').
///
/// To extend: append `(kebabName, enumCase)` to the table and
/// rebuild (= a `print("\(kebabName) -> not in fork enum")` log
/// in CI would surface any further missing names).
private let lucideNameAliases: [String: String] = {
    let map: [String: String] = [
    // bring-shrubbery had a separate `sidebar-right` (= the right
    // sidebar panel) distinct from `panel-right`. The ajaxjiang96
    // fork merged both into `panelRight` (= the toolbar inspector
    // toggle uses this when collapsed). The fork's enum rawValue
    // is camelCase (= the case declaration is `case panelRight`,
    // NOT `case panel-right`); = the alias MUST be the camelCase
    // rawValue.
    "sidebar-right": "panelRight",
    // bring-shrubbery `sidebar-left` → ajaxjiang96 `panelLeft` (= the
    // camelCase rawValue of the fork's `case panelLeft`).
    "sidebar-left": "panelLeft",
    // suffix-stripped
    "maximize-2": "maximize",
    "minimize-2": "minimize",
    "undo-2": "undo",
    "trash-2": "trash",
    // kebab -> camelCase
    "book-plus": "bookPlus",
    "circle-arrow-down": "circleArrowDown",
    "circle-check": "circleCheck",
    "circle-dot": "circleDot",
    "circle-plus": "circlePlus",
    "circle-x": "circleX",
    "file-plus": "filePlus",
    "list-checks": "listChecks",
    "refresh-cw": "refreshCw",
    "search-check": "searchCheck",
    "square-arrow-right": "squareArrowRight",
    "triangle-alert": "triangleAlert",
    "wand-sparkles": "wandSparkles",
    ]
    return map
}()

/// v1.0.0-m1-shell boss 2026-09-12 OOB '排查所有 icon 位置, 统一替换':
/// resolve a Lucide icon name (= kebab-case string) to the
/// ajaxjiang96 fork's LucideIconName case. Falls back to
/// stripping the trailing '-2' (a common older pattern in
/// bring-shrubbery; e.g. 'trash-2' -> 'trash') then to the
/// direct LucideIconName(rawValue:) lookup (= the strict
/// path for names that have no alias and no fork match).
///
/// Exposed as `internal` (= not public) so LucideThinIcon and
/// other internal wrappers can call it; = NOT part of the
/// stable wenshu public API (= callers should go through the
/// LucideIcon / LucideImage / LucideIconSystemFallback / etc.
/// public wrappers).
internal func resolveLucideName(_ name: String) -> LucideIconName? {
    // 1. Direct rawValue match (= handles 'kanban', 'library',
    //    'plus', 'wrench', etc. unchanged).
    if let direct = LucideIconName(rawValue: name) {
        return direct
    }
    // 2. Explicit alias table (= handles the 19 names that
    //    don't have a clean kebab→camelCase mapping; e.g.
    //    'trash-2' -> 'trash' which is NOT the result of a
    //    naive kebab→camelCase conversion).
    if let alias = lucideNameAliases[name] {
        if let mapped = LucideIconName(rawValue: alias) {
            return mapped
        }
    }
    // 3. Generic kebab→camelCase conversion (= handles the
    //    general case where the wenshu codebase uses kebab-case
    //    rawValues from the bring-shrubbery fork 1.25.0 but
    //    the ajaxjiang96 fork 0.9.4 uses camelCase for both
    //    case names and rawValues; = e.g. 'book-open' ->
    //    'bookOpen', 'circle-arrow-down' -> 'circleArrowDown',
    //    'sidebar-left' -> 'panel-left'; = if the naive
    //    kebab→camelCase conversion yields a valid enum case
    //    (= the camelCase name appears in the fork's enum),
    //    use it).
    let camelCased = kebabToCamelCase(name)
    if let mapped = LucideIconName(rawValue: camelCased) {
        return mapped
    }
    // 4. Drop a trailing '-2' suffix and retry (= handles the
    //    older 'trash-2' / 'maximize-2' style names that were
    //    disambiguated in bring-shrubbery 1.25.0 but merged
    //    with their base name in ajaxjiang96 0.9.4).
    if name.hasSuffix("-2") {
        let stripped = String(name.dropLast(2))
        if let mapped = LucideIconName(rawValue: stripped) {
            return mapped
        }
        // Also try kebab→camelCase of the stripped form.
        let strippedCamel = kebabToCamelCase(stripped)
        if let mapped = LucideIconName(rawValue: strippedCamel) {
            return mapped
        }
    }
    return nil
}

/// Convert kebab-case to camelCase (= "book-open" -> "bookOpen",
/// "circle-arrow-down" -> "circleArrowDown"). Helper for
/// `resolveLucideName` (= the general kebab→camelCase fallback
/// for the ajaxjiang96 fork's camelCase rawValue convention).
private func kebabToCamelCase(_ kebab: String) -> String {
    let parts = kebab.split(separator: "-")
    guard let first = parts.first else { return kebab }
    return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
}

/// LucideIcon as a default-arg helper (= call without name: to get
/// the fork's default fork name = 'activity' = an animated chevron).
@ViewBuilder
private func resolveLucideIconView(_ name: String, size: CGFloat) -> some View {
    if let iconName = resolveLucideName(name) {
        LucideIcon(
            iconName,
            size: size,
            strokeWidth: 1,
            absoluteStrokeWidth: true
        )
    } else {
        // Empty placeholder (= icon name not found in lucide;
        // followup = add the correct icon name).
        Color.clear.frame(width: size, height: size)
    }
}

@ViewBuilder
public func LucideIcon(_ name: String, size: CGFloat = 18) -> some View {
    // v1.0.0-m1-shell ajaxjiang96 fork: `LucideIcon(name:)` is
    // non-optional. Always succeeds (= falls back to the house
    // icon if `name` doesn't match any LucideIconName case; = the
    // fork's built-in resolver). To preserve the original wenshu
    // contract (= missing icon = empty placeholder rather than a
    // house icon), we use `resolveLucideName` (= the kebab-case to
    // camelCase alias table + the '-2' suffix stripper + the strict
    // rawValue match). If everything fails, return Color.clear.
    //
    // v1.0.0-m1-shell boss 2026-09-12 OOB 'Lucide 最细的多少?
    // 现在放大了, 线条好粗': render with strokeWidth: 1 (= 1 PT
    // hairline = the thinnest Apple HIG macOS 27 icon weight; =
    // matches the empty-state icons rendered by LucideThinIcon).
    if let iconName = resolveLucideName(name) {
        // v1.0.0-m1-shell boss 2026-09-12 OOB '大量 icon 消失,
        // 建议你还得慢点, 没一个都先验证一下会不会 miss': pass the
        // RESOLVED enum case (= e.g. .userRound) to the fork, NOT
        // the original raw string (= e.g. 'user-round'). Passing
        // the original rawValue causes the fork's internal
        // resolver to silently fall back to .house (= visually
        // looks like a missing icon for callers using kebab-case
        // rawValues like 'square-dashed' or 'user-round' from the
        // bring-shrubbery 1.25.0 era).
        LucideIcon(
            iconName,
            size: size,
            strokeWidth: 1,
            absoluteStrokeWidth: true
        )
            .frame(width: size, height: size)
            .foregroundStyle(.primary)
    } else {
        Color.clear
            .frame(width: size, height: size)
    }
}

/// Sidebar icon variant (= size derived from macOS sidebar icon size
/// system preference). Use this for icons inside List(.sidebar) rows.
/// Per Apple HIG, sidebar icons MUST adapt to user's "Sidebar icon size"
/// preference (= Small/Medium/Large). Without this, custom icons stay
/// fixed while SF Symbols auto-resize, breaking visual harmony.
@ViewBuilder
public func LucideIconSidebar(_ name: String) -> some View {
    // v1.0.0-m1-shell boss 2026-09-12 OOB 'Lucide 最细的多少?
    // 现在放大了, 线条好粗': strokeWidth: 1 + absoluteStrokeWidth: true
    // (= 1 PT hairline at every size = the same Apple HIG
    // inspector-tab visual weight regardless of the user's
    // "Sidebar icon size" preference).
    //
    // v1.0.0-m1-shell boss 2026-09-12 OOB '排查所有 icon 位置, 统一替换':
    // route through `resolveLucideName` so callers using
    // 'trash-2' (= bring-shrubbery rawValue) hit the
    // ajaxjiang96 enum case `trash`.
    if let iconName = resolveLucideName(name) {
        LucideIcon(
            iconName,
            size: wenshuSidebarIconSize(),
            strokeWidth: 1,
            absoluteStrokeWidth: true
        )
    } else {
        Color.clear.frame(width: wenshuSidebarIconSize(), height: wenshuSidebarIconSize())
    }
}

/// Icon helper that takes an SF Symbol name (= legacy / boss shorthand)
/// and resolves it to the canonical Lucide equivalent. Falls back to
/// the SF Symbol itself if no Lucide match exists (= preserves
/// behavior so boss can request a followup rename).
///
/// Mapping (= boss 8/27 '，' = if SF Symbol name
/// is already valid Lucide, use directly; otherwise try the closest
/// Lucide equivalent):
/// - SF 'checkmark' → Lucide 'check'
/// - SF 'sidebar.left' → Lucide 'panel-left'
/// - SF 'eye.fill' → Lucide 'eye'
/// - SF 'wrench.and.screwdriver' → Lucide 'wrench'
/// - SF 'bubble.left' → Lucide 'message-square'
/// - SF 'chart.bar' → Lucide 'chart-bar'
/// - SF 'square.and.arrow.up' → Lucide 'share-2'
/// - SF 'paperplane.fill' → Lucide 'send'
/// - SF 'arrow.down.doc' → Lucide 'arrow-down-to-line'
/// - SF 'square.and.pencil' → Lucide 'square-pen'
/// - SF 'arrow.down.right.and.arrow.up.left' → Lucide 'minimize-2'
/// - SF 'arrow.up.left.and.arrow.down.right' → Lucide 'maximize-2'
/// - SF 'chevron.up.chevron.down' → Lucide 'chevrons-up-down'
/// - SF 'cpu' → Lucide 'cpu'
/// - SF 'plus' → Lucide 'plus'
/// - SF 'folder' → Lucide 'folder'
/// - SF 'key' / 'key.fill' → Lucide 'key'
/// - SF 'chevron.right' → Lucide 'chevron-right'
/// - SF 'chevron.down' → Lucide 'chevron-down'
/// - SF 'eye' → Lucide 'eye'
/// - SF 'gauge' → Lucide 'gauge'
/// - SF 'person' / 'person.crop.circle' → Lucide 'user'
/// - SF 'tag' → Lucide 'tag'
@ViewBuilder
public func LucideIconSystemFallback(_ sfSymbol: String, size: CGFloat = 18) -> some View {
    // v1.0.0-m1-shell boss 2026-09-12 OOB 'Lucide 最细的多少?
    // 现在放大了, 线条好粗': render with strokeWidth: 1 (= 1 PT
    // hairline = the thinnest Apple HIG macOS 27 icon weight; =
    // matches the empty-state icons rendered by LucideThinIcon).
    //
    // The mapping chain below is the same as before (= SF → Lucide
    // name via sfSymbolToLucideName; = direct Lucide name as
    // fallback for SF names that double as Lucide; = question-mark
    // placeholder for unmapped SF names). All three rendering paths
    // now use strokeWidth: 1 + absoluteStrokeWidth: true (= 1 PT
    // hairline regardless of size = same visual weight across the
    // app).
    let lucideName = sfSymbolToLucideName(sfSymbol)
    if let iconName = resolveLucideName(lucideName) {
        LucideIcon(
            iconName,
            size: size,
            strokeWidth: 1,
            absoluteStrokeWidth: true
        )
            .frame(width: size, height: size)
            .foregroundStyle(.primary)
    } else if let iconName = resolveLucideName(sfSymbol) {
        // SF Symbol name is itself valid as Lucide name (= e.g. 'plus',
        // 'folder', 'cpu', 'tag' which exist in both libraries).
        LucideIcon(
            iconName,
            size: size,
            strokeWidth: 1,
            absoluteStrokeWidth: true
        )
            .frame(width: size, height: size)
            .foregroundStyle(.primary)
    } else {
        // v0.46 boss 2026-09-09 OOB 'SF Symbol is dropped, use the
        // third-party icon library': the Image(systemName:) fall-through
        // is gone. wenshu is strict Lucide-only now. An unmapped name
        // renders the Lucide question-mark glyph so a missing mapping is
        // visible on screen instead of silently blank.
        if let iconName = resolveLucideName("circle-question-mark") {
            LucideIcon(
                iconName,
                size: size,
                strokeWidth: 1,
                absoluteStrokeWidth: true
            )
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        } else {
            Color.clear
                .frame(width: size, height: size)
        }
    }
}

/// Maps an SF Symbol name to its closest Lucide equivalent (= boss
/// 8/27 ' rule). Returns the SF Symbol name unchanged
/// if a direct Lucide equivalent exists (= Lucide's API accepts both
/// kebab-case and camelCase).
private func sfSymbolToLucideName(_ sfSymbol: String) -> String {
    let mapping: [String: String] = [
        "checkmark": "check",
        "sidebar.left": "panel-left",
        "wrench.and.screwdriver": "wrench",
        "bubble.left": "message-square",
        "chart.bar": "chart-bar",
        "square.and.arrow.up": "share-2",
        "paperplane.fill": "send",
        "arrow.down.doc": "arrow-down-to-line",
        "square.and.pencil": "square-pen",
        "arrow.down.right.and.arrow.up.left": "minimize-2",
        "arrow.up.left.and.arrow.down.right": "maximize-2",
        "chevron.up.chevron.down": "chevrons-up-down",
        "person.crop.circle": "user-round",
        "person.crop.circle.badge.questionmark": "bot-message-square",
        "person.crop.square": "user-square",
        "person.text.rectangle": "user-cog",
        "exclamationmark.triangle": "triangle-alert",
        "bubble.left.and.bubble.right": "messages-square",
        "bubble.left.fill": "message-square",
        "square.grid.2x2": "layout-grid",
        "square.grid.3x2": "layout-list",
        "moon": "moon",
        "sun.max": "sun",
        "magnifyingglass": "search",
        "arrow.up.arrow.down": "arrow-up-down",
        "arrow.left.arrow.right": "arrow-left-right",
        "circle": "circle",
        "circle.fill": "circle-dot",
        "trash": "trash-2",
        "pencil": "pen",
        "doc": "file-text",
        "doc.fill": "file-text",
        "doc.on.doc": "copy",
        "arrow.up.to.line": "arrow-up-to-line",
        "arrow.down.to.line": "arrow-down-to-line",
        "arrow.left.to.line": "arrow-left-to-line",
        "arrow.right.to.line": "arrow-right-to-line",
        "folder.fill": "folder",
        "tag.fill": "tag",
        "eye.fill": "eye",
        "key.fill": "key",
        "chart.bar.fill": "chart-bar",
        "person.fill": "user",
        // v0.34 boss 2026-09-02 OOB: extend mapping to cover every
        // LucideIconSystemFallback callsite (= eliminate the Image(systemName:)
        // fall-through branch in LucideIconSystemFallback's third layer).
        // All 16 mappings below verified against lucide-swift 1.25.0
        // (= .build/checkouts/lucide-swift/Sources/Lucide/LucideIcon.swift).
        "brain": "brain",
        "checkmark.circle.fill": "circle-check",
        "circle.dashed": "circle-dashed",
        "cpu": "cpu",
        "exclamationmark.circle.fill": "triangle-alert",
        "git-branch": "git-branch",
        "git-fork": "git-fork",
        "inbox": "inbox",
        "magnifyingglass.circle": "search",
        "plus": "plus",
        "square.and.arrow.down": "square-arrow-down",
        "square-dashed": "square-dashed",
        "square-dashed-mouse-pointer": "square-dashed-mouse-pointer",
        "text.book.closed": "book-text",
        "xmark": "x",
        "xmark.circle.fill": "x",
    ]
    return mapping[sfSymbol] ?? sfSymbol
}


// MARK: - Rasterized Lucide glyph (= for controls that only accept Image)

/// Cache of rendered Lucide glyphs, keyed by name + point size.
/// `ImageRenderer` is not free, and a segmented Picker re-evaluates its
/// label on every selection change.
@MainActor
private var lucideImageCache: [String: NSImage] = [:]

/// Renders a Lucide glyph into a template `NSImage`.
///
/// Why this exists: `Lucide` is a `Shape`-filling `View`. AppKit-backed
/// SwiftUI controls that only accept `Text` or `Image` in their labels
/// (= `Picker(.segmented)`, `Menu`, `NSToolbarItem`) silently DROP any
/// other view type, so a Lucide glyph passed straight into a segmented
/// Picker renders as an empty capsule. Rasterizing to a template
/// `NSImage` and handing back an `Image(nsImage:)` makes the glyph a
/// first-class control label that also picks up the control's tint.
///
/// Boss 2026-09-09 OOB 'SF Symbol is dropped, use the third-party icon
/// library': this is the bridge that keeps segmented controls on Lucide
/// instead of falling back to SF Symbols.
@MainActor
public func LucideImage(_ name: String, size: CGFloat = 16) -> Image? {
    let key = "\(name)@\(size)"
    if let cached = lucideImageCache[key] {
        return Image(nsImage: cached)
    }
    // v1.0.0-m1-shell boss 2026-09-12 OOB 'Lucide 最细的多少?
    // 现在放大了, 线条好粗': render with strokeWidth: 1 (= 1 PT
    // hairline = the thinnest Apple HIG macOS 27 icon weight; =
    // matches the empty-state icons rendered by LucideThinIcon
    // so the rasterized toolbar items (= segmented picker pages,
    // kanban/todo buttons) and the vector icons share the same
    // visual weight across the app).
    //
    // absoluteStrokeWidth: true (= constant 1 PT regardless of
    // size; = a 16 PT toolbar item and a 76 PT empty-state icon
    // both use the same 1 PT stroke; = Apple's macOS 27 inspector
    // visual rhythm).
    //
    // ajaxjiang96 fork: `LucideIcon(name:)` is non-optional. Render
    // whatever icon resolves (= fork's fallback = house if the
    // name doesn't match). Return nil only if the renderer itself
    // fails to produce an NSImage.
    //
    // v1.0.0-m1-shell boss 2026-09-12 OOB '排查所有 icon 位置, 统一替换':
    // route through `resolveLucideName` (= the kebab-case to
    // camelCase alias table) so callers using names like
    // 'circle-x' (= bring-shrubbery rawValue) hit the
    // ajaxjiang96 enum case `circleX`. Without this, the fork's
    // LucideIcon(name:) call would fall back to the house icon
    // (= wrong visual = boss's complaint).
    guard let iconName = resolveLucideName(name) else { return nil }
    let glyph = LucideIcon(
        iconName,
        size: size,
        strokeWidth: 1,
        absoluteStrokeWidth: true
    )
    let renderer = ImageRenderer(
        content: glyph
            .frame(width: size, height: size)
            .foregroundStyle(.black)
    )
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
    guard let nsImage = renderer.nsImage else { return nil }
    // Template rendering = the control tints the glyph (= selected
    // segment gets the accent color, unselected gets the label color),
    // exactly like SF Symbols behaved.
    nsImage.isTemplate = true
    lucideImageCache[key] = nsImage
    return Image(nsImage: nsImage)
}

/// Label whose icon is a rasterized Lucide glyph. Use inside
/// `Picker(.segmented)`, `Menu`, and toolbar items.
public struct LucideLabel: View {
    private let title: String
    private let icon: String
    private let size: CGFloat

    public init(_ title: String, icon: String, size: CGFloat = 16) {
        self.title = title
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        if let image = LucideImage(icon, size: size) {
            Label { Text(title) } icon: { image }
        } else {
            Text(title)
        }
    }
}
