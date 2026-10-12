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
        // 2026-10-12 boss directive "你去看一下聊天区的底栏
        // 的写法. 照抄就行了, 那是已经实现过的逻辑"
        // — copy `ChatInputBarView.tokenCountFooter` 1:1 (= the
        // chat token-count footer has been visually verified to
        // land flush against the bottom of the chat column with
        // no visible gap). The chat footer is:
        //
        //   VStack(spacing: 0) {
        //     Divider()
        //     HStack(spacing: <tight>) {
        //       Text(...).font(.callout).foregroundStyle(...)
        //     }
        //     .frame(maxWidth: .infinity, alignment: .leading)
        //     .padding(.vertical, DesignTokens.spacingStandard = 8)
        //     .padding(.horizontal, DesignTokens.spacingStandard = 8)
        //   }
        //   .background(.bar)
        //
        // The editor status bar has THREE chunks (word count /
        // cursor location / autosave state) — copy the chat
        // footer's outer VStack shell 1:1 (= Divider + HStack
        // + `.frame(maxWidth: .infinity, alignment: .leading)`
        // + `.padding(.vertical, 8)` + `.padding(.horizontal,
        // 8)` + `.background(.bar)`). Inside the HStack, the
        // three editor-specific chunks use the same SFIcon +
        // Text + .callout + .secondary pattern the chat
        // footer's single Text uses. NO `Spacer(minLength:
        // DesignTokens.spacingStandard)` between the
        // middle/right chunks (= the prior Spacer between the
        // cursor chunk and the autosave chunk was the
        // root-cause of the round-1 status bar feeling
        // "floating": the Spacer introduced a flex
        // `HStack` height equal to its own .spacingStandard
        // hint, and combined with the icon height and the
        // padding the bar's natural height ballooned to
        // ~60-80 PT instead of the chat footer's 38 PT).
        // Drop the Spacer — the chat footer's `.frame(
        // maxWidth: .infinity, alignment: .leading)` already
        // anchors the chunks to the leading edge (= the
        // natural Inspector status row format; = the
        // rightmost chunk sits right after the middle chunk
        // with the same HStack spacing as the leftmost and
        // middle).
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: DesignTokens.spacingCaption) {
                // Word count (= leftmost chunk = canonical
                // Pages / Numbers inspector "0 words" pattern).
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon("text.alignleft", style: .inlineSmall, color: IconColor.secondary)
                    Text(wordCountLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                // Cursor location (= middle chunk = canonical
                // Pages / Numbers "Ln N, Col N" pattern).
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon("text.cursor", style: .inlineSmall, color: IconColor.secondary)
                    Text(cursorLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                // Autosave indicator (= rightmost chunk =
                // Pages / Numbers "Saved" / "Unsaved" /
                // "Saving..." pattern; = no Spacer, just
                // the next item in the HStack with the
                // same spacing).
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon(autosaveIcon, style: .inlineSmall, color: autosaveColor)
                    Text(autosaveLabel)
                        .font(.callout)
                        .foregroundStyle(autosaveColorShapeStyle)
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