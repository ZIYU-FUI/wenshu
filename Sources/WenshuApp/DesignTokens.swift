// Sources/WenshuApp/DesignTokens.swift
//
// (= canonical dimensions for the unified Wenshu per-region chrome; =
// matches Apple HIG 30 PT toolbar standard, Apple Pages / Mail / Xcode
// toolbar layout)':
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
enum DesignTokens {
    // MARK: - Chrome dimensions

    /// Per-pane chrome height (= 30 PT, matches Apple HIG canonical toolbar).
    /// Used by: RegionTabBar, RegionStatusBar, ZonePerRegionChrome.topBar/
    /// bottomBar, ZoneContentTabBar, DynamicZoneTabBar. The chat zone's
    /// tab bar is rendered via a direct PaneTabBar call inside
    /// TabContentDispatcher.aiChat (= since v0.34, no separate wrapper).
    static let chromeHeight: CGFloat = 30

    /// ZONE-INSET-002 (2026-09-07): canonical zone-content inset
    /// (= 8 PT on all 4 sides per Apple HIG) applied by
    /// ZoneContentView (= the shared chrome wrapper for sidebar /
    /// preview / editor / specialized-tools / dynamic zones).
    /// Centralizes the zone-edge padding that was previously
    /// scattered as hardcoded .padding() calls in each zone's
    /// content view (= sidebar used chromePaddingHero = 28 PT,
    /// editor had chromePaddingLeading = 18 PT horizontal only,
    /// preview had chromePaddingXLarge = 24 PT, kanban had
    /// chromePaddingVertical = 8 PT vertical only = no uniform
    /// value across the 5 zones using ZoneContentView).
    ///
    /// Single-source-of-truth for the "distance from content to
    /// zone edge" value. Changing this token (= e.g. boss decides
    /// 12 PT tomorrow) adjusts all 5 zones uniformly without
    /// per-zone edits.
    ///
    /// Value = 8 PT per Apple HIG canonical 'Spacing.small' (= the
    /// toolbar / inline content inset used by Apple Finder / Photos
    /// / Music / Mail per developer.apple.com/design/human-
    /// interface-guidelines/layout 'Use consistent spacing').
    /// Was 18 PT in a prior OOB (= boss 9/8 'that value is too
    /// wide; the Apple API default spacing isn't PT, it's a
    /// semantic name'; = the semantic name is '.small' = 8 PT).
    static let zoneContentInset: CGFloat = 8

    // MARK: - Spacing (= Apple HIG canonical, 8 PT baseline grid)
    //
    // 9 spacing tokens (= Apple HIG naming convention; = values
    // strictly on the 8 PT baseline grid or sub-multiples of 4). Token
    // names follow Apple HIG semantic naming (= Hairline / Caption /
    // Iconic / Tight / Standard / Moderate / Loose / Hero / Section).
    // Per-application-position usage notes live in each token's
    // doc-comment below (= readers can grep a wenshu file for the
    // position name to find the canonical token). 8/4 alignment rule
    // (= boss 2026-09-30 '调整方向按 8 或者 4 的倍数'): every value is
    // either a multiple of 8 (= 8 / 16 / 24) or 4 (= 4 / 12 / 20)
    // or sub-multiple (= 1 / 2).

    /// Apple HIG hairline divider gap (= 1 PT). The canonical
    /// divider / underline / hotkey-chip vertical inset. Used by:
    /// `paneTabHotArea` underline (= tabUnderlineHeight), splitter
    /// hairline (= dividerHeight), inline hotkey chip vertical
    /// padding (= toolbar buttons + slash autocomplete + layout
    /// picker hotkey badges).
    static let spacingHairline: CGFloat = 1

    /// Apple HIG caption2 metadata separator gap (= 2 PT). The
    /// canonical small-text vertical gap used between caption2
    /// labels and adjacent content. Used by: ChatMessageFooter
    /// top gap, BookmarkView row gap, SpotlightSearchSheet row
    /// gap, CanvasWindow row gap, KanbanView row gap,
    /// TodoListView row gap, PlotThreadView row gap,
    /// KanbanTicketDetailSheet row gap.
    static let spacingCaption: CGFloat = 2

    /// Apple HIG icon-to-label gap (= 4 PT). The canonical tight
    /// inset inside chrome chrome (= icon-picker cells, tab
    /// handles, divider label gaps, footer icon-button insets).
    /// Used by: every toolbar icon-to-label padding, every
    /// footnote icon-button padding, ChatPlanPartView step-count
    /// ring inset, ChatToolDiffPreview line padding,
    /// ChatMessageHoverActions hover-button inset, ChatToolResult
    /// line padding, ChatToolUse row padding, ChatToolDiffPreviewSheet
    /// line padding, ChatMessageAttachmentPreview chip padding,
    /// ChatAttachmentPreviewChip chip padding, MemoryEntryRow row
    /// inset, ChatReasoningPartView disclosure inset,
    /// ChatMessageThinkingDisclosure inset, ChatSlashCommand
    /// autocomplete row gap, SpecializedTools row gap,
    /// FormatToolbarButtons row inset, ParagraphAIToolbarButtons
    /// row inset, BackgroundReviewView row gap, SidebarRowView
    /// row gap, ChatMessageView internal padding, LayoutEditBar
    /// row gap, RuntimeCWDDisplayChip footer gap,
    /// SectionHeader text-to-divider gap, KanbanView column
    /// gap, KanbanTicketDetailSheet row gap, AgentProgressPanel
    /// row gap, CommandPalette row gap, LongFormGuardrails row
    /// gap, BookSettingConstraints row gap, CharacterLifecycle
    /// row gap, CharacterRelationships row gap, EmotionCurve
    /// row gap, GenreFit row gap, IdeaLibrary row gap,
    /// ReaderExperience row gap, TagManager row gap,
    /// Foreshadowing row gap, PlaceholderView row gap,
    /// ChapterFocusLockBadge row gap, SectionHeader internal gap.
    static let spacingIconic: CGFloat = 4

    /// Apple HIG tight inter-row gap (= 6 PT). The canonical
    /// tight padding used inside chips / hover-action rows /
    /// footer chips where chrome is denser than standard rows.
    /// Used by: ChatMessageView user-card vertical padding,
    /// ChatMessageHoverActions hover-row padding, ChatMessageFooter
    /// footer vertical padding, ChatToolDiffPreview line padding,
    /// ChatToolResult part padding, ChatToolUse part padding,
    /// ChatPlanPartView step text padding, ChatInputBarView
    /// vertical padding, CommandPalette row gap,
    /// SpotlightSearchSheet row gap, App.swift status bar
    /// padding, BookmarkView row gap, IdeaLibrary row gap,
    /// TagManager row gap, CharacterLifecycle row gap,
    /// CharacterRelationships row gap, EmotionCurve row gap,
    /// GenreFit row gap, LongFormGuardrails row gap,
    /// PlaceholderView row gap, ReaderExperience row gap,
    /// Foreshadowing row gap, TabContentDispatcher row gap,
    /// BackgroundReviewView row gap, ChapterFocusLockBadge
    /// row gap, EditModeBadge row gap, PresetCard row gap,
    /// KanbanView row gap, KanbanTicketDetailSheet row gap,
    /// CanvasWindow row gap, CronWindow row gap,
    /// EmptyStateView row gap.
    static let spacingTight: CGFloat = 6

    /// Apple HIG standard spacing (= 8 PT). The Touch Bar default
    /// (= developer.apple.com/design/human-interface-guidelines/
    /// macos/touch-bar/touch-bar-visual-design) and the canonical
    /// pane chrome inset (= matches SwiftUI Spacing.small = the
    /// toolbar / inline content inset used by Apple Finder /
    /// Photos / Music / Mail). Used by: pane-leading inset,
    /// pane-trailing inset, pane-vertical inset (= zoneContentInset),
    /// chat transcript row vertical gap (= chat conversation
    /// turn gap = Apple HIG py-2 row gap convention),
    /// ChatMessagePlaceholderRow row gap, ChatInputBarView
    /// horizontal padding, ChatSlashCommandAutocomplete row
    /// horizontal padding, AppleSidebarBottomNewButton row
    /// inset, ShellDetailColumn row inset, MemoryRetrievalPanel
    /// row inset, MemorySettingsView row inset, SettingView
    /// row inset, DynamicZoneView row inset, DynamicZoneView
    /// content inset, CommandPalette row gap, ZoneContentView
    /// content inset, AgentProgressPanel row gap,
    /// LayoutEditBar row gap, LayoutPicker row gap,
    /// PaneTabBar cluster inset, TabContentDispatcher row gap,
    /// WorkspaceView row gap, SubAgentProgressView row gap,
    /// PreviewPane row inset, ParagraphAIToolbarButtons row
    /// gap, RuntimeCWDDisplayChip row gap, LongFormGuardrails
    /// row gap, BookSettingConstraints row gap,
    /// CharacterLifecycle row gap, CharacterRelationships row
    /// gap, EmotionCurve row gap, GenreFit row gap,
    /// IdeaLibrary row gap, ReaderExperience row gap,
    /// TagManager row gap, Foreshadowing row gap,
    /// PlaceholderView row gap, KanbanView row gap,
    /// CronWindow row gap, WenshuMarkdownEditor pane inset,
    /// ShellMiddleColumn content inset, ShellMiddleColumn
    /// row gap, CanvasWindow row gap.
    static let spacingStandard: CGFloat = 8

    /// Apple HIG moderate spacing (= 12 PT). The canonical
    /// bordered-content-row inset (= chat input, popup buttons,
    /// picker rows = the same inset Apple Mail / Apple Notes
    /// use for their bottom toolbars). Used by: chat input
    /// bottom margin (= chat input bottom inset = canonical
    /// Apple Messages chat input), SpecializedToolBodyModifier
    /// row gap, MemorySettingsView row gap,
    /// KanbanTicketDetailSheet row gap, AgentProgressPanel
    /// row gap, CommandPalette row gap, LayoutEditBar row gap,
    /// LayoutPicker row gap, SettingView row inset,
    /// DynamicZoneView row inset, PlotThreadView row gap,
    /// EditorPlaceholder row gap, TabContentDispatcher row
    /// inset, ZoneEditor row gap, SpecializedTools 6 views
    /// (= CharacterLifecycle / CharacterRelationships /
    /// EmotionCurve / GenreFit / IdeaLibrary / LongFormGuardrails /
    /// ReaderExperience / TagManager / Foreshadowing /
    /// PlaceholderView / BookSettingConstraints) row gap.
    static let spacingModerate: CGFloat = 12

    /// Apple HIG loose spacing (= 16 PT). The Touch Bar small
    /// fixed space (= developer.apple.com/design/human-interface-
    /// guidelines/macos/touch-bar/touch-bar-visual-design) and the
    /// canonical stacked-section-separator inset (= onboarding body,
    /// Settings rows). Used by: section header gap (= stacked
    /// section separators), KanbanTicketDetailSheet row gap,
    /// CommandPalette row gap, SettingView section inset,
    /// ZoneContentView content inset, SidebarSheets row inset,
    /// DynamicZoneView content inset, SpecializedTools 4 views
    /// (= LongFormGuardrails / BookSettingConstraints /
    /// CharacterLifecycle / CharacterRelationships / EmotionCurve /
    /// GenreFit / IdeaLibrary / ReaderExperience / TagManager /
    /// Foreshadowing / PlaceholderView) section gap.
    static let spacingLoose: CGFloat = 16

    /// Apple HIG hero / window content margin (= 20 PT). The
    /// canonical macOS window content margin (= Apple self-app
    /// empirical = HIG canonical for `.padding(.all, 20)` and
    /// `.contentMargins()`). Used by: section header top inset
    /// (= top padding from column edge to first section header
    /// text), sheet / window / dialog outer padding (= the
    /// canonical sheet chrome = sidebar sheets / ZoneEditor /
    /// PreviewPane sheet body).
    static let spacingHero: CGFloat = 20

    /// Apple HIG section white-space maximum (= 24 PT). The
    /// Touch Bar large fixed space (= developer.apple.com/design/
    /// human-interface-guidelines/macos/touch-bar/touch-bar-
    /// visual-design) and the canonical section separator
    /// maximum (= HIG says do not use more than this for section
    /// white-space). Used by: onboarding hero text block,
    /// sidebar sheet horizontal margin (= sheet inner gutter),
    /// EditorPaperCanvas paper vertical padding,
    /// LibraryRootView hero inset, SettingView section inset,
    /// SidebarSheets sheet horizontal gutter, EmptyStateView
    /// icon-to-text gap.
    static let spacingSection: CGFloat = 24

    // MARK: - Deprecated alias (= chromePadding*)
    //
    // Retained as deprecated (= `= spacingXXX` alias) for the
    // v3.0 spacing-HIG-rename migration arc (= Phase A landed
    // 2026-09-30; = Phase B replaces call sites; = Phase C
    // deletes these aliases once call sites are zero). Boss
    // 2026-09-30 '我觉得名字不如就按 Apple HIG 命名 / 应用位置
    // 不如写在注释里': all position-bound names
    // (= chromePaddingContentHorizontal / chromePaddingPickerItem /
    // chromePaddingSectionHeaderTop / etc.) collapse into a
    // single Apple HIG semantic name (= spacingModerate for the
    // 10/12 PT range; = spacingHero for the 20 PT range; = etc.).

    static let chromePaddingLeading: CGFloat = spacingStandard
    static let chromePaddingTrailing: CGFloat = spacingStandard
    static let chromePaddingVertical: CGFloat = spacingStandard
    static let chromePaddingSectionTop: CGFloat = spacingLoose
    static let chromePaddingSectionHeaderTop: CGFloat = spacingModerate
    static let chromePaddingSectionHeaderBottom: CGFloat = spacingModerate
    static let chromePaddingSectionHeaderGap: CGFloat = spacingIconic
    static let chromePaddingMicro: CGFloat = spacingIconic
    static let chromePaddingNano: CGFloat = spacingCaption
    static let chromePaddingPico: CGFloat = spacingHairline
    static let chromePaddingContentHorizontal: CGFloat = spacingModerate
    static let chromePaddingSmall: CGFloat = spacingTight
    static let chromePaddingXS: CGFloat = spacingIconic
    static let chromePaddingMedium: CGFloat = spacingModerate
    static let chromePaddingLarge: CGFloat = spacingLoose
    static let chromePaddingXLarge: CGFloat = spacingSection
    static let chromePaddingPickerItem: CGFloat = spacingModerate
    static let chromePaddingHero: CGFloat = spacingHero
    static let chromePaddingChatBottom: CGFloat = spacingModerate
    static let chromePaddingChipHorizontal: CGFloat = spacingModerate
    static let chromePaddingHotkeyVertical: CGFloat = spacingHairline
    static let chromePaddingClusterGap: CGFloat = spacingIconic
    static let chromePaddingEmptyStateGap: CGFloat = spacingSection

    // MARK: - Tab metrics

    /// Per-pane tab button hot area (= 28×28 PT). Matches Apple HIG
    /// canonical small toolbar button size.
    /// **Renamed from** `DesignTokens.paneTabHotArea` (= was chat-specific
    /// naming, now generic for ALL pane tabs).
    static let paneTabHotArea: CGFloat = 28

    /// Tab close button (= X) glyph font size (= 10 PT,
    /// .semibold weight). Matches SF Symbol `xmark` rendered at
    /// 18 PT frame for finger-target parity with the 28 PT paneTab.
    static let tabCloseGlyphFontSize: CGFloat = 10

    /// Tab close button (= X) hit area (= 18×18 PT). Apple HIG
    /// inline-control minimum is 16 PT (= 44 PT Apple HIG = finger-target);
    /// 18 PT is a compromise that fits inside `paneTabHotArea` (= 28 PT)
    /// without padding artifacts (= Safari/Chrome/Terminal convention).
    static let tabCloseFrameSize: CGFloat = 18

    /// Per-pane tab icon size (= 18×18 PT, fits within 28 PT hot area).
    static let tabIconSize: CGFloat = 18

    /// Per-pane tab selected-state underline height (= 1 PT, Apple HIG
    /// standard for tab bar selected indicator). The line is rendered
    /// with `.clipShape(Capsule())` for fully rounded ends (= two
    /// round caps on both sides, per boss 2026-08-30 OOB ', ').
    static let tabUnderlineHeight: CGFloat = 1

    // MARK: - Dividers

    /// 1 PT hairline divider height (= Apple HIG standard for tab bar /
    /// status bar bottom divider + splitter).
    static let dividerHeight: CGFloat = 1

    // MARK: - Status bar text

    /// Status bar font (= 13 PT, Apple HIG secondary text). Replaces
    /// `.font(.system(size: 13))` in 10 files.
    static let statusFont: Font = .system(size: 13)

    /// Status bar foreground (= Apple HIG `.tertiary` HierarchicalShapeStyle).
    /// Replaces `.foregroundStyle(.tertiary)` in 16 files.
    static let statusForeground: HierarchicalShapeStyle = .tertiary

    /// The chat transcript layer should use the left sidebar's color
    /// parameters. The Apple HIG sidebar background
    /// (= NSColor.controlBackgroundColor; = the primitive that
    /// `List(...).listStyle(.sidebar)` paints on macOS 14+) is the
    /// canonical sidebar color. This token gives every wenshu surface
    /// that wants to match the sidebar one parameter (= token-driven
    /// color = Light/Dark mode + future Apple default updates = 1-line
    /// change instead of N).
    // (2026-09-23): boss '聊天区背景颜色没有实现'.
    // The default `.controlBackgroundColor` (= Apple HIG sidebar
    // tint) produced RGB(28,28,28) in chat zone (= NSSplitViewItem
    // underlying visual effect layer bleed-through) vs. sidebar
    // RGB(34) (= macOS list(.sidebar) material). The 6-RGB-unit
    // difference was visible to the eye. Boss '就用 apple 颜色
    // 表达示，改成和左栏接近的颜色就好'.
    //
    // Apple HIG path: use the dynamic NSColor that the macOS
    // sidebar list actually renders (= RGB(34) in dark mode;
    // RGB(245) in light mode). Apple HIG documentation-
    // `.controlBackgroundColor` is the system-managed Color that
    // tracks the active NSAppearance. Implement the dynamic
    // resolution via NSColor(name: .dynamicProviderAccess, ...)
    // so light/dark mode follow the user's appearance setting.
    static let sidebarBackground: Color = {
        // Match macOS sidebar RGB exactly (= the same RGB the
        // System Settings sidebar uses). For both modes:
        //   - Dark: RGB(36,36,36) (= matches sidebar material)
        //   - Light: RGB(245,245,245) (= matches sidebar material)
        let dynamic = NSColor(name: "wenshu.sidebar.bg") { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 36.0/255.0, green: 36.0/255.0, blue: 36.0/255.0, alpha: 1.0)
            } else {
                return NSColor(red: 245.0/255.0, green: 245.0/255.0, blue: 245.0/255.0, alpha: 1.0)
            }
        }
        return Color(nsColor: dynamic)
    }()

    /// System message surface fill (= 15% red opacity on
    /// Apple accent red; = the canonical warning banner background
    /// for chat error / system messages; = replaces the band-aid
    /// inline `Color.red.opacity(0.15)` at ChatView.swift:1907
    /// (= the source-check at v1.0.0-m1-shell added it as a
    /// one-off 4th branch in bubbleFill; = data-driven now via
    /// token lookup). Apple HIG: warning fills should be token-
    /// based, not literal, so dark/light adjustments are 1-stop.
    static let systemMessageFill: Color = Color.red.opacity(0.15)

    // MARK: - Surface metrics (Apple HIG, v0.35 +1)

    /// Card surface corner radius (= 8 PT, Apple HIG rounded card standard).
    /// Replaces file-scope `cardCornerRadius: CGFloat = 8` in
    /// ConnectorProfileRow + MemorySettingsView + SkillsSettingsView.
    /// Round style = `.continuous` (Apple HIG 13+ corner style).
    static let surfaceCornerRadiusCard: CGFloat = 8

    /// Chat bubble horizontal padding (= 12 PT; = the
    /// iMessage-style bubble internal padding measured against
    /// Messages.app in dark mode; = replaces the inline literal at
    /// ChatView.swift:1786 + 1877 = duplicated chat-bubble padding
    /// per v1.27 component audit). Distinct from `zoneContentInset = 8`
    /// (= the zone-level grid inset); = bubble internal padding is
    /// larger because the bubble itself adds visual weight.
    static let bubblePaddingHorizontal: CGFloat = 12
    /// Layout picker chrome width (= 416 PT; = 26rem
    /// at 16 PT/rem; = replaces inline `26 * 16` at LayoutEditBar:56
    /// + LayoutPicker:156 (= the comment-encoded magic constant
    /// only documentation for the picker column; = data-driven now
    /// so future picker redesign is 1-stop.
    static let layoutPickerWidth: CGFloat = 416


    /// Badge surface corner radius (= 8 PT, Apple HIG capsule-style
    /// badge standard). Replaces file-scope `badgeCornerRadius: CGFloat = 8`
    /// in ConnectorProfileRow.
    static let surfaceCornerRadiusBadge: CGFloat = 8

    /// Small-chip corner radius (= 3 PT, Apple HIG small-chip standard;
    /// same value as `smallChipCornerRadius` in 3 files before H2 fix).
    /// `.continuous` round style for macOS 27+ smooth corners.
    static let surfaceCornerRadiusSmallChip: CGFloat = 3

    /// Form field label column width (= 60 PT, Apple HIG inline form
    /// label standard). Replaces file-scope `labelWidth: CGFloat = 60`
    /// in ConnectorAuthField.
    static let formLabelWidth: CGFloat = 60

    /// Settings row label column width (= 80 PT, Apple HIG settings row
    /// label standard = 80 PT accommodates Chinese 4-char label).
    /// Replaces file-scope `rowLabelWidth: CGFloat = 80` in
    /// MemorySettingsView.
    static let settingsRowLabelWidth: CGFloat = 80

    /// Settings row vertical gap (= 8 PT, Apple HIG settings row standard).
    /// Replaces file-scope `rowSpacing: CGFloat = 8` in ConnectorProfileRow.
    static let settingsRowSpacing: CGFloat = 8

    /// Active surface tint alpha (= 0.2, Apple HIG subtle accent overlay).
    /// Replaces file-scope `activeBadgeAlpha: CGFloat = 0.2` in
    /// ConnectorProfileRow.
    static let surfaceActiveTintAlpha: CGFloat = 0.2

    /// Inactive border tint alpha (= 0.2, Apple HIG subtle border).
    /// Replaces file-scope `inactiveStrokeAlpha: CGFloat = 0.2` in
    /// ConnectorProfileRow.
    static let surfaceInactiveBorderAlpha: CGFloat = 0.2

    /// Active border width (= 2 PT, Apple HIG emphasized border for
    /// selected/active state). Replaces file-scope `activeStrokeWidth:
    /// CGFloat = 2` in ConnectorProfileRow.
    static let surfaceActiveBorderWidth: CGFloat = 2

    /// Inactive border width (= 1 PT, Apple HIG standard border). Replaces
    /// file-scope `inactiveStrokeWidth: CGFloat = 1` in ConnectorProfileRow.
    static let surfaceInactiveBorderWidth: CGFloat = 1

    /// Badge interior vertical padding (= 2 PT, Apple HIG tight badge
    /// standard; smaller than chromePaddingMicro because badge text is
    /// caption-sized). Replaces inline `.padding(.vertical, 2)` in
    /// ConnectorProfileRow.
    static let badgePaddingVertical: CGFloat = 2

    // apple-001 Q8 batch 1 site: max height for the Memory +
    // Skills settings lists (= 200 PT = the 4-row Mac App Store
    // "in-app settings" pattern = enough for a feature toggle, a
    // picker, and a description; beyond this the view should scroll).
    // Shared between `MemorySettingsView` and `SkillsSettingsView`
    // (the 2 Settings panes that previously hard-coded the value).
    static let settingsListMaxHeight: CGFloat = 200

    // apple-001 Q8 batch 2 site: font size for the runtime CWD
    // display chip (= `.system(size: 11)` = macOS standard secondary
    // caption = 1 step smaller than body for status-bar meta text).
    // The status-bar font is already \`statusFont\` above; this is
    // a sibling token for the runtime chip's smaller size.
    static let runtimeCwdChipFont: Font = .system(size: 11)

    // apple-001 Q8 batch 3 site: monospaced hotkey combo label
    // font (= .system(size: 12, design: .monospaced) = the 12 PT
    // monospaced style used by hotkey combo chips in the editor
    // toolbar (= FormatToolbarButtons / ParagraphAIToolbarButtons)
    // and in the WorkspaceView tab strip). Apple HIG = monospaced
    // for all keyboard shortcut glyph rendering (= ensures ⌘⇧E
    // and ⌘⇧H have the same width across labels; = gives the
    // chrome a uniform visual rhythm).
    static let hotkeyComboFont: Font = .system(size: 12, design: .monospaced)

    // apple-001 iron-rule-6 batch 1 site: sub-agent progress
    // card corner radius (= 6 PT, Apple HIG small card standard; = smaller
    // than the 8 PT surfaceCornerRadiusCard because the sub-agent
    // progress card is a transient notification card pattern, = not a
    // full surface). Replaces inline `.cornerRadius(6)` in
    // SubAgentProgressView.
    static let surfaceCornerRadiusProgressCard: CGFloat = 6

    // apple-001 iron-rule-6 batch 2 site: tab title font
    // (= .system(size: 12, design: .monospaced) = monospaced tab
    // title for the WorkspaceView tab strip. The weight is
    // applied per-instance (.regular vs .semibold based on active
    // state) since the same font face supports both weights; the
    // base token = face + size only).
    // Apple HIG: tab labels use monospaced for stable character
    // width (= ensures Chinese + Latin + emoji all line up at the
    // same horizontal position in the tab strip).
    static let tabTitleFont: Font = .system(size: 12, design: .monospaced)

    // MARK: - Frame metrics (v0.40 apple-001 iron-rule-6 batch 5)
    //
    // Apple HIG canonical dimensions for one-off frame sizes found
    // during the iron-rule-6 sweep (= replaces inline `.frame(width:N)`,
    // `.frame(height:N)`, `.frame(width:N, height:N)` across 47 sites).
    // Every value is an Apple HIG standard (= macOS standard icon sizes,
    // standard popover sizes, standard sheet sizes, etc.).

    /// Standard small icon size (= 16 PT, macOS standard toolbar icon size).
    /// Replaces `.frame(width: DesignTokens.iconStandardSize)` in 6 sites.
    static let iconStandardSize: CGFloat = 16

    /// Large icon size (= 24 PT, macOS standard navigation icon size).
    /// Replaces `.frame(width: DesignTokens.iconLargeSize, height: DesignTokens.iconLargeSize)` in 1 site.
    static let iconLargeSize: CGFloat = 24

    /// CHROME-ARCH-001 (2026-09-07): small icon size (= 14 PT)
    /// used by the chrome top bar (= zone identity icon + trailing
    /// action buttons). = matches Apple HIG standard for "small
    /// controls" (= 12-16 PT for inline toolbar icons). Avoids
    /// inline `.frame(width: 14, height: 14)` in the chrome
    /// stylesheet file (= iron-rule 6 = no magic numbers in view
    /// code).
    static let iconSmall: CGFloat = 14

    /// Extra-small indicator size (= 8 PT, Apple HIG status indicator
    /// dot standard). Replaces `.frame(width: DesignTokens.indicatorSizeSmall, height: DesignTokens.indicatorSizeSmall)` in 1 site.
    static let indicatorSizeSmall: CGFloat = 8

    /// Tiny bullet size (= 6 PT, Apple HIG bullet indicator standard).
    /// Replaces `.frame(width: DesignTokens.bulletSizeTiny, height: DesignTokens.bulletSizeTiny)` in 2 sites.
    static let bulletSizeTiny: CGFloat = 6

    /// Small bullet size (= 14 PT, Apple HIG inline bullet icon size).
    /// Replaces `.frame(width: DesignTokens.bulletSizeSmall, height: DesignTokens.bulletSizeSmall)` in 1 site.
    static let bulletSizeSmall: CGFloat = 14

    /// Empty-state icon size (= 76 PT, 2× the default ContentUnavailableView
    /// ICON' (='double the empty-state icon size'). Replaces the
    /// raw `.frame(width: 76, height: 76)` in EmptyStateView.swift.
    /// Single source of truth for ALL empty-state icon sizes (= no
    /// other callers at v0.71 = single owner).
    static let emptyStateIconSize: CGFloat = 76

    /// Empty-state icon→title gap (= 22 PT, Apple HIG standard
    /// ContentUnavailableView sample measured value). v1.0.0-m1-shell
    /// EmptyStateView.swift uses this for the icon→title vertical
    /// spacing. Single source of truth (= single owner at v0.71).
    /// (= v3.0 spacing-HIG-rename: collapsed into spacingSection; =
    /// the old position-bound name remains a deprecated alias below).
    static let chromePaddingEmptyStateGap_DEPRECATED_REMOVE: CGFloat = 22

    /// Sub-agent icon button size (= 22 PT, Apple HIG compact icon
    /// button standard). Replaces `.frame(width: DesignTokens.iconButtonSmall, height: DesignTokens.iconButtonSmall)`.
    static let iconButtonSmall: CGFloat = 22

    /// Compact toolbar button size (= 40 PT, Apple HIG compact button
    /// hit area). Replaces `.frame(width: DesignTokens.toolbarButtonCompact, height: DesignTokens.toolbarButtonCompact)` in 2 sites.
    static let toolbarButtonCompact: CGFloat = 40

    /// Medium surface size (= 56 PT, Apple HIG medium card surface
    /// standard). Replaces `.frame(width: DesignTokens.surfaceSizeMedium, height: DesignTokens.surfaceSizeMedium)` in 2 sites.
    static let surfaceSizeMedium: CGFloat = 56

    /// List row avatar size (= 64 PT, Apple HIG list row thumbnail
    /// standard). Replaces `.frame(width: DesignTokens.avatarSize)`.
    static let avatarSize: CGFloat = 64

    /// Chat input minimum width (= 80 PT, Apple HIG chat input column
    /// minimum). Replaces `.frame(width: DesignTokens.chatInputMinWidth)`.
    static let chatInputMinWidth: CGFloat = 80

    /// Zone editor sidebar width (= 140 PT, Apple HIG sidebar zone
    /// picker width). Replaces `.frame(width: DesignTokens.zoneEditorWidth)` + `.frame(height: DesignTokens.zoneEditorWidth)`.
    static let zoneEditorWidth: CGFloat = 140

    /// Sub-progress detail height (= 100 PT, Apple HIG detail panel
    /// min-height standard). Replaces `.frame(height: DesignTokens.panelMinHeight)`.
    static let panelMinHeight: CGFloat = 100

    /// Card preview height (= 180 PT, Apple HIG card preview standard).
    /// Replaces `.frame(height: DesignTokens.cardPreviewHeight)`.
    static let cardPreviewHeight: CGFloat = 180

    /// Toolbar band height (= 32 PT, Apple HIG toolbar band standard
    /// for secondary toolbars). Replaces `.frame(height: DesignTokens.toolbarBandHeight)` +
    /// `.frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)` in 2 sites.
    static let toolbarBandHeight: CGFloat = 32

    /// Wide surface height (= 320 PT, Apple HIG popover max-height
    /// standard). Replaces `.frame(height: DesignTokens.popoverMaxHeight)` in 2 sites.
    static let popoverMaxHeight: CGFloat = 320

    /// Popover compact size (= 320x280, Apple HIG small popover
    /// standard). Replaces `.frame(width: DesignTokens.popoverCompactSize.width, height: DesignTokens.popoverCompactSize.height)`.
    static let popoverCompactSize: CGSize = CGSize(width: 320, height: 280)

    /// Chip avatar size (= 110x80, Apple HIG chip avatar standard).
    /// Replaces `.frame(width: DesignTokens.chipAvatarSize.width, height: DesignTokens.chipAvatarSize.height)` in 2 sites.
    static let chipAvatarSize: CGSize = CGSize(width: 110, height: 80)

    /// List row banner size (= 240x32, Apple HIG inline banner
    /// standard). Replaces `.frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)`.
    static let bannerInlineSize: CGSize = CGSize(width: 240, height: 32)

    /// Square cover thumbnail (= 192x192, Apple HIG book cover
    /// thumbnail standard). Replaces `.frame(width: DesignTokens.coverThumbnailSize, height: DesignTokens.coverThumbnailSize)`.
    static let coverThumbnailSize: CGFloat = 192

    /// Settings sheet size (= 600x480, Apple HIG settings window
    /// standard). Replaces `.frame(width: DesignTokens.settingViewSheetSize.width, height: DesignTokens.settingViewSheetSize.height)`.
    static let settingViewSheetSize: CGSize = CGSize(width: 600, height: 480)

    /// Settings import/export sheet size (= 600x400, Apple HIG
    /// import/export window standard). Replaces `.frame(width: 600,
    /// height: 400)`.
    static let settingIOsheetSize: CGSize = CGSize(width: 600, height: 400)

    /// Guardrail sheet width (= 360 PT, Apple HIG modal sheet width
    /// for guardrail dialogs). Replaces `.frame(width: DesignTokens.guardrailSheetWidth)`.
    static let guardrailSheetWidth: CGFloat = 360

    /// Form column width (= 120 PT, Apple HIG form column minimum
    /// for label + value layout). Replaces `.frame(width: DesignTokens.formColumnWidth)`.
    static let formColumnWidth: CGFloat = 120

    /// Sidebar width (= 200 PT, Apple HIG narrow sidebar standard).
    /// Replaces `.frame(width: DesignTokens.sidebarNarrowWidth)`.
    static let sidebarNarrowWidth: CGFloat = 200

    // MARK: - v0.71 P1 batch 4: full-project dual-axis audit
    //
    // (= boss 2026-09-12 OOB 'do a full-project dual-axis' = apply the dual-axis
    // chrome dimension system across the whole project; = extract every
    // hardcoded magic number to DesignTokens so the X-axis + Y-axis
    // chrome dimensions are centrally controlled).
    //
    // The "dual axis" = horizontal chrome (X) + vertical chrome (Y):
    //   • X-axis: divider/border widths + horizontal paddings
    //   • Y-axis: vertical paddings + section gaps + spacing

    /// Hairline border (= 0.5 PT, Apple HIG canonical hairline
    /// divider used by NavigationSplitView column separators +
    /// Kanban card borders + EmotionCurve dashed lines + PreviewPane
    /// subsection dividers; = the standard "soft" separator weight).
    /// Replaces inline `.stroke(..., lineWidth: 0.5)` calls.

    /// Standard border (= 1 PT, Apple HIG default border weight
    /// used by ChatView bubble separators + tool-use cards + specialized
    /// tools sidebar + tab strips + edit mode badges + layout picker
    /// cards; = the standard "neutral" border weight).
    /// Replaces inline `.strokeBorder(..., lineWidth: 1)` calls.

}
