// Sources/WenshuApp/Views/Inspector/EditorDocumentToolsView.swift
//
// Inspector-page host (= the 5th InspectorPage: `.documentTools`).
// Aggregates 4 sub-tools that all read or write the engine's
// `MarkdownEditorBus` (= the same bus the engine observes internally
// for selection-state events + format / replace requests + the spell-
// check toggle surface).
//
// Sub-tools (= 5 = the canonical Apple HIG document-inspector
// surface for Pages / Numbers / Keynote):
//   1. Selection-state readout (= bold / italic / highlight toggle
//      states, derived from `selectionBoldDidChange` etc.).
//   2. Find & replace (= query field + count + prev / next / current /
//      all, derived from `findQuery` + `findResults` + `replaceCurrent`
//      + `replaceAll`).
//   3. Heading outline (= parsed H1..H6 outline + jump-to-line, =
//      derived from the engine's view-of-text via a private
//      dispatch).
//   4. Code-block list (= `CodeBlockSelection` list + per-block
//      `CodeBlockButton` copy, derived from `onCodeBlockSelectionChange`).
//   5. Spell-check toggles (= continuous / grammar / autoCorrect, =
//      derived from `SpellCheckingPolicy` + onSpellCheckingPolicyChanged).
//
// Wiring (= T-06..09) ships each sub-tool as its own sub-view (= the
// shell here owns the page + the zone-title divider; = each sub-tool
// is a sibling in the inner VStack). Sub-tools own their own state
// + their own bus listener registrations (= this shell stays a
// pure routing surface; = no @State, no @Observable, no business
// logic).
//
// Why this shell exists separately from InspectorView's switch in
// `toolsForCurrentPage` (= same split shape as the 4 authoring pages):
// the page lists 5 sibling entries (= each tuple: label + icon +
// content); = the shell hosts the per-tab navigation itself (= the
// `ZoneContentView` parent only handles the tab strip + a single
// `content` slot per entry; = we mirror that shape). When T-06..09
// ship their sub-views, the switch entry's `content` becomes an
// `EditorDocumentToolsView` (= pages-with-sub-tabs); = the inner
// per-tool navigation lives inside this shell, not in the parent's
// switch.
import SwiftUI
import MarkdownEngine

/// Page host (= the Inspector page's body when `.documentTools` is
/// selected). 4 sub-tools stacked vertically (= Apple HIG inspector
/// sidebar = no horizontal scrolling between sub-tools; = the user
/// tabs through them = 1 sub-tool visible at a time = the standard
/// inspector-idiom).
struct EditorDocumentToolsView: View {
    /// Document the inspector currently reads from. We bind to the
    /// active tab via `WorkspaceUIState.activeDocumentKey` so the
    /// sub-tools can re-read the current document text (= no static
    /// snapshot). T-06..09 read this binding to drive their views.
    ///
    /// Default nil (= no document open = empty page hint).
    let activeDocumentText: () -> String?

    /// The engine's `MarkdownEditorBus` (= shared with the engine's
    /// own observer; = sub-tools post via the same instance so the
    /// engine-internal coordinator picks up the requests). T-04 ships
    /// a fresh bus per view-body invocation (= the bus is a
    /// single-screen object; = no instance data; = rebuild cost =
    /// trivial).
    let bus: MarkdownEditorBus

    var body: some View {
        // Sub-tool selector (= a 4-entry segmented pill at the top
        // of the page; = Apple HIG Inspector sidebar idiom = Pages /
        // Numbers / Xcode inspector pane uses the same shape). Sub-tools
        // own their own @State (= `currentlySelectedSubTool`
        // persists across the page lifecycle; = T-06..09 each read
        // the value to render their own panel).
        //
        // Why a dedicated sub-tool picker (= not just stacking 5
        // panels): the inspector column is a fixed-width sidebar; =
        // 4 stacked panels blow up vertically. Pages / Numbers /
        // Keynote inspector UX = the column hosts ONE panel + a
        // picker to swap between sub-tools (= matches the inspector
        // column's natural rhythm).
        EditorDocumentToolsSubToolPicker(
            // T-06..09 each append a sub-tool enum case; = the
            // picker source contract is `EditorDocumentToolsSubTool.allCases`.
            selected: .constant(.findReplace),
            bus: bus,
            activeDocumentText: activeDocumentText
        )
    }
}

/// Sub-tool selector (= the inner picker that drives which of the
/// 5 engine-affordance surfaces is visible at any time). Wires the
/// 4 sub-tool entry points (= T-06..09 each ship a real View body;
/// = today they're placeholders that print "tool name — wired in
/// T-XX" so the user can see the contract surface = no silent
/// regression when a future ticket forgets to wire a sub-tool).
///
/// Real sub-tool hosting lives in `EditorDocumentToolsSubToolPicker`
/// body (= one switch on the selected case; = the picker source
/// contract is one View body per case). When T-06..09 ship they
/// replace the placeholder body of their case.
private struct EditorDocumentToolsSubToolPicker: View {
    /// Selected sub-tool (= bound to a parent @State so the picker
    /// survives editor mount / re-render). Today `.constant` —
    /// when T-04's body lands the picker source contract, the
    /// InspectorView parent promotes this to a real @State.
    @Binding var selected: EditorDocumentToolsSubTool

    /// Bus passed down (= see `EditorDocumentToolsView.bus`).
    let bus: MarkdownEditorBus

    /// Document text closure (= T-06..09 each invoke to read the
    /// current draft text).
    let activeDocumentText: () -> String?

    var body: some View {
        // Sub-tool pill picker (= Apple HIG inspector column segmented
        // pill idiom). The 4 sub-tools are listed in canonical
        // Pages / Numbers order (= format / find / outline / code /
        // spell). T-04 ships a placeholder body per sub-tool.
        //
        // Each sub-tool lives behind a switch case (= adding a new
        // sub-tool = adding 1 enum case + 1 switch case + 1
        // Section header = no other site in the codebase is touched).
        VStack(spacing: DesignTokens.spacingSection) {
            // Picker (= 4 segments, one per sub-tool). Apple HIG
            // Pages / Numbers inspector = iOS-style segmented control
            // rendered as a pill of 4 icon buttons. icon-only by
            // default (= tooltips + a11y labels carry the text).
            Picker("", selection: $selected) {
                ForEach(EditorDocumentToolsSubTool.allCases) { subTool in
                    Label {
                        Text(subTool.localizedTitle)
                    } icon: {
                        SFIcon(subTool.icon, style: .inlineSmall, color: IconColor.tint)
                    }
                    .tag(subTool)
                }
            }
            .pickerStyle(.segmented)
            .help(String(localized: "inspector.documentTools.picker.help"))

            // Body (= one of the 4 sub-tool views). T-06..09
            // replace the body of their case without touching the
            // picker source.
            switch selected {
            case .findReplace:
                // T-06: real body shipped. Two text fields + count
                // + 4 buttons + observer of bus.findResults.
                EditorFindReplaceView(bus: bus)
            case .headingOutline:
                // T-07: real body shipped. Pure-parser outline (= no
                // engine API; = host re-parses `^#{1,6}\s` rows from
                // the current draft). Tap-to-scroll deferred (= future
                // ticket wires via a parent callback).
                EditorHeadingOutlineView(activeDocumentText: activeDocumentText)
            case .codeBlocks:
                // T-08: real body shipped. Pure-parser code-block
                // list (= parses ```/~~~ fences from the current
                // draft). Tap-to-scroll deferred (= future ticket).
                EditorCodeBlocksView(activeDocumentText: activeDocumentText)
            case .spellToggles:
                // T-09: real body shipped. 3-toggle inspector row
                // (= continuous / grammar / autocorrect). Reflects
                // the engine's `SpellCheckingPolicy`; = mutating
                // happens in the editor's context menu (= Apple HIG
                // system Settings pattern).
                EditorSpellTogglesView(bus: bus, initialPolicy: .default)
            }
        }
    }
}

/// One sub-tool inside the `documentTools` page (= 4 cases).
enum EditorDocumentToolsSubTool: String, CaseIterable, Identifiable {
    case findReplace
    case headingOutline
    case codeBlocks
    case spellToggles

    var id: String { rawValue }

    /// Localized picker label (= the human-readable name).
    var localizedTitle: String {
        switch self {
        case .findReplace:      return String(localized: "inspector.documentTools.findReplace.title")
        case .headingOutline:    return String(localized: "inspector.documentTools.headingOutline.title")
        case .codeBlocks:        return String(localized: "inspector.documentTools.codeBlocks.title")
        case .spellToggles:      return String(localized: "inspector.documentTools.spellToggles.title")
        }
    }

    /// SF Symbol on the picker segment (= icon-only = matches Apple
    /// HIG Pages / Numbers inspector pill).
    var icon: String {
        switch self {
        case .findReplace:      return "magnifyingglass"
        case .headingOutline:    return "list.bullet.indent"
        case .codeBlocks:        return "chevron.left.forwardslash.chevron.right"
        case .spellToggles:      return "textformat.abc.dottedunderline"
        }
    }
}

/// Placeholder body (= T-04 ships empty placeholders so the page
/// structure is wired end-to-end before any sub-tool lands). Each
/// placeholder names the upcoming ticket (= so future agents know
/// exactly where to land the body when the ticket fires).
///
/// `wiredIn` is shown as a `help()` on the title (= a 1-line audit
/// trail = which ticket fills this body; = disappears once a real
/// body lands in T-06..09).
private struct EditorDocumentToolsPlaceholder: View {
    /// Localized title key (= rendered as the placeholder header).
    let titleKey: String
    /// Localized body key (= rendered as the placeholder description).
    let bodyKey: String
    /// Upcoming ticket name (= shown as `.help()` audit trail so
    /// future agents know where the real body lands).
    let wiredIn: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            Text(LocalizedStringKey(titleKey))
                .font(.body)
                .foregroundStyle(.secondary)
                .help("wired in \(wiredIn)")
            Text(LocalizedStringKey(bodyKey))
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}