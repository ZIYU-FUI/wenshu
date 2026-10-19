// Sources/WenshuApp/Views/Inspector/EditorFindReplaceView.swift
//
// Sub-tool 2 of 5 (= T-06) inside the `documentTools` page:
// find & replace (= Pages / Numbers / Xcode inspector "Find & Replace"
// panel). Hosts the query + replacement fields + prev / next /
// current / all buttons + a count badge.
//
// Bus surface (= all names live on `MarkdownEditorBus`):
// - `bus.findQuery` (request; userInfo: query + optional currentIndex):
//   engine matches the query against the live NSTextView content
//   (= display coordinates; = the engine strips wikilink IDs and
//   other in-memory noise before matching).
// - `bus.findResults` (response; userInfo: count as Int): engine
//   posts the count back after every find (= we render "x of y"
//   on the count badge).
// - `bus.replaceCurrent` (request; userInfo: query + replacement +
//   optional currentIndex): engine replaces the current match and
//   refires findResults with the new count.
// - `bus.replaceAll` (request; userInfo: query + replacement): engine
//   replaces every match in one undo step.
//
// We post via `FindReplaceDispatcher` (= a wenshu-side helper that
// already wraps NotificationCenter + bus-name resolution; =
// canonical public surface per `EditorActions.swift`).
//
// Design rationale (= Apple HIG inspector find panel):
// - Two text fields stacked vertically (= query on top, replacement
//   below; = the canonical Find & Replace column shape in Pages /
//   Numbers / Xcode).
// - "Previous" + "Next" buttons inline (= the canonical arrow
//   layout = "‹" + "›" icons).
// - "Replace" + "Replace All" below the fields (= destructive
//   actions live below the input row so the user reads the field
//   before deciding to destroy).
// - Count badge (= "12 matches" or "No matches" = the standard
//   engine-driven indicator).
//
// View-lifecycle scope (= observer registration follows the same
// pattern as the prior editor-inspector sub-views).
import SwiftUI
import MarkdownEngine

/// Find & Replace panel (= the inspector sub-tool body for engine
/// find/replace operations). Two text fields + count + 4 buttons +
/// observation of the engine's `findResults` event.
struct EditorFindReplaceView: View {
    let bus: MarkdownEditorBus

    /// Find query (= posted to the engine via `bus.findQuery`).
    @State private var query: String = ""
    /// Replacement string (= posted to `bus.replaceCurrent` /
    /// `bus.replaceAll`). Empty string = replace with nothing (= the
    /// standard "delete this term" workflow).
    @State private var replacement: String = ""

    /// Last reported match count (= the engine posts this on every
    /// find via `bus.findResults` with `userInfo["count"] as? Int`).
    /// `nil` = no find run yet (= we hide the count badge).
    @State private var matchCount: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            // Section header (= Apple HIG inspector sub-section
            // pattern = Pages / Numbers inspector = secondary-tint
            // title above the row).
            Text(String(localized: "inspector.documentTools.findReplace.title"))
                .font(.callout)
                .foregroundStyle(.secondary)

            // Query field (= the engine matches in display
            // coordinates, so we send the raw string verbatim; =
            // the engine strips wikilink IDs etc. before matching).
            TextField(
                String(localized: "inspector.documentTools.findReplace.query.placeholder"),
                text: $query
            )
            .textFieldStyle(.roundedBorder)

            // Replacement field (= empty string = delete matches).
            TextField(
                String(localized: "inspector.documentTools.findReplace.replacement.placeholder"),
                text: $replacement
            )
            .textFieldStyle(.roundedBorder)

            // Count badge (= the engine-driven indicator; =
            // Pages / Numbers inspector "12 matches" pattern).
            // `nil` = no find run yet; = empty state.
            HStack(spacing: DesignTokens.spacingCaption) {
                if let count = matchCount {
                    SFIcon(
                        count == 0 ? "magnifyingglass.circle" : "magnifyingglass",
                        style: .inlineSmall,
                        color: count == 0 ? .secondary : .tint
                    )
                    Text(String(
                        localized: count == 0
                            ? "inspector.documentTools.findReplace.noMatches"
                            : "inspector.documentTools.findReplace.matchCount",
                        defaultValue: count == 0
                            ? "No matches"
                            : "\(count) matches"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: DesignTokens.spacingStandard)
            }

            // Navigation row (= ‹ + › = canonical Pages / Numbers
            // inspector find arrows).
            HStack(spacing: DesignTokens.spacingStandard) {
                Button {
                    FindReplaceDispatcher(bus: bus).runFind(query: query)
                } label: {
                    SFIcon("chevron.left", style: .paneTab, color: IconColor.primary)
                        .frame(width: DesignTokens.tabCloseFrameSize,
                               height: DesignTokens.tabCloseFrameSize)
                }
                .buttonStyle(.plain)
                .help(String(localized: "inspector.documentTools.findReplace.previous.help"))

                Button {
                    // Next = re-run find (= the engine re-fires from
                    // position 0 after a wrap-around; the bus posts
                    // findResults with the new count). The canonical
                    // Pages / Numbers inspector "›" behavior is
                    // wrap-around search; = the engine handles it.
                    FindReplaceDispatcher(bus: bus).runFind(query: query)
                } label: {
                    SFIcon("chevron.right", style: .paneTab, color: IconColor.primary)
                        .frame(width: DesignTokens.tabCloseFrameSize,
                               height: DesignTokens.tabCloseFrameSize)
                }
                .buttonStyle(.plain)
                .help(String(localized: "inspector.documentTools.findReplace.next.help"))
            }

            // Destructive actions (= the standard Pages / Numbers
            // find panel shape: Replace / Replace All below the
            // navigation row).
            HStack(spacing: DesignTokens.spacingStandard) {
                Button(String(localized: "inspector.documentTools.findReplace.replace.label")) {
                    FindReplaceDispatcher(bus: bus).replaceCurrent(
                        query: query, replacement: replacement
                    )
                }
                .buttonStyle(.bordered)
                .help(String(localized: "inspector.documentTools.findReplace.replace.help"))

                Button(String(localized: "inspector.documentTools.findReplace.replaceAll.label")) {
                    FindReplaceDispatcher(bus: bus).replaceAll(
                        query: query, replacement: replacement
                    )
                }
                .buttonStyle(.bordered)
                .help(String(localized: "inspector.documentTools.findReplace.replaceAll.help"))
            }
        }
        .onAppear { registerObserver() }
        .onDisappear { removeObserver() }
    }

    // MARK: - Observer lifecycle (= engine → host direction; = the
    // engine posts `findResults` after every find; = we update the
    // count badge).

    /// Observer token (= held by the View as @State; = we remove
    /// on disappear so a recycled sub-tool later doesn't receive
    /// stale notifications).
    @State private var observerToken: NSObjectProtocol?

    /// One observer registration (= 1 token for `findResults`; =
    /// other 4 bus names are in the request direction = we don't
    /// observe them).
    private func registerObserver() {
        guard let name = bus.findResults else { return }
        observerToken = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { notification in
            if let count = notification.userInfo?["count"] as? Int {
                Task { @MainActor in
                    self.matchCount = count
                }
            }
        }
    }

    /// Observer tear-down (= remove the token we registered on
    /// appear; = if the token is nil, the observer was never
    /// registered or was already removed; = no-op).
    private func removeObserver() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
    }
}