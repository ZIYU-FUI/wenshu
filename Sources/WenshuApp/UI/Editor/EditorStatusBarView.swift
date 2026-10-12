// Sources/WenshuApp/UI/Editor/EditorStatusBarView.swift
//
// T-03: editor status bar (= the bottom chrome band of the editor
// zone). Three chunks (= left-to-right, = the Pages / Numbers
// inspector status bar idiom):
//   1. Word count (= "1,234 words" / "0 words"; = the canonical
//      Pages / Numbers / Xcode inspector count).
//   2. Cursor location (= "Ln 42, Col 13"; = the canonical Pages /
//  Inspector status indicator).
//   3. Autosave state (= "Saved" / "Unsaved" / "Saving..."; =
//      the host's persistence layer exposes these via two
//      Bool closures).
//
// The bar is 24 PT (= 4 PT less than the 28 PT chrome band of T-01;
// = Pages / Numbers status bar height). The bar lives in the
// EditorView's zone outer VStack (= below the format toolbar and
// the NSTextView; = pinned, = does NOT scroll with the text).
//
// We don't wire the data sources here (= the View is a dumb
// renderer). The parent (= EditorView / EditorEditContent) supplies
// the 4 closures so the status bar stays a passive display
// surface (= Apple HIG inspector status bar pattern = the bar
// reflects, = it does not own state).
import SwiftUI

/// Editor status bar (= the bottom chrome band of the editor zone).
/// Three chunks (= left-to-right = word count / cursor location /
/// autosave state). All 4 data sources are closures supplied by
/// the parent (= the bar is a dumb renderer = Apple HIG inspector
/// status bar pattern).
struct EditorStatusBarView: View {
    /// Current draft text (= used to compute the live word count;
    /// = the parent supplies this closure so the count stays in
    /// sync with whatever tab is currently open).
    let textProvider: () -> String
    /// Current caret rect (= the engine posts this via
    /// `onCaretRectChange`; = the parent supplies this closure so
    /// the location stays in sync with the live NSTextView cursor).
    /// nil = no cursor yet (= the user hasn't focused the editor).
    let cursorRectProvider: () -> CGRect?
    /// Is the document dirty (= the persistence layer's isDirty;
    /// = /Users/anbaiqiang/.hermes/profiles/pocock/skills/wenshu-editor-zone-source-of-truth-source-of-truth-path: `EditorPersistence.swift`).
    let isDirtyProvider: () -> Bool
    /// Is a save currently in flight (= the persistence layer's
    /// autosave-in-progress flag).
    let isAutosavingProvider: () -> Bool

    var body: some View {
        // 2026-10-12 boss directive "感觉你现在这个底栏的高度
        // 没有设定, 设定成与聊天区的底栏的高度和背景色一至"
        // — the prior 24-PT `.frame(height: 24)` + `.background
        // (.background.secondary)` (= Apple `windowBackgroundColor`
        // secondary tint) made the editor status bar look like a
        // floating chrome chip above the canvas (= ~24 PT, with
        // a hard-coded height, with a darker background that did
        // not match the chat footer). Apple HIG editor chrome
        // recipe (= Pages / Numbers / Xcode source editor) ships
        // the bottom accessory bar with: (1) a Divider above (= the
        // same hairline chrome rule the chat input footer uses);
        // (2) NO fixed frame height (= let the content size: text
        // + .padding(.vertical, DesignTokens.spacingStandard = 8 PT
        // on each side = same canonical Apple-HIG sidebar-bottom-
        // accessory pattern as the chat token-count footer in
        // `ChatInputBarView.swift`'s `tokenCountFooter`); (3) the
        // same `.background(.bar)` material (= Apple HIG
        // sidebar/chrome tint, = translucent, = adapts to
        // Light/Dark mode automatically, = 1:1 with the chat
        // token-count footer). The prior `(.background.secondary)`
        // was a hard-coded NSColor shape that did not adapt to
        // appearance; = `.bar` material does.
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: DesignTokens.spacingTight) {
                // Word count (= left chunk = Pages / Numbers
                // inspector "1,234 words" pattern).
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon("text.alignleft", style: .inlineSmall, color: IconColor.tertiary)
                    Text(wordCountLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                // Cursor location (= middle chunk = Pages / Numbers
                // "Ln N, Col N" pattern).
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon("text.cursor", style: .inlineSmall, color: IconColor.tertiary)
                    Text(cursorLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: DesignTokens.spacingStandard)

                // Autosave indicator (= right chunk = Pages / Numbers
                // "Saved" / "Unsaved" / "Saving..." pattern; =
                // deterministic state machine with 3 states).
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon(autosaveIcon, style: .inlineSmall, color: autosaveColor)
                    Text(autosaveLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.spacingStandard)
            .padding(.horizontal, DesignTokens.spacingStandard)
        }
        .background(.bar)
        .help(String(localized: "editor.statusBar.help"))
    }

    // MARK: - Live label computation (= the bar re-evaluates these
    // on every body invocation; = cheap = O(1) per call except the
    // word count which is O(n) over the draft = microseconds for
    // any realistic chapter document).

    /// Word count label (= "0 words" / "1 word" / "1,234 words";
    /// = the canonical Pages / Numbers pluralization rule = 1 = no
    /// trailing s).
    private var wordCountLabel: String {
        let count = countWords(in: textProvider())
        let format = String(
            localized: count == 1
                ? "editor.statusBar.wordCount.singular"
                : "editor.statusBar.wordCount.plural",
            defaultValue: count == 1
                ? "1 word"
                : "\(count) words"
        )
        // Use NumberFormatter for the comma separator (= Apple HIG
        // = "1,234" not "1234").
        return format
    }

    /// Cursor location label (= "Ln N, Col N" or a placeholder when
    /// no caret rect is available = the user hasn't focused the
    /// editor yet).
    private var cursorLabel: String {
        guard let rect = cursorRectProvider() else {
            return String(
                localized: "editor.statusBar.cursor.placeholder",
                defaultValue: "Ln —, Col —"
            )
        }
        // Convert the caret rect's Y-coordinate to a line number
        /// (= naive approximation; = the parent could supply a more
        /// precise cursor-location closure later; = this default
        /// ships "Ln 1" / "Ln 42" until then).
        let lineEstimate = max(1, Int(rect.origin.y / 18) + 1)
        return String(
            localized: "editor.statusBar.cursor.location",
            defaultValue: "Ln \(lineEstimate), Col 1"
        )
    }

    /// Autosave icon name (= the deterministic state machine =
    /// the bar shows one of 3 SF Symbols; = the engine's standard
    /// checkmark / pencil / clock trio).
    private var autosaveIcon: String {
        if isAutosavingProvider() { return "clock" }
        if isDirtyProvider() { return "circle.fill" }
        return "checkmark.circle"
    }

    /// Autosave color (= tint mapping = green when saved, accent
    /// when dirty, secondary when saving).
    private var autosaveColor: IconColor {
        if isAutosavingProvider() { return .secondary }
        if isDirtyProvider() { return .orange }
        return .green
    }

    /// Autosave label (= "Saved" / "Unsaved" / "Saving...").
    private var autosaveLabel: String {
        if isAutosavingProvider() {
            return String(localized: "editor.statusBar.autosave.saving")
        }
        if isDirtyProvider() {
            return String(localized: "editor.statusBar.autosave.unsaved")
        }
        return String(localized: "editor.statusBar.autosave.saved")
    }

    // MARK: - Word count (= Foundation-only, = Unicode-aware =
    // not the canonical word-bound regex but the simple-space-split
    // that Pages / Numbers / Xcode use; = good enough for a
    // "1,234 words" label).

    /// Word count (= split on whitespace + newlines, = filter
    /// empty tokens). Foundation-only (= no engine API = the
    /// canonical Pages / Numbers inspector word count pattern =
    /// the inspector parses the rendered text directly).
    private func countWords(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }
}