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
        // RATIONALE: the editor status
        // bar uses the shared
        // `ChromeBottomFooter` shell (= the
        // same shell the chat token-count
        // footer uses; = the wenshu 1:1
        // macOS sidebar-bottom-accessory
        // chrome surface; = the two
        // call sites converge on the
        // same canonical bottom chrome).
        // `Sources/WenshuApp/UI/Chrome/ChromeBottomFooter.swift`
        // component = VStack { Divider + content + .frame(
        // maxWidth: .infinity, alignment: .leading) + .padding(
        // .vertical, 8) + .padding(.horizontal, 8) } +
        // .background(.bar)). The editor status bar is the
        // 3-chunk Inspector status row shape (= word count /
        // cursor location / autosave state) = canonical
        // Pages / Numbers / Xcode inspector single-line
        // status row. NO `Spacer(minLength: ...)` between
        // chunks (= the Spacer inflated the HStack's natural
        // height because SwiftUI reserves the Spacer's
        // minLength as the HStack's flex baseline; = the
        // bar was 60-80 PT tall instead of the canonical
        // 38 PT). All three chunks are 1:1 with the chat
        // footer's `HStack { SFIcon + Text }` shape.
        ChromeBottomFooter(help: "editor.statusBar.help") {
            // RATIONALE: only 2 chunks (= word count + autosave);
            // = the cursor location chunk was dropped per the
            // boss visual diff 2026-10-13 (= the "Ln N, Col N"
            // pattern is a Pages / Xcode convention for
            // developers; = wenshu users don't read the line /
            // column coordinate; = removing the chunk frees up
            // horizontal real estate for the autosave indicator
            // (= the only chunk that has a state transition the
            // user cares about)).
            HStack(spacing: DesignTokens.spacingCaption) {
                // Word count chunk (= left side = the canonical
                // Pages / Numbers inspector
                // "X words" / "X characters" pattern;
                // = the unit switches per locale).
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon("text.alignleft", style: .inlineSmall, color: IconColor.secondary)
                    Text(wordCountLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                // Autosave indicator (= right side = the
                // canonical Pages / Numbers / Xcode "save state
                // on the right" inspector status bar convention).
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon(autosaveIcon, style: .inlineSmall, color: autosaveColor)
                    Text(autosaveLabel)
                        .font(.callout)
                        .foregroundStyle(autosaveColorShapeStyle)
                }
            }
        }
    }

    // MARK: - Live label computation (= the bar re-evaluates these
    // on every body invocation; = cheap = O(1) per call except the
    // word count which is O(n) over the draft = microseconds for
    // any realistic chapter document).

    /// Word count label (= "256 words" /
    /// "1 word" / "1 character" etc).
    /// RATIONALE: the number is the only part that
    /// changes per render (= the unit "words"
    /// is constant
    /// per locale); = the unit is hardcoded in Swift (= the
    /// previous `String(localized: "word.unit.plural")` approach
    /// rendered the unit twice in zh-Hans — once from the
    /// xcstrings value, once from the defaultValue; = the
    /// hardcoded `+ " "` + literal unit gives a single, reliable
    /// render). The number is `count.formatted(.number)` (= the
    /// Apple HIG `1,234` comma-separator format).
    private var wordCountLabel: String {
        let count = countWords(in: textProvider())
        let formatted = count.formatted(.number)
        // Hardcoded unit string per locale (= no xcstrings token;
        // = the literal lives in code so a missing localization
        // entry never duplicates the unit).
        return "\(formatted) 字"
    }

    /// Cursor location label — NOT USED 2026-10-13. RATIONALE:
    /// the "Ln N, Col N" cursor coordinate is a Pages / Xcode
    /// developer convention; = wenshu users don't read the line
    /// / column coordinate; = the chunk was removed from the
    /// status bar body (see body RATIONALE above). The
    /// `cursorRectProvider` closure is still in the API (= a
    /// future ticket may re-introduce the chunk in a different
    /// form); = the closure is preserved (= removing it would
    /// be a breaking change to the public initializer; = the
    /// closure just isn't consumed in the current body). The
    /// helper below is kept (= it computes the same string the
    /// status bar used to render; = a future caller can pull it
    /// without re-deriving the line-estimate math).
    private var cursorLabel: String {
        guard let rect = cursorRectProvider() else {
            return String(
                localized: "editor.statusBar.cursor.placeholder",
                defaultValue: "Ln —, Col —"
            )
        }
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

    /// Same as `autosaveColor` but as a SwiftUI `Color` (= for
    /// `.foregroundStyle(...)` which requires `ShapeStyle`
    /// conformance; = `IconColor` does not conform to
    /// `ShapeStyle` so we map the icon's color to a plain
    /// `Color` for the text foreground).
    private var autosaveColorShapeStyle: Color {
        if isAutosavingProvider() { return .secondary }
        if isDirtyProvider() { return .orange }
        return .secondary
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