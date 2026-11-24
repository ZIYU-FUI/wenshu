// Sources/WenshuApp/DesignTokens.swift: Single source of truth for all chrome
// dimensions, paddings, font sizes, dividers, tab metrics (= extracted from
// LayoutTokens + 16 files of inline literals). Listed in ComponentIndex.md Level
// 1.1. The old header cited an "Apple HIG 30 PT toolbar standard" and an
// "18 PT padding in 5 places"; neither figure exists in the HIG or in this
// file (grep '= 30' = 0 hits; the only macOS bar height the HIG publishes is the menu
// bar's 24 pt) (= the 2026-11-21 craft audit, rule C3/X12). Values below are
// the product's; where one coincides with a system measurement, the doc
// comment names the measurement instead of a citation.
// Use these constants instead of inline numbers.
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

    /// Product sidebar list-row height (= 22 PT): the row rhythm the tree
    /// settled on. No HIG figure exists; distinct from the row surface.
    static let sidebarRowHeight: CGFloat = 22

    /// Product sidebar row icon tile size (= 24 PT). The wenshu bans naked
    /// chrome (= the tile has to read as visibly smaller than the row's
    /// tappable target).
    static let sidebarIconTileSize: CGFloat = 24

    /// Product sidebar row icon tile corner radius (= 6 PT = ~25% of the
    /// 24 PT tile). The tile's corners go through this token.
    static let sidebarIconTileCornerRadius: CGFloat = 6

    /// Product sidebar row icon tile inner padding (= 4 PT = the gap inside
    /// the tile). The padding goes through this token.
    static let sidebarIconTilePadding: CGFloat = 4

    /// Canonical zone-content inset (= 8 PT on every side). The semantic name
    /// is '.small', and '.small' is 8 PT.
    static let zoneContentInset: CGFloat = 8

    // MARK: - Spacing (= internal 8 PT grid; base step measured, see below)

    /// Hairline spacing (= 1 PT): the gap the autocomplete field and the
    /// layout picker's hotkey badges sit across.
    static let spacingHairline: CGFloat = 1

    /// Caption micro-gap (= 2 PT): the product title/subtitle separator.
    /// The HIG publishes no caption-gap figure (= audit C3, withdrawn).
    static let spacingCaption: CGFloat = 2

    /// Product icon-to-label gap (= 4 PT, the tightest rung): the
    /// ChapterFocusLockBadge row gap and the chat tool-part row gap.
    /// The system's own HStack icon-text gap measures 8 PT (= this rung is
    /// deliberately tighter, a product choice, not a HIG figure).
    static let spacingIconic: CGFloat = 4

    /// Product mid-step stack spacing (= 10 PT). The old comment cited an
    /// "Apple HIG `.relaxed` stack spacing"; no such SDK value exists (audit C3).
    static let spacingRelaxed: CGFloat = 10

    /// Tight inter-row gap (= 6 PT): the product half-step between the
    /// 4 and 8 rungs; the EmptyStateView row gap.
    static let spacingTight: CGFloat = 6

    /// The grid's base step (= 8 PT): measured as SwiftUI's default HStack
    /// spacing on macOS 27.2 (= the old "Touch Bar default row gap" provenance
    /// is withdrawn; the Touch Bar is discontinued and the HIG publishes no
    /// such figure, audit C3).
    static let spacingStandard: CGFloat = 8

    /// Product moderate spacing (= 12 PT): the bordered-content-row gap,
    /// the PlaceholderView and BookSettingConstraints row gap.
    static let spacingModerate: CGFloat = 12

    /// The window's default inset (= 16 PT): measured as the default inset of
    /// `.padding()` on macOS 27.2 (= the old "Touch Bar small fixed space"
    /// provenance is withdrawn, audit C3).
    static let spacingLoose: CGFloat = 16

    /// Product hero / window content margin (= 20 PT): the margin the
    /// sidebar sheets, the ZoneEditor and the PreviewPane sheet body use.
    static let spacingHero: CGFloat = 20

    /// Product section gap (= 24 PT): the EmptyStateView icon-to-text gap and
    /// the chrome section runs. NOTE the system's own Form inter-section gap
    /// measures 32 PT on macOS 27.2 (= this rung is deliberately tighter, a
    /// product choice; the old "Touch Bar large gap" provenance is withdrawn,
    /// audit C3/X12).
    static let spacingSection: CGFloat = 24

    // MARK: - Tab metrics

    /// The hot area of a pane tab (= 28 PT): the height a click on the tab
    /// lands in. The name is generic now, because it serves every pane tab.
    static let paneTabHotArea: CGFloat = 28

    /// Per-pane tab close-X icon point size (= 8 PT): the product small
    /// glyph rung for tab chrome.
    static let tabCloseIconPointSize: CGFloat = 8

    /// Per-pane tab selected-state underline height (= 1 PT): one device
    /// hairline at the app's rendering scale.
    static let tabUnderlineHeight: CGFloat = 1

    // MARK: - Dividers

    /// The height of a hairline divider (= 1 PT): the bar's bottom divider and
    /// the splitter.
    static let dividerHeight: CGFloat = 1

    // MARK: - Status bar text

    /// The system's four-tier label ladder mapped to writing surfaces.
    /// The body text across the editor (NativeTextViewWrapper / NSTextView
    /// labelColor = .label) AND the chat (SwiftUI Text.font(.body))
    /// reads `.primary` = the same SwiftUI semantic token. Dimming is the
    /// four-tier ladder's job, not `.primary.opacity(0.X)` tweaks: hand-
    /// rolled alphas do not follow Dark Mode or Increase Contrast (audit C2).
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
    /// The loading placeholder's text-bar height (= 10 PT).
    ///
    /// = = The bar stands in for one line of words (= the title row or
    /// = = the summary row of a card) = = so it reads as a line of text
    /// = = rather than as a hairline or a slab. The number is the
    /// = = app's own (= Apple ships no skeleton API = = there is no
    /// = = Apple number to copy; see `LoadingPlaceholder`'s docblock).
    static let skeletonTextBarHeight: CGFloat = 10

    /// The loading placeholder's leading text-bar height (= 12 PT).
    ///
    /// = = The leading bar stands in for a row's FIRST line of words
    /// = = (= the title) = = and the second bar stands in for the row's
    /// = = detail line. = = The title is the larger of the two = = so
    /// = = the reserved row reads as a title over a detail, the way
    /// = = the real card does.
    static let skeletonTextBarHeightLarge: CGFloat = 12

    /// The foreground colour of a status (= `.tertiary`). Replaces
    /// `.foregroundStyle(.tertiary)` in 16 files.
    static let statusForeground: HierarchicalShapeStyle = .tertiary

    // MARK: - Surface metrics (product)

    /// Accent tint opacity at 18%: the product hero-card wash. The HIG's
    /// Liquid Glass chapter publishes no gradient stop values (audit C3).
    static let accentTintOpacityHero: Double = 0.18

    /// Window chrome shadow vertical offset (= 4 PT): the product shadow
    /// family's offset.
    static let surfaceShadowOffsetWindow: CGFloat = 4

    /// Canvas drag gesture minimum distance (= 5 PT). Wenshu-specific: the
    /// canvas lives inside the zone grid layout.
    static let dragGestureThresholdCanvas: CGFloat = 5

    /// Chat bubble max-width (= 360 PT, the product chat panel standard
    /// = the Messages app reference width).
    static let chatBubbleMaxWidth: CGFloat = 360

    /// Inline metadata panel max-width (= 320 PT, the product compact inset
    /// panel). The ReaderExperienceView and GenreFitView report metadata
    /// side-panels use it.
    static let metadataPanelMaxWidth: CGFloat = 320

    /// The reasoning block's height cap (= 160 PT).
    ///
    /// The number is the app's own: Apple's HIG publishes no figure for
    /// the height of a nested scrolling region, so the cap is the
    /// product's decision. At the app's caption line height (= 13 PT)
    /// the rectangle holds about twelve lines: a screenful of thinking
    /// is readable at a glance, and the rest scrolls inside the
    /// rectangle instead of pushing the transcript down.
    static let reasoningBoxMaxHeight: CGFloat = 160

    /// Attachment thumbnail max-width and height (= 240 PT): the product
    /// inline chat attachment preview size.
    static let attachmentPreviewMaxSize: CGFloat = 240

    /// Plan list max-width (= 420 PT, the product inline structured list
    /// panel). Used in `.frame(maxWidth: 420)` for ChatPlanPartView.
    static let planListMaxWidth: CGFloat = 420

    /// Onboarding welcome max-width (= 480 PT, the product first-run
    /// width).
    static let onboardingWelcomeMaxWidth: CGFloat = 480

    /// TextEditor small min-height (= 80 PT, the product single-paragraph
    /// height) for the small TextEditor (= the 2-paragraph display minimum).
    static let textEditorSmallMinHeight: CGFloat = 80

    /// TextEditor small max-height (= 140 PT, the product single-paragraph
    /// maximum) for the small TextEditor.
    static let textEditorSmallMaxHeight: CGFloat = 140

    /// TextEditor medium min-height (= 100 PT, the product 2-3 paragraph
    /// height) for the medium TextEditor (= the 3-paragraph display minimum).
    static let textEditorMediumMinHeight: CGFloat = 100

    /// TextEditor medium max-height (= 160 PT, the product 2-3 paragraph
    /// maximum) for the medium TextEditor.
    static let textEditorMediumMaxHeight: CGFloat = 160

    /// TextEditor compact max-height (= 120 PT, the product compact
    /// maximum). The compact editor starts at `textEditorSmallMinHeight` (= 80).
    static let textEditorCompactMaxHeight: CGFloat = 120

    /// Preset thumbnail aspect ratio (= 4:3, the product classic photo /
    /// preview layout picker thumbnail).
    static let presetThumbnailAspectRatio: CGFloat = 4.0 / 3.0

    /// Specialized panel medium max-height (= 180 PT, the product list
    /// panel). BookSettingConstraintsView, CharacterLifecycleView and
    /// IdeaLibraryView use it.
    static let panelMediumMaxHeight: CGFloat = 180

    /// Specialized panel large max-height (= 220 PT, the product list
    /// panel). PlaceholderView and CharacterRelationshipsView use it.
    static let panelLargeMaxHeight: CGFloat = 220

    /// Inline panel max-height (= 100 PT, the product compact inline
    /// list). The IdeaLibraryView inline panel uses it.
    static let panelInlineMaxHeight: CGFloat = 100

    /// Kanban board max-height (= 360 PT, product kanban board standard
    /// = 5-row display). Used in `.frame(maxHeight: 360)` for KanbanView.
    static let kanbanBoardMaxHeight: CGFloat = 360

    /// Kanban board column width (= 256 PT, the Hermes board's lane width).
    /// A column holds a card's title plus a body preview, so it is wider
    /// than the sidebar (= the sidebar token keeps its own meaning).
    static let kanbanColumnWidth: CGFloat = 256

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

    /// Button shadow vertical offset (= 2 PT, the product button shadow
    /// pattern).
    static let surfaceShadowOffsetButton: CGFloat = 2

    /// Card surface corner radius (= 8 PT, the product rounded card choice).
    /// The corner style is `.continuous` (the product 13+ corner style).
    static let surfaceCornerRadiusCard: CGFloat = 8

    /// The layout picker's width (= 416 PT). The value is one step away from
    /// the chat bubble's, so a future picker redesign is a one-step change.
    static let layoutPickerWidth: CGFloat = 416

    /// The badge surface's corner radius (= 3 PT). The corner style is
    /// `.continuous`, which gives macOS 27+ its smooth corners.
    static let surfaceCornerRadiusSmallChip: CGFloat = 3

    /// List row leading icon column width (= 18 PT). The product sidebar
    /// list row pins the leading SF Symbol into a column this wide.
    static let listRowLeadingIconColumnWidth: CGFloat = 18

    /// Plan step number column width (= 22 PT, the product list row trailing
    /// column). The ChatPlanPartView step number trailing-align column uses it.
    static let stepNumberColumnWidth: CGFloat = 22

    /// Attachment thumbnail size (= 48×48 PT, the product inline attachment
    /// thumbnail = the user-attached image preview chip in the chat input bar).
    static let attachmentThumbnailSize: CGFloat = 48

    /// Bullet dot size (= 3×3 PT, the product inline bullet indicator). The
    /// unread dot next to a message timestamp uses it.
    static let bulletDotSize: CGFloat = 3

    /// Window chrome corner radius (= 10 PT, the product window chrome
    /// radius). The inspector's bottom card uses it.
    static let surfaceCornerRadiusWindow: CGFloat = 10

    /// Hero card corner radius (= 12 PT, the product hero card standard). The
    /// new-book and new-shelf sheets use it for the hero icon's background card.
    static let surfaceCornerRadiusHeroCard: CGFloat = 12

    /// Small button corner radius (= 5 PT, the product control standard).
    static let surfaceCornerRadiusSmallButton: CGFloat = 5

    /// Window shadow radius (= 12 PT, the product window chrome shadow
    /// radius).
    static let surfaceShadowRadiusWindow: CGFloat = 12

    /// The hairline rungs (= 0.5 PT): one device pixel at 2x, the thickness
    /// measured on the app's own window capture (the old "Apple HIG macOS 26+
    /// hairline" citation published no number; audit C3). The system `Divider`
    /// itself measures 1.0 PT.
    static let separatorThicknessHairline: CGFloat = 0.5

    /// Emphasis border thickness (= 2 PT, the product selected/active border
    /// in the picker grid).
    static let separatorThicknessEmphasis: CGFloat = 2

    /// Button shadow radius (= 8 PT, the product button drop-shadow standard).
    /// The canvas uses it too: the canvas is a 2-D surface inside the editor,
    /// not a floating window.
    static let surfaceShadowRadiusButton: CGFloat = 8

    /// Active surface tint alpha (= 0.2, the product subtle accent overlay).
    /// ConnectorProfileRow uses it.
    static let surfaceActiveTintAlpha: CGFloat = 0.2

    /// Inactive border tint alpha (= 0.2, product subtle border). Replaces
    /// file-scope `inactiveStrokeAlpha: CGFloat = 0.2` in ConnectorProfileRow.
    static let surfaceInactiveBorderAlpha: CGFloat = 0.2

    /// Active border width (= 2 PT, the product emphasized border).
    /// ConnectorProfileRow spells the same value as a file-scope constant.
    static let surfaceActiveBorderWidth: CGFloat = 2

    /// Inactive border width (= 1 PT, product choice border). Replaces
    /// file-scope `inactiveStrokeWidth: CGFloat = 1` in ConnectorProfileRow.
    static let surfaceInactiveBorderWidth: CGFloat = 1

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

    /// Tiny bullet size (= 6 PT, the product bullet indicator standard).
    /// Replaces the inline value in 2 sites.
    static let bulletSizeTiny: CGFloat = 6

    /// Small bullet size (= 14 PT, the product inline bullet icon size).
    /// Replaces the inline value in 1 site.
    static let bulletSizeSmall: CGFloat = 14

    /// The compact toolbar button's height (= 40 PT). The empty-state
    /// icon-to-title gap beside it is 22 PT (the product choice).
    static let toolbarButtonCompact: CGFloat = 40

    /// Medium surface size (= 56×56 PT, the product value).
    static let surfaceSizeMedium: CGFloat = 56

    /// List row avatar size (= 64 PT, the product value). Replaces
    /// `.frame(width: DesignTokens.avatarSize)` in 1 site.
    static let avatarSize: CGFloat = 64

    /// Zone editor sidebar width (= 140 PT, the product sidebar zone picker
    /// width). Used in `.frame(height: DesignTokens.zoneEditorWidth)`.
    static let zoneEditorWidth: CGFloat = 140

    /// Sub-progress detail height (= 100 PT, product detail panel min-height
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

    /// Card preview height (= 180 PT, product card preview standard).
    /// Replaces `.frame(height: DesignTokens.cardPreviewHeight)`.
    static let cardPreviewHeight: CGFloat = 180

    /// Popover compact size (= 320x280, the product small popover standard).
    static let popoverCompactSize: CGSize = .init(width: 320, height: 280)

    /// List row banner size (= 240x32, the product inline banner standard).
    static let bannerInlineSize: CGSize = .init(width: 240, height: 32)

    /// Square cover thumbnail (= 192×192 PT, the product value).
    static let coverThumbnailSize: CGFloat = 192

    /// Settings sheet size (= 600x480, the product settings window standard).
    static let settingViewSheetSize: CGSize = .init(width: 600, height: 480)

    /// Settings import/export sheet size (= 600x400, product import/export
    /// window standard). Replaces `.frame(width: 600, height: 400)`.
    static let settingIOsheetSize: CGSize = .init(width: 600, height: 400)

    /// Guardrail sheet width (= 360 PT, the product modal sheet width).
    static let guardrailSheetWidth: CGFloat = 360

    /// Sidebar width (= 200 PT, product narrow sidebar standard). Replaces
    /// `.frame(width: DesignTokens.sidebarNarrowWidth)`.
    static let sidebarNarrowWidth: CGFloat = 200

    // MARK: - full-project dual-axis audit

    /// The chat input bar's height (= 80 PT): the height that keeps the
    /// agent's message visible above it.
    static let chatInputBarHeight: CGFloat = 80

    /// Large control height (= 36 PT). The old comment cited "the Apple HIG
    /// macOS control standard"; no 36 PT figure exists in the HIG and the
    /// system's own large bordered control measures 28 PT (= audit C3/X12).
    /// The value stays as the product's stable composer height; controls must
    /// take density from `.controlSize(.large)`, not from a frame on this
    /// token (audit K2/X13).
    static let controlHeightLarge: CGFloat = 36

    /// Pages-style picker card row height (= 32 PT). The product source is
    /// the Pages inspector panel, and the row is aligned with it.
    static let pickerCardHeight: CGFloat = 32

    /// Picker card internal horizontal padding (= 12 PT). The product source is
    /// the Pages step 1 wizard, and the card follows the Pages-style picker cards.
    static let pickerCardPaddingH: CGFloat = 12

    /// Sheet width for inline rename dialogs (= 360 PT, the product macOS
    /// sheet width). The sheet is a NavigationStack+Form, which read as
    /// iOS-shaped chrome on macOS 27.
    static let controlSheetWidthRename: CGFloat = 360

    /// Onboarding welcome window size (= 640×720 PT, the product onboarding
    /// panel size). The onboarding runs through library creation.
    static let onboardingWindowSize: CGSize = .init(width: 640, height: 720)
}
