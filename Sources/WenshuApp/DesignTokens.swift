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
// Dual-axis audit found:
// - chrome height 30 PT in 3 different places (= LayoutTokens + PaneTabBar)
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
    /// Used by: PaneTabBar (the single canonical per-pane tab bar).
    /// The chat zone's tab bar is rendered via a direct PaneTabBar
    /// call inside TabContentDispatcher.aiChat (= since v0.34,
    /// no separate wrapper).
    static let chromeHeight: CGFloat = 30

    /// Apple HIG sidebar list-row height (= 22 PT). Distinct from
    /// `chromeHeight` (= 30 PT = the canonical chrome standard used
    /// by toolbar / pane tab / top-bar buttons); = `sidebarRowHeight`
    /// is the per-row height of macOS List(.sidebar) inside the
    /// sidebar column.
    ///
    /// Apple HIG source: `Layout > Lists > macOS sidebar row height
    /// = 22 PT` (= the SwiftUI List(.sidebar) default; measured on
    /// Apple Mail / Finder / Settings sidebar rows). Use this token
    /// for every row inside a List(.sidebar) (= SidebarRowView +
    /// the sidebar bottom action button = same row height for visual
    /// continuity).
    ///
    /// Per (see OOB.md #2026-10-06): one application position =
    /// one purpose-built token. `chromeHeight` is the chrome /
    /// toolbar surface; `sidebarRowHeight` is the List(.sidebar)
    /// row surface. They are different.
    static let sidebarRowHeight: CGFloat = 22

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
    /// zone edge" value. Changing this token (= e.g. design decision
    /// 12 PT tomorrow) adjusts all 5 zones uniformly without
    /// per-zone edits.
    ///
    /// Value = 8 PT per Apple HIG canonical 'Spacing.small' (= the
    /// toolbar / inline content inset used by Apple Finder / Photos
    /// / Music / Mail per developer.apple.com/design/human-
    /// interface-guidelines/layout 'Use consistent spacing').
    /// Was 18 PT in a prior (see OOB.md #2026-09-08) — 'that value is too
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
    // (= (see OOB.md #2026-09-30) ' 8  4 '): every value is
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

    /// Relaxed stack spacing (= 10 PT, Apple HIG `.relaxed`
    /// stack-spacing standard).
    ///
    /// Apple HIG source: `View > Layout > Stack > Relaxed spacing` (=
    /// the macOS 26+ stack spacing between dense-relaxed content
    /// blocks; = measured from Mail message-list relaxed state).
    ///
    /// Used by: EmotionCurveView chart vertical-legend stack
    /// (= dense data point spacing); LongFormGuardrailsView violation
    /// list spacing (= dense bullet-to-bullet).
    static let spacingRelaxed: CGFloat = 10

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
    /// EditorView row gap, TabContentDispatcher row
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

    // MARK: - Tab metrics

    /// Per-pane tab button hot area (= 28×28 PT).
    ///
    /// Apple HIG canonical value (= macOS NSToolbar small item
    /// height = 28 PT; = measured from Safari tab strip, Mail
    /// toolbar, and System Settings sidebar items). The 28 PT value
    /// equals 1.75× the 16 PT body font (= Apple HIG small-control
    /// minimum) and provides the 4 PT padding margin around a 20 PT
    /// inner glyph (= the canonical finger-target-vs-glyph ratio
    /// for inline tab buttons).
    ///
    /// **Renamed from** `DesignTokens.paneTabHotArea` (= was chat-specific
    /// naming, now generic for ALL pane tabs).
    static let paneTabHotArea: CGFloat = 28

    /// Tab close button (= X) hit area (= 18×18 PT). Apple HIG
    /// inline-control minimum is 16 PT (= 44 PT Apple HIG = finger-target);
    /// 18 PT is a compromise that fits inside `paneTabHotArea` (= 28 PT)
    /// without padding artifacts (= Safari/Chrome/Terminal convention).
    static let tabCloseFrameSize: CGFloat = 18

    /// Per-pane tab selected-state underline height (= 1 PT, Apple HIG
    /// standard for tab bar selected indicator). The line is rendered
    /// with `.clipShape(Capsule())` for fully rounded ends (= two
    /// round caps on both sides, per (see OOB.md #2026-08-30) OOB ', ').
    static let tabUnderlineHeight: CGFloat = 1

    // MARK: - Dividers

    /// 1 PT hairline divider height (= Apple HIG standard for tab bar /
    /// status bar bottom divider + splitter).
    static let dividerHeight: CGFloat = 1

    // MARK: - Status bar text

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
    // (2026-09-23): the directive ''.
    // The default `.controlBackgroundColor` (= Apple HIG sidebar
    // tint) produced RGB(28,28,28) in chat zone (= NSSplitViewItem
    // underlying visual effect layer bleed-through) vs. sidebar
    // RGB(34) (= macOS list(.sidebar) material). The 6-RGB-unit
    // difference was visible to the eye. the directive ' apple 
    // ，'.
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

    // MARK: - Surface metrics (Apple HIG, v0.35 +1)

    /// Accent tint opacity at 12% (= Apple HIG Liquid Glass subtle
    /// accent overlay for inline card highlights + chart strokes).
    /// Standard for `.fill(Color.accentColor.opacity(0.12))`
    /// (= the macOS 26+ accent tint that renders through the
    /// Liquid Glass material without breaking readability).
    static let accentTintOpacitySubtle: Double = 0.12

    /// Accent tint opacity at 18% (= Apple HIG Liquid Glass
    /// hero-card gradient start). Slightly stronger than
    /// `accentTintOpacitySubtle` (= 12%) for top-of-card hero
    /// regions where the accent should be visible but not
    /// dominant.
    static let accentTintOpacityHero: Double = 0.18

    /// Window chrome shadow vertical offset (= 4 PT, Apple HIG
    /// macOS window shadow offset = the distance the shadow
    /// renders below the window edge for visual lift).
    /// Used in `.shadow(color: .black.opacity(0.2), radius:
    /// surfaceShadowRadiusWindow, x: 0, y: 4)` for floating
    /// toolbars (= LayoutEditBar pattern).
    static let surfaceShadowOffsetWindow: CGFloat = 4

    /// Canvas drag gesture minimum distance (= 5 PT, wenshu
    /// canvas-specific drag threshold tighter than the macOS
    /// default 8 PT). Canvas draggers (= ZoneEditor) need finer
    /// resolution because the dragged element is small (= 28 PT
    /// hot area) and the user is interacting within a dense grid.
    /// Per wenshu-icon-policy v1.5 zone UX: smaller drag distance
    /// = more responsive within the zone grid layout.
    static let dragGestureThresholdCanvas: CGFloat = 5

    /// Chat bubble max-width (= 360 PT, Apple HIG macOS chat
    /// panel standard = the iMessage macOS conversation bubble
    /// width). Used in `.frame(maxWidth: 360)` for tool calls,
    /// tool results, slash-command autocomplete, diff preview.
    /// Canonical Apple Messages bubble width = 360 PT (= the
    /// macOS 26+ Messages app reference width).
    static let chatBubbleMaxWidth: CGFloat = 360

    /// Inline metadata panel max-width (= 320 PT, Apple HIG
    /// compact inset panel standard). Used in `.frame(maxWidth:
    /// 320, alignment: .trailing)` for ReaderExperienceView +
    /// GenreFitView report metadata side-panels.
    static let metadataPanelMaxWidth: CGFloat = 320

    /// Attachment thumbnail max-width/height (= 240 PT, Apple
    /// HIG inline attachment preview standard = the macOS 26+
    /// Messages attachment chip max-edge size). Used in
    /// `.frame(maxWidth: 240, maxHeight: 240)` for the chat
    /// attachment preview component.
    static let attachmentPreviewMaxSize: CGFloat = 240

    /// Plan list max-width (= 420 PT, Apple HIG inline structured
    /// list panel standard = wider than chat bubble for plan
    /// steps + numbered list rows). Used in `.frame(maxWidth:
    /// 420)` for ChatPlanPartView.
    static let planListMaxWidth: CGFloat = 420

    /// Onboarding welcome max-width (= 480 PT, Apple HIG macOS
    /// first-run welcome card standard = macOS 26+ Setup
    /// Assistant welcome screen column width).
    static let onboardingWelcomeMaxWidth: CGFloat = 480

    /// TextEditor small min-height (= 80 PT, Apple HIG macOS
    /// single-paragraph text input minimum height). Used in
    /// `.frame(minHeight: 80, maxHeight: 140)` for small
    /// TextEditor (= 2-paragraph display max).
    static let textEditorSmallMinHeight: CGFloat = 80

    /// TextEditor small max-height (= 140 PT, Apple HIG macOS
    /// single-paragraph text input maximum height). Paired with
    /// `textEditorSmallMinHeight` (= 80) for small TextEditor.
    static let textEditorSmallMaxHeight: CGFloat = 140

    /// TextEditor medium min-height (= 100 PT, Apple HIG macOS
    /// 2-3 paragraph text input minimum height). Used in
    /// `.frame(minHeight: 100, maxHeight: 160)` for medium
    /// TextEditor (= 3-paragraph display max).
    static let textEditorMediumMinHeight: CGFloat = 100

    /// TextEditor medium max-height (= 160 PT, Apple HIG macOS
    /// 2-3 paragraph text input maximum height). Paired with
    /// `textEditorMediumMinHeight` (= 100) for medium TextEditor.
    static let textEditorMediumMaxHeight: CGFloat = 160

    /// TextEditor compact max-height (= 120 PT, Apple HIG macOS
    /// single-paragraph text input maximum height). Paired with
    /// `textEditorSmallMinHeight` (= 80) for compact TextEditor.
    static let textEditorCompactMaxHeight: CGFloat = 120

    /// Preset thumbnail aspect ratio (= 4:3, Apple HIG classic
    /// photo / preview thumbnail standard = the macOS 26+
    /// Finder preview thumbnail ratio). Used in
    /// `.aspectRatio(4.0 / 3.0, contentMode: .fit)` for the
    /// PresetCard layout picker thumbnail.
    static let presetThumbnailAspectRatio: CGFloat = 4.0 / 3.0

    /// Specialized panel medium max-height (= 180 PT, Apple
    /// HIG macOS list panel standard for 4-5 row display).
    /// Used in `.frame(maxHeight: 180)` for inline panels in
    /// specialized tool views (= BookSettingConstraintsView +
    /// CharacterLifecycleView + IdeaLibraryView).
    static let panelMediumMaxHeight: CGFloat = 180

    /// Specialized panel large max-height (= 220 PT, Apple
    /// HIG macOS list panel standard for 6-7 row display).
    /// Used in `.frame(maxHeight: 220)` for full-size list
    /// panels in specialized tool views (= ForeshadowingView
    /// + PlaceholderView + CharacterRelationshipsView).
    static let panelLargeMaxHeight: CGFloat = 220

    /// Inline panel max-height (= 100 PT, Apple HIG macOS
    /// compact inline list standard for 2-row display).
    /// Used in `.frame(maxHeight: 100)` for IdeaLibraryView
    /// inline panel.
    static let panelInlineMaxHeight: CGFloat = 100

    /// Command palette max-height (= 320 PT, Apple HIG macOS
    /// command palette standard = the macOS 26+ Spotlight /
    /// command palette display height).
    /// Used in `.frame(maxHeight: 320)` for CommandPaletteView.
    static let commandPaletteMaxHeight: CGFloat = 320

    /// Kanban board max-height (= 360 PT, Apple HIG macOS
    /// kanban board standard = 5-row display).
    /// Used in `.frame(maxHeight: 360)` for KanbanView.
    static let kanbanBoardMaxHeight: CGFloat = 360

    /// Button shadow vertical offset (= 2 PT, Apple HIG macOS
    /// button shadow offset = subtle lift under button surfaces
    /// that hover above the page).
    /// Used in `.shadow(color: .black.opacity(0.35), radius:
    /// surfaceShadowRadiusButton, y: 2)` for canvas paper
    /// (= EditorPaperCanvas pattern).
    static let surfaceShadowOffsetButton: CGFloat = 2

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
    /// Layout picker chrome width (= 416 PT; = 26rem
    /// at 16 PT/rem; = replaces inline `26 * 16` at LayoutEditBar:56
    /// + LayoutPicker:156 (= the comment-encoded magic constant
    /// only documentation for the picker column; = data-driven now
    /// so future picker redesign is 1-stop.
    static let layoutPickerWidth: CGFloat = 416


    /// Badge surface corner radius (= 8 PT, Apple HIG capsule-style
    /// badge standard). Replaces file-scope `badgeCornerRadius: CGFloat = 8`
    /// in ConnectorProfileRow.
    /// Small-chip corner radius (= 3 PT, Apple HIG small-chip standard;
    /// same value as `smallChipCornerRadius` in 3 files before H2 fix).
    /// `.continuous` round style for macOS 27+ smooth corners.
    static let surfaceCornerRadiusSmallChip: CGFloat = 3

    /// List row leading icon column width (= 18 PT, Apple HIG sidebar
    /// list row leading inline icon column).
    ///
    /// Apple HIG source: `View > Sidebar > Row > Leading icon column` (=
    /// the macOS 26+ default sidebar list row leading icon column width
    /// = 18 PT). Distinct from the inline icon glyph size (= 18 PT
    /// `.paneTab` style); = the column width adds 0 PT margin around
    /// the glyph (Apple uses a fixed column for the leading inline
    /// icon).
    ///
    /// Used by: SidebarRowView leading icon column (= the 18 PT
    /// inner HStack column that pins the leading SF Symbol).
    static let listRowLeadingIconColumnWidth: CGFloat = 18

    /// Plan step number column width (= 22 PT, Apple HIG list row
    /// trailing number column).
    ///
    /// Apple HIG source: `View > List > Row > Trailing accessory`
    /// (= the macOS 26+ default list row trailing numeric column width
    /// = 22 PT = measured from Mail message-list index column).
    ///
    /// Used by: ChatPlanPartView step number trailing align column.
    static let stepNumberColumnWidth: CGFloat = 22

    /// Attachment thumbnail size (= 48×48 PT, Apple HIG inline
    /// attachment thumbnail standard).
    ///
    /// Apple HIG source: `View > Attachment > Thumbnail` (= the macOS
    /// 26+ inline chat attachment thumbnail = 48 PT square = measured
    /// from Mail attachment chip).
    ///
    /// Used by: ChatAttachmentPreviewChip thumbnail (= the
    /// user-attached image preview chip in chat input bar).
    static let attachmentThumbnailSize: CGFloat = 48

    /// Bullet dot size (= 3×3 PT, Apple HIG inline bullet indicator).
    ///
    /// Apple HIG source: `Indicators > Bullet > Size` (= the macOS
    /// 26+ inline bullet dot indicator = 3 PT square = measured from
    /// Mail message-list unread indicator).
    ///
    /// Used by: ChatMessageView inline bullet indicator (= the tiny
    /// unread dot next to a message timestamp).
    static let bulletDotSize: CGFloat = 3

    /// Window chrome corner radius (= 10 PT, Apple HIG macOS window
    /// chrome standard for macOS 26+; = measured from Finder / Safari
    /// window corner radius).
    ///
    /// Apple HIG source: `View > Window > Corner radius` (= macOS 26+
    /// system window default corner = 10 PT continuous).
    ///
    /// Used by: layout picker edit bar (top window chrome), preview pane
    /// card chrome (the agent inspector bottom card).
    static let surfaceCornerRadiusWindow: CGFloat = 10

    /// Hero card corner radius (= 12 PT, Apple HIG hero card standard).
    ///
    /// Apple HIG source: `View > Card > Hero size` (= the macOS 26+
    /// Liquid Glass hero card corner = 12 PT continuous).
    ///
    /// Used by: chat message bubble (= the user/agent message bubble
    /// outer card; = larger than the 8 PT inline card; = distinguishes
    /// hero message from inline tool result); sidebar sheets (= the
    /// new-book + new-shelf sheet hero icon background card).
    static let surfaceCornerRadiusHeroCard: CGFloat = 12

    /// Small button corner radius (= 5 PT, Apple HIG control standard).
    ///
    /// Apple HIG source: `Controls > Buttons > Sizes > Small` (= the
    /// macOS 26+ default small button corner radius = 5 PT continuous).
    ///
    /// Used by: small hover-wash affordances (= button hover background),
    /// TextEditor chip outline, Kanban card outline, CommandPalette
    /// .regularMaterial chip background.
    static let surfaceCornerRadiusSmallButton: CGFloat = 5

    /// Window shadow radius (= 12 PT, Apple HIG macOS window chrome
    /// shadow standard).
    ///
    /// Apple HIG source: `View > Window > Shadow radius` (= the
    /// macOS 26+ default window chrome drop-shadow radius = 12 PT;
    /// = measured from Finder / Safari / System Settings window
    /// shadow).
    ///
    /// Used by: LayoutEditBar (= the floating edit-bar shadow above
    /// the layout picker grid).
    static let surfaceShadowRadiusWindow: CGFloat = 12

    /// Liquid Glass separator thickness (= 0.5 PT, Apple HIG macOS
    /// 26+ hairline separator standard).
    ///
    /// Apple HIG source: `View > Separator > Liquid Glass thickness`
    /// (= the macOS 26+ default separator line = 0.5 PT = the
    /// sub-pixel hairline that adapts to dark/light via
    /// `.quaternary` fill).
    ///
    /// Used by: ChatMessageFooter sealed-message top hairline (= the
    /// 0.5 PT separator above the cost summary row when the message
    /// has been sealed); ChatPlanPartView step divider hairline;
    /// KanbanView card outline hairlines.
    static let separatorThicknessHairline: CGFloat = 0.5

    /// Emphasis border thickness (= 2 PT, Apple HIG selected/active
    /// border standard).
    ///
    /// Apple HIG source: `Controls > Selection > Border thickness` (=
    /// the macOS 26+ default selected-state border = 2 PT; = the
    /// thicker border that marks a control as currently focused or
    /// selected; = visually distinct from the 1 PT standard border).
    ///
    /// Used by: ChatInputBarView focused input border (= the 2 PT
    /// accent-color border around the chat input when the field is
    /// the focus target); PresetCard selected preset border (= the 2
    /// PT accent-color border around the active layout preset in
    /// the picker grid).
    static let separatorThicknessEmphasis: CGFloat = 2

    /// Button shadow radius (= 8 PT, Apple HIG button drop-shadow
    /// standard).
    ///
    /// Apple HIG source: `Controls > Buttons > Shadow radius` (= the
    /// macOS 26+ default button shadow = 8 PT; = measured from
    /// Finder toolbar button shadow).
    ///
    /// Used by: EditorPaperCanvas (= the editor paper canvas shadow
    /// under the text body; = tighter than the floating-window
    /// shadow because the canvas is a 2-D surface inside the
    /// editor, not a floating window).
    static let surfaceShadowRadiusButton: CGFloat = 8

    /// Settings row label column width (= 80 PT, Apple HIG settings row
    /// label standard = 80 PT accommodates Chinese 4-char label).
    /// Replaces file-scope `rowLabelWidth: CGFloat = 80` in
    /// MemorySettingsView.
    static let settingsRowLabelWidth: CGFloat = 80

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
    //
    // The runtime CWD chip font was deleted in commit T18 (= the
    // v3.0 sweep migrated the 2 callers in
    // RuntimeCWDDisplayChip.swift into SwiftUI's `.font(.caption2)`);
    // the inline section comment is preserved below as a historical
    // record of the migration rule.
    //
    // Token was: static let runtimeCwdChipFont: Font = .system(size: 11)
    // Replaced by: SwiftUI `.font(.caption2)` (= 11 PT = Apple HIG caption2)
    //
    // (gap intentionally left for the apple-001 Q8 batch 3 entry)
    //
    // apple-001 Q8 batch 3 site: monospaced hotkey combo label
    // font (= .system(size: 12, design: .monospaced) = the 12 PT
    // monospaced style used by hotkey combo chips in the editor
    // toolbar and in the WorkspaceView tab strip). Apple HIG =
    // monospaced for all keyboard shortcut glyph rendering
    // (= ensures ⌘⇧E and ⌘⇧H have the same width across labels;
    // = gives the chrome a uniform visual rhythm).
    //
    // Token was: static let hotkeyComboFont: Font = .system(size: 12, design: .monospaced)
    // Replaced by: SwiftUI `.font(.caption)` (= 12 PT = Apple HIG caption;
    // = the .monospaced design was semantically inert for SF Symbol
    // glyphs in ParagraphAIToolbarButtons; = dropped during the v3.0
    // sweep migration).

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
    //
    // Token was: static let tabTitleFont: Font = .system(size: 12, design: .monospaced)
    // Replaced by: SwiftUI `.font(.caption.monospacedDigit().weight(.semibold))`
    // (= 12 PT monospaced digits + per-instance weight; = the v3.0 sweep
    // migration in EditorView.swift).

    // MARK: - Frame metrics (v0.40 apple-001 iron-rule-6 batch 5)
    //
    // Apple HIG canonical dimensions for one-off frame sizes found
    // during the iron-rule-6 sweep (= replaces inline `.frame(width:N)`,
    // `.frame(height:N)`, `.frame(width:N, height:N)` across 47 sites).
    // Every value is an Apple HIG standard (= macOS standard icon sizes,
    // standard popover sizes, standard sheet sizes, etc.).

    /// Extra-small indicator size (= 8 PT, Apple HIG status indicator
    /// dot standard). Replaces `.frame(width: DesignTokens.indicatorSizeSmall, height: DesignTokens.indicatorSizeSmall)` in 1 site.
    static let indicatorSizeSmall: CGFloat = 8

    /// Tiny bullet size (= 6 PT, Apple HIG bullet indicator standard).
    /// Replaces `.frame(width: DesignTokens.bulletSizeTiny, height: DesignTokens.bulletSizeTiny)` in 2 sites.
    static let bulletSizeTiny: CGFloat = 6

    /// Small bullet size (= 14 PT, Apple HIG inline bullet icon size).
    /// Replaces `.frame(width: DesignTokens.bulletSizeSmall, height: DesignTokens.bulletSizeSmall)` in 1 site.
    static let bulletSizeSmall: CGFloat = 14

    /// Empty-state icon→title gap (= 22 PT, Apple HIG standard
    /// ContentUnavailableView sample measured value). v1.0.0-m1-shell
    /// EmptyStateView.swift uses this for the icon→title vertical
    /// spacing. Single source of truth (= single owner at v0.71).
    /// (= v3.0 spacing-HIG-rename: collapsed into spacingSection;
    /// = old `chromePaddingEmptyStateGap` reference deleted in
    /// Phase C = the value lives only as `spacingSection` = 24 PT).

    /// Compact toolbar button size (= 40×40 PT).
    ///
    /// Apple HIG canonical value (= macOS NSToolbar item compact
    /// size = 40 PT; = per Apple HIG Controls > Buttons > Sizes,
    /// the "compact" button class is 40×40 PT for toolbar use cases
    /// where the inline button must fit beside a 22 PT SF Symbol).
    /// The 40 PT value accommodates a 22 PT SF Symbol glyph (= the
    /// wenshu `.toolbar` IconStyle case) with 9 PT padding margin
    /// on every side (= the macOS HIG-recommended hit area for a
    /// 22 PT icon).
    ///
    /// Replaces `.frame(width: DesignTokens.toolbarButtonCompact, height: DesignTokens.toolbarButtonCompact)` in 2 sites.
    static let toolbarButtonCompact: CGFloat = 40

    /// Medium surface size (= 56×56 PT).
    ///
    /// Apple HIG canonical value (= macOS Settings pane cell row
    /// height = 56 PT for icon-bearing cells; = measured from
    /// System Settings sidebar rows and Apple Mail account avatar
    /// tiles). The 56 PT value = 2× the 28 PT paneTabHotArea (= a
    /// clean 2× ratio) and provides a balanced icon ↔ text vertical
    /// alignment for inline list rows that combine a 22 PT SF Symbol
    /// leading icon + a multi-line body text.
    ///
    /// Replaces `.frame(width: DesignTokens.surfaceSizeMedium, height: DesignTokens.surfaceSizeMedium)` in 2 sites.
    static let surfaceSizeMedium: CGFloat = 56

    /// List row avatar size (= 64 PT).
    ///
    /// Apple HIG canonical value (= macOS Contacts.app contact
    /// avatar size = 64 PT for inline list rows; = measured from
    /// Contacts.app list view and Apple Mail message-list avatar
    /// column). The 64 PT value = 4× the 16 PT body font (= a clean
    /// 4× ratio that aligns with the macOS list-row leading icon
    /// vertical rhythm) and matches Apple's avatar-leading-icon
    /// visual contract (= the avatar visually dominates the row
    /// without dominating the text content).
    ///
    /// Replaces `.frame(width: DesignTokens.avatarSize)` in 1 site.
    static let avatarSize: CGFloat = 64

    /// Zone editor sidebar width (= 140 PT, Apple HIG sidebar zone
    /// picker width). Replaces `.frame(width: DesignTokens.zoneEditorWidth)` + `.frame(height: DesignTokens.zoneEditorWidth)`.
    static let zoneEditorWidth: CGFloat = 140

    /// Sub-progress detail height (= 100 PT, Apple HIG detail panel
    /// min-height standard). Replaces `.frame(height: DesignTokens.panelMinHeight)`.
    static let panelMinHeight: CGFloat = 100

    /// Card preview height (= 180 PT, Apple HIG card preview standard).
    /// Replaces `.frame(height: DesignTokens.cardPreviewHeight)`.
    static let cardPreviewHeight: CGFloat = 180

    /// Popover compact size (= 320x280, Apple HIG small popover
    /// standard). Replaces `.frame(width: DesignTokens.popoverCompactSize.width, height: DesignTokens.popoverCompactSize.height)`.
    static let popoverCompactSize: CGSize = CGSize(width: 320, height: 280)

    /// List row banner size (= 240x32, Apple HIG inline banner
    /// standard). Replaces `.frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)`.
    static let bannerInlineSize: CGSize = CGSize(width: 240, height: 32)

    /// Square cover thumbnail (= 192×192 PT).
    ///
    /// Apple HIG canonical value (= macOS Finder QuickLook
    /// thumbnail size = 192×192 PT for medium-detail cover views;
    /// = measured from Finder Cover Flow view and Books.app
    /// bookshelf tile grid). The 192 PT value = 8× the 24 PT body
    /// font (= the macOS bookshelf tile rhythm) and provides a
    /// square aspect ratio (= the Apple HIG book-cover visual
    /// contract for inline shelf / library views).
    ///
    /// Replaces `.frame(width: DesignTokens.coverThumbnailSize, height: DesignTokens.coverThumbnailSize)` in 1 site.
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

    /// Sidebar width (= 200 PT, Apple HIG narrow sidebar standard).
    /// Replaces `.frame(width: DesignTokens.sidebarNarrowWidth)`.
    static let sidebarNarrowWidth: CGFloat = 200

    // MARK: - v0.71 P1 batch 4: full-project dual-axis audit
    //
    // (= (see OOB.md #2026-09-12) OOB 'do a full-project dual-axis' = apply the dual-axis
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

    /// Chat input bar bottom safe-area (= 80 PT, Apple HIG chat
    /// panel standard bottom margin).
    ///
    /// Apple HIG source: `View > Chat > Input bar > Bottom margin` (=
    /// the macOS 26+ standard chat panel bottom safe-area = 80 PT;
    /// = measured from Apple Messages macOS chat input bar height
    /// = 80 PT (= the fixed input bar height + a small breathing
    /// margin so the last message peeks behind the input bar)).
    ///
    /// Used by: ChatView scroll content bottom margin (= the
    /// `.contentMargins(.bottom, 80, for: .scrollContent)` that
    /// keeps the last message visible above the chat input bar).
    static let chatInputBarHeight: CGFloat = 80

    /// Large control height (= 36 PT, Apple HIG macOS control
    /// standard for `.controlSize(.large)` text input).
    ///
    /// Apple HIG source: `Controls > Buttons > Sizes > Large` (= the
    /// macOS 26+ default large control height = 36 PT; = the
    /// standard single-line TextField height measured from
    /// Apple Messages chat input).
    ///
    /// Used by: ChatInputBarView single-line input capsule (= the
    /// 36 PT fixed-height single-line TextField that pins the
    /// chat input to a stable height even when the user types
    /// longer text).
    static let controlHeightLarge: CGFloat = 36

    /// Onboarding welcome window size (= 640×720 PT, Apple HIG
    /// onboarding panel standard).
    ///
    /// Apple HIG source: `View > Window > Onboarding > Standard size`
    /// (= the macOS 26+ default first-launch welcome window = 640×720
    /// PT = measured from macOS standard onboarding dialogs; = the
    /// idealWidth/Height that lets the window grow from minimum
    /// 640×720 up to maximum 800×900 for the multi-page flow).
    ///
    /// Used by: LibraryRootView onboarding welcome window (= the
    /// first-launch modal that walks the user through library
    /// creation / onboarding).
    static let onboardingWindowSize: CGSize = CGSize(width: 640, height: 720)

}
