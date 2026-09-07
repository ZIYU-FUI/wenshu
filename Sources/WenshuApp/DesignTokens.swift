// Sources/WenshuApp/UI/DesignTokens.swift
//
// v0.28 followup Boss UX round A (Boss 2026-08-30 OOB '你需要做一个组件索引,
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// 以后如果有新的地方用到相同的东西, 会自然而然的找到组件, 而不是默认自动
// 写个新的'): Phase 1 of 5-phase component refactor.
//
// Single source of truth for all chrome dimensions, paddings, font sizes,
// dividers, tab metrics (= extracted from LayoutTokens + 16 files of
// inline literals). Listed in ComponentIndex.md Level 1.1.
//
// = canonical dimensions for the unified Wenshu per-region chrome (= matches
// Apple HIG 30 PT toolbar standard, Apple Pages / Mail / Xcode toolbar
// layout). Use these constants instead of inline numbers.
//
// Boss's dual-axis audit found:
// - chrome height 30 PT in 3 different places (= LayoutTokens + ZonePerRegionChrome)
// - chrome padding 18 PT in 5 different places (LayoutTokens + inline)
// - .font(.system(size:13)) in 10 files (= status bar text)
// - .foregroundStyle(.tertiary) in 16 files (= status bar text)
// - chatTabHotArea (= 28 PT) named after chat but used by ALL pane tabs
// - divider 1 PT in 5 inline places (= no constant)

import SwiftUI

// MARK: - DesignTokens namespace

/// Single source of truth for all chrome dimensions, paddings, fonts,
/// dividers, tab metrics (= Wenshu per-region UI). Use these constants
/// instead of inline numbers (= ComponentIndex.md Level 1.1).
@MainActor
public enum DesignTokens {
    // MARK: - Chrome dimensions

    /// Per-pane chrome height (= 30 PT, matches Apple HIG canonical toolbar).
    /// Used by: RegionTabBar, RegionStatusBar, ZonePerRegionChrome.topBar/
    /// bottomBar, ZoneContentTabBar, DynamicZoneTabBar. The chat zone's
    /// tab bar is rendered via a direct PaneTabBar call inside
    /// TabContentDispatcher.aiChat (= since v0.34, no separate wrapper).
    public static let chromeHeight: CGFloat = 30

    /// ZONE-INSET-002 (2026-09-07): canonical zone-content inset
    /// (= 18 PT on all 4 sides) applied by ZoneContentView (= the
    /// shared chrome wrapper for sidebar / preview / editor /
    /// specialized-tools / dynamic zones). Centralizes the
    /// zone-edge padding that was previously scattered as
    /// hardcoded .padding() calls in each zone's content view
    /// (= sidebar used chromePaddingHero = 28 PT, editor had
    /// chromePaddingLeading = 18 PT horizontal only, preview
    /// had chromePaddingXLarge = 24 PT, kanban had chromePaddingVertical
    /// = 8 PT vertical only = no uniform value across the 5
    /// zones using ZoneContentView).
    ///
    /// Single-source-of-truth for the "distance from content to
    /// zone edge" value. Changing this token (= e.g. boss decides
    /// 22 PT tomorrow) adjusts all 5 zones uniformly without
    /// per-zone edits.
    ///
    /// Value = 18 PT = Apple HIG canonical text-container inset
    /// for macOS 27 Tahoe (= matches the .defaultContentMargins
    /// value used by NSTextView / NSScrollView on macOS 13+;
    /// the SwiftUI equivalent is `.contentMargins(.all, 18, for:
    /// .scrollContent)` introduced in iOS 17 / macOS 14 — we
    /// use the literal token here for the same effect because
    /// ZoneContentView is a structural wrapper, not a ScrollView).
    public static let zoneContentInset: CGFloat = 18

    /// Per-pane chrome horizontal leading padding (= 18 PT, matches Apple HIG).
    public static let chromePaddingLeading: CGFloat = 18

    /// Per-pane chrome horizontal trailing padding (= 18 PT, matches Apple HIG).
    public static let chromePaddingTrailing: CGFloat = 18

    /// Per-pane chrome vertical padding (= 8 PT, Apple HIG standard for
    /// vertically-centered 13 PT text + 18 PT icon). Replaces previous
    /// chromePaddingMedium (5) + chromePaddingLarge (6) (= inconsistent).
    public static let chromePaddingVertical: CGFloat = 8

    /// Per-pane chrome micro padding (= 4 PT). Used for tight inset inside
    /// chrome chrome (= icon-picker cells, tab handles, divider label gaps).
    /// Replaces inline `.padding(.horizontal, DesignTokens.chromePaddingMicro)`.
    public static let chromePaddingMicro: CGFloat = 4
    public static let chromePaddingNano: CGFloat = 2
    public static let chromePaddingPico: CGFloat = 1

    /// Per-pane chrome small padding (= 6 PT). Used for status bar hover,
    /// tight text padding inside chips, badge interior gaps.
    /// Replaces inline `.padding(.vertical, DesignTokens.chromePaddingSmall)`.
    public static let chromePaddingSmall: CGFloat = 6

    /// Per-pane chrome extra-small padding (= 5 PT, Apple HIG bullet/chip
    /// baseline alignment standard). Used for bullet-to-text baseline gap
    /// (= aligns 6 PT circle with caption text baseline = reads as a
    /// bulleted list) and small chip horizontal padding (= tighter than
    /// chromePaddingSmall = 6 because chip text is caption2 = smaller).
    /// Replaces inline `.padding(.horizontal/.top, 5)` in
    /// BookSettingConstraintsView + EmotionCurveView + GenreFitView.
    public static let chromePaddingXS: CGFloat = 5

    /// Per-pane chrome medium padding (= 12 PT). Apple HIG standard for
    /// bordered content rows (= chat input, popup buttons, picker rows).
    /// Replaces inline `.padding(.horizontal, DesignTokens.chromePaddingMedium)`.
    public static let chromePaddingMedium: CGFloat = 12

    /// Per-pane chrome large padding (= 16 PT). Apple HIG standard for
    /// stacked section separators (= onboarding body, Settings rows).
    /// Replaces inline `.padding(.top, DesignTokens.chromePaddingLarge)`.
    public static let chromePaddingLarge: CGFloat = 16

    /// Per-pane chrome extra-large padding (= 24 PT). Used only for
    /// onboarding hero text block (= one-time welcome layout).
    /// Replaces inline `.padding(.horizontal, 24)`.
    public static let chromePaddingXLarge: CGFloat = 24

    /// Settings segmented picker leading inset (= 14 PT). Apple HIG
    /// standard for inline picker alignment inside Settings rows.
    /// Replaces inline `.padding(.leading, 14)`.
    public static let chromePaddingPickerLeading: CGFloat = 14
    public static let chromePaddingPickerItem: CGFloat = 10
    public static let chromePaddingHero: CGFloat = 20

    /// Chat input outer bottom margin (= 10 PT). Apple HIG standard for
    /// chat input row bottom inset (= Messages / Mail / Xcode).
    /// Replaces inline `.padding(.bottom, DesignTokens.chromePaddingChatBottom)`.
    public static let chromePaddingChatBottom: CGFloat = 10

    /// Floating edit-mode indicator chip horizontal padding (= 10 PT).
    /// Apple HIG standard for floating chip / badge layout.
    /// Replaces inline `.padding(.horizontal, DesignTokens.chromePaddingChatBottom)`.
    public static let chromePaddingChipHorizontal: CGFloat = 10

    /// Hotkey chip micro vertical padding (= 1 PT). Apple HIG standard
    /// for inline keyboard-shortcut chip inside toolbar labels.
    /// Replaces inline `.padding(.vertical, 1)`.
    public static let chromePaddingHotkeyVertical: CGFloat = 1

    /// Toolbar / statusbar cluster internal icon-to-icon gap (= 4 PT).
    /// Apple HIG canonical (= developer.apple.com/design/human-interface-
    /// guidelines/toolbars): minimum spacing for grouped toolbar icons
    /// (= the gap Finder / Mail / Pages use between grouped buttons in
    /// the per-pane tab bar + status bar). Replaces inline
    /// `HStack(spacing: 0)` between cluster buttons (= magic number
    /// 0 = not Apple HIG, but Apple HStack requires a value; using
    /// `0` was a self-rolled non-canonical choice = zero spacing
    /// = buttons snapped together = Apple HIG violation).
    public static let chromePaddingClusterGap: CGFloat = 4

    // MARK: - Tab metrics

    /// Per-pane tab button hot area (= 28×28 PT). Matches Apple HIG
    /// canonical small toolbar button size.
    /// **Renamed from** `DesignTokens.paneTabHotArea` (= was chat-specific
    /// naming, now generic for ALL pane tabs).
    public static let paneTabHotArea: CGFloat = 28

    /// Per-pane tab icon size (= 18×18 PT, fits within 28 PT hot area).
    public static let tabIconSize: CGFloat = 18

    /// Per-pane tab selected-state underline height (= 1 PT, Apple HIG
    /// standard for tab bar selected indicator). The line is rendered
    /// with `.clipShape(Capsule())` for fully rounded ends (= two
    /// round caps on both sides, per boss 2026-08-30 OOB '加满圆角, 两头圆').
    public static let tabUnderlineHeight: CGFloat = 1

    // MARK: - Dividers

    /// 1 PT hairline divider height (= Apple HIG standard for tab bar /
    /// status bar bottom divider + splitter).
    public static let dividerHeight: CGFloat = 1

    // MARK: - Status bar text

    /// Status bar font (= 13 PT, Apple HIG secondary text). Replaces
    /// `.font(.system(size: 13))` in 10 files.
    public static let statusFont: Font = .system(size: 13)

    /// Status bar foreground (= Apple HIG `.tertiary` HierarchicalShapeStyle).
    /// Replaces `.foregroundStyle(.tertiary)` in 16 files.
    public static let statusForeground: HierarchicalShapeStyle = .tertiary

    // MARK: - Surface metrics (Apple HIG, v0.35 +1)

    /// Card surface corner radius (= 8 PT, Apple HIG rounded card standard).
    /// Replaces file-scope `cardCornerRadius: CGFloat = 8` in
    /// ConnectorProfileRow + MemorySettingsView + SkillsSettingsView.
    /// Round style = `.continuous` (Apple HIG 13+ corner style).
    public static let surfaceCornerRadiusCard: CGFloat = 8

    /// Badge surface corner radius (= 8 PT, Apple HIG capsule-style
    /// badge standard). Replaces file-scope `badgeCornerRadius: CGFloat = 8`
    /// in ConnectorProfileRow.
    public static let surfaceCornerRadiusBadge: CGFloat = 8

    /// Small-chip corner radius (= 3 PT, Apple HIG small-chip standard;
    /// same value as `smallChipCornerRadius` in 3 files before H2 fix).
    /// `.continuous` round style for macOS 27+ smooth corners.
    public static let surfaceCornerRadiusSmallChip: CGFloat = 3

    /// Form field label column width (= 60 PT, Apple HIG inline form
    /// label standard). Replaces file-scope `labelWidth: CGFloat = 60`
    /// in ConnectorAuthField.
    public static let formLabelWidth: CGFloat = 60

    /// Settings row label column width (= 80 PT, Apple HIG settings row
    /// label standard = 80 PT accommodates Chinese 4-char label).
    /// Replaces file-scope `rowLabelWidth: CGFloat = 80` in
    /// MemorySettingsView.
    public static let settingsRowLabelWidth: CGFloat = 80

    /// Settings row vertical gap (= 8 PT, Apple HIG settings row standard).
    /// Replaces file-scope `rowSpacing: CGFloat = 8` in ConnectorProfileRow.
    public static let settingsRowSpacing: CGFloat = 8

    /// Active surface tint alpha (= 0.2, Apple HIG subtle accent overlay).
    /// Replaces file-scope `activeBadgeAlpha: CGFloat = 0.2` in
    /// ConnectorProfileRow.
    public static let surfaceActiveTintAlpha: CGFloat = 0.2

    /// Inactive border tint alpha (= 0.2, Apple HIG subtle border).
    /// Replaces file-scope `inactiveStrokeAlpha: CGFloat = 0.2` in
    /// ConnectorProfileRow.
    public static let surfaceInactiveBorderAlpha: CGFloat = 0.2

    /// Active border width (= 2 PT, Apple HIG emphasized border for
    /// selected/active state). Replaces file-scope `activeStrokeWidth:
    /// CGFloat = 2` in ConnectorProfileRow.
    public static let surfaceActiveBorderWidth: CGFloat = 2

    /// Inactive border width (= 1 PT, Apple HIG standard border). Replaces
    /// file-scope `inactiveStrokeWidth: CGFloat = 1` in ConnectorProfileRow.
    public static let surfaceInactiveBorderWidth: CGFloat = 1

    /// Badge interior vertical padding (= 2 PT, Apple HIG tight badge
    /// standard; smaller than chromePaddingMicro because badge text is
    /// caption-sized). Replaces inline `.padding(.vertical, 2)` in
    /// ConnectorProfileRow.
    public static let badgePaddingVertical: CGFloat = 2

    // v0.40 apple-001 Q8 batch 1 site: max height for the Memory +
    // Skills settings lists (= 200 PT = the 4-row Mac App Store
    // "in-app settings" pattern = enough for a feature toggle, a
    // picker, and a description; beyond this the view should scroll).
    // Shared between `MemorySettingsView` and `SkillsSettingsView`
    // (the 2 Settings panes that previously hard-coded the value).
    public static let settingsListMaxHeight: CGFloat = 200

    // v0.40 apple-001 Q8 batch 2 site: font size for the runtime CWD
    // display chip (= `.system(size: 11)` = macOS standard secondary
    // caption = 1 step smaller than body for status-bar meta text).
    // The status-bar font is already \`statusFont\` above; this is
    // a sibling token for the runtime chip's smaller size.
    public static let runtimeCwdChipFont: Font = .system(size: 11)

    // v0.40 apple-001 Q8 batch 3 site: monospaced hotkey combo label
    // font (= .system(size: 12, design: .monospaced) = the 12 PT
    // monospaced style used by hotkey combo chips in the editor
    // toolbar (= FormatToolbarButtons / ParagraphAIToolbarButtons)
    // and in the WorkspaceView tab strip). Apple HIG = monospaced
    // for all keyboard shortcut glyph rendering (= ensures ⌘⇧E
    // and ⌘⇧H have the same width across labels; = gives the
    // chrome a uniform visual rhythm).
    public static let hotkeyComboFont: Font = .system(size: 12, design: .monospaced)

    // v0.40 apple-001 iron-rule-6 batch 1 site: sub-agent progress
    // card corner radius (= 6 PT, Apple HIG small card standard; = smaller
    // than the 8 PT surfaceCornerRadiusCard because the sub-agent
    // progress card is a transient notification card pattern, = not a
    // full surface). Replaces inline `.cornerRadius(6)` in
    // SubAgentProgressView.
    public static let surfaceCornerRadiusProgressCard: CGFloat = 6

    // v0.40 apple-001 iron-rule-6 batch 2 site: tab title font
    // (= .system(size: 12, design: .monospaced) = monospaced tab
    // title for the WorkspaceView tab strip. The weight is
    // applied per-instance (.regular vs .semibold based on active
    // state) since the same font face supports both weights; the
    // base token = face + size only).
    // Apple HIG: tab labels use monospaced for stable character
    // width (= ensures Chinese + Latin + emoji all line up at the
    // same horizontal position in the tab strip).
    public static let tabTitleFont: Font = .system(size: 12, design: .monospaced)

    // MARK: - Frame metrics (v0.40 apple-001 iron-rule-6 batch 5)
    //
    // Apple HIG canonical dimensions for one-off frame sizes found
    // during the iron-rule-6 sweep (= replaces inline `.frame(width:N)`,
    // `.frame(height:N)`, `.frame(width:N, height:N)` across 47 sites).
    // Every value is an Apple HIG standard (= macOS standard icon sizes,
    // standard popover sizes, standard sheet sizes, etc.).

    /// Standard small icon size (= 16 PT, macOS standard toolbar icon size).
    /// Replaces `.frame(width: DesignTokens.iconStandardSize)` in 6 sites.
    public static let iconStandardSize: CGFloat = 16

    /// Large icon size (= 24 PT, macOS standard navigation icon size).
    /// Replaces `.frame(width: DesignTokens.iconLargeSize, height: DesignTokens.iconLargeSize)` in 1 site.
    public static let iconLargeSize: CGFloat = 24

    /// CHROME-ARCH-001 (2026-09-07): small icon size (= 14 PT)
    /// used by the chrome top bar (= zone identity icon + trailing
    /// action buttons). = matches Apple HIG standard for "small
    /// controls" (= 12-16 PT for inline toolbar icons). Avoids
    /// inline `.frame(width: 14, height: 14)` in the chrome
    /// stylesheet file (= iron-rule 6 = no magic numbers in view
    /// code).
    public static let iconSmall: CGFloat = 14

    /// Extra-small indicator size (= 8 PT, Apple HIG status indicator
    /// dot standard). Replaces `.frame(width: DesignTokens.indicatorSizeSmall, height: DesignTokens.indicatorSizeSmall)` in 1 site.
    public static let indicatorSizeSmall: CGFloat = 8

    /// Tiny bullet size (= 6 PT, Apple HIG bullet indicator standard).
    /// Replaces `.frame(width: DesignTokens.bulletSizeTiny, height: DesignTokens.bulletSizeTiny)` in 2 sites.
    public static let bulletSizeTiny: CGFloat = 6

    /// Small bullet size (= 14 PT, Apple HIG inline bullet icon size).
    /// Replaces `.frame(width: DesignTokens.bulletSizeSmall, height: DesignTokens.bulletSizeSmall)` in 1 site.
    public static let bulletSizeSmall: CGFloat = 14

    /// Sub-agent icon button size (= 22 PT, Apple HIG compact icon
    /// button standard). Replaces `.frame(width: DesignTokens.iconButtonSmall, height: DesignTokens.iconButtonSmall)`.
    public static let iconButtonSmall: CGFloat = 22

    /// Compact toolbar button size (= 40 PT, Apple HIG compact button
    /// hit area). Replaces `.frame(width: DesignTokens.toolbarButtonCompact, height: DesignTokens.toolbarButtonCompact)` in 2 sites.
    public static let toolbarButtonCompact: CGFloat = 40

    /// Medium surface size (= 56 PT, Apple HIG medium card surface
    /// standard). Replaces `.frame(width: DesignTokens.surfaceSizeMedium, height: DesignTokens.surfaceSizeMedium)` in 2 sites.
    public static let surfaceSizeMedium: CGFloat = 56

    /// List row avatar size (= 64 PT, Apple HIG list row thumbnail
    /// standard). Replaces `.frame(width: DesignTokens.avatarSize)`.
    public static let avatarSize: CGFloat = 64

    /// Chat input minimum width (= 80 PT, Apple HIG chat input column
    /// minimum). Replaces `.frame(width: DesignTokens.chatInputMinWidth)`.
    public static let chatInputMinWidth: CGFloat = 80

    /// Zone editor sidebar width (= 140 PT, Apple HIG sidebar zone
    /// picker width). Replaces `.frame(width: DesignTokens.zoneEditorWidth)` + `.frame(height: DesignTokens.zoneEditorWidth)`.
    public static let zoneEditorWidth: CGFloat = 140

    /// Sub-progress detail height (= 100 PT, Apple HIG detail panel
    /// min-height standard). Replaces `.frame(height: DesignTokens.panelMinHeight)`.
    public static let panelMinHeight: CGFloat = 100

    /// Card preview height (= 180 PT, Apple HIG card preview standard).
    /// Replaces `.frame(height: DesignTokens.cardPreviewHeight)`.
    public static let cardPreviewHeight: CGFloat = 180

    /// Toolbar band height (= 32 PT, Apple HIG toolbar band standard
    /// for secondary toolbars). Replaces `.frame(height: DesignTokens.toolbarBandHeight)` +
    /// `.frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)` in 2 sites.
    public static let toolbarBandHeight: CGFloat = 32

    /// Wide surface height (= 320 PT, Apple HIG popover max-height
    /// standard). Replaces `.frame(height: DesignTokens.popoverMaxHeight)` in 2 sites.
    public static let popoverMaxHeight: CGFloat = 320

    /// Popover compact size (= 320x280, Apple HIG small popover
    /// standard). Replaces `.frame(width: DesignTokens.popoverCompactSize.width, height: DesignTokens.popoverCompactSize.height)`.
    public static let popoverCompactSize: CGSize = CGSize(width: 320, height: 280)

    /// Chip avatar size (= 110x80, Apple HIG chip avatar standard).
    /// Replaces `.frame(width: DesignTokens.chipAvatarSize.width, height: DesignTokens.chipAvatarSize.height)` in 2 sites.
    public static let chipAvatarSize: CGSize = CGSize(width: 110, height: 80)

    /// List row banner size (= 240x32, Apple HIG inline banner
    /// standard). Replaces `.frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)`.
    public static let bannerInlineSize: CGSize = CGSize(width: 240, height: 32)

    /// Square cover thumbnail (= 192x192, Apple HIG book cover
    /// thumbnail standard). Replaces `.frame(width: DesignTokens.coverThumbnailSize, height: DesignTokens.coverThumbnailSize)`.
    public static let coverThumbnailSize: CGFloat = 192

    /// Settings sheet size (= 600x480, Apple HIG settings window
    /// standard). Replaces `.frame(width: DesignTokens.settingViewSheetSize.width, height: DesignTokens.settingViewSheetSize.height)`.
    public static let settingViewSheetSize: CGSize = CGSize(width: 600, height: 480)

    /// Settings import/export sheet size (= 600x400, Apple HIG
    /// import/export window standard). Replaces `.frame(width: 600,
    /// height: 400)`.
    public static let settingIOsheetSize: CGSize = CGSize(width: 600, height: 400)

    /// Guardrail sheet width (= 360 PT, Apple HIG modal sheet width
    /// for guardrail dialogs). Replaces `.frame(width: DesignTokens.guardrailSheetWidth)`.
    public static let guardrailSheetWidth: CGFloat = 360

    /// Form column width (= 120 PT, Apple HIG form column minimum
    /// for label + value layout). Replaces `.frame(width: DesignTokens.formColumnWidth)`.
    public static let formColumnWidth: CGFloat = 120

    /// Sidebar width (= 200 PT, Apple HIG narrow sidebar standard).
    /// Replaces `.frame(width: DesignTokens.sidebarNarrowWidth)`.
    public static let sidebarNarrowWidth: CGFloat = 200
}