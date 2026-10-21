// Sources/WenshuApp/DesignTokens.swift
// … (= 19 rationale lines collapsed; = A112 docblock collapse per §1.8)
// - divider 1 PT in 5 inline places (= no constant)
import SwiftUI

// MARK: - DesignTokens namespace
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / numbers (= ComponentIndex.md Level 1.1).
@MainActor
enum DesignTokens {
    // MARK: - Chrome dimensions
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / TabContentDispatcher.aiChat (= no separate wrapper).
    static let chromeHeight: CGFloat = 30

    /// Height of `ChromeBottomFooter` (= the 1 PT divider + the
    /// content's own padding + the content's intrinsic height).
    ///
    /// MEASURED, not estimated: rendered the footer offscreen and read
    /// its fitting height = 32 PT (= 1 divider + 8 + 8 padding + 15
    /// content).
    ///
    /// A zone that hosts this footer has to reserve this much space for
    /// it. SwiftUI's `.safeAreaInset(edge: .bottom)` adds the footer's
    /// height to the RECEIVER's bottom safe area, but it does not
    /// shrink the inner scroll view's own frame — the content can still
    /// scroll to the very bottom of the column, which is UNDER the
    /// footer. The chat zone solves this with
    /// `.contentMargins(.bottom, DesignTokens.chatInputBarHeight, for:
    /// .scrollContent)`, and the preview grids with
    /// `.contentMargins(.bottom, 33, for: .scrollContent)`. The editor's
    /// scroll view is the engine's own `NSScrollView` (= not a SwiftUI
    /// `ScrollView`), so it takes the same reserve as a padding on the
    /// engine view instead.
    static let chromeBottomFooterHeight: CGFloat = 32

    // / Apple HIG sidebar list-row height (= 22 PT). Distinct from
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / row surface. They are different.
    static let sidebarRowHeight: CGFloat = 22

    // / Apple Tahoe sidebar row icon tile size (= 24 PT). The wenshu bans naked
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / chrome = it should be visibly smaller than the row's tappable target).
    static let sidebarIconTileSize: CGFloat = 24

    // / Apple Tahoe sidebar row icon tile corner radius (= 6 PT = ~25% of the 24
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / sidebar icon tile through this token.
    static let sidebarIconTileCornerRadius: CGFloat = 6

    // / Apple Tahoe sidebar row icon tile inner padding (= 4 PT = the gap
    // … (= 17 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / through this token.
    static let sidebarIconTilePadding: CGFloat = 4

    // / ZONE-INSET-002 (2026-09-07): canonical zone-content inset (= 8 PT on all
    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / a semantic name'; = the semantic name is '.small' = 8 PT).
    static let zoneContentInset: CGFloat = 8

    // MARK: - Spacing (= Apple HIG canonical, 8 PT baseline grid)
    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / autocomplete + layout picker hotkey badges).
    static let spacingHairline: CGFloat = 1

    // / Apple HIG caption2 metadata separator gap (= 2 PT). The canonical
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / row gap.
    static let spacingCaption: CGFloat = 2

    // / Apple HIG icon-to-label gap (= 4 PT). The canonical tight inset inside
    // … (= 19 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ChapterFocusLockBadge row gap, SectionHeader internal gap.
    static let spacingIconic: CGFloat = 4

    // / Relaxed stack spacing (= 10 PT, Apple HIG `.relaxed` stack-spacing
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / bullet-to-bullet).
    static let spacingRelaxed: CGFloat = 10

    // / Apple HIG tight inter-row gap (= 6 PT). The canonical tight padding used
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / gap, EmptyStateView row gap.
    static let spacingTight: CGFloat = 6

    // / Apple HIG standard spacing (= 8 PT). The Touch Bar default (=
    // … (= 23 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / row gap.
    static let spacingStandard: CGFloat = 8

    // / Apple HIG moderate spacing (= 12 PT). The canonical bordered-content-row
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / PlaceholderView / BookSettingConstraints) row gap.
    static let spacingModerate: CGFloat = 12

    // / Apple HIG loose spacing (= 16 PT). The Touch Bar small fixed space (=
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / gap.
    static let spacingLoose: CGFloat = 16

    // / Apple HIG hero / window content margin (= 20 PT). The canonical macOS
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / sidebar sheets / ZoneEditor / PreviewPane sheet body).
    static let spacingHero: CGFloat = 20

    // / Apple HIG section white-space maximum (= 24 PT). The Touch Bar large
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / EmptyStateView icon-to-text gap.
    static let spacingSection: CGFloat = 24

    // MARK: - Tab metrics
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / naming, now generic for ALL pane tabs).
    static let paneTabHotArea: CGFloat = 28

    // / Tab close button (= X) hit area (= 18×18 PT). Apple HIG inline-control
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / artifacts (= Safari/Chrome/Terminal convention).
    static let tabCloseFrameSize: CGFloat = 18

    // / Per-pane tab close-X icon point size (= 8 PT; = Apple HIG "small" tier
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / boss's calibrated visual preference for the close affordance).
    static let tabCloseIconPointSize: CGFloat = 8

    // / Per-pane tab selected-state underline height (= 1 PT, Apple HIG standard
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / sides, per (see OOB.md #2026-08-30) OOB ', ').
    static let tabUnderlineHeight: CGFloat = 1

    // MARK: - Dividers
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / bar bottom divider + splitter).
    static let dividerHeight: CGFloat = 1

    // MARK: - Status bar text
    // / Apple HIG foreground four-tier ladder mapped to writing surfaces.
    // The body text across the editor (NativeTextViewWrapper / NSTextView
    // labelColor = .label) AND the chat (SwiftUI Text.font(.body))
    // reads `.primary` = the same SwiftUI semantic token. Apple HIG
    // forbids `.primary.opacity(0.X)` for dimming: dimming is the
    // job of the four-tier semantic ladder, not opacity tweaks.
    //   .primary   = writing body (= Pages / Notes body).
    //   .secondary = bubble chrome (= timestamps, captions, footers).
    //   .tertiary  = tertiary metadata (= IDs, hashes, badges).
    //   .quaternary = disabled / placeholder text.
    // Body (writing) text never uses .secondary / .tertiary /
    // .quaternary — those tiers are reserved for chrome around the
    // body, not for the body itself.
    static let textBody: HierarchicalShapeStyle = .primary
    static let textChrome: HierarchicalShapeStyle = .secondary
    static let textMetadata: HierarchicalShapeStyle = .tertiary
    static let textPlaceholder: HierarchicalShapeStyle = .quaternary
    // / Apple HIG text-style scale (macOS 27). Pinning editor +
    // / chrome around body to the same Apple scale stops the
    // / chat zone from drifting to ad-hoc `Font.system(size:)` calls.
    static let bodyFontSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
    static let captionFontSize: CGFloat = NSFont.preferredFont(forTextStyle: .caption1).pointSize
    static let caption2FontSize: CGFloat = NSFont.preferredFont(forTextStyle: .caption2).pointSize
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Replaces `.foregroundStyle(.tertiary)` in 16 files.
    static let statusForeground: HierarchicalShapeStyle = .tertiary

    // / The chat transcript layer should use the left sidebar's color
    // … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // so light/dark mode follow the user's appearance setting.
    static let sidebarBackground: Color = {
        // Match macOS sidebar RGB exactly (= the same RGB the
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // - Light: RGB(245,245,245) (= matches sidebar material)
        let dynamic = NSColor(name: "wenshu.sidebar.bg") { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 36.0/255.0, green: 36.0/255.0, blue: 36.0/255.0, alpha: 1.0)
            } else {
                return NSColor(red: 245.0/255.0, green: 245.0/255.0, blue: 245.0/255.0, alpha: 1.0)
            }
        }
        return Color(nsColor: dynamic)
    }()

    // MARK: - Surface metrics (Apple HIG)
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / readability).
    static let accentTintOpacitySubtle: Double = 0.12

    // / Accent tint opacity at 18% (= Apple HIG Liquid Glass hero-card gradient
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / dominant.
    static let accentTintOpacityHero: Double = 0.18

    // / Window chrome shadow vertical offset (= 4 PT, Apple HIG macOS window
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / LayoutEditBar pattern).
    static let surfaceShadowOffsetWindow: CGFloat = 4

    // / Canvas drag gesture minimum distance (= 5 PT, wenshu canvas-specific
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / within the zone grid layout.
    static let dragGestureThresholdCanvas: CGFloat = 5

    // / Chat bubble max-width (= 360 PT, Apple HIG macOS chat panel standard =
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Messages app reference width).
    static let chatBubbleMaxWidth: CGFloat = 360

    // / Inline metadata panel max-width (= 320 PT, Apple HIG compact inset panel
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ReaderExperienceView + GenreFitView report metadata side-panels.
    static let metadataPanelMaxWidth: CGFloat = 320

    // / Attachment thumbnail max-width/height (= 240 PT, Apple HIG inline
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / chat attachment preview component.
    static let attachmentPreviewMaxSize: CGFloat = 240

    // / Plan list max-width (= 420 PT, Apple HIG inline structured list panel
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Used in `.frame(maxWidth: 420)` for ChatPlanPartView.
    static let planListMaxWidth: CGFloat = 420

    // / Onboarding welcome max-width (= 480 PT, Apple HIG macOS first-run
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / width).
    static let onboardingWelcomeMaxWidth: CGFloat = 480

    // / TextEditor small min-height (= 80 PT, Apple HIG macOS single-paragraph
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 140)` for small TextEditor (= 2-paragraph display max).
    static let textEditorSmallMinHeight: CGFloat = 80

    // / TextEditor small max-height (= 140 PT, Apple HIG macOS single-paragraph
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 80) for small TextEditor.
    static let textEditorSmallMaxHeight: CGFloat = 140

    // / TextEditor medium min-height (= 100 PT, Apple HIG macOS 2-3 paragraph
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 160)` for medium TextEditor (= 3-paragraph display max).
    static let textEditorMediumMinHeight: CGFloat = 100

    // / TextEditor medium max-height (= 160 PT, Apple HIG macOS 2-3 paragraph
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 100) for medium TextEditor.
    static let textEditorMediumMaxHeight: CGFloat = 160

    // / TextEditor compact max-height (= 120 PT, Apple HIG macOS
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `textEditorSmallMinHeight` (= 80) for compact TextEditor.
    static let textEditorCompactMaxHeight: CGFloat = 120

    // / Preset thumbnail aspect ratio (= 4:3, Apple HIG classic photo / preview
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / layout picker thumbnail.
    static let presetThumbnailAspectRatio: CGFloat = 4.0 / 3.0

    // / Specialized panel medium max-height (= 180 PT, Apple HIG macOS list
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / BookSettingConstraintsView + CharacterLifecycleView + IdeaLibraryView).
    static let panelMediumMaxHeight: CGFloat = 180

    // / Specialized panel large max-height (= 220 PT, Apple HIG macOS list panel
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / PlaceholderView + CharacterRelationshipsView).
    static let panelLargeMaxHeight: CGFloat = 220

    // / Inline panel max-height (= 100 PT, Apple HIG macOS compact inline list
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / IdeaLibraryView inline panel.
    static let panelInlineMaxHeight: CGFloat = 100

    // / Command palette max-height (= 320 PT, Apple HIG macOS command palette
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Used in `.frame(maxHeight: 320)` for CommandPaletteView.
    static let commandPaletteMaxHeight: CGFloat = 320

    /// Kanban board max-height (= 360 PT, Apple HIG macOS kanban board standard
    /// = 5-row display). Used in `.frame(maxHeight: 360)` for KanbanView.
    static let kanbanBoardMaxHeight: CGFloat = 360

    // / Button shadow vertical offset (= 2 PT, Apple HIG macOS button shadow
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / pattern).
    static let surfaceShadowOffsetButton: CGFloat = 2

    // / Card surface corner radius (= 8 PT, Apple HIG rounded card standard).
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / style = `.continuous` (Apple HIG 13+ corner style).
    static let surfaceCornerRadiusCard: CGFloat = 8

    // / Chat bubble horizontal padding (= 12 PT; = the iMessage-style bubble
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / now so future picker redesign is 1-stop.
    static let layoutPickerWidth: CGFloat = 416

    // / Badge surface corner radius (= 8 PT, Apple HIG capsule-style badge
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / before H2 fix). `.continuous` round style for macOS 27+ smooth corners.
    static let surfaceCornerRadiusSmallChip: CGFloat = 3

    // / List row leading icon column width (= 18 PT, Apple HIG sidebar list row
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / pins the leading SF Symbol).
    static let listRowLeadingIconColumnWidth: CGFloat = 18

    // / Plan step number column width (= 22 PT, Apple HIG list row trailing
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ChatPlanPartView step number trailing align column.
    static let stepNumberColumnWidth: CGFloat = 22

    // / Attachment thumbnail size (= 48×48 PT, Apple HIG inline attachment
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / thumbnail (= the user-attached image preview chip in chat input bar).
    static let attachmentThumbnailSize: CGFloat = 48

    // / Bullet dot size (= 3×3 PT, Apple HIG inline bullet indicator). Apple HIG
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / unread dot next to a message timestamp).
    static let bulletDotSize: CGFloat = 3

    // / Window chrome corner radius (= 10 PT, Apple HIG macOS window chrome
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / inspector bottom card).
    static let surfaceCornerRadiusWindow: CGFloat = 10

    // / Hero card corner radius (= 12 PT, Apple HIG hero card standard). Apple
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / sheets (= the new-book + new-shelf sheet hero icon background card).
    static let surfaceCornerRadiusHeroCard: CGFloat = 12

    // / Small button corner radius (= 5 PT, Apple HIG control standard). Apple
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / background.
    static let surfaceCornerRadiusSmallButton: CGFloat = 5

    // / Window shadow radius (= 12 PT, Apple HIG macOS window chrome shadow
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / grid).
    static let surfaceShadowRadiusWindow: CGFloat = 12

    // / Liquid Glass separator thickness (= 0.5 PT, Apple HIG macOS 26+ hairline
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / hairlines.
    static let separatorThicknessHairline: CGFloat = 0.5

    // / Emphasis border thickness (= 2 PT, Apple HIG selected/active border
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / in the picker grid).
    static let separatorThicknessEmphasis: CGFloat = 2

    // / Button shadow radius (= 8 PT, Apple HIG button drop-shadow standard).
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the canvas is a 2-D surface inside the editor, not a floating window).
    static let surfaceShadowRadiusButton: CGFloat = 8

    // / Settings row label column width (= 80 PT, Apple HIG settings row label
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `rowLabelWidth: CGFloat = 80` in MemorySettingsView.
    static let settingsRowLabelWidth: CGFloat = 80

    // / Active surface tint alpha (= 0.2, Apple HIG subtle accent overlay).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ConnectorProfileRow.
    static let surfaceActiveTintAlpha: CGFloat = 0.2

    /// Inactive border tint alpha (= 0.2, Apple HIG subtle border). Replaces
    /// file-scope `inactiveStrokeAlpha: CGFloat = 0.2` in ConnectorProfileRow.
    static let surfaceInactiveBorderAlpha: CGFloat = 0.2

    // / Active border width (= 2 PT, Apple HIG emphasized border for
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / = 2` in ConnectorProfileRow.
    static let surfaceActiveBorderWidth: CGFloat = 2

    /// Inactive border width (= 1 PT, Apple HIG standard border). Replaces
    /// file-scope `inactiveStrokeWidth: CGFloat = 1` in ConnectorProfileRow.
    static let surfaceInactiveBorderWidth: CGFloat = 1

    // / Badge interior vertical padding (= 2 PT, Apple HIG tight badge standard;
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Replaces inline `.padding(.vertical, 2)` in ConnectorProfileRow.
    static let badgePaddingVertical: CGFloat = 2

    // apple-001 Q8 batch 1 site: max height for the Memory +
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // (the 2 Settings panes that previously hard-coded the value).
    static let settingsListMaxHeight: CGFloat = 200

    // apple-001 Q8 batch 2 site: font size for the runtime CWD
    // … (= 32 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // SubAgentProgressView.
    static let surfaceCornerRadiusProgressCard: CGFloat = 6

    // apple-001 iron-rule-6 batch 2 site: tab title font
    // … (= 22 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / height: DesignTokens.indicatorSizeSmall)` in 1 site.
    static let indicatorSizeSmall: CGFloat = 8

    // / Tiny bullet size (= 6 PT, Apple HIG bullet indicator standard). Replaces
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / DesignTokens.bulletSizeTiny)` in 2 sites.
    static let bulletSizeTiny: CGFloat = 6

    // / Small bullet size (= 14 PT, Apple HIG inline bullet icon size). Replaces
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / DesignTokens.bulletSizeSmall)` in 1 site.
    static let bulletSizeSmall: CGFloat = 14

    // / Empty-state icon→title gap (= 22 PT, Apple HIG standard
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / height: DesignTokens.toolbarButtonCompact)` in 2 sites.
    static let toolbarButtonCompact: CGFloat = 40

    // / Medium surface size (= 56×56 PT). Apple HIG canonical value (= macOS
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / DesignTokens.surfaceSizeMedium)` in 2 sites.
    static let surfaceSizeMedium: CGFloat = 56

    // / List row avatar size (= 64 PT). Apple HIG canonical value (= macOS
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Replaces `.frame(width: DesignTokens.avatarSize)` in 1 site.
    static let avatarSize: CGFloat = 64

    // / Zone editor sidebar width (= 140 PT, Apple HIG sidebar zone picker
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `.frame(height: DesignTokens.zoneEditorWidth)`.
    static let zoneEditorWidth: CGFloat = 140

    /// Sub-progress detail height (= 100 PT, Apple HIG detail panel min-height
    /// standard). Replaces `.frame(height: DesignTokens.panelMinHeight)`.
    static let panelMinHeight: CGFloat = 100

    /// Card preview height (= 180 PT, Apple HIG card preview standard).
    /// Replaces `.frame(height: DesignTokens.cardPreviewHeight)`.
    static let cardPreviewHeight: CGFloat = 180

    // / Popover compact size (= 320x280, Apple HIG small popover standard).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / DesignTokens.popoverCompactSize.height)`.
    static let popoverCompactSize: CGSize = CGSize(width: 320, height: 280)

    // / List row banner size (= 240x32, Apple HIG inline banner standard).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / DesignTokens.bannerInlineSize.height)`.
    static let bannerInlineSize: CGSize = CGSize(width: 240, height: 32)

    // / Square cover thumbnail (= 192×192 PT). Apple HIG canonical value (=
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / DesignTokens.coverThumbnailSize)` in 1 site.
    static let coverThumbnailSize: CGFloat = 192

    // / Settings sheet size (= 600x480, Apple HIG settings window standard).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / DesignTokens.settingViewSheetSize.height)`.
    static let settingViewSheetSize: CGSize = CGSize(width: 600, height: 480)

    /// Settings import/export sheet size (= 600x400, Apple HIG import/export
    /// window standard). Replaces `.frame(width: 600, height: 400)`.
    static let settingIOsheetSize: CGSize = CGSize(width: 600, height: 400)

    // / Guardrail sheet width (= 360 PT, Apple HIG modal sheet width for
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / DesignTokens.guardrailSheetWidth)`.
    static let guardrailSheetWidth: CGFloat = 360

    /// Sidebar width (= 200 PT, Apple HIG narrow sidebar standard). Replaces
    /// `.frame(width: DesignTokens.sidebarNarrowWidth)`.
    static let sidebarNarrowWidth: CGFloat = 200

    // MARK: - full-project dual-axis audit
    // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / message visible above the chat input bar).
    static let chatInputBarHeight: CGFloat = 80

    // / Large control height (= 36 PT, Apple HIG macOS control standard for
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / chat input to a stable height even when the user types longer text).
    static let controlHeightLarge: CGFloat = 36

    // / Pages-style picker card row height (= 32 PT). Apple HIG source: `Design
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / aligned with the Pages inspector panel).
    static let pickerCardHeight: CGFloat = 32

    // / Picker card internal horizontal padding (= 12 PT). Apple HIG source:
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / step 1 wizard (= the Pages- style picker cards).
    static let pickerCardPaddingH: CGFloat = 12

    // / Sheet width for inline rename dialogs (= 360 PT, Apple HIG macOS
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / NavigationStack+Form sheet that read as iOS-shaped chrome on macOS 27).
    static let controlSheetWidthRename: CGFloat = 360

    // / Onboarding welcome window size (= 640×720 PT, Apple HIG onboarding panel
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / through library creation / onboarding).
    static let onboardingWindowSize: CGSize = CGSize(width: 640, height: 720)

}
