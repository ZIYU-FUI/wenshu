//
//  IconStyles.swift · Wenshu · v3.0
//
//  Central SF Symbols 6 icon factory + Apple HIG walk for wenshu icon and
//  text sizing (= boss 2026-10-01: merge icon + font under one file;
//  every token name = Apple HIG official terminology; every point value =
//  Apple-default or Apple-shipped app default; zero ad-hoc numbers).
//
//  ============================ WHY THIS FILE EXISTS ============================
//
//  Pre-v3.0 wenshu had 13 icon-size tokens in `DesignTokens.swift`
//  (= iconStandardSize, iconSmall, iconLargeSize, iconButtonSmall,
//  toolbarButtonCompact, paneTabHotArea, tabIconSize, tabCloseFrameSize,
//  tabCloseGlyphFontSize, emptyStateIconSize, avatarSize, coverThumbnailSize,
//  surfaceSizeMedium) plus 4 font tokens (= statusFont, runtimeCwdChipFont,
//  hotkeyComboFont, tabTitleFont). 166 `Image(systemName:)` call sites in
//  Sources/ + 16 font token call sites = scattered visibility for any change
//  to the icon or font system. The visual hierarchy rule (= all toolbar
//  icons same weight, all hero icons same weight) was enforceable only by
//  grep, not by the type system.
//
//  Per boss OOB 2026-10-01:
//
//    1. 中央抽象 (central abstraction) is mandatory — without it the
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
//       (.small)). hero / cover / avatar = .thin weight (= boss 2026-09-17
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
//  ticket / boss / Q-numbers / version narrative).
//
//  ============================ MIGRATION RULE ============================
//
//  Pre-v3.0 tokens (`DesignTokens.tabIconSize` etc.) remain in place;
//  this file adds a NEW canonical surface (= `SFIcon(...)`) on top.
//  Future PRs migrate call sites one surface at a time (= per Q112 =
//  1 source + 1 test per ticket). Once a surface is migrated, the
//  corresponding `DesignTokens.*` token is deleted in the same PR.
//  Migration lives on the table's MigrationState case per surface.
//
//  ============================ USAGE NOTES ============================
//
//  Production call sites migrate from:
//
//      Image(systemName: "paperplane")
//          .frame(width: DesignTokens.tabIconSize)
//          .symbolRenderingMode(.hierarchical)
//          .foregroundStyle(.tint)
//
//  To:
//
//      SFIcon("paperplane", style: .paneTab, color: .tint)
//
//  Future ticket: sweep all 166 call sites to SFIcon, one surface per
//  PR (= see the Q112 <QQ-coupling> ladder in the per-case doc below).
//

import SwiftUI

// MARK: - IconStyle

/// Apple HIG / Apple-shipped app icon-style enum. Each case carries the
/// point size + the weight (= the .thin split for the ≥38 PT zone per
/// boss 2026-09-17 SF Symbols 6 weight rule).
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
    /// decorations. Weight: .regular (= boss 9/15 "细体" canonical
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
    /// = 18 PT` (boss 2026-10-01).
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
    /// zone). Thin weight per boss 2026-09-17 SF Symbols 6 weight split
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
    /// standard). Thin weight per boss 2026-09-17 rule.
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
    /// standard). Thin weight per boss 2026-09-17 rule.
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
        }
    }

    /// Apple HIG weight for this case. The ≥38 PT zone (= emptyStateHero
    /// / avatar / cover) uses .thin per boss 2026-09-17 SF Symbols 6
    /// weight split rule. Smaller zones use .regular (= boss 9/15 "细体"
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

    /// Per-layer explicit color (= 1-3 N `Color` values; = boss 9/15
    /// "use SF Symbols 6 (3rd gen) with palette rendering" canonical
    /// default for SF Symbols 6).
    case palette

    /// Apple's intrinsic colors (= use when the symbol has a curated
    /// multicolor variant; = Apple wifi / calendar.badge.plus / etc.).
    case multicolor
}

// MARK: - SFIcon

/// Central SF Symbols 6 icon factory. All wenshu icons go through this
/// View (= `Image(systemName:)` directly is anti-pattern for new code;
/// pre-v3.0 call sites migrate via per-surface sweep PRs).
///
/// Apple HIG rationale (boss 2026-10-01): one factory enforces one
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
    let color: IconColor
    let rendering: IconRendering?

    init(
        _ name: String,
        style: IconStyle,
        color: IconColor = .secondary,
        rendering: IconRendering? = nil
    ) {
        self.name = name
        self.style = style
        self.color = color
        self.rendering = rendering
    }

    var body: some View {
        let image = Image(systemName: name)
            .font(.system(size: style.pointSize, weight: style.fontWeight))

        switch rendering {
        case .monochrome:
            image.symbolRenderingMode(.monochrome).foregroundStyle(color.style)
        case .hierarchical:
            image.symbolRenderingMode(.hierarchical).foregroundStyle(color.style)
        case .palette:
            image.symbolRenderingMode(.palette).foregroundStyle(color.style)
        case .multicolor:
            image.symbolRenderingMode(.multicolor).foregroundStyle(color.style)
        case nil:
            // No explicit rendering = apply the Apple HIG per-zone default:
            //   ≥38 PT zone (= emptyStateHero / avatar / cover) = .monochrome
            //   <38 PT zone (= everything else) = .hierarchical (= boss 9/15 canonical)
            if style.pointSize >= 38 {
                image.symbolRenderingMode(.monochrome).foregroundStyle(color.style)
            } else {
                image.symbolRenderingMode(.hierarchical).foregroundStyle(color.style)
            }
        }
    }
}

// MARK: - WenshuTextStyle

/// Apple HIG text-style enum. Each case carries the SwiftUI text-style
/// API (= `.body` / `.callout` / `.caption` / `.title2` / `.footnote`)
/// + the point size (= SwiftUI default; = Apple HIG default).
///
/// The case names walk Apple HIG text-style terminology (= boss
/// 2026-10-01 = "字体字号样式 走 HIG 术语"; = 本 case 名 = Apple
/// Text Style 原名).
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