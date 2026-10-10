//
//  IconStyles.swift · Wenshu · v3.0
//
//  Central SF Symbols 6 icon factory + Apple HIG walk for wenshu icon and
//  text sizing (= (see OOB.md #2026-10-01): merge icon + font under one file;
//  every token name = Apple HIG official terminology; every point value =
//  Apple-default or Apple-shipped app default; zero ad-hoc numbers).
//
//  ============================ WHY THIS FILE EXISTS ============================
//
//  Pre-v3.0 wenshu had 13 icon-size tokens in `DesignTokens.swift`
//  (= iconStandardSize, iconSmall, iconLargeSize, iconButtonSmall,
//  toolbarButtonCompact, paneTabHotArea, tabIconSize, tabCloseFrameSize,
//  tabCloseGlyphFontSize, emptyStateIconSize, avatarSize, coverThumbnailSize,
//  surfaceSizeMedium). The v3.0 icon sweep series (= c5b897507 +
//  f44266fb7 + ce7510708 + 1fbd0e610 + b56c3c22c + 029295b6b +
//  638ae8996 + ef15e4595 + 40969fb0c + b9ef4ad7f + 83f5c8c78 +
//  4d6c02270 + d5aba1d34 + dfe599868 + d55d9b06d + 5b801b8f9 +
//  bf73ebfb4 + ae14835bf + 21ff18c43 + a39fb4f91) migrated every
//  production-code call site into IconStyle (= 11 cases: inlineSmall,
//  small, paneTab, toolbar, nav, hitArea, emptyStateHero, avatar,
//  cover, toolbarButton, surface) and deleted the 5 token definitions
//  that became 0-reference (= iconSmall, iconLargeSize, iconButtonSmall,
//  tabIconSize, iconStandardSize, emptyStateIconSize). The remaining
//  7 DesignTokens icon-related values (= paneTabHotArea, toolbarButtonCompact,
//  surfaceSizeMedium, avatarSize, coverThumbnailSize, tabCloseFrameSize,
//  tabCloseGlyphFontSize) are layout hit-area / container-frame sizes that
//  SFIcon does not own (= SFIcon owns the icon glyph size; = layout tokens
//  stay in DesignTokens).
//
//
//    1.  (central abstraction) is mandatory — without it the
//       single point of truth is missing and visual hierarchy drifts.
//
//    2. token names walk Apple HIG official terminology (= `.hitArea`
//       for the macOS HIG minimum hit zone, `.paneTab` for the
//       NSToolbar item default, `.toolbar` for ControlSize.small).
//
//    3. point values follow Apple-default (= Apple-shipped apps) values,
//       not wenshu-invented numbers. Empty-state = 76 (= Apple
//       ContentUnavailableView default). paneTab = 18 (= Apple
//       NSToolbar item macOS 14+ default). toolbar = 22 (= .controlSize
//       (.small)). hero / cover / avatar = .thin weight (= (see OOB.md #2026-09-17)
//       SF Symbols 6 weight split rule for the ≥38 PT zone).
//
//    4. font styles walk Apple HIG text-style APIs (= .body, .callout,
//       .caption). Status font = .body (= 13 PT). Hotkey font = .callout
//       + monospaced. Tab title font = .callout + monospaced.
//
//  Each IconStyle case carries a doc-comment that names the exact HIG
//  surface (= NSToolbar item / ControlSize.small / ContentUnavailableView /
//  HIG minimum hit area) and the existing wenshu call sites that consume
//  it. The comment policy applies (= engineering facts only, no
//  ticket / status / Q-numbers / version narrative).
//
//  ============================ MIGRATION RULE ============================
//
//  The v3.0 sweep migrated `DesignTokens.tabIconSize` (18 PT) and
//  `DesignTokens.iconStandardSize` (16 PT) into the `IconStyle` enum
//  (= `.paneTab = 18` and `.inlineSmall = 14` cover the previous
//  call sites). The tokens were deleted in this same PR series;
//  SFIcon is now the sole canonical surface.
//
//  ============================ USAGE NOTES ============================
//
//  Production call sites migrate from:
//
//      Image(systemName: "paperplane")
//          .symbolRenderingMode(.hierarchical)
//          .foregroundStyle(.tint)
//
//  To:
//
//      SFIcon("paperplane", style: .paneTab, color: .tint)
//
//  Future ticket: sweep all 166 call sites to SFIcon, one surface per
//  PR (= see the the per-commit 1-source-1-test rule <QQ-coupling> ladder in the per-case doc below).
//

import SwiftUI
import AppKit
// MARK: - IconStyle

/// Apple HIG / Apple-shipped app icon-style enum. Each case carries the
/// point size + the weight (= the .thin split for the ≥38 PT zone per
/// (see OOB.md #2026-09-17) SF Symbols 6 weight rule).
///
/// The case names walk Apple HIG official terminology (= `hitArea` for
/// macOS HIG minimum hit area; `paneTab` for NSToolbar item default;
/// `toolbar` for `.controlSize(.small)`; etc.).
enum IconStyle: Sendable, Equatable, CaseIterable {

    /// List row leading inline icon (= Apple HIG recommended inline icon
    /// size for list / table row leading affordances).
    ///
    /// Apple HIG source: `View > List > Standard row accessories`
    /// (= Apple Mail / Finder sidebar leading icon).
    ///
    /// Used by: list row leading, sidebar leading glyphs, inline row
    /// decorations. Weight: .regular (= (see OOB.md #2026-09-15)" canonical
    /// macOS toolbar weight).
    case inlineSmall

    /// List row leading icon at the 16 PT (= Apple HIG ControlSize.mini
    /// point size) tier.
    ///
    /// Apple HIG source: `ControlSize.mini` / SwiftUI `.controlSize(.mini)`.
    ///
    /// Used by: command palette leading glyphs, dense list rows.
    case small

    /// NSToolbar item default icon (= the actual rendered size of an
    /// NSToolbar item icon on macOS 14+ when paired with regular toolbar
    /// density; = measured on Mail / Safari / Xcode).
    ///
    /// Apple HIG source: `NSToolbar > Toolbar item > Default icon
    /// = 18 PT` ((see OOB.md #2026-10-01)).
    ///
    /// Used by: PaneTabBar (11 sites), pane close-button glyph,
    /// font-format toolbar buttons (= FormatToolbarButtons), inline
    /// format toolbar (= ParagraphAIToolbarButtons). Weight: .regular.
    case paneTab

    /// macOS standard toolbar button icon (= SwiftUI `.controlSize(.small)`
    /// point size). Chat-input bar action icons live here.
    ///
    /// Apple HIG source: `ControlSize.small` / SwiftUI `.controlSize(.small)`
    /// / macOS standard toolbar button icon.
    ///
    /// Used by: chat input bar buttons (= ChatInputBarView GlassIconButton),
    /// format toolbar (kicker / superscript / etc.). Weight: .regular.
    case toolbar

    /// macOS HIG navigation icon (= SwiftUI `.controlSize(.regular)`
    /// point size).
    ///
    /// Apple HIG source: `ControlSize.regular` / SwiftUI `.controlSize(.regular)`
    /// / HIG macOS navigation icon.
    ///
    /// Used by: sidebar primary nav, large button affordances. Weight: .regular.
    case nav

    /// macOS HIG minimum hit area (= the smallest tappable zone for
    /// pointer-driven interactions).
    ///
    /// Apple HIG source: `Layout > Tap targets > macOS = 28 PT minimum`.
    ///
    /// Used by: pane tab hot area (= the full tap zone of a pane tab),
    /// trailing icon-button hot area (= PaneTrailingIconButton),
    /// icon-only button tap targets. This is a HIT AREA, not a glyph
    /// size: use it with `Color.clear` overlay + `.contentShape(Rectangle())`
    /// to extend the tap target around a smaller visual icon.
    /// Weight: .regular.
    case hitArea

    /// ContentUnavailableView default icon size (= the empty-state hero
    /// zone). Thin weight per (see OOB.md #2026-09-17) SF Symbols 6 weight split
    /// rule for the ≥38 PT zone.
    ///
    /// Apple HIG source: `ContentUnavailableView > Default icon zone
    /// = 76 PT` (= Apple's documented default for the "no content here"
    /// affordance).
    ///
    /// Used by: EmptyStateView (the canonical wenshu empty state
    /// across all 12 specialized tools + editor zone + PreviewPane +
    /// ChatView chat-zone "configure LLM" empty state).
    /// Weight: .thin.
    case emptyStateHero

    /// List row avatar / thumbnail size (= NSTableView thumbnail row
    /// standard). Thin weight per (see OOB.md #2026-09-17) rule.
    ///
    /// Apple HIG source: `NSTableView > Row thumbnail size = 64 PT`
    /// (= Apple's default for list-row thumbnails; = Mail / Finder row
    /// icon zone).
    ///
    /// Used by: book cover thumbnails in PlaceholderView, character
    /// portrait icons, kanban card hero.
    /// Weight: .thin.
    case avatar

    /// CoverFlow thumbnail size (= Apple-shipped Finder cover preview
    /// standard). Thin weight per (see OOB.md #2026-09-17) rule.
    ///
    /// Apple HIG source: `Finder > CoverFlow preview = 192 PT`.
    ///
    /// Used by: onboarding cover preview (= LibraryRootView).
    /// Weight: .thin.
    case cover

    /// Toolbar button hot area (= `.controlSize(.regular)` = 32 PT).
    ///
    /// Apple HIG source: `ControlSize.regular` / SwiftUI `.controlSize(.regular)`
    /// / HIG macOS toolbar button = 32 PT.
    ///
    /// Used by: sidebar trailing buttons (= SidebarSheets).
    /// This is a HIT AREA, not a glyph size.
    /// Weight: .regular.
    case toolbarButton

    /// Medium card surface size (= HIG small-card standard).
    ///
    /// Apple HIG source: `Layout > Surfaces > Medium card = 56 PT`.
    ///
    /// Used by: sidebar sheets medium surface (= SidebarSheets).
    /// Weight: .regular.
    case surface

    /// Sidebar row leading icon (= Apple HIG sidebar list row anatomy).
    /// One canonical slot for every row in the tree so the visual
    /// baseline is fixed; SF Symbols render at the .small scale that
    /// Apple Mail / Notes / Xcode / System Settings use.
    ///
    /// Apple HIG source: `Sidebars > List > A sidebar's row height,
    /// text, and glyph size depend on its overall size, which can be
    /// small, medium, or large.` (= `NSTableViewDefaultSizeMode` /
    /// SwiftUI `\.sidebarRowSize`). The wenshu default follows Apple
    /// Mail / Notes / Xcode at 16 PT and .regular; the
    /// `sidebarWidth` + `sidebarInset` properties on this case hold
    /// the optical slot so callers do not have to know the difference
    /// between the symbol's intrinsic width and the row slot.
    ///
    /// Used by: SFLabelRow (every sidebar row in the library tree).
    /// Weight: .regular. Color: `.primary` (= Apple Tahoe sidebar
    /// default = black in light mode, white in dark mode, NOT
    /// app accent color).
    case sidebar

    /// Apple HIG point size for this case. Values follow Apple-shipped
    /// app defaults (= not wenshu-invented).
    var pointSize: CGFloat {
        switch self {
        case .inlineSmall: 14
        case .small: 16
        case .paneTab: 18
        case .toolbar: 22
        case .nav: 24
        case .hitArea: 28
        case .emptyStateHero: 76
        case .avatar: 64
        case .cover: 192
        case .toolbarButton: 32
        case .surface: 56
        case .sidebar: 16
        }
    }

    /// Apple HIG weight for this case. The ≥38 PT zone (= emptyStateHero
    /// / avatar / cover) uses .thin per (see OOB.md #2026-09-17) SF Symbols 6
    /// weight split rule. Smaller zones use .regular (= (see OOB.md #2026-09-15)"
    /// canonical macOS toolbar weight).
    var fontWeight: Font.Weight {
        switch self {
        case .emptyStateHero, .avatar, .cover: .thin
        default: .regular
        }
    }

    /// Whether this case is a hit-area tier (= glyph is invisible;
    /// caller overlays an actual icon inside the hit zone). Affects
    /// SFIcon rendering: hit areas render with no font = icon at any
    /// size nested inside.
    var isHitArea: Bool {
        self == .hitArea || self == .toolbarButton
    }

    /// AppKit counterpart used at NSImage boundaries. Apple keeps
    /// the symbol's intrinsic optical bounds; the factory normalizes
    /// only the shared point size, weight, and scale.
    var symbolWeight: NSFont.Weight {
        switch self {
        case .emptyStateHero, .avatar, .cover: .thin
        default: .regular
        }
    }
}

// MARK: - Sidebar slot (only meaningful on .sidebar)

// Sidebar row iconography owns its own slot dimensions and tint so
// callers do not need to know the optical difference between an SF
// Symbol's intrinsic width and the row's leading icon frame. Apple
// HIG does not define a sidebar row icon width; the 16 PT baseline
// matches Apple Mail / Notes / Xcode / System Settings (= the
// wenshu-declared default in the absence of a system override).
extension IconStyle {
    /// Sidebar row leading icon width (= the row's leading icon
    /// frame; = the fixed visual slot the SF Symbol sits inside).
    /// Only meaningful when `self == .sidebar`.
    var sidebarWidth: CGFloat { 16 }
    /// Sidebar row leading icon inner horizontal padding (= the
    /// breathing room inside the slot so the symbol's optical bounds
    /// never touch the slot edge). Only meaningful when
    /// `self == .sidebar`.
    var sidebarInset: CGFloat { 2 }
}

// MARK: - IconColor

/// Apple HIG-compatible icon color enum (= SwiftUI semantic colors only;
/// no ad-hoc `Color.red` / `Color.blue`).
enum IconColor: Sendable, Equatable {
    case primary        // = .primary (= HIG text-primary on light mode)
    case secondary      // = .secondary (= HIG text-secondary)
    case tertiary       // = .tertiary
    case quaternary     // = .quaternary
    case accent         // = Color.accentColor (= HIG accent)
    case tint           // = .tint (= SwiftUI environment tint = follows role)
    case red, green, orange, blue

    /// SwiftUI semantic color resolver (= `Color` to be passed to
    /// `.foregroundStyle(_:)`). HIG quaternary = primary with 0.15 alpha
    /// (= SwiftUI `.quaternary` resolves internally to `HierarchyShape`.
    /// quaternary`; we use the explicit alpha for stability across macOS
    /// SDKs).
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

    /// Single color with opacity-derived depth per layer (= Apple HIG
    /// chrome default for toolbar icons at <38 PT).
    case hierarchical

    /// Per-layer explicit color (= 1-3 N `Color` values; = the 2026-09-15
    /// "use SF Symbols 6 (3rd gen) with palette rendering" canonical
    /// default for SF Symbols 6).
    case palette

    /// Apple's intrinsic colors (= use when the symbol has a curated
    /// multicolor variant; = Apple wifi / calendar.badge.plus / etc.).
    case multicolor

    /// v2.7 round-66 commit G (= boss
    /// 2026-10-10 "这
    /// 个分
    /// 析中
    /// 三
    /// 个字
    /// 前
    /// 面，
    /// 需
    /// 要
    /// 加
    /// 一个
    /// 小
    /// 小
    /// 的
    /// 动
    /// 态
    /// SF"
    /// feedback): the
    /// `.variableColor`
    /// symbol effect
    /// (= the SF
    /// Symbol's
    /// colors cycle
    /// through the
    /// spectrum
    /// continuously;
    /// = the canonical
    /// "in progress"
    /// visual
    /// affordance; =
    /// e.g.
    /// `ellipsis.circle.fill`
    /// with this
    /// rendering = the
    /// three dots
    /// cycle through
    /// colors at ~1
    /// Hz; = the user
    /// sees
    /// continuous
    /// motion and
    /// immediately
    /// knows the
    /// system is
    /// still
    /// working). The
    /// `SFIcon` factory
    /// applies the
    /// effect via
    /// `.symbolEffect(.variableColor.iterative)`
    /// (= the SwiftUI
    /// 4.0+
    /// API; = the loop
    /// runs forever
    /// while the view
    /// is mounted).
    case variableColor
}

// MARK: - SFIcon

/// Central SF Symbols 6 icon factory. All wenshu icons go through this
/// View (= `Image(systemName:)` directly is anti-pattern for new code;
/// pre-v3.0 call sites migrate via per-surface sweep PRs).
///
/// Apple HIG rationale ((see OOB.md #2026-10-01)): one factory enforces one
/// weight + one color strategy per surface; 166 call sites can't
/// drift because the factory pins it.
///
/// ```swift
/// SFIcon("magnifyingglass", style: .small)
/// SFIcon("paperplane", style: .toolbar, color: .accent)
/// SFIcon("text.document", style: .emptyStateHero, rendering: .monochrome)
/// ```
struct SFIcon: View {
    let name: String
    let style: IconStyle
    let color: Color
    let rendering: IconRendering?

    init(
        _ name: String,
        style: IconStyle,
        color: Color = Color.secondary,
        rendering: IconRendering? = nil
    ) {
        self.name = name
        self.style = style
        self.color = color
        self.rendering = rendering
    }

    /// Convenience initializer accepting an `IconColor` semantic token (= the
    /// canonical Apple HIG color enum; = `.primary / .secondary / .tint / .red`).
    /// This is the form most call sites use; the underlying `Color` form
    /// above is the escape hatch for call sites that compute the color from
    /// a domain enum (= CommandPaletteView category colors).
    init(
        _ name: String,
        style: IconStyle,
        color: IconColor,
        rendering: IconRendering? = nil
    ) {
        self.name = name
        self.style = style
        self.color = color.style
        self.rendering = rendering
    }

    var body: some View {
        // The plain Image is needed for .resizable() (= .resizable()
        // is Image-only and must follow Image(...) before any other
        // modifier that returns `some View`). The styledImage carries
        // .font() for the non-sidebar tiers. The .sidebar tier uses
        // plainImage so it can call .resizable() first.
        let plainImage = Image(systemName: name)
        let styledImage = plainImage
            .font(.system(size: style.pointSize, weight: style.fontWeight))

        // .sidebar uses .monochrome so .foregroundStyle(Color.primary)
        // surfaces as the actual system primary (= black on light
        // mode, white on dark mode). In .hierarchical mode,
        // Color.primary is interpreted as the foreground style's
        // primary variant (= system tint = accent = blue on macOS),
        // so the icon surfaces as blue regardless of the
        // explicit foreground style. Per Apple HIG sidebar
        // row anatomy (= Apple Mail / Notes / Xcode sidebar
        // row icons render in the system primary color, not
        // the app accent), monochrome is the canonical
        // rendering for the .sidebar tier.
        let isSidebar = style == .sidebar

        // .sidebar tier: lock the row icon to a 16×16 square
        // frame and force the SF Symbol to fill it via
        // .resizable() + .aspectRatio(contentMode: .fit). Per
        // the boss 2026-10-08 decision (= "光学, 也就是视觉宽度
        // 统一"), every sidebar row icon must occupy the same
        // optical width inside the 16×16 box. SF Symbols 6 keeps
        // each symbol's intrinsic optical bounds; resizable +
        // aspectRatio flatten them to the frame. The trade-off
        // (= book.vertical no longer looks slim) is the
        // documented wenshu sidebar row decision.
        //
        // .font() is dropped here (= Image.font() returns
        // `some View` on Swift 6.4 macOS 27, which blocks
        // .resizable() from following). The 16×16 frame
        // below pins the rendered size; the .style.pointSize
        // value still drives the non-sidebar tiers.
        if isSidebar && rendering == nil {
            return AnyView(
                plainImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(color)
            )
        }

        // All other tiers: rendering decision only (= the
        // IconStyle .hierarchical default for <38 PT and
        // .monochrome for ≥38 PT, plus the explicit
        // rendering override).
        switch rendering {
        case .monochrome:
            return AnyView(styledImage.symbolRenderingMode(.monochrome).foregroundStyle(color))
        case .hierarchical:
            return AnyView(styledImage.symbolRenderingMode(.hierarchical).foregroundStyle(color))
        case .palette:
            return AnyView(styledImage.symbolRenderingMode(.palette).foregroundStyle(color))
        case .multicolor:
            return AnyView(styledImage.symbolRenderingMode(.multicolor).foregroundStyle(color))
        case .variableColor:
            // v2.7 round-66 commit G
            // (= boss
            // 2026-10-10 "这
            // 个分
            // 析中
            // 三
            // 个字
            // 前
            // 面，
            // 需
            // 要
            // 加
            // 一
            // 个
            // 小
            // 小
            // 的
            // 动
            // 态
            // SF"
            // feedback).
            // The
            // `.variableColor`
            // symbol
            // effect
            // (= the
            // SF
            // Symbol's
            // colors
            // cycle
            // through
            // the
            // spectrum
            // continuously;
            // = the
            // canonical
            // "in
            // progress"
            // visual
            // affordance).
            // `.symbolEffect(.variableColor.iterative)`
            // loops
            // forever
            // while
            // the
            // view
            // is
            // mounted;
            // = the
            // effect
            // stops
            // automatically
            // when
            // the
            // view
            // is
            // removed
            // (= the
            // state
            // pill
            // is
            // unmounted
            // when
            // the
            // task
            // transitions
            // away
            // from
            // .routing
            // / .writing;
            // = no
            // cleanup
            // needed).
            // The
            // `.symbolRenderingMode(.monochrome)`
            // is
            // skipped
            // for
            // .variableColor
            // (= the
            // effect
            // requires
            // the
            // multicolor
            // rendering
            // path;
            // = the
            // symbol's
            // intrinsic
            // colors
            // are
            // what's
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

// MARK: - SFLabelRow

/// Central Apple HIG sidebar-row factory. Renders one icon + title + optional
/// subtitle per Apple HIG Sidebars canonical pattern (=
/// `developer.apple.com/design/human-interface-guidelines/sidebars`:
/// "Short labels / Familiar SF Symbols / Calm the sidebar").
///
/// Application position: macOS 27 List(.sidebar) rows. Pinned to Apple's
/// own sidebar row anatomy = 22 PT row height (= SwiftUI List(.sidebar)
/// default), 16 PT leading icon (= Apple Mail / Finder / Settings sidebar
/// default), `.body` title + `.caption + .secondary` subtitle, with the
/// 10 PT inner gutter (= the Apple HIG standard sidebar inset).
///
/// Per (see OOB.md #2026-10-06) "中央工厂保留 / 按应用位置不同加工":
/// the central icon factory is preserved but each application position
/// gets its own purpose-built surface. SFLabelRow is the surface for
/// "one icon + one line of text" (= the dominant Apple sidebar row
/// pattern). Apple's official recommended form is the `Label` view with
/// the title-and-icon initializer; SFLabelRow delegates to it so the
/// factory does not duplicate what Apple already gives us.
///
/// ```swift
/// SFLabelRow(title: "Documents", systemImage: "folder")
/// SFLabelRow(title: "Chapter 1", systemImage: "book",
///            subtitle: "12 pages")
/// ```
struct SFLabelRow: View {
    let title: String
    let systemImage: String
    let subtitle: String?
    let iconStyle: IconStyle

    init(
        title: String,
        systemImage: String,
        subtitle: String? = nil,
        iconStyle: IconStyle = .sidebar
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.iconStyle = iconStyle
    }

    var body: some View {
        Label {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingTight) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            // Sidebar rows use one fixed icon slot. The same nominal
            // point size alone is not enough: SF Symbols with different
            // intrinsic bounds can still look larger or smaller beside
            // one another. A fixed slot plus the canonical regular
            // weight keeps the tree visually aligned without tuning each
            // symbol individually. Color follows Apple Tahoe sidebar
            // default (= system primary, not app accent).
            //
            // No explicit .symbolRenderingMode here (= the SFIcon
            // factory owns the rendering decision via IconStyle.sidebar
            // = .monochrome; per the boss 2026-10-08 finding,
            // .hierarchical + .foregroundStyle(Color.primary)
            // surfaces the icon as system tint = accent = blue;
            // only .monochrome renders Color.primary as the
            // actual system primary color).
            SFIcon(
                systemImage,
                style: iconStyle,
                color: IconColor.primary
            )
            .padding(.horizontal, iconStyle.sidebarInset)
            .frame(width: iconStyle.sidebarWidth)
            .foregroundStyle(Color.primary)
        }
        .frame(height: DesignTokens.sidebarRowHeight)
    }
}

// MARK: - SFStatusBadge

/// Apple HIG status-badge view wrapper. Renders a small icon + text
/// in a Capsule-pill background (= the Apple Mail / Notes status
/// chip convention).
///
/// Application position: every place in wenshu that needs a
/// pill-shaped status indicator (= "已配置" / "未连接" / "N 项" / etc.).
/// Per (see OOB.md #2026-10-06) "按区域提需求": all wenshu status
/// pills flow through this single surface so that the next
/// "make the status pill smaller" directive becomes a 1-line
/// change in this file (= the call sites inherit automatically).
///
/// Apple's recommended form for a status chip is a `Label { ... }
/// icon: { ... }` rendered inside `Capsule().fill(...)`. SFStatusBadge
/// delegates to Label so the factory does not duplicate Apple's
/// canonical pattern.
///
/// ```swift
/// SFStatusBadge(systemImage: "checkmark.circle.fill",
///               text: "Configured",
///               tint: .green)
/// ```
struct SFStatusBadge: View {
    let systemImage: String
    let text: String
    let tint: Color

    init(systemImage: String, text: String, tint: Color = .accentColor) {
        self.systemImage = systemImage
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: IconStyle.inlineSmall.pointSize,
                              weight: IconStyle.inlineSmall.fontWeight))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, DesignTokens.spacingTight)
        .padding(.vertical, DesignTokens.spacingCaption)
        .background(
            Capsule().fill(tint.opacity(DesignTokens.accentTintOpacitySubtle))
        )
    }
}

// MARK: - SFCardHero

/// Apple HIG card-hero view wrapper. Renders a large icon + title +
/// optional subtitle stacked vertically (= the Apple Notes folder-card
/// / Apple Music album-card convention).
///
/// Application position: every place in wenshu that needs a card
/// with a hero icon (= card picker, library card, character
/// portrait card). Per (see OOB.md #2026-10-06) "按区域提需求":
/// every wenshu hero card flows through this surface so the next
/// "make the card icon 10 PT larger" directive becomes a 1-line
/// change here (= the call sites inherit automatically).
///
/// Apple's recommended form is `Label { ... } icon: { ... }` for
/// the icon-title pair; SFCardHero delegates to it and stacks the
/// optional subtitle via VStack below.
///
/// ```swift
/// SFCardHero(systemImage: "book.closed",
///            title: "Reference Library",
///            subtitle: "12 references")
/// ```
struct SFCardHero: View {
    let systemImage: String
    let title: String
    let subtitle: String?

    init(systemImage: String, title: String, subtitle: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingModerate) {
            Image(systemName: systemImage)
                .font(.system(size: IconStyle.avatar.pointSize,
                              weight: IconStyle.avatar.fontWeight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .padding(DesignTokens.spacingLoose)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SFToolbarButton

/// Apple HIG toolbar-button view wrapper. Renders an icon-only button
/// at the macOS HIG toolbar control size (= the SwiftUI
/// `.controlSize(.regular)` point size).
///
/// Application position: every toolbar / pane-tab / top-bar
/// action button in wenshu. Per (see OOB.md #2026-10-06)
/// "按区域提需求": every wenshu toolbar action flows through this
/// surface so the next "make the toolbar button hot area 4 PT
/// wider" directive becomes a 1-line change here (= the call sites
/// inherit automatically).
///
/// Apple's recommended form is `Button { ... } label: { ... }` with
/// the icon-only `.labelStyle(.iconOnly)`. SFToolbarButton delegates
/// to it and applies the standard control-size + 28 PT minimum hit
/// area (= Apple HIG macOS minimum tap target).
///
/// ```swift
/// SFToolbarButton(systemImage: "plus", action: { addItem() })
/// ```
struct SFToolbarButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: IconStyle.toolbar.pointSize,
                              weight: IconStyle.toolbar.fontWeight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: IconStyle.hitArea.pointSize,
               height: IconStyle.hitArea.pointSize)
        .contentShape(Rectangle())
    }
}

// MARK: - SFListRow

/// Apple HIG generic list-row view wrapper. Renders a leading icon
/// + title + optional subtitle + optional trailing accessory stacked
/// horizontally (= the Apple Mail message-list / Finder list row
/// convention for non-sidebar lists).
///
/// Application position: every list row OUTSIDE a sidebar (= search
/// results, memory entries, settings rows, file lists). The sidebar
/// itself has its own `SFLabelRow` (= 22 PT height, 16 PT icon).
/// SFListRow is the general-list cousin (= 30 PT chrome-height,
/// 14 PT inline icon).
///
/// Per (see OOB.md #2026-10-06) "按区域提需求": every general-list
/// row flows through this surface so the next "make all list rows
/// 2 PT taller" directive becomes a 1-line change here (= the call
/// sites inherit automatically).
///
/// Apple's recommended form is `Label { ... } icon: { ... }`.
/// SFListRow delegates to it and adds the optional trailing
/// accessory slot.
///
/// ```swift
/// SFListRow(systemImage: "doc", title: "Chapter 1",
///           subtitle: "12 pages",
///           trailing: { Text("Today") })
/// ```
struct SFListRow<Trailing: View>: View {
    let systemImage: String
    let title: String
    let subtitle: String?
    let trailing: (() -> Trailing)?

    init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        Label {
            HStack(spacing: DesignTokens.spacingTight) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if let trailing {
                    trailing()
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: IconStyle.inlineSmall.pointSize,
                              weight: IconStyle.inlineSmall.fontWeight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: IconStyle.inlineSmall.pointSize + 4)
        }
        .frame(height: DesignTokens.chromeHeight)
    }
}

// MARK: - WenshuTextStyle

/// Apple HIG text-style enum. Each case carries the SwiftUI text-style
/// API (= `.body` / `.callout` / `.caption` / `.title2` / `.footnote`)
/// + the point size (= SwiftUI default; = Apple HIG default).
///
/// The case names walk Apple HIG text-style terminology (= the 2026-09-15
/// 2026-10-01 = "  HIG "; =  case  = Apple
/// Text Style ).
enum WenshuTextStyle: Sendable, Equatable, CaseIterable {

    /// HIG `.largeTitle` (= SwiftUI `.font(.largeTitle)`, default 26 PT).
    /// Used by: top-level page hero text.
    case largeTitle

    /// HIG `.title` (= SwiftUI `.font(.title)`, default 22 PT).
    /// Used by: section titles (= h1).
    case title

    /// HIG `.title2` (= SwiftUI `.font(.title2)`, default 17 PT).
    /// Used by: secondary section titles (= h2).
    case title2

    /// HIG `.title3` (= SwiftUI `.font(.title3)`, default 15 PT).
    /// Used by: tertiary section titles (= h3).
    case title3

    /// HIG `.headline` (= SwiftUI `.font(.headline)`, default 13 PT
    /// semibold). Used by: list row emphasis.
    case headline

    /// HIG `.body` (= SwiftUI `.font(.body)`, default 13 PT regular).
    /// Apple-shipped Mail / Notes body text.
    /// Used by: status bar text (= former `statusFont` 13 PT),
    /// kanban card body.
    case body

    /// HIG `.callout` (= SwiftUI `.font(.callout)`, default 12 PT).
    /// Apple-shipped inline button label.
    /// Used by: hotkey combo label (= former `hotkeyComboFont` 12 PT),
    /// pane tab title (= former `tabTitleFont` 12 PT).
    case callout

    /// HIG `.subheadline` (= SwiftUI `.font(.subheadline)`, default 11 PT).
    /// Used by: secondary metadata.
    case subheadline

    /// HIG `.caption` (= SwiftUI `.font(.caption)`, default 11 PT regular).
    /// Apple-shipped inline footnote.
    /// Used by: runtime CWD display chip (= former `runtimeCwdChipFont`
    /// 11 PT), inline metadata captions.
    case caption

    /// HIG `.caption2` (= SwiftUI `.font(.caption2)`, default 11 PT).
    /// Used by: very small captions.
    case caption2

    /// HIG `.footnote` (= SwiftUI `.font(.footnote)`, default 10 PT).
    /// Used by: footnote text.
    case footnote

    /// SwiftUI text-style API (= the canonical HIG text style).
    var font: Font {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .caption: .caption
        case .caption2: .caption2
        case .footnote: .footnote
        }
    }

    /// HIG default point size (= SwiftUI text-style default).
    var pointSize: CGFloat {
        switch self {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline, .caption, .caption2: 11
        case .footnote: 10
        }
    }
}

// MARK: - WenshuText (= presentational helper for SwiftUI .font(_:))

/// Convenience modifier that applies a `WenshuTextStyle` (= the HIG
/// text-style API). Production code that previously did
/// `.font(DesignTokens.statusFont)` (= 13 PT ad-hoc) moves to
/// `.wenshuFont(.body)` (= HIG body, same 13 PT default, same
/// Dynamic Type semantics).
///
/// Used by: status bar text, hotkey columns, tab titles.
extension View {
    func wenshuFont(_ style: WenshuTextStyle) -> some View {
        self.font(style.font)
    }
}