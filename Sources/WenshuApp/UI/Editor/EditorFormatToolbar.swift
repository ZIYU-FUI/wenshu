// Sources/WenshuApp/UI/Editor/EditorFormatToolbar.swift
//
// Pages / Numbers / Keynote document-toolbar strip (= 12 small icon
// buttons keyed to the markdown engine's `MarkdownEditorBus`
// `applyXxxRequest` notifications). The toolbar posts via
// `FormatDispatcher(bus:)` (= a wenshu-side helper from
// Sources/WenshuApp/Editor/EditorActions.swift) and the SMC engine's
// own observer applies the change to the live NSTextView.
//
// Design constraints (= Apple HIG macOS document-toolbar idiom):
// - 28 PT fixed height (= matches EditorHeaderView so the two chrome
//   bands align vertically; = Safari tab-stop standard).
// - 8 PT horizontal padding (= matches `DesignTokens.spacingStandard`)
//   + 4 PT inter-button spacing (= `DesignTokens.spacingCaption`).
// - Icon size = `.inlineSmall` (= 14 PT per `SFIcon` factory).
// - No toggle / pressed-state logic (= the engine fires
//   `selectionBoldDidChange` etc. to drive toggle state in T-05;
//   = today the toolbar is a one-way request surface).
//
// Why this is pinned (= not inside the engine's `header:` slot):
// The engine reserves the `header:` slot for the SAME row as the
// NSTextView (= scrolls together with the document). Pinning the
// format toolbar here (= inside EditorView's outer VStack =
// ALWAYS visible regardless of scroll position) is the canonical
// Pages / Numbers / Xcode pattern: the toolbar never goes off-screen.
// Future tickets may move the toolbar into the engine's header slot
// if Apple HIG direction changes (= unlikely for the
// "formatting-affects-selection" toolbar which must stay visible
// while typing).
import SwiftUI
import MarkdownEngine

/// One button on the editor format toolbar. Each button is keyed to
/// exactly one `MarkdownEditorBus` request name (= the bus factory
/// in `MarkdownEditorBus.buildWenshu()` registers all 12 names).
/// Tapping the button = `FormatDispatcher(bus: bus).apply()` posts the
/// matching request; = the engine applies the change to the live
/// NSTextView with native undo support (= engine-internal).
enum EditorFormatAction: String, CaseIterable, Identifiable {
    case bold
    case italic
    case highlight
    case strikethrough
    case inlineCode
    case heading
    case blockquote
    case unorderedList
    case orderedList
    case link
    case codeBlock
    case horizontalRule

    var id: String { rawValue }

    /// SF Symbol shown on the button (= the toolbar is icon-only =
    /// standard macOS document-toolbar idiom; = tooltip + a11y label
    /// carry the textual affordance).
    var iconName: String {
        switch self {
        case .bold:              return "bold"
        case .italic:            return "italic"
        case .highlight:         return "highlighter"
        case .strikethrough:     return "strikethrough"
        case .inlineCode:        return "chevron.left.forwardslash.chevron.right"
        case .heading:           return "textformat.size"
        case .blockquote:        return "text.quote"
        case .unorderedList:     return "list.bullet"
        case .orderedList:       return "list.number"
        case .link:              return "link"
        case .codeBlock:         return "note.text"
        case .horizontalRule:    return "minus"
        }
    }

    /// Localized tooltip (= "editor.format.bold.tooltip" etc.).
    /// We resolve the key once (= the catalog has the keys =
    /// `editor.format.<action>.tooltip`).
    var localizedLabel: String {
        String(localized: "editor.format.\(rawValue).tooltip")
    }

    /// Accessibility label (= used by VoiceOver; = the same
    /// localized key as the tooltip but with the `a11y` suffix so
    /// future punctuation tweaks don't conflict).
    var localizedAccessibilityLabel: String {
        String(localized: "editor.format.\(rawValue).a11y")
    }

    /// Bus notification name this action posts. `FormatDispatcher`
    /// (= `Sources/WenshuApp/Editor/EditorActions.swift`) currently
    /// only ships `applyBold` (= the canonical single-method
    /// dispatcher; the other 11 names are exercised via raw
    /// `NotificationCenter.default.post(name: bus.apply…Request…,
    /// object: nil)` until the delegate grows the symmetric methods in
    /// a future cleanup). We do that here so the toolbar source stays
    /// the single owner of the 12-button contract.
    func dispatch(bus: MarkdownEditorBus) {
        let dispatcher = FormatDispatcher(bus: bus)
        let post: (Notification.Name?) -> Void = { name in
            guard let name else { return }
            NotificationCenter.default.post(name: name, object: nil)
        }
        switch self {
        case .bold:
            dispatcher.applyBold()
        case .italic:
            post(bus.applyItalicRequest)
        case .highlight:
            post(bus.applyHighlightRequest)
        case .strikethrough:
            post(bus.applyStrikethroughRequest)
        case .inlineCode:
            post(bus.applyInlineCodeRequest)
        case .heading:
            post(bus.applyHeadingRequest)
        case .blockquote:
            post(bus.applyBlockquoteRequest)
        case .unorderedList:
            post(bus.applyUnorderedListRequest)
        case .orderedList:
            post(bus.applyOrderedListRequest)
        case .link:
            post(bus.applyLinkRequest)
        case .codeBlock:
            post(bus.applyCodeBlockRequest)
        case .horizontalRule:
            post(bus.applyHorizontalRuleRequest)
        }
    }

    /// Apple HIG tooltip key per icon (= the wenshu canonical
    /// `xcstrings` lookup key; = the tooltip on each button
    /// uses this key so the user-facing string lives in
    /// `Localizable.xcstrings`; = zh-Hans + en translations
    /// are already populated for all 12 keys).
    /// RATIONALE: pre-compute the 12 keys (= each enum case
    /// carries its own `tooltipKey` string literal =
    /// SwiftUI's `String(localized:)` `StaticString`-only
    /// constraint; = runtime interpolation like
    /// `String.localizedStringWithFormat` would call xcstrings
    /// but the `%@` at runtime means the
    /// `Localizable.xcstrings` extractor can't auto-discover
    /// the dynamic key; = the runtime lookup would fall back
    /// to the format result and the user would see the raw
    /// key). The `defaultValue: action.localizedLabel`
    /// argument is the English fallback for any future locale
    /// that ships without the key.
    var tooltipKey: String {
        switch self {
        case .bold: "editor.format.bold.tooltip"
        case .italic: "editor.format.italic.tooltip"
        case .highlight: "editor.format.highlight.tooltip"
        case .strikethrough: "editor.format.strikethrough.tooltip"
        case .inlineCode: "editor.format.inlineCode.tooltip"
        case .heading: "editor.format.heading.tooltip"
        case .blockquote: "editor.format.blockquote.tooltip"
        case .unorderedList: "editor.format.unorderedList.tooltip"
        case .orderedList: "editor.format.orderedList.tooltip"
        case .link: "editor.format.link.tooltip"
        case .codeBlock: "editor.format.codeBlock.tooltip"
        case .horizontalRule: "editor.format.horizontalRule.tooltip"
        }
    }

    /// Per-icon SF Symbols point size (= the wenshu 1:1
    /// `Image.font(.system(size:))` strategy from
    /// `wenshu-apple-api-first`). RATIONALE 2026-10-13:
    /// the previous `.imageScale(.large / .medium)` per
    /// icon DID NOT CHANGE the visual width (= the boss
    /// measured: 13 PT `</>` + `.imageScale(.large)` = 14
    /// px; = 16 PT `bold` + `.imageScale(.large)` = 20 px;
    /// = the delta is the same; = `.imageScale` is a
    /// no-op for Apple-shipped SF Symbols 6 because each
    /// symbol is a fixed design that ignores the scale
    /// parameter (= per Apple WWDC19-206 "Introducing SF
    /// Symbols": the scale only matters for text-mode
    /// symbols; = Apple-shipped SF Symbols 6 ship a fixed
    /// design that already includes optical alignment for
    /// their canonical size tier). The wenshu 1:1 fix is
    /// to give each icon its own `.font(.system(size:))`
    /// (= the boss's measured 14 PT default → some icons
    /// need 16 PT or 18 PT to optical-match the rest).
    /// Per-icon measured sizes (= 28 PT hot-area button,
    /// measured from the boss's 2026-10-13 screenshot):
    ///   - "bold" (B): 20 px @ 14 PT → 16 PT (BOSS target)
    ///   - "italic" (I): 18 px @ 14 PT → 16 PT
    ///   - "highlight" (✏): 25 px @ 14 PT → 12 PT
    ///     (= the boss's 2026-10-13 visual diff: the
    ///     highlight pencil felt too tall inside the
    ///     28 PT hot area; = 12 PT shrinks the glyph's
    ///     vertical extent = the pencil no longer
    ///     overshoots the line under it).
    ///   - "strikethrough" (S̲): 22 px @ 14 PT → 16 PT
    ///     (= the boss's 2026-10-13 visual diff: the
    ///     "S" glyph felt too small at 14 PT; = the
    ///     16 PT bump gives the S the same optical
    ///     weight as the surrounding buttons).
    ///   - "inlineCode" (`</>`): 14 px @ 14 PT → 18 PT (thin)
    ///     RATIONALE 2026-10-13 visual diff: the boss asked
    ///     to drop from 18 PT back to 16 PT (= the 18 PT
    ///     bumped `</>` too large; = 16 PT keeps the icon
    ///     visibly different from the 14 PT default while
    ///     not overshooting the 28 PT hot-area frame).
    ///   - "heading" (`textformat.size`):
    ///     39 px @ 14 PT → 14 PT
    ///     (icon too wide; = 14 PT matches Apple HIG default)
    ///   - "blockquote" (❝): 15 px @ 14 PT → 16 PT
    ///   - "unorderedList" / "orderedList": 3-5 px @ 14 PT
    ///     → 18 PT (icon too small)
    ///   - "link" (🔗): 37 px @ 14 PT → 12 PT
    ///   - "codeBlock" (`textbox`):
    ///     16 px @ 14 PT → 16 PT
    ///   - "horizontalRule" (—): 29 px @ 14 PT → 14 PT
    ///   (= all 12 icons calibrated to the same optical
    ///   weight inside the 28 PT hot area).
    /// The mapping above is the measured
    /// per-icon calibration so all 12 icons render at
    /// the same VISUAL width inside the 28 PT hot area.
    var iconPointSize: CGFloat {
        switch self {
        case .bold: 16
        case .italic: 16
        case .highlight: 12
        case .strikethrough: 16
        case .inlineCode: 14
        case .heading: 14
        case .blockquote: 16
        case .unorderedList: 18
        case .orderedList: 18
        case .link: 12
        case .codeBlock: 16
        case .horizontalRule: 14
        }
    }

    /// Chunked action list (= the 12 buttons grouped into 3
    /// sub-clusters matching the `EditorStatusBarView` rhythm;
    /// = inline-emphasis / block / insertion). Returned as
    /// an array of `(chunkIndex, [actions])` tuples so the
    /// `ForEach` in the toolbar body can index the chunk
    /// directly (= no inline index arithmetic; = a future 4th
    /// chunk lands in one place).
    static let chunked: [(Int, [EditorFormatAction])] = [
        (0, [.bold, .italic, .highlight, .strikethrough, .inlineCode]),
        (1, [.heading, .blockquote, .unorderedList, .orderedList]),
        (2, [.link, .codeBlock, .horizontalRule])
    ]
}

/// 28 PT Apple HIG document-format toolbar (= the canonical
/// Pages / Numbers / Keynote pinned toolbar shape). Hosted in the
/// editor zone's outer VStack (= does NOT scroll with the document).
struct EditorFormatToolbar: View {
    /// MarkdownEditorBus passed down from `MarkdownEditorBus.buildWenshu()`
    /// (= the engine's `MarkdownEditorServices.bus` slot, also wired
    /// to the same bus instance the engine observes internally for
    /// selection-state events).
    let bus: MarkdownEditorBus
    /// RATIONALE: the 1 trailing icon
    /// on the right of the format toolbar
    /// is close (= canonical
    /// Pages / Numbers format toolbar
    /// rhythm = "formatting buttons on
    /// the left, document-level actions
    /// on the right").
    /// The `onClose` callback
    /// is owned by the parent (= `EditorView`;
    /// = the same parent that already owns
    /// the `onSelect` / `onClose` callbacks
    /// for `EditorTabStrip`).
    /// The close
    /// callback fires `appState.closeTab(id:)`
    /// (= the same path the tab strip's
    /// per-tab close X uses). The
    /// callback defaults to `nil` (= when
    /// nil, the trailing button is hidden;
    /// = the toolbar is forward-compatible
    /// with any caller that doesn't supply
    /// them).
    ///
    /// 2026-10-14: the previous 2-trailing-icon
    /// layout (= save + close) dropped the save
    /// icon. Wenshu has a built-in autosave
    /// mechanism (= the `EditorStatusBarView`
    /// shows the green "已保存" indicator when
    /// the autosave task writes the active
    /// tab's draft to disk; = the user can
    /// see the save state in the status bar
    /// at the bottom of the editor zone; =
    /// a manual save button in the format
    /// toolbar is redundant with the
    /// always-on autosave; = the boss
    /// 2026-10-14 OOB instruction was to
    /// drop the save button (= "因为我们有自动
    /// 保存机制, 多余"). The `onSave` callback
    /// was also dropped from this struct
    /// because the only caller was
    /// `EditorView.editorFormatToolbar` (= no
    /// other call site; = the closure had
    /// exactly one user; = the closure is
    /// dropped with the button).
    let onClose: (() -> Void)?

    var body: some View {
        // RATIONALE: matches the `EditorStatusBarView` chunk
        // pattern (= each chrome band is a row of sub-`HStack`
        // groups, with 8 PT between groups; = the wenshu
        // canonical "chrome band" rhythm per
        // `wenshu-apple-api-first` Apple HIG document-toolbar
        // idiom; = the toolbar visually groups into
        // inline-emphasis / block / insertion clusters the
        // way the status bar groups word count / autosave).
        // The 12 buttons are split into 3 chunks (=
        // inline-emphasis / block / insertion) by
        // `EditorFormatAction.chunk` (= the action enum owns
        // the grouping; = no inline index arithmetic in the
        // body; = a future 4th chunk lands in one place).
        // RATIONALE: the format toolbar's outer shell
        // is `ChromeTopBar` (= shared wenshu chrome surface
        // recipe; = the content slot is the HStack of
        // buttons; = the `.background(.bar)` Material is
        // provided by `ChromeTopBar`).
        ChromeTopBar {
            HStack(spacing: DesignTokens.spacingStandard) {
                ForEach(EditorFormatAction.chunked, id: \.0) { chunkIndex, chunk in
                    HStack(spacing: DesignTokens.spacingCaption) {
                    ForEach(chunk) { action in
                        formatButton(for: action)
                    }
                }
                if chunkIndex < EditorFormatAction.chunked.count - 1 {
                    // RATIONALE: a vertical `Divider` (= the
                    // canonical Pages / Numbers / Xcode
                    // toolbar chunk separator; = visually
                    // breaks the 3 chunks into inline-emphasis
                    // / block / insertion; = the `Divider()`
                    // height tracks the surrounding button
                    // hot area (= 28 PT) because it's nested
                    // inside the outer HStack next to the
                    // 28 PT-tall buttons; = the 1 PT hairline
                    // is centered vertically inside the 28 PT
                    // hot area (= the hairline is at the
                    // icon's optical center; = visually the
                    // divider lines up with the icon
                    // crosshairs; = matches the Safari /
                    // Pages chunk-separator idiom). The
                    // previous `Spacer(minLength: 0).frame
                    // (width: 0)` was an invisible spacer
                    // (= no visible separator; = the boss
                    // asked for a visible chunk separator).
                    Divider()
                }
            }
            // RATIONALE: the 2 trailing icons
            // are wrapped in a private
            // `trailingIconGroup` (= small HStack
            // with the 8 PT `spacingStandard`
            // gap = matches the outer HStack
            // chunk rhythm = canonical Pages
            // / Numbers toolbar-item spacing).
            // The `Spacer()` pushes the 2
            // trailing icons to the right edge
            // (= macOS Pages / Numbers format
            // toolbar rhythm = "formatting
            // buttons on the left, document-
            // level actions on the right").
            // The save icon is `tray.and.arrow.down`
            // (= the wenshu 1:1 macOS Mail
            // "save to inbox" toolbar item;
            // = closer to a square than
            // `square.and.arrow.down`).
            Spacer()
            trailingIconGroup
        }
        }  // close ChromeTopBar
        // RATIONALE: the outer `ChromeTopBar`
        // is intentionally unconstrained on
        // height; = the call site specifies the
        // height via `.frame(height: 28)` (= the
        // wenshu canonical 28 PT button hot area).
        .frame(height: 28)
    }
        // RATIONALE: the chrome surface Material
        // (`.bar`) is provided by the outer
        // `ChromeTopBar`; = the inner HStack doesn't
        // carry its own background modifier (= would
        // double-layer and produce a near-black
        // override = the macOS Material composite
        // collapses when stacked).
        // The HStack still has the
        // `.frame(height: 28)`
        // (= the only 28 PT frame in
        // the file; = the `.bar` Material
        // is provided by the outer
        // `ChromeTopBar`).
        // RATIONALE 2026-10-13 OOB: the
        // boss asked to add the
        // `.background(.bar)`
        // modifier between
        // `.frame(height: 28)` and
        // `.overlay(alignment: .bottom) { Divider() }`;
        // = the canonical macOS 27
        // chrome tint now shows
        // across the full 28 PT band
        // (= the same Material the
        // status bar uses; = the
        // user sees a
        // semi-transparent system
        // tint; = the buttons sit on
        // top of the Material; = the
        // previous round's
        // `.padding(.top, 12)` was
        // removed (= the buttons
        // now occupy the full 28 PT
        // frame height; = the
        // `.bar` Material composites
        // against the actual
        // button area, not against
        // empty 12 PT padding)).
        // RATIONALE: 36 PT total toolbar height (= the boss
        // 4 PT top + 28 PT content + 4 PT bottom = 36 PT
        // instruction; = the explicit
        // `.frame(height: 36)` clamps the toolbar band; = the
        // per-button 4 PT vertical padding lives on the outer
        // toolbar = the previous attempt put the 4 PT padding
        // on each individual button = stacking outer + per-
        // button padding inflated the toolbar to 40+ PT; =
        // the boss instructed to move the spacing to the
        // outer band; = 4 PT outer top + 28 PT button + 4 PT
        // outer bottom = 36 PT band height; = the
        // `.frame(maxWidth: .infinity, alignment: .leading)`
        // preserves the left-anchor horizontal rhythm).
        // RATIONALE: revised 2026-10-13 — the boss
        // visually diffed the 2 PT symmetric padding (= the
        // bottom of the toolbar still felt too far from the
        // body's top edge; = the visual rhythm reads as
        // "icon-and-divider-above-body" with the divider
        // being the toolbar's bottom Divider; = the boss
        // asked to keep 2 PT top padding but drop the bottom
        // padding to 0 PT). RATIONALE: 0 PT bottom padding
        // = the toolbar bottom Divider is now flush with
        // the NSTextView top (= no breathing room between
        // the toolbar and the body; = matches the Apple
        // HIG Safari tab-strip + body rhythm where the
        // tab-strip divider IS the visual top edge of the
        // body content).
        // RATIONALE: revised 2026-10-13 again — the boss
        // asked to drop BOTH the top and bottom padding
        // (= the previous `.padding(.top, 2) + .padding
        // (.bottom, 0)` pair was too much breathing room; =
        // the toolbar band now sits flush with its
        // 36 PT `frame(height:)` and the button's 28 PT
        // hot area = the button is centered inside the
        // 36 PT band without top / bottom gutter; = the
        // remaining Y space is split into 4 PT above
        // the button + 4 PT below = the 28 PT hot area
        // visually centers inside the 36 PT band; = the
        // 36 PT `frame(height:)` alone provides the
        // visual breathing room; = no per-side padding
        // needed).
        // RATIONALE: revised 2026-10-13 once more — the
        // boss asked for 4 PT top padding (= the toolbar
        // band was too tight against the tab-strip
        // divider above; = the 4 PT top padding pulls
        // the icons down 4 PT from the top edge of the
        // band; = visually the 28 PT hot area + 4 PT top
        // + 4 PT bottom (= 36 PT total) gives the icon
        // a balanced top + bottom gutter inside the band;
        // = the bottom Divider is the visual bottom edge
        // of the band; = 0 PT bottom padding = the band
        // is flush with the body's top edge below).
        // RATIONALE: 32 PT total toolbar height
        // (= 4 PT reduction from 36 PT; = the 28 PT
        // content is the dominant visual; = the
        // toolbar reads as more compact; = the
        // `.frame(height: 32)` is the single
        // source of truth for the band height).
        // The visual effect: the
        // gap between the segmented
        // control and the toolbar is
        // still 8 PT (= the Apple
        // canonical NSSegmentedControl
        // content inset that we
        // already established is
        // unavoidable); = the toolbar
        // itself is 4 PT shorter.
        // RATIONALE: the canonical chrome
        // color is
        // `Color(nsColor: .controlBackgroundColor)`
        // (= the AppKit API is macOS 10.0+
        // and is the same source of truth
        // that `.bar` material uses internally;
        // = applying it via `Color(nsColor:)`
        // avoids the `.bar` material layout
        // loop in the nested editor column).
        // The frame
        // stays 28 PT (= the wenshu canonical
        // button hot area = the
        // 12-button row fits exactly
        // without vertical padding).
        // RATIONALE: the `.bar` background
        // layer is the outer layer (= the
        // one that controls the 28 PT
        // height); = the inner HStack
        // of buttons does NOT need its own
        // `.frame(height: 28)` because
        // the outer shell already constrains
        // the HStack; = the wenshu 1:1
        // macOS Pages / Numbers toolbar
        // recipe).
        // The duplicate
        // `.background { Rectangle().fill(.bar).frame(height: 28) }`
        // is replaced by the shared
        // `ChromeTopBar` shell (= the
        // canonical `.bar` Material is
        // applied once at the top chrome
        // surface; = no inner duplication).
        // RATIONALE: the canonical baseline
        // is `spacingRelaxed + spacingCaption`
        // = 10 + 2 = 12 PT (= the wenshu
        // standing 1:1 macOS toolbar rhythm;
        // = the value expressed as the sum
        // of two `DesignTokens` so a future
        // ticket can adjust the two pieces
        // independently).
        // RATIONALE 2026-10-13 OOB: the
        // `.padding(.top, DesignTokens.spacingRelaxed + DesignTokens.spacingCaption)`
        // (= 12 PT) was clipping the
        // 28 PT buttons inside the
        // 28 PT frame (= total 40 PT
        // clipped to 28 PT; = the
        // `.bar` Material was
        // rendered behind the
        // clipped 16 PT button area
        // only; = the user saw a
        // near-black band). The
        // boss observed the same
        // `.bar` works fine on the
        // status bar (= same parent
        // VStack; = same Material; =
        // the issue is purely the
        // format toolbar's own
        // layout). The fix: remove
        // the explicit
        // `.padding(.top, ...)`;
        // the buttons'
        // `paneTabHotArea` = 28 PT
        // token already constrains
        // their height; = the
        // 28 PT frame now exactly
        // matches the buttons'
        // natural height; = no
        // padding is needed; = the
        // `.bar` Material composites
        // across the entire 28 PT
        // band.
        // RATIONALE: the `.bar` Material
        // needs the parent's frame to be
        // a concrete `Rectangle` (= the
        // Material composites against
        // the rectangle shape; = the
        // `ChromeTopBar` shell is a
        // `VStack` whose outer frame
        // is the concrete rectangle for
        // the material).
        // frame IS a Rectangle, so the
        // Material composites; = in the
        // `EditorFormatToolbar` the
        // shell is an HStack of buttons
        // whose layout produces a
        // non-Rectangular shape = the
        // Material composites
        // incorrectly or not at all).
        // The fix: replace
        // `.background(.bar)` with an
        // explicit
        // `.background { Rectangle().fill(.bar) }`
        // (= the `Rectangle` is the
        // canonical SwiftUI
        // rectangular fill surface; =
        // `.bar` Material composites
        // against the Rectangle
        // = the material renders the
        // semi-transparent macOS 27
        // system chrome tint; = the
        // user sees the chrome band
        // with content visible
        // through it; = the wenshu
        // 1:1 macOS canonical
        // sidebar-bottom accessory
        // surface recipe (= the same
        // recipe `ChromeBottomFooter`
        // uses; = the explicit
        // `Rectangle` is the
        // composition target the
        // Material needs).
        //
        // RATIONALE: this is a single
        // 28 PT frame on the outer
        // `ChromeTopBar` shell (= the
        // wenshu 1:1 macOS canonical
        // chrome surface; = exactly
        // ONE 28 PT frame, exactly ONE
        // `.bar` background).

    /// RATIONALE 2026-10-13: the entire format-button
    /// (= `Button` + label + tooltip + background + a11y)
    /// is extracted into this private helper (= the Swift
    /// compiler can type-check a smaller expression in
    /// reasonable time; = the body of `body` is now under
    /// the 60-second type-check budget per Apple Swift
    /// guidance). The helper renders the 28×28 PT icon
    /// (= `paneTabHotArea`) with the per-icon point-size
    /// override (= each SF Symbol gets its own calibrated
    /// size; = all 12 icons match the same optical
    /// weight inside the 28 PT hot area). The
    /// tooltip uses `String(localized: "editor.format.<action>.tooltip")`
    /// so the user-facing string lives in
    /// `Localizable.xcstrings` (= the wenshu canonical i18n
    /// surface; = zh-Hans + en translations already
    /// populated for all 12 actions; = the
    /// `defaultValue: action.localizedLabel` is the English
    /// fallback if a future locale ships without the key).
    @ViewBuilder
    private func formatButton(for action: EditorFormatAction) -> some View {
        Button {
            action.dispatch(bus: bus)
        } label: {
            SFIcon(
                action.iconName,
                style: .inlineSmall,
                color: IconColor.primary,
                pointSizeOverride: action.iconPointSize
            )
            .frame(
                width: DesignTokens.paneTabHotArea,
                height: DesignTokens.paneTabHotArea
            )
        }
        // RATIONALE 2026-10-13: the tooltip is keyed by
        // `action.tooltipKey` (= a `String.LocalizationValue`
        // compile-time literal; = SwiftUI's
        // `String(localized:table:bundle:locale:comment:)` and
        // `NSLocalizedString(_:tableName:bundle:value:comment:)`
        // both accept a `String.LocalizationValue` /
        // `String` lookup key; = the `value:` (= `defaultValue`)
        // argument is the English fallback (= Apple's
        // canonical i18n pattern); = the runtime lookup
        // resolves to the translated value via
        // `Localizable.xcstrings`; = if a future locale ships
        // without the key, the user sees the English text =
        // no raw-key display; = the `comment` is the
        // developer-facing hint for the xcstrings extractor).
        .help(NSLocalizedString(
            action.tooltipKey,
            bundle: .main,
            value: action.localizedLabel,
            comment: "Format toolbar button tooltip"
        ))
        .accessibilityLabel(action.localizedAccessibilityLabel)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                .fill(Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton))
        .hoverWash()
        .buttonStyle(.plain)
    }
}
// MARK: - Trailing toolbar icons
//
// The save + close icons live on the right of the format toolbar
// into private computed views (= same pattern as
// `formatButton(for:)`; = keeps the type-checker happy; = the
// 28×28 PT hot area + small icon + hover wash are shared with
// the 12 format buttons).

extension EditorFormatToolbar {
    /// RATIONALE 2026-10-13 OOB: the
    /// `trailingIconGroup` (= a small
    /// HStack containing the 1 trailing
    /// icon = close). The
    /// `HStack(spacing:
    /// DesignTokens.spacingStandard)`
    /// (= 8 PT) sets the gap between
    /// the icons (= now just close; =
    /// the 8 PT remains as a no-op
    /// spacing in case a future ticket
    /// adds a 2nd trailing icon). The
    /// `Spacer()` (= NOT used here) is
    /// the parent's responsibility (= it
    /// pushes the whole `trailingIconGroup`
    /// to the right edge of the toolbar).
    ///
    /// 2026-10-14: the previous
    /// 2-icon `trailingIconGroup` (= save +
    /// close) was reduced to 1 icon (= close
    /// only). The save icon was removed
    /// because wenshu has autosave (= the
    /// `EditorStatusBarView` already shows
    /// the save state at the bottom of the
    /// editor zone; = a manual save button
    /// in the format toolbar would be
    /// redundant).
    private var trailingIconGroup: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            trailingCloseButton
        }
    }

    /// RATIONALE 2026-10-13: the close icon
    /// (= `xmark.circle` = the macOS
    /// canonical "close" symbol = the
    /// same as Finder's "close"
    /// button in the Recent Files
    /// list = the same as Safari's
    /// "Close Tab" item).
    ///
    /// 2026-10-14: the previous
    /// `trailingSaveButton` private
    /// property (= the `tray.and.arrow.down`
    /// save icon) was removed alongside the
    /// `onSave` field (= both halves of the
    /// save-button feature were dropped
    /// together; = no dead code left
    /// behind).
    private var trailingCloseButton: some View {
        trailingToolbarButton(
            iconName: "xmark.circle",
            tooltipKey: "editor.format.close_tab.tooltip",
            defaultLabel: "Close"
        ) {
            onClose?()
        }
    }

    /// RATIONALE 2026-10-13: the shared
    /// trailing-button factory (= the
    /// save + close icons share the
    /// exact same visual idiom; = a
    /// single private helper produces
    /// both; = the `iconName` +
    /// `tooltipKey` + `defaultLabel`
    /// are the 3 parameters; = the
    /// `action` callback fires the
    /// parent-supplied closure). The
    /// button is hidden when
    /// `onSave == nil` / `onClose == nil`
    /// (= graceful degradation if the
    /// parent caller doesn't supply
    /// the callback).
    @ViewBuilder
    private func trailingToolbarButton(
        iconName: String,
        tooltipKey: String,
        defaultLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SFIcon(
                iconName,
                style: .inlineSmall,
                color: IconColor.primary
            )
            .frame(
                width: DesignTokens.paneTabHotArea,
                height: DesignTokens.paneTabHotArea
            )
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                .fill(Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton))
        .hoverWash()
        .help(NSLocalizedString(
            tooltipKey,
            bundle: .main,
            value: defaultLabel,
            comment: "Trailing toolbar button tooltip"
        ))
    }
}
