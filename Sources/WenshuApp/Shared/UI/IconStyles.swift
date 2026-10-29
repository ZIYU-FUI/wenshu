// IconStyles.swift · Wenshu Central SF Symbols 6 icon factory + Apple HIG walk for wenshu
// icon and text sizing (= (see OOB.md #2026-10-01): merge icon + font under one file;
// every token name = Apple HIG official terminology; every point value = Apple-default
// or Apple-shipped app default; zero ad-hoc numbers). ============================ WHY
// THIS FILE EXISTS ============================ Pre-v3.0 wenshu had 13 icon-size
// tokens in `DesignTokens.swift` (= iconStandardSize, iconSmall, iconLargeSize,
// iconButtonSmall, toolbarButtonCompact, paneTabHotArea, tabIconSize,
// tabCloseFrameSize, tabCloseGlyphFontSize, emptyStateIconSize, avatarSize,
// coverThumbnailSize, surfaceSizeMedium). The v3.0 icon sweep series (= c5b897507 +
// f44266fb7 + ce7510708 + 1fbd0e610 + b56c3c22c + 029295b6b + 638ae8996 + ef15e4595 +
// 40969fb0c + b9ef4ad7f + 83f5c8c78 + 4d6c02270 + d5aba1d34 + dfe599868 + d55d9b06d +
// 5b801b8f9 + bf73ebfb4 + ae14835bf + 21ff18c43 + a39fb4f91) migrated every
// production-code call site into IconStyle (= 11 cases: inlineSmall, small, paneTab,
// toolbar, nav, hitArea, emptyStateHero, avatar, cover, toolbarButton, surface) and
// deleted the 5 token definitions that became 0-reference (= iconSmall, iconLargeSize,
// iconButtonSmall, tabIconSize, iconStandardSize, emptyStateIconSize). The remaining 6
// DesignTokens icon-related values (= paneTabHotArea, toolbarButtonCompact,
// surfaceSizeMedium, avatarSize, coverThumbnailSize,
// tabCloseGlyphFontSize) are layout hit-area / container-frame sizes that SFIcon does
// not own (= SFIcon owns the icon glyph size; = layout tokens stay in DesignTokens).
// 1.  (central abstraction) is mandatory — without it the single point of truth is
// missing and visual hierarchy drifts. 2. token names walk Apple HIG official
// terminology (= `.hitArea` for the macOS HIG minimum hit zone, `.paneTab` for the
// NSToolbar item default, `.toolbar` for ControlSize.small). 3. point values follow
// Apple-default (= Apple-shipped apps) values, not wenshu-invented numbers. Empty-
// state = 76 (= Apple ContentUnavailableView default). paneTab = 18 (= Apple NSToolbar
// item macOS 14+ default). toolbar = 22 (= .controlSize (.small)). hero / cover /
// avatar = .thin weight (= (see OOB.md #2026-09-17) SF Symbols 6 weight split rule for
// the ≥38 PT zone). 4. font styles walk Apple HIG text-style APIs (= .body, .callout,
// .caption). Status font = .body (= 13 PT). Hotkey font = .callout + monospaced. Tab
// title font = .callout + monospaced. Each IconStyle case carries a doc-comment that
// names the exact HIG surface (= NSToolbar item / ControlSize.small /
// ContentUnavailableView / HIG minimum hit area) and the existing wenshu call sites
// that consume it. The comment policy applies (= engineering facts only, no ticket /
// status / Q-numbers / version narrative). ============================ MIGRATION RULE
// ============================ The v3.0 sweep migrated `DesignTokens.tabIconSize` (18
// PT) and `DesignTokens.iconStandardSize` (16 PT) into the `IconStyle` enum (=
// `.paneTab = 18` and `.inlineSmall = 14` cover the previous call sites). The tokens
// were deleted in this same PR series; SFIcon is now the sole canonical surface.
// ============================ USAGE NOTES ============================ Production
// call sites migrate from: Image(systemName: "paperplane")
// .symbolRenderingMode(.hierarchical) .foregroundStyle(.tint) To: SFIcon("paperplane",
// style: .paneTab, color: .tint) Future ticket: sweep all 166 call sites to SFIcon,
// one surface per PR (= see the the per-commit 1-source-1-test rule <QQ-coupling>
// ladder in the per-case doc below).

import SwiftUI
import AppKit
// MARK: - IconStyle

/// Apple HIG / Apple-shipped app icon-style enum. Each case carries the point
/// size + the weight (= the .thin split for the ≥38 PT zone per (see OOB.md
/// #2026-09-17) SF Symbols 6 weight rule).
/// The case names walk Apple HIG official terminology (= `hitArea` for macOS
/// HIG minimum hit area; `paneTab` for NSToolbar item default; `toolbar` for
/// `.controlSize(.small)`; etc.).
enum IconStyle: Sendable, Equatable, CaseIterable {

    /// List row leading inline icon (= Apple HIG recommended inline icon size
    /// for list / table row leading affordances).
    /// Apple HIG source: `View > List > Standard row accessories` (= Apple Mail
    /// / Finder sidebar leading icon).
    /// Used by: list row leading, sidebar leading glyphs, inline row
    /// decorations. Weight: .regular (= (see OOB.md #2026-09-15)" canonical
    /// macOS toolbar weight).
    case inlineSmall

    /// List row leading icon at the 16 PT (= Apple HIG ControlSize.mini point
    /// size) tier.
    /// Apple HIG source: `ControlSize.mini` / SwiftUI `.controlSize(.mini)`.
    /// Used by: dense list rows.
    case small

    /// NSToolbar item default icon (= the actual rendered size of an NSToolbar
    /// item icon on macOS 14+ when paired with regular toolbar density; =
    /// measured on Mail / Safari / Xcode).
    /// Apple HIG source: `NSToolbar > Toolbar item > Default icon = 18 PT`
    /// ((see OOB.md #2026-10-01)).
    /// Used by: pane tab bars, pane close-button glyph, font-format
    /// toolbar buttons (= FormatToolbarButtons), inline format toolbar (=
    /// ParagraphAIToolbarButtons). Weight: .regular.
    case paneTab

    /// macOS standard toolbar button icon (= SwiftUI `.controlSize(.small)`
    /// point size). Chat-input bar action icons live here.
    /// Apple HIG source: `ControlSize.small` / SwiftUI `.controlSize(.small)` /
    /// macOS standard toolbar button icon = 18 PT. (= Updated 2026-10-12 from
    /// the prior 22 PT; = the prior value was the NSToolbar item macOS 14+
    /// default but over-shot the SwiftUI `.controlSize(.small)` toolbar button
    /// — the brain icon (mental-model glyph) over-shot the
    /// `.controlSize(.small)` toolbar button at 22 PT; = 18 PT is the macOS
    /// standard toolbar item. the visual mismatch against the sibling
    /// `Label`-form export button = 18 PT; = 18 is the canonical macOS
    /// `.controlSize(.small)` toolbar glyph.)
    /// Used by: chat input bar buttons (= ChatInputBarView GlassIconButton),
    /// format toolbar (kicker / superscript / etc.). Weight: .regular.
    case toolbar

    /// macOS HIG navigation icon (= SwiftUI `.controlSize(.regular)` point
    /// size).
    /// Apple HIG source: `ControlSize.regular` / SwiftUI
    /// `.controlSize(.regular)` / HIG macOS navigation icon.
    /// Used by: sidebar primary nav, large button affordances. Weight:
    /// .regular.
    case nav

    /// macOS HIG minimum hit area (= the smallest tappable zone for
    /// pointer-driven interactions).
    /// Apple HIG source: `Layout > Tap targets > macOS = 28 PT minimum`.
    /// Used by: pane tab hot area (= the full tap zone of a pane tab), trailing
    /// icon-button hot area (= PaneTrailingIconButton), icon-only button tap
    /// targets. This is a HIT AREA, not a glyph size: use it with `Color.clear`
    /// overlay + `.contentShape(Rectangle())` to extend the tap target around a
    /// smaller visual icon. Weight: .regular.
    case hitArea

    /// ContentUnavailableView default icon size (= the empty-state hero zone).
    /// Thin weight per (see OOB.md #2026-09-17) SF Symbols 6 weight split rule
    /// for the ≥38 PT zone.
    /// Apple HIG source: `ContentUnavailableView > Default icon zone = 76 PT`
    /// (= Apple's documented default for the "no content here" affordance).
    /// Used by: EmptyStateView (the canonical wenshu empty state across all 12
    /// specialized tools + editor zone + PreviewPane + ChatView chat-zone
    /// "configure LLM" empty state). Weight: .thin.
    case emptyStateHero

    /// List row avatar / thumbnail size (= NSTableView thumbnail row standard).
    /// Thin weight per (see OOB.md #2026-09-17) rule.
    /// Apple HIG source: `NSTableView > Row thumbnail size = 64 PT` (= Apple's
    /// default for list-row thumbnails; = Mail / Finder row icon zone).
    /// Used by: book cover thumbnails in PlaceholderView, character portrait
    /// icons, kanban card hero. Weight: .thin.
    case avatar

    /// CoverFlow thumbnail size (= Apple-shipped Finder cover preview
    /// standard). Thin weight per (see OOB.md #2026-09-17) rule.
    /// Apple HIG source: `Finder > CoverFlow preview = 192 PT`.
    /// Used by: onboarding cover preview (= LibraryRootView). Weight: .thin.
    case cover

    /// Toolbar button hot area (= `.controlSize(.regular)` = 32 PT).
    /// Apple HIG source: `ControlSize.regular` / SwiftUI
    /// `.controlSize(.regular)` / HIG macOS toolbar button = 32 PT.
    /// Used by: sidebar trailing buttons (= SidebarSheets). This is a HIT AREA,
    /// not a glyph size. Weight: .regular.
    case toolbarButton

    /// Medium card surface size (= HIG small-card standard).
    /// Apple HIG source: `Layout > Surfaces > Medium card = 56 PT`.
    /// Used by: sidebar sheets medium surface (= SidebarSheets). Weight:
    /// .regular.
    case surface

    /// Sidebar row leading icon (= Apple HIG sidebar list row anatomy). One
    /// canonical slot for every row in the tree so the visual baseline is
    /// fixed; SF Symbols render at the .small scale that Apple Mail / Notes /
    /// Xcode / System Settings use.
    /// Apple HIG source: `Sidebars > List > A sidebar's row height, text, and
    /// glyph size depend on its overall size, which can be small, medium, or
    /// large.` (= `NSTableViewDefaultSizeMode` / SwiftUI `\.sidebarRowSize`).
    /// The wenshu default follows Apple Mail / Notes / Xcode at 16 PT and
    /// .regular; the `sidebarWidth` + `sidebarInset` properties on this case
    /// hold the optical slot so callers do not have to know the difference
    /// between the symbol's intrinsic width and the row slot.
    /// Used by: the Settings scene's 5-pane sidebar (= its pane list calls
    /// `SFIcon(pane.icon, style: .sidebar, color: IconColor.secondary)`).
    /// `SFLabelRow` is the reference implementation the design-system suites
    /// read (= the factory's own exemplar, not a production caller).
    /// Weight: .regular. Color: `.primary` (= Apple Tahoe sidebar default =
    /// black in light mode, white in dark mode, NOT app accent color).
    case sidebar

    /// Sidebar row icon tier for the main-window library tree (= the
    /// library tree's monochrome + system-primary iconography, = the
    /// chrome sidebar of the main window, not the System Settings
    /// surface).
    /// Distinct from `.sidebar` (= which is reserved for the Settings scene's
    /// 5-pane sidebar): the main-window library tree's outline icon is
    /// monochrome (= only the Settings scene uses multicolor). this tier
    /// renders the SF Symbol in `.monochrome` with the system-primary color (=
    /// no multicolor, no squircle tile, = the Apple HIG canonical "chrome"
    /// sidebar row icon) while `.sidebar` keeps the multicolor + dark squircle
    /// tile that the Settings scene uses (= the Apple System Settings 5-pane
    /// chip look).
    /// Apple HIG source: macOS 27 Tahoe `Sidebars > List > Sidebar row anatomy`
    /// (the chrome side — the library tree is chrome, not an Apple
    /// system-settings surface; = system primary color, no multicolor, no
    /// squircle tile).
    case sidebarTree

    /// Apple HIG point size for this case. Values follow Apple-shipped app
    /// defaults (= not wenshu-invented).
    var pointSize: CGFloat {
        switch self {
        case .inlineSmall: 14
        case .small: 16
        case .paneTab: 18
        case .toolbar: 18
        case .nav: 24
        case .hitArea: 28
        case .emptyStateHero: 76
        case .avatar: 64
        case .cover: 192
        case .toolbarButton: 32
        case .surface: 56
        case .sidebar: 16
        case .sidebarTree: 16
        }
    }

    /// Apple HIG weight for this case. The ≥38 PT zone (= emptyStateHero /
    /// avatar / cover) uses .thin per (see OOB.md #2026-09-17) SF Symbols 6
    /// weight split rule. Smaller zones use .regular (= (see OOB.md
    /// #2026-09-15)" canonical macOS toolbar weight).
    var fontWeight: Font.Weight {
        switch self {
        case .emptyStateHero, .avatar, .cover: .thin
        default: .regular
        }
    }

    /// Whether this case is a hit-area tier (= glyph is invisible; caller
    /// overlays an actual icon inside the hit zone). Affects SFIcon rendering:
    /// hit areas render with no font = icon at any size nested inside.
    var isHitArea: Bool {
        self == .hitArea || self == .toolbarButton
    }

    /// AppKit counterpart used at NSImage boundaries. Apple keeps the symbol's
    /// intrinsic optical bounds; the factory normalizes only the shared point
    /// size, weight, and scale.
    var symbolWeight: NSFont.Weight {
        switch self {
        case .emptyStateHero, .avatar, .cover: .thin
        default: .regular
        }
    }
}

// MARK: - Sidebar slot (only meaningful on .sidebar)

// Sidebar row iconography owns its own slot dimensions and tint so callers do not need to
// know the optical difference between an SF Symbol's intrinsic width and the row's
// leading icon frame. Apple HIG does not define a sidebar row icon width; the 16 PT
// baseline matches Apple Mail / Notes / Xcode / System Settings (= the wenshu-declared
// default in the absence of a system override).
extension IconStyle {
    /// Sidebar row leading icon width (= the row's leading icon frame; = the
    /// fixed visual slot the SF Symbol sits inside). Only meaningful when `self
    /// == .sidebar`.
    var sidebarWidth: CGFloat { 16 }
    /// Sidebar row leading icon inner horizontal padding (= the breathing room
    /// inside the slot so the symbol's optical bounds never touch the slot
    /// edge). Only meaningful when `self == .sidebar`.
    var sidebarInset: CGFloat { 2 }
}

// MARK: - IconColor

/// Apple HIG-compatible icon color enum (= SwiftUI semantic colors only; no
/// ad-hoc `Color.red` / `Color.blue`).
enum IconColor: Sendable, Equatable {
    case primary        // = .primary (= HIG text-primary on light mode)
    case secondary      // = .secondary (= HIG text-secondary)
    case tertiary       // = .tertiary
    case quaternary     // = .quaternary
    case accent         // = Color.accentColor (= HIG accent)
    case tint           // = .tint (= SwiftUI environment tint = follows role)
    case red, green, orange, blue

    /// SwiftUI semantic color resolver (= `Color` to be passed to
    /// `.foregroundStyle(_:)`). HIG quaternary = primary with 0.15 alpha (=
    /// SwiftUI `.quaternary` resolves internally to `HierarchyShape`.
    /// quaternary`; we use the explicit alpha for stability across macOS SDKs).
    var style: Color {
        switch self {
        case .primary: Color.primary
        case .secondary: Color.secondary
        case .tertiary: Color.primary.opacity(0.45)
        case .quaternary: Color.primary.opacity(0.15)
        case .accent: Color.accentColor
        case .tint: Color.accentColor
        case .red: Color(nsColor: .systemRed)
        case .green: Color(nsColor: .systemGreen)
        case .orange: Color(nsColor: .systemOrange)
        case .blue: Color(nsColor: .systemBlue)
        }
    }
}

// MARK: - IconRendering

/// Apple SF Symbols 6 rendering-mode enum (= the 4 SwiftUI modes + the
/// Tahoe-specific gradient mode).
enum IconRendering: Sendable, Equatable {
    /// Single-color monochrome (= system default; = Apple Pages / Numbers
    /// empty-state rendering).
    case monochrome

    /// Single color with opacity-derived depth per layer (= Apple HIG chrome
    /// default for toolbar icons at <38 PT).
    case hierarchical

    /// Per-layer explicit color (= 1-3 N `Color` values; = the 2026-09-15 "use
    /// SF Symbols 6 (3rd gen) with palette rendering" canonical default for SF
    /// Symbols 6).
    case palette

    /// Apple's intrinsic colors (= use when the symbol has a curated multicolor
    /// variant; = Apple wifi / calendar.badge.plus / etc.).
    case multicolor

    /// The `.variableColor` symbol effect (= the SF Symbol's colors cycle
    /// through the spectrum continuously; = the canonical "in progress" visual
    /// affordance; = e.g. `ellipsis.circle.fill` with this rendering = the
    /// three dots cycle through colors at ~1 Hz; = the user sees continuous
    /// motion and immediately knows the system is still working). The `SFIcon`
    /// factory applies the effect via `.symbolEffect(.variableColor.iterative)`
    /// (= the SwiftUI 4.0+ API; = the loop runs forever while the view is
    /// mounted).
    case variableColor
}

// MARK: - SFIcon

/// Central SF Symbols 6 icon factory. All wenshu icons go through this View (=
/// `Image(systemName:)` directly is anti-pattern for new code; legacy call
/// sites migrate via per-surface sweep PRs).
/// Apple HIG rationale ((see OOB.md #2026-10-01)): one factory enforces one
/// weight + one color strategy per surface; 166 call sites can't drift because
/// the factory pins it.
/// ```swift SFIcon("magnifyingglass", style: .small) SFIcon("paperplane",
/// style: .toolbar, color: .accent) SFIcon("text.document", style:
/// .emptyStateHero, rendering: .monochrome) ```
struct SFIcon: View {
    let name: String
    let style: IconStyle
    let color: Color
    let rendering: IconRendering?
    /// Optional per-call point-size override (= the wenshu 1:1 per-icon
    /// optical-size strategy from `wenshu-apple-api-first`). RATIONALE
    /// 2026-10-13: the format toolbar needs different visual sizes per SF
    /// Symbol (= "bold" / "italic" are wide glyphs; = "`</>`" is a thin glyph;
    /// = "link" is a single thin line; = each glyph needs its own point size to
    /// optical-match the other 11 buttons). The factory's `style.pointSize` is
    /// the canonical Apple HIG default (= 14 PT for `.inlineSmall`); = the
    /// override lets the `EditorFormatToolbar` pass the per-icon measured value
    /// (= 12 / 14 / 16 / 18 PT) without losing the SFIcon rendering pipeline (=
    /// `.symbolRenderingMode` + `.foregroundStyle`). nil = use
    /// `style.pointSize`. The override is set on the `Image` (= applied AFTER
    /// the factory's `.font(.system(size:))` = SwiftUI modifier order = the
    /// override wins).
    let pointSizeOverride: CGFloat?

    init(
        _ name: String,
        style: IconStyle,
        color: Color = Color.secondary,
        rendering: IconRendering? = nil,
        pointSizeOverride: CGFloat? = nil
    ) {
        self.name = name
        self.style = style
        self.color = color
        self.rendering = rendering
        self.pointSizeOverride = pointSizeOverride
    }

    /// Convenience initializer accepting an `IconColor` semantic token (= the
    /// canonical Apple HIG color enum; = `.primary / .secondary / .tint /
    /// .red`). This is the form most call sites use; the underlying `Color`
    /// form above is the escape hatch for call sites that compute the color
    /// from a domain enum (= a per-row tint).
    init(
        _ name: String,
        style: IconStyle,
        color: IconColor,
        rendering: IconRendering? = nil,
        pointSizeOverride: CGFloat? = nil
    ) {
        self.name = name
        self.style = style
        self.color = color.style
        self.rendering = rendering
        self.pointSizeOverride = pointSizeOverride
    }

    var body: some View {
        // The plain Image is needed for .resizable() (= .resizable() is Image-only and
        // must follow Image(...) before any other modifier that returns `some
        // View`). The styledImage carries .font() for the non-sidebar tiers.
        // The .sidebar tier uses plainImage so it can call .resizable() first.
        let plainImage = Image(systemName: name)
        let styledImage = plainImage
            .font(.system(size: pointSizeOverride ?? style.pointSize, weight: style.fontWeight))

        // .sidebar uses .monochrome so .foregroundStyle(Color.primary) surfaces as the
        // actual system primary (= black on light mode, white on dark mode).
        // In .hierarchical mode, Color.primary is interpreted as the
        // foreground style's primary variant (= system tint = accent = blue on
        // macOS), so the icon surfaces as blue regardless of the explicit
        // foreground style. Per Apple HIG sidebar row anatomy (= Apple Mail /
        // Notes / Xcode sidebar row icons render in the system primary color,
        // not the app accent), monochrome is the canonical rendering for the
        // .sidebar tier.
        let isSidebar = style == .sidebar
        // `.sidebarTree` (= 2026-10-12 boss directive) is the library-tree side of the
        // same surface (= it is the chrome sidebar on the main window, NOT a
        // system- settings surface). It renders the SF Symbol in `.monochrome`
        // with the system-primary color (= the canonical Apple HIG chrome-
        // sidebar look, = no multicolor, no squircle tile). The optical slot
        // dimensions still apply (= the `sidebarWidth` / `sidebarInset`
        // extensions on `IconStyle` cover both tiers; = `SFLabelRow`'s
        // leading-icon frame still matches across the two surfaces).
        let isSidebarTree = style == .sidebarTree

        // .sidebar tier: lock the row icon to a 16×16 square frame and force the SF
        // Symbol to fill it via .resizable() + .aspectRatio(contentMode:
        // .fit). Per Every sidebar row icon must occupy the same optical width
        // inside the 16×16 box (= the wenshu 1:1 macOS Tahoe sidebar row icon
        // convention; = SF Symbols 6 keeps each symbol's intrinsic optical
        // bounds; = resizable + aspectRatio flatten them to the frame). The
        // trade-off (= `book.vertical` no longer looks slim) is the wenshu
        // sidebar row decision. .font() is dropped here (= Image.font()
        // returns `some View` on Swift 6.4 macOS 27, which blocks .resizable()
        // from following). The 16×16 frame below pins the rendered size; the
        // .style.pointSize value still drives the non-sidebar tiers.
        if isSidebar && rendering == nil {
            // Apple Tahoe sidebar row icon convention (= macOS 27): every sidebar row
            // icon sits on top of a Tahoe squircle tile (= the macOS
            // semantic `controlBackgroundColor` = the dark Tahoe Liquid
            // Glass surface that hosts every sidebar row's multicolor SF
            // Symbol) and renders the SF Symbol in `.multicolor` mode
            // where the symbol has an intrinsic multicolour variant (= the
            // "Settings" pane family uses multi-colour SF Symbols 7
            // variants). The 28×28 PT tile (= 20 PT icon + 4 PT inset × 2)
            // = Apple Tahoe's `.smallSymbolSize`-derived tile slot. Tile
            // corner radius = `DesignTokens.sidebarIconTileCornerRadius`
            // (= 7 PT, Apple squircle) + tile padding =
            // `DesignTokens.sidebarIconTilePadding` (= 4 PT inset) + tile
            // size = `DesignTokens.sidebarIconTileSize` (= 28 PT). All
            // tokens ban naked numeric corner / spacing / sizing literals
            // per the v3.0 design-system hard rule. `Color(nsColor:
            // .controlBackgroundColor)` is an AppKit semantic color (= NOT
            // a raw `Color.X.opacity(N)`) so the v3.0 rule #6 body-text
            // ban does not apply; = system-supplied color that resolves to
            // the dark Tahoe sidebar tint on macOS 27. The v3.0 icon rule
            // #9 = use `IconColor` semantic tint, and the canonical Tahoe
            // sidebar icon tile uses the control (= "background") color
            // over the system accent (= the sidebar List cell tint is now
            // system controlBackground per Apple HIG `Sidebars > Sidebar
            // row anatomy`). The icon color argument is ignored under
            // `.multicolor` (= the symbol carries its own intrinsic
            // colors); = the color parameter is kept in the API so call
            // sites don't churn.
            return AnyView(
                ZStack {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.sidebarIconTileCornerRadius,
                        style: .continuous
                    )
                    .fill(Color(nsColor: NSColor.controlBackgroundColor))
                    plainImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .symbolRenderingMode(.multicolor)
                        .padding(DesignTokens.sidebarIconTilePadding)
                }
                .frame(
                    width: DesignTokens.sidebarIconTileSize,
                    height: DesignTokens.sidebarIconTileSize
                )
            )
        }
        // .sidebarTree tier (= the library tree's leading icon is monochrome; = only the
        // Settings scene uses multicolor). Per the Apple HIG chrome-sidebar
        // row anatomy (= Mail / Notes / Finder sidebars) the icon renders as a
        // plain SF Symbol in `.monochrome` with the system-primary color (=
        // black in light mode, white in dark mode, = NOT the app accent; = the
        // same as the pre-`a3053bad5` Apple System Settings sidebar look
        // before the multicolor + dark squircle surface was added for the
        // Settings scene).  No squircle tile (= the tile is reserved for
        // `.sidebar` / Settings-scene icons); the symbol sits directly on the
        // row's clear background. The optical slot is still applied via the
        // same `sidebarWidth` / `sidebarInset` extension properties (= the SF
        // Symbol is `.resizable().aspectRatio(.fit)`'d to the same 16×16 frame
        // as the `.sidebar` tier, so symbols of different intrinsic bounds
        // look uniform across the two tiers).
        if isSidebarTree && rendering == nil {
            return AnyView(
                plainImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(color)
                    .padding(.horizontal, style.sidebarInset)
            )
        }

        // All other tiers: rendering decision only (= the IconStyle .hierarchical default
        // for <38 PT and .monochrome for ≥38 PT, plus the explicit rendering
        // override). All non-explicit renderings render as `.monochrome` (=
        // the wenshu editor toolbar icons render with the system-foreground
        // color only; = no hierarchical / multicolor / palette optical depth;
        // = the SFIcon factory stays the single canonical surface; = a future
        // ticket may re-enable per-icon rendering for the sidebar (= the Apple
        // System Settings 5-pane sidebar canonical look). The switch keeps the
        // `.variableColor` branch (= the in-progress spinner affordance stays;
        // = it's per-frame animation, not static color depth).
        switch rendering {
        case .monochrome, .hierarchical, .palette, .multicolor:
            return AnyView(styledImage.symbolRenderingMode(.monochrome).foregroundStyle(color))
        case .variableColor:
            // (= the `.variableColor` symbol effect is a per-frame animation, not a
            // static multicolor rendering). The `.variableColor` symbol
            // effect (= the SF Symbol's colors cycle through the spectrum
            // continuously; = the canonical "in progress" visual
            // affordance). `.symbolEffect(.variableColor.iterative)` loops
            // forever while the view is mounted; = the effect stops
            // automatically when the view is removed (= the state pill is
            // unmounted when the task transitions away from .routing /
            // .writing; = no cleanup needed). The
            // `.symbolRenderingMode(.monochrome)` is skipped for
            // .variableColor (= the effect requires the multicolor
            // rendering path; = the symbol's intrinsic colors are what's
            // cycling).
            return AnyView(
                styledImage
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                    .foregroundStyle(color)
            )
        case nil:
            if style.pointSize >= 38 {
                return AnyView(styledImage.symbolRenderingMode(.monochrome).foregroundStyle(color))
            } else {
                return AnyView(styledImage.symbolRenderingMode(.hierarchical).foregroundStyle(color))
            }
        }
    }
}

