// Sources/WenshuApp/DesignTokens.swift (= canonical dimensions for the unified
// Wenshu per-region chrome; = matches Apple HIG 30 PT toolbar standard, Apple
// Pages / Mail / Xcode toolbar layout)': Single source of truth for all chrome
// dimensions, paddings, font sizes, dividers, tab metrics (= extracted from
// LayoutTokens + 16 files of inline literals). Listed in ComponentIndex.md Level
// 1.1. = canonical dimensions for the unified Wenshu per-region chrome (= matches
// Apple HIG 30 PT toolbar standard, Apple Pages / Mail / Xcode toolbar layout).
// Use these constants instead of inline numbers. Dual-axis audit found: - chrome
// height 30 PT in 3 different places (= LayoutTokens + PaneTabBar) - chrome
// padding 18 PT in 5 different places (LayoutTokens + inline)
// -.font(.system(size:13)) in 10 files (= status bar text)
// -.foregroundStyle(.tertiary) in 16 files (= status bar text) - chatTabHotArea
// (= 28 PT) named after chat but used by ALL pane tabs - divider 1 PT in 5 inline
// places (= no constant)
import SwiftUI

// MARK: - DesignTokens namespace

/// The token values are the numbers ComponentIndex.md lists at Level 1.1.
@MainActor
enum DesignTokens {
    // MARK: - Chrome dimensions

    /// Height of `ChromeBottomFooter` (= the shared column-bottom bar).
    ///
    /// MEASURED, not estimated: rendered the footer offscreen and read
    /// its fitting height = 32 PT (= 1 divider + 8 + 8 padding + 15
    /// content row).
    ///
    /// The shared component pins its content row to the height that
    /// leaves this total, so every column's bottom bar is the same size
    /// whatever the caller puts in the content slot. A zone that hosts
    /// this footer reserves this much space for it.
    static let chromeBottomFooterHeight: CGFloat = 32

    /// Apple HIG sidebar list-row height (= 22 PT). Distinct from the row
    /// surface: the two are different measurements.
    static let sidebarRowHeight: CGFloat = 22

    /// Apple Tahoe sidebar row icon tile size (= 24 PT). The wenshu bans naked
    /// chrome (= the tile has to read as visibly smaller than the row's
    /// tappable target).
    static let sidebarIconTileSize: CGFloat = 24

    /// Apple Tahoe sidebar row icon tile corner radius (= 6 PT = ~25% of the
    /// 24 PT tile). The tile's corners go through this token.
    static let sidebarIconTileCornerRadius: CGFloat = 6

    /// Apple Tahoe sidebar row icon tile inner padding (= 4 PT = the gap inside
    /// the tile). The padding goes through this token.
    static let sidebarIconTilePadding: CGFloat = 4

    /// Canonical zone-content inset (= 8 PT on every side). The semantic name
    /// is '.small', and '.small' is 8 PT.
    static let zoneContentInset: CGFloat = 8

    // MARK: - Spacing (= Apple HIG canonical, 8 PT baseline grid)

    /// Hairline spacing (= 1 PT): the gap the autocomplete field and the
    /// layout picker's hotkey badges sit across.
    static let spacingHairline: CGFloat = 1

    /// Apple HIG caption2 metadata separator gap (= 2 PT). The canonical
    /// caption row gap.
    static let spacingCaption: CGFloat = 2

    /// Apple HIG icon-to-label gap (= 4 PT). The canonical tight inset: the
    /// ChapterFocusLockBadge row gap and the chat tool-part row gap.
    static let spacingIconic: CGFloat = 4

    /// Relaxed stack spacing (= 10 PT, the Apple HIG `.relaxed` stack spacing).
    static let spacingRelaxed: CGFloat = 10

    /// Apple HIG tight inter-row gap (= 6 PT). The canonical tight padding:
    /// the EmptyStateView row gap.
    static let spacingTight: CGFloat = 6

    /// Apple HIG standard spacing (= 8 PT). The Touch Bar default row gap.
    static let spacingStandard: CGFloat = 8

    /// Apple HIG moderate spacing (= 12 PT). The canonical
    /// bordered-content-row gap: the PlaceholderView and BookSettingConstraints
    /// row gap.
    static let spacingModerate: CGFloat = 12

    /// Apple HIG loose spacing (= 16 PT). The Touch Bar small fixed space.
    static let spacingLoose: CGFloat = 16

    /// Apple HIG hero / window content margin (= 20 PT). The canonical macOS
    /// margin for the sidebar sheets, the ZoneEditor and the PreviewPane sheet
    /// body.
    static let spacingHero: CGFloat = 20

    /// Apple HIG section white-space maximum (= 24 PT). The Touch Bar large gap
    /// and the EmptyStateView icon-to-text gap.
    static let spacingSection: CGFloat = 24

    // MARK: - Tab metrics

    /// The hot area of a pane tab (= 28 PT): the height a click on the tab
    /// lands in. The name is generic now, because it serves every pane tab.
    static let paneTabHotArea: CGFloat = 28

    /// Per-pane tab close-X icon point size (= 8 PT, the Apple HIG "small"
    /// tier).
    static let tabCloseIconPointSize: CGFloat = 8

    /// Per-pane tab selected-state underline height (= 1 PT, the Apple HIG
    /// standard).
    static let tabUnderlineHeight: CGFloat = 1

    // MARK: - Dividers

    /// The height of a hairline divider (= 1 PT): the bar's bottom divider and
    /// the splitter.
    static let dividerHeight: CGFloat = 1

    // MARK: - Status bar text

    /// Apple HIG foreground four-tier ladder mapped to writing surfaces.
    /// The body text across the editor (NativeTextViewWrapper / NSTextView
    /// labelColor = .label) AND the chat (SwiftUI Text.font(.body))
    /// reads `.primary` = the same SwiftUI semantic token. Apple HIG
    /// forbids `.primary.opacity(0.X)` for dimming: dimming is the
    /// job of the four-tier semantic ladder, not opacity tweaks.
    ///   .primary   = writing body (= Pages / Notes body).
    ///   .secondary = bubble chrome (= timestamps, captions, footers).
    ///   .tertiary  = tertiary metadata (= IDs, hashes, badges).
    ///   .quaternary = disabled / placeholder text.
    /// Body (writing) text never uses .secondary / .tertiary /
    /// .quaternary — those tiers are reserved for chrome around the
    /// body, not for the body itself.
    static let textBody: HierarchicalShapeStyle = .primary
    static let textChrome: HierarchicalShapeStyle = .secondary
    static let textMetadata: HierarchicalShapeStyle = .tertiary
    static let textPlaceholder: HierarchicalShapeStyle = .quaternary
    /// Apple HIG text-style scale (macOS 27). Pinning the editor and the chrome
    /// around the body to the same Apple scale stops the chat zone from
    /// drifting to ad-hoc `Font.system(size:)` calls.
    static let bodyFontSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
    static let captionFontSize: CGFloat = NSFont.preferredFont(forTextStyle: .caption1).pointSize
    static let caption2FontSize: CGFloat = NSFont.preferredFont(forTextStyle: .caption2).pointSize
    /// The foreground colour of a status (= `.tertiary`). Replaces
    /// `.foregroundStyle(.tertiary)` in 16 files.
    static let statusForeground: HierarchicalShapeStyle = .tertiary

    // MARK: - Surface metrics (Apple HIG)

    /// Accent tint opacity at 18% (= the dominant stop of the Apple HIG Liquid
    /// Glass hero-card gradient).
    static let accentTintOpacityHero: Double = 0.18

    /// Window chrome shadow vertical offset (= 4 PT, the Apple HIG macOS window
    /// shadow pattern).
    static let surfaceShadowOffsetWindow: CGFloat = 4

    /// Canvas drag gesture minimum distance (= 5 PT). Wenshu-specific: the
    /// canvas lives inside the zone grid layout.
    static let dragGestureThresholdCanvas: CGFloat = 5

    /// Chat bubble max-width (= 360 PT, the Apple HIG macOS chat panel standard
    /// = the Messages app reference width).
    static let chatBubbleMaxWidth: CGFloat = 360

    /// Inline metadata panel max-width (= 320 PT, the Apple HIG compact inset
    /// panel). The ReaderExperienceView and GenreFitView report metadata
    /// side-panels use it.
    static let metadataPanelMaxWidth: CGFloat = 320

    /// Attachment thumbnail max-width and height (= 240 PT, the Apple HIG
    /// inline chat attachment preview component).
    static let attachmentPreviewMaxSize: CGFloat = 240

    /// Plan list max-width (= 420 PT, the Apple HIG inline structured list
    /// panel). Used in `.frame(maxWidth: 420)` for ChatPlanPartView.
    static let planListMaxWidth: CGFloat = 420

    /// Onboarding welcome max-width (= 480 PT, the Apple HIG macOS first-run
    /// width).
    static let onboardingWelcomeMaxWidth: CGFloat = 480

    /// TextEditor small min-height (= 80 PT, the Apple HIG macOS single-paragraph
    /// height) for the small TextEditor (= the 2-paragraph display minimum).
    static let textEditorSmallMinHeight: CGFloat = 80

    /// TextEditor small max-height (= 140 PT, the Apple HIG macOS single-paragraph
    /// maximum) for the small TextEditor.
    static let textEditorSmallMaxHeight: CGFloat = 140

    /// TextEditor medium min-height (= 100 PT, the Apple HIG macOS 2-3 paragraph
    /// height) for the medium TextEditor (= the 3-paragraph display minimum).
    static let textEditorMediumMinHeight: CGFloat = 100

    /// TextEditor medium max-height (= 160 PT, the Apple HIG macOS 2-3 paragraph
    /// maximum) for the medium TextEditor.
    static let textEditorMediumMaxHeight: CGFloat = 160

    /// TextEditor compact max-height (= 120 PT, the Apple HIG macOS compact
    /// maximum). The compact editor starts at `textEditorSmallMinHeight` (= 80).
    static let textEditorCompactMaxHeight: CGFloat = 120

    /// Preset thumbnail aspect ratio (= 4:3, the Apple HIG classic photo /
    /// preview layout picker thumbnail).
    static let presetThumbnailAspectRatio: CGFloat = 4.0 / 3.0

    /// Specialized panel medium max-height (= 180 PT, the Apple HIG macOS list
    /// panel). BookSettingConstraintsView, CharacterLifecycleView and
    /// IdeaLibraryView use it.
    static let panelMediumMaxHeight: CGFloat = 180

    /// Specialized panel large max-height (= 220 PT, the Apple HIG macOS list
    /// panel). PlaceholderView and CharacterRelationshipsView use it.
    static let panelLargeMaxHeight: CGFloat = 220

    /// Inline panel max-height (= 100 PT, the Apple HIG macOS compact inline
    /// list). The IdeaLibraryView inline panel uses it.
    static let panelInlineMaxHeight: CGFloat = 100

    /// Kanban board max-height (= 360 PT, Apple HIG macOS kanban board standard
    /// = 5-row display). Used in `.frame(maxHeight: 360)` for KanbanView.
    static let kanbanBoardMaxHeight: CGFloat = 360

    /// Kanban board column width (= 256 PT, the Hermes board's lane width).
    /// A column holds a card's title plus a body preview, so it is wider
    /// than the sidebar (= the sidebar token keeps its own meaning).
    static let kanbanColumnWidth: CGFloat = 256

    /// Kanban card status edge width (= 2 PT, the Hermes board's card
    /// left edge). The edge carries the column's status color.
    static let kanbanCardStatusEdgeWidth: CGFloat = 2

    /// The column a card's state marker sits in (= 16 PT = the width of the
    /// widest inline-small symbol the column's cards wear; the symbols' ink
    /// measures 14 to 15 PT at the 14 PT point size, and a column narrower
    /// than the widest symbol lets the symbol spill over the words beside
    /// it). A spinner and a symbol have different intrinsic widths, so a card
    /// that does not reserve the column reads ragged (= the words start at
    /// different places).
    static let inspectionMarkerColumnWidth: CGFloat = 16

    /// Kanban column dot diameter (= 6 PT, the status dot in a column
    /// header). Matches the Hermes board's column dot.
    static let kanbanColumnDotSize: CGFloat = 6

    /// Kanban board search field width (= 160 PT, the narrow filter field
    /// in the board header). Wide enough for a title, narrow enough to
    /// leave the pickers room.
    static let kanbanSearchFieldWidth: CGFloat = 160

    /// Button shadow vertical offset (= 2 PT, the Apple HIG macOS button shadow
    /// pattern).
    static let surfaceShadowOffsetButton: CGFloat = 2

    /// Card surface corner radius (= 8 PT, the Apple HIG rounded card standard).
    /// The corner style is `.continuous` (the Apple HIG 13+ corner style).
    static let surfaceCornerRadiusCard: CGFloat = 8

    /// The layout picker's width (= 416 PT). The value is one step away from
    /// the chat bubble's, so a future picker redesign is a one-step change.
    static let layoutPickerWidth: CGFloat = 416

    /// The badge surface's corner radius (= 3 PT). The corner style is
    /// `.continuous`, which gives macOS 27+ its smooth corners.
    static let surfaceCornerRadiusSmallChip: CGFloat = 3

    /// List row leading icon column width (= 18 PT). The Apple HIG sidebar
    /// list row pins the leading SF Symbol into a column this wide.
    static let listRowLeadingIconColumnWidth: CGFloat = 18

    /// Plan step number column width (= 22 PT, the Apple HIG list row trailing
    /// column). The ChatPlanPartView step number trailing-align column uses it.
    static let stepNumberColumnWidth: CGFloat = 22

    /// Attachment thumbnail size (= 48×48 PT, the Apple HIG inline attachment
    /// thumbnail = the user-attached image preview chip in the chat input bar).
    static let attachmentThumbnailSize: CGFloat = 48

    /// Bullet dot size (= 3×3 PT, the Apple HIG inline bullet indicator). The
    /// unread dot next to a message timestamp uses it.
    static let bulletDotSize: CGFloat = 3

    /// Window chrome corner radius (= 10 PT, the Apple HIG macOS window chrome
    /// radius). The inspector's bottom card uses it.
    static let surfaceCornerRadiusWindow: CGFloat = 10

    /// Hero card corner radius (= 12 PT, the Apple HIG hero card standard). The
    /// new-book and new-shelf sheets use it for the hero icon's background card.
    static let surfaceCornerRadiusHeroCard: CGFloat = 12

    /// Small button corner radius (= 5 PT, the Apple HIG control standard).
    static let surfaceCornerRadiusSmallButton: CGFloat = 5

    /// Window shadow radius (= 12 PT, the Apple HIG macOS window chrome shadow
    /// radius).
    static let surfaceShadowRadiusWindow: CGFloat = 12

    /// Liquid Glass separator thickness (= 0.5 PT, the Apple HIG macOS 26+
    /// hairline).
    static let separatorThicknessHairline: CGFloat = 0.5

    /// Emphasis border thickness (= 2 PT, the Apple HIG selected/active border
    /// in the picker grid).
    static let separatorThicknessEmphasis: CGFloat = 2

    /// Button shadow radius (= 8 PT, the Apple HIG button drop-shadow standard).
    /// The canvas uses it too: the canvas is a 2-D surface inside the editor,
    /// not a floating window.
    static let surfaceShadowRadiusButton: CGFloat = 8

    /// Settings row label column width (= 80 PT, the Apple HIG settings row
    /// label column). MemorySettingsView spells the same value as a file-scope
    /// `rowLabelWidth: CGFloat = 80`.
    static let settingsRowLabelWidth: CGFloat = 80

    /// Active surface tint alpha (= 0.2, the Apple HIG subtle accent overlay).
    /// ConnectorProfileRow uses it.
    static let surfaceActiveTintAlpha: CGFloat = 0.2

    /// Inactive border tint alpha (= 0.2, Apple HIG subtle border). Replaces
    /// file-scope `inactiveStrokeAlpha: CGFloat = 0.2` in ConnectorProfileRow.
    static let surfaceInactiveBorderAlpha: CGFloat = 0.2

    /// Active border width (= 2 PT, the Apple HIG emphasized border).
    /// ConnectorProfileRow spells the same value as a file-scope constant.
    static let surfaceActiveBorderWidth: CGFloat = 2

    /// Inactive border width (= 1 PT, Apple HIG standard border). Replaces
    /// file-scope `inactiveStrokeWidth: CGFloat = 1` in ConnectorProfileRow.
    static let surfaceInactiveBorderWidth: CGFloat = 1

    /// Badge interior vertical padding (= 2 PT, the Apple HIG tight badge
    /// standard). Replaces inline `.padding(.vertical, 2)` in ConnectorProfileRow.
    static let badgePaddingVertical: CGFloat = 2

    /// The cap for a settings list's height (= 200 PT = the 4-row Mac App Store
    /// "in-app settings" pattern = enough for a feature toggle, a picker, and a
    /// description; beyond this the view should scroll). No pane reads it yet:
    /// the settings lists set their own height, so this is the shared value to
    /// use when one of them takes a cap.
    static let settingsListMaxHeight: CGFloat = 200

    /// Batch 2 site: font size for the runtime CWD SubAgentProgressView.
    static let surfaceCornerRadiusProgressCard: CGFloat = 6

    /// The small indicator's size (= 8 PT): the tab title font's indicator.
    static let indicatorSizeSmall: CGFloat = 8

    /// Tiny bullet size (= 6 PT, the Apple HIG bullet indicator standard).
    /// Replaces the inline value in 2 sites.
    static let bulletSizeTiny: CGFloat = 6

    /// Small bullet size (= 14 PT, the Apple HIG inline bullet icon size).
    /// Replaces the inline value in 1 site.
    static let bulletSizeSmall: CGFloat = 14

    /// The compact toolbar button's height (= 40 PT). The empty-state
    /// icon-to-title gap beside it is 22 PT (the Apple HIG standard).
    static let toolbarButtonCompact: CGFloat = 40

    /// Medium surface size (= 56×56 PT, the Apple HIG canonical value).
    static let surfaceSizeMedium: CGFloat = 56

    /// List row avatar size (= 64 PT, the Apple HIG canonical value). Replaces
    /// `.frame(width: DesignTokens.avatarSize)` in 1 site.
    static let avatarSize: CGFloat = 64

    /// Zone editor sidebar width (= 140 PT, the Apple HIG sidebar zone picker
    /// width). Used in `.frame(height: DesignTokens.zoneEditorWidth)`.
    static let zoneEditorWidth: CGFloat = 140

    /// Sub-progress detail height (= 100 PT, Apple HIG detail panel min-height
    /// standard). Replaces `.frame(height: DesignTokens.panelMinHeight)`.
    static let panelMinHeight: CGFloat = 100

    /// The colour of the words on a card with no picture.
    ///
    /// A card with no cover shows a warm paper wash (= the colour the
    /// pictures are painted on), so its words are ink on that paper
    /// and there is no wash drawn under them. A card WITH a cover has
    /// a painting behind it, so its words are white over a wash.
    static let coverInk = Color(red: 0.17, green: 0.13, blue: 0.11)

    /// The paper wash a card with no picture shows, from its lightest corner
    /// to its darkest.
    ///
    /// A card with no cover stands in for the thing it replaces: a card
    /// whose cover is a Chinese scroll painting on pale paper gets a warm
    /// paper wash, not a cool grey. The three stops run from the paper's
    /// lit corner (= top leading) to its shaded corner (= bottom trailing),
    /// so the gradient reads as one sheet of paper under raking light.
    static let coverPaperTop = Color(red: 0.968, green: 0.949, blue: 0.906)
    static let coverPaperMiddle = Color(red: 0.910, green: 0.878, blue: 0.816)
    static let coverPaperBottom = Color(red: 0.780, green: 0.733, blue: 0.659)

    /// The watermark glyph on the paper wash, as ink on that paper.
    ///
    /// The glyph sits in the middle of the sheet, so it is drawn in a
    /// deeper ink than the card's words use (= `coverInk` = 0.17/0.13/0.11
    /// = the near-black the text is set in; = this token = 0.28/0.24/0.20 =
    /// the softer brown the wash reads as ink), at the opacity a
    /// watermark reads at (= present, not legible).
    static let coverPaperWatermarkInk = Color(red: 0.28, green: 0.24, blue: 0.20)

    /// The shape of a card's picture tile.
    ///
    /// 4:3, which is the shape the picture is generated in
    /// (= 768 x 576), so the picture fills the tile and nothing is
    /// trimmed. The tile's width is the material column's width
    /// (= 216-316 PT), so its height follows.
    static let coverTileRatio: CGFloat = 4.0 / 3.0

    /// Card preview height (= 180 PT, Apple HIG card preview standard).
    /// Replaces `.frame(height: DesignTokens.cardPreviewHeight)`.
    static let cardPreviewHeight: CGFloat = 180

    /// Popover compact size (= 320x280, the Apple HIG small popover standard).
    static let popoverCompactSize: CGSize = .init(width: 320, height: 280)

    /// List row banner size (= 240x32, the Apple HIG inline banner standard).
    static let bannerInlineSize: CGSize = .init(width: 240, height: 32)

    /// Square cover thumbnail (= 192×192 PT, the Apple HIG canonical value).
    static let coverThumbnailSize: CGFloat = 192

    /// Settings sheet size (= 600x480, the Apple HIG settings window standard).
    static let settingViewSheetSize: CGSize = .init(width: 600, height: 480)

    /// Settings import/export sheet size (= 600x400, Apple HIG import/export
    /// window standard). Replaces `.frame(width: 600, height: 400)`.
    static let settingIOsheetSize: CGSize = .init(width: 600, height: 400)

    /// Guardrail sheet width (= 360 PT, the Apple HIG modal sheet width).
    static let guardrailSheetWidth: CGFloat = 360

    /// Sidebar width (= 200 PT, Apple HIG narrow sidebar standard). Replaces
    /// `.frame(width: DesignTokens.sidebarNarrowWidth)`.
    static let sidebarNarrowWidth: CGFloat = 200

    // MARK: - full-project dual-axis audit

    /// The chat input bar's height (= 80 PT): the height that keeps the
    /// agent's message visible above it.
    static let chatInputBarHeight: CGFloat = 80

    /// Large control height (= 36 PT, the Apple HIG macOS control standard).
    /// The chat input uses it to keep a stable height even when the user types
    /// longer text.
    static let controlHeightLarge: CGFloat = 36

    /// Pages-style picker card row height (= 32 PT). The Apple HIG source is
    /// the Pages inspector panel, and the row is aligned with it.
    static let pickerCardHeight: CGFloat = 32

    /// Picker card internal horizontal padding (= 12 PT). The Apple HIG source is
    /// the Pages step 1 wizard, and the card follows the Pages-style picker cards.
    static let pickerCardPaddingH: CGFloat = 12

    /// Sheet width for inline rename dialogs (= 360 PT, the Apple HIG macOS
    /// sheet width). The sheet is a NavigationStack+Form, which read as
    /// iOS-shaped chrome on macOS 27.
    static let controlSheetWidthRename: CGFloat = 360

    /// Onboarding welcome window size (= 640×720 PT, the Apple HIG onboarding
    /// panel size). The onboarding runs through library creation.
    static let onboardingWindowSize: CGSize = .init(width: 640, height: 720)
}
