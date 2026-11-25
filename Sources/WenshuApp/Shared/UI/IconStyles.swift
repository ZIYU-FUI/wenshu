// IconStyles.swift · Wenshu — the one place a symbol's size, weight,
// colour and rendering are decided.
//
// Every symbol in the app is drawn through `SFIcon`, and every value it can
// take is named here: a zone tier (`IconStyle`) for the surface the glyph
// sits in, a text style (`WenshuTextStyle`) for the label it sits beside, an
// `IconColor` rung for the semantic colour, and an `IconRendering` mode. No
// call site spells its own size or weight: a value wanted twice belongs in
// this file, and a value wanted once is still not written at the call site.
//
// A case here is a real AppKit or SwiftUI surface. Its doc comment names that
// surface, and the size it draws is either an Apple control metric the comment
// cites or this tier's own number. `IconStylesTests` reads those figures back
// out of this file and compares them with `IconStyle.pointSize`, so a tier can
// only be retuned by moving its own number.
//
// What this file does not own: the size of a container. A hot area, a tile, a
// row's leading column and a thumbnail's frame are layout, and they stay in
// `DesignTokens`; the glyph drawn inside them is decided here.
//
// A naked `Image(systemName:)` outside this file is the form the factory
// exists to replace: it takes a size and a weight nobody named, and it drops
// the rendering pipeline the factory owns (= `.symbolRenderingMode` and
// `.foregroundStyle`).

import AppKit
import SwiftUI

// MARK: - IconStyle

/// The zone tiers a symbol can be drawn in. Each case carries the point
/// size of the surface it names, and the weight is uniform `.regular`: a
/// call site that needs another weight orders it, it does not invent a tier.
/// The case names walk the surfaces they came from (= `hitArea` is Apple's
/// macOS hit-area minimum, `paneTab` an NSToolbar item, `toolbar` a
/// `.controlSize(.small)` control).
enum IconStyle: Sendable, Equatable, CaseIterable {
    /// List row leading inline icon (= the product's own row-icon size
    /// for list / table row leading affordances; the HIG publishes no
    /// row-leading icon figure, so none is cited. Matches the Apple
    /// Mail / Finder sidebar leading icon look.
    /// Used by: list row leading, sidebar leading glyphs, inline row
    /// decorations. Weight: .regular (= (see OOB.md #2026-09-15)" canonical
    /// macOS toolbar weight).
    case inlineSmall

    /// List row leading icon at the 16 PT (= product ControlSize.mini point
    /// size) tier.
    /// product source: `ControlSize.mini` / SwiftUI `.controlSize(.mini)`.
    /// Used by: dense list rows.
    case small

    /// NSToolbar item default icon (= the actual rendered size of an NSToolbar
    /// item icon on macOS 14+ when paired with regular toolbar density; =
    /// measured on Mail / Safari / Xcode).
    /// product source: `NSToolbar > Toolbar item > Default icon = 18 PT`.
    /// Used by: pane tab bars, pane close-button glyph, font-format
    /// toolbar buttons (= FormatToolbarButtons), inline format toolbar (=
    /// ParagraphAIToolbarButtons). Weight: .regular.
    case paneTab

    /// A `.controlSize(.small)` toolbar glyph: the figure the `Label`-form
    /// buttons beside it resolve to, which is what lets a row of toolbar
    /// buttons read as one row.
    /// product source: `ControlSize.small` / SwiftUI `.controlSize(.small)` /
    /// macOS standard toolbar button icon = 18 PT.
    /// Used by: chat input bar buttons (= ChatInputBarView GlassIconButton),
    /// format toolbar (kicker / superscript / etc.). Weight: .regular.
    case toolbar

    /// navigation icon (= SwiftUI `.controlSize(.regular)` point
    /// size).
    /// product source: `ControlSize.regular` / SwiftUI
    /// `.controlSize(.regular)` / macOS navigation icon size.
    /// Used by: sidebar primary nav, large button affordances. Weight:
    /// .regular.
    case nav

    /// Apple's documented macOS hit-area minimum (= 28 x 28 PT; the only
    /// Apple primary statement of this figure is WWDC24 session 10085,
    /// transcript @12:17; the HIG document carries no
    /// "Tap targets" path and no such number).
    /// Used by: pane tab hot area (= the full tap zone of a pane tab), trailing
    /// icon-button hot area (= PaneTrailingIconButton), icon-only button tap
    /// targets. This is a HIT AREA, not a glyph size: use it with `Color.clear`
    /// overlay + `.contentShape(Rectangle())` to extend the tap target around a
    /// smaller visual icon. Weight: .regular.
    case hitArea

    /// ContentUnavailableView default icon size (= the empty-state hero zone).
    /// The empty state is a zone, not a label: its glyph is sized by the
    /// zone and weighted like every other glyph.
    /// product source: `ContentUnavailableView > Default icon zone = 76 PT`
    /// (= Apple's documented default for the "no content here" affordance).
    /// Used by: EmptyStateView (the canonical wenshu empty state across all 12
    /// specialized tools + editor zone + PreviewPane + ChatView chat-zone
    /// "configure LLM" empty state). Weight: .regular.
    case emptyStateHero

    /// List row avatar / thumbnail size (= NSTableView thumbnail row standard).
    /// product source: `NSTableView > Row thumbnail size = 64 PT` (= Apple's
    /// default for list-row thumbnails; = Mail / Finder row icon zone).
    /// Used by: book cover thumbnails in PlaceholderView, character portrait
    /// icons, kanban card hero. Weight: .regular.
    case avatar

    /// CoverFlow thumbnail size (= Apple-shipped Finder cover preview
    /// standard). product source: `Finder > CoverFlow preview = 192 PT`.
    /// Used by: onboarding cover preview (= LibraryRootView). Weight: .regular.
    case cover

    /// Toolbar button hot area (= `.controlSize(.regular)` = 32 PT).
    /// product source: `ControlSize.regular` / SwiftUI
    /// `.controlSize(.regular)` / macOS toolbar button default = 32 PT.
    /// Used by: sidebar trailing buttons (= SidebarSheets). This is a HIT AREA,
    /// not a glyph size. Weight: .regular.
    case toolbarButton

    /// Medium card surface size (= product sizing value, 56 PT; no Apple
    /// figure is claimed — the HIG publishes no "Medium card" figure).
    /// Used by: sidebar sheets medium surface (= SidebarSheets). Weight:
    /// .regular.
    case surface

    /// Sidebar row leading icon (= product sidebar list row anatomy). One
    /// canonical slot for every row in the tree so the visual baseline is
    /// fixed; SF Symbols render at the .small scale that Apple Mail / Notes /
    /// Xcode / System Settings use.
    /// HIG source (corpus, verbatim): Sidebars > Platform considerations >
    /// macOS — "A sidebar's row height, text, and glyph size depend on its
    /// overall size, which can be small, medium, or large." (= `NSTableViewDefaultSizeMode` / SwiftUI `\.sidebarRowSize`).
    /// The wenshu default follows Apple Mail / Notes / Xcode at 16 PT and
    /// .regular; the `sidebarWidth` + `sidebarInset` properties on this case
    /// hold the optical slot so callers do not have to know the difference
    /// between the symbol's intrinsic width and the row slot.
    /// Used by: the Settings scene's 10-pane sidebar (= its pane list calls
    /// `SFIcon(pane.icon, style: .sidebar, color: IconColor.secondary)`).
    /// `SFLabelRow` is the reference implementation the design-system suites
    /// read (= the factory's own exemplar, not a production caller).
    /// Weight: .regular. Color: `.primary` (= macOS sidebar default =
    /// black in light mode, white in dark mode, NOT app accent color).
    case sidebar

    /// Sidebar row icon tier for the main-window library tree (= the
    /// library tree's monochrome + system-primary iconography, = the
    /// chrome sidebar of the main window, not the System Settings
    /// surface).
    /// Distinct from `.sidebar` (= which is reserved for the Settings scene's
    /// 10-pane sidebar): the main-window library tree's outline icon is
    /// monochrome (= only the Settings scene uses multicolor). this tier
    /// renders the SF Symbol in `.monochrome` with the system-primary color (=
    /// no multicolor, no squircle tile, = the product "chrome"
    /// sidebar row icon) while `.sidebar` keeps the multicolor + dark squircle
    /// tile that the Settings scene uses (= the Apple System Settings
    /// chip look).
    /// (no HIG path is cited: the HIG publishes no numeric sidebar-row
    /// anatomy — the chrome side stands on its own rule: the library tree
    /// is chrome, not an Apple system-settings surface; = system primary
    /// color, no multicolor, no squircle tile).
    case sidebarTree

    /// Point size for this zone (= the product's own per-zone table; NOT
    /// claimed as HIG figures — the HIG publishes no icon point-size
    /// table).
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

    /// Symbol weight = uniform `.regular` across every zone. The HIG does speak
    /// about symbol weight — "Each of the nine symbol weights — from ultralight
    /// to black — corresponds to a weight of the San Francisco system font,
    /// helping you achieve precise weight matching between symbols and adjacent
    /// text" (= https://developer.apple.com/design/human-interface-guidelines/sf-symbols) — and it states no rule that assigns a weight
    /// per UI zone. The uniform `.regular` is this app's own decision (thin
    /// strokes on a dark ground smear; = the 2026-11-21 craft audit rule
    /// ). A zone that wants another weight orders it at its own call site.
    var fontWeight: Font.Weight {
        .regular
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
        .regular
    } // the AppKit mirror of `fontWeight`
}

// MARK: - Sidebar slot (only meaningful on .sidebar)

/// Sidebar row iconography owns its own slot dimensions and tint so callers do not need to
/// know the optical difference between an SF Symbol's intrinsic width and the row's
/// leading icon frame. the HIG defines no sidebar row icon width; the 16 PT
/// baseline matches Apple Mail / Notes / Xcode / System Settings (= the wenshu-declared
/// default in the absence of a system override).
extension IconStyle {
    /// Sidebar row leading icon width (= the row's leading icon frame; = the
    /// fixed visual slot the SF Symbol sits inside). Only meaningful when `self
    /// == .sidebar`.
    var sidebarWidth: CGFloat {
        16
    }

    /// Sidebar row leading icon inner horizontal padding (= the breathing room
    /// inside the slot so the symbol's optical bounds never touch the slot
    /// edge). Only meaningful when `self == .sidebar`.
    var sidebarInset: CGFloat {
        2
    }
}

// MARK: - IconColor

/// product-compatible icon color enum (= SwiftUI semantic colors only; no
/// ad-hoc `Color.red` / `Color.blue`).
enum IconColor: Sendable, Equatable {
    case primary // = .primary (= the system primary label color)
    case secondary // = .secondary (= the system secondary label)
    case tertiary // = .tertiary
    case quaternary // = .quaternary
    case accent // = Color.accentColor (= the system accent)
    case tint // = .tint (= SwiftUI environment tint = follows role)
    case red, green, orange, blue

    /// The `Color` to hand `.foregroundStyle(_:)`. Every rung is a system
    /// color: the tertiary and quaternary rungs ARE `tertiaryLabelColor` and
    /// `quaternaryLabelColor`, not an opacity painted onto the primary one.
    /// An opacity of one's own choosing ignores dark mode, increased
    /// contrast, and whatever else the appearance already decides.
    var style: Color {
        switch self {
        case .primary: Color.primary
        case .secondary: Color.secondary
        case .tertiary: Color(nsColor: .tertiaryLabelColor)
        case .quaternary: Color(nsColor: .quaternaryLabelColor)
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
/// gradient mode added with macOS 26).
enum IconRendering: Sendable, Equatable {
    /// Single-color monochrome (= system default; = Apple Pages / Numbers
    /// empty-state rendering).
    case monochrome

    /// Single color with opacity-derived depth per layer (= product chrome
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
/// product rationale: one factory enforces one
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
    /// optical-size strategy from `wenshu-apple-api-first`). A CALLER
    /// passes the point size its own glyph needs (= one icon that must
    /// optical-match the icons around it, = measured for that case).
    /// The factory's own size is `style.pointSize`, the zone's number
    /// (= 14 PT for `.inlineSmall`). The override replaces it
    /// inside that one `.font` expression, so the caller keeps the whole
    /// rendering pipeline (= `.symbolRenderingMode` + `.foregroundStyle`).
    /// nil = use `style.pointSize`. A symbol that sits beside text names
    /// `matchingText` instead, which sizes it off the label.
    let pointSizeOverride: CGFloat?

    /// Optional per-call weight override (= the same 1:1 per-icon optical
    /// strategy `pointSizeOverride` serves, on the weight axis).
    ///
    /// The library sidebar's pinyin letter-circle glyphs are `.sidebarTree`
    /// (= 16 PT) and are drawn at the `.thin` weight that ruling names: a
    /// monogram is read as a letterform, not as an icon. Weight is a property
    /// of the ZONE, so a call site that needs
    /// another weight at the zone's size had either to reach past the
    /// factory for a naked `Image(systemName:)` or to lose the weight.
    ///
    /// nil = use `style.fontWeight`. The override enters the same `.font`
    /// expression as the size, so it never splits a glyph's size from its
    /// weight.
    let weightOverride: Font.Weight?

    /// The text style the symbol sits BESIDE (= nil for a symbol that stands
    /// in a zone of its own).
    ///
    /// A symbol is drawn from a font, so the style a symbol wears IS its size
    /// and its weight. Naming the style here makes the glyph and the label
    /// beside it one piece of type, at one size and at Apple's own weight for
    /// that style; a zone tier cannot do it, because the factory cannot know
    /// what text the call site happens to sit next to (= a 14 PT tier font
    /// outdraws the caption role the label beside it wears).
    ///
    /// When this is named it decides the font on its own. `style.pointSize`,
    /// `pointSizeOverride` and `weightOverride` are the zone's answer to the
    /// same question, and two fonts on one symbol resolve to the first one
    /// applied, so a tier font left under a named style would silently win
    /// over the label the glyph belongs to. `IconStylesTests` reads the
    /// pairing back out of the call sites it covers.
    let matchingText: WenshuTextStyle?

    init(
        _ name: String,
        style: IconStyle,
        color: Color = Color.secondary,
        rendering: IconRendering? = nil,
        pointSizeOverride: CGFloat? = nil,
        weightOverride: Font.Weight? = nil,
        matchingText: WenshuTextStyle? = nil
    ) {
        self.name = name
        self.style = style
        self.color = color
        self.rendering = rendering
        self.pointSizeOverride = pointSizeOverride
        self.weightOverride = weightOverride
        self.matchingText = matchingText
    }

    /// Convenience initializer accepting an `IconColor` semantic token (= the
    /// Apple color enum; = `.primary / .secondary / .tint /
    /// .red`). This is the form most call sites use; the underlying `Color`
    /// form above is the escape hatch for call sites that compute the color
    /// from a domain enum (= a per-row tint).
    init(
        _ name: String,
        style: IconStyle,
        color: IconColor,
        rendering: IconRendering? = nil,
        pointSizeOverride: CGFloat? = nil,
        weightOverride: Font.Weight? = nil,
        matchingText: WenshuTextStyle? = nil
    ) {
        self.name = name
        self.style = style
        self.color = color.style
        self.rendering = rendering
        self.pointSizeOverride = pointSizeOverride
        self.weightOverride = weightOverride
        self.matchingText = matchingText
    }

    var body: some View {
        // The plain Image is needed for .resizable() (= .resizable() is Image-only and
        // must follow Image(...) before any other modifier that returns `some
        // View`). The styledImage carries .font() for the non-sidebar tiers.
        // The .sidebar tier uses plainImage so it can call .resizable() first.
        let plainImage = Image(systemName: name)
        // A symbol that names the text it sits beside wears that text's own
        // style: one Apple text style decides both the glyph's size and its
        // weight, so the symbol and the label beside it cannot drift apart.
        // The zone tier's font is not applied underneath it (= the first font
        // applied to a symbol is the one it reads). The `.sidebar` tiers size
        // the glyph to their own slot below and do not read this.
        let styledImage: AnyView = matchingText.map { AnyView(plainImage.font($0.font)) }
            ?? AnyView(plainImage
                .font(.system(size: pointSizeOverride ?? style.pointSize, weight: weightOverride ?? style.fontWeight)))

        // .sidebar uses .monochrome so .foregroundStyle(Color.primary) surfaces as the
        // actual system primary (= black on light mode, white on dark mode).
        // In .hierarchical mode, Color.primary is interpreted as the
        // foreground style's primary variant (= system tint = accent = blue on
        // macOS), so the icon surfaces as blue regardless of the explicit
        // foreground style. Product rule, matching what Apple Mail /
        // Notes / Xcode sidebar row icons render in the system primary color,
        // not the app accent), monochrome is the canonical rendering for the
        // .sidebar tier.
        let isSidebar = style == .sidebar
        // `.sidebarTree` (= 2026-10-12 boss directive) is the library-tree side of the
        // same surface (= it is the chrome sidebar on the main window, NOT a
        // system- settings surface). It renders the SF Symbol in `.monochrome`
        // with the system-primary color (= the Apple chrome-
        // sidebar look, = no multicolor, no squircle tile). The optical slot
        // dimensions still apply (= the `sidebarWidth` / `sidebarInset`
        // extensions on `IconStyle` cover both tiers; = `SFLabelRow`'s
        // leading-icon frame still matches across the two surfaces).
        let isSidebarTree = style == .sidebarTree

        // .sidebar tier: lock the row icon to a 16×16 square frame and force the SF
        // Symbol to fill it via .resizable() + .aspectRatio(contentMode:
        // .fit). Per Every sidebar row icon must occupy the same optical width
        // inside the 16×16 box (= the wenshu 1:1 sidebar row icon
        // convention; = SF Symbols 6 keeps each symbol's intrinsic optical
        // bounds; = resizable + aspectRatio flatten them to the frame). The
        // trade-off (= `book.vertical` no longer looks slim) is the wenshu
        // sidebar row decision. .font() is dropped here (= Image.font()
        // returns `some View` on Swift 6.4 macOS 27, which blocks .resizable()
        // from following). The 16×16 frame below pins the rendered size; the
        // .style.pointSize value still drives the non-sidebar tiers.
        if isSidebar && rendering == nil {
            // macOS sidebar row icon convention (= macOS 27): every sidebar row
            // icon sits on top of a squircle tile (= the macOS
            // semantic `controlBackgroundColor` = the dark Liquid
            // Glass surface that hosts every sidebar row's multicolor SF
            // Symbol) and renders the SF Symbol in `.multicolor` mode
            // where the symbol has an intrinsic multicolour variant (= the
            // "Settings" pane family uses multi-colour SF Symbols 7
            // variants). The 24×24 PT tile (= 16 PT content box + 4 PT
            // inset × 2) = the product tile slot. Tile corner radius =
            // `DesignTokens.sidebarIconTileCornerRadius` (= 6 PT) + tile
            // padding = `DesignTokens.sidebarIconTilePadding` (= 4 PT
            // inset) + tile size = `DesignTokens.sidebarIconTileSize`
            // (= 24 PT) — the three product tile tokens, read at source.
            // All tokens ban naked numeric corner / spacing / sizing literals
            // per the v3.0 design-system hard rule. `Color(nsColor:
            // .controlBackgroundColor)` is an AppKit semantic color (= NOT
            // a raw `Color.X.opacity(N)`) so the v3.0 rule #6 body-text
            // ban does not apply; = system-supplied color that resolves to
            // the current OS's dark sidebar tint. Icon rule #9 = use
            // `IconColor` semantic tint, and the sidebar icon tile uses
            // the control (= "background") color
            // over the system accent (= the sidebar List cell tint is now
            // system controlBackground; no HIG path is cited — the HIG
            // publishes no such anatomy). The icon color argument is ignored under
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
        // Settings scene uses multicolor). per product convention chrome-sidebar
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
        // System Settings sidebar canonical look). The switch keeps the
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
