//
//  FormatToolbarButtons.swift · Wenshu · v0.40 apple-001 Q2 slice 2
//
//  Extracted from WorkspaceView.swift (formerly inline private
//  struct at line 2097). Q2 boss拍 split WorkspaceView; this
//  slice = the lowest-risk, highest-payoff extraction (= the
//  view is fully self-contained = no @State, no @Environment,
//  no @Observable; just @Binding var draft + two file-local
//  helpers wrapSelection / prefixCurrentLine that mutate the
//  binding). Removing it from WorkspaceView = -160 lines from
//  the 2500-line monolith (smallest Apple-canonical file
//  per the AVG ≈ 180 LOC finding in apple-self-check §2 row B).
//
//  Apple HIG = one view per file. FormatToolbarButtons is
//  invoked from WorkspaceView's editor-toolbar HStack as
//  `FormatToolbarButtons(draft: $editorTab.draft)` and is
//  otherwise fully self-contained. Splitting it here does
//  not change behavior (= no caller signature changes).
//

import SwiftUI

struct FormatToolbarButtons: View {
    @Binding var draft: String

    var body: some View {
        // 5 buttons inline (= HStack of PaneTrailingIconButton
        // reuse = consistent visual contract with the rest of the
        // top bar; = Rule 7 system component pattern). Spacing 4 PT
        // between buttons (= tight cluster for inline toolbar; =
        // DesignTokens.chromePaddingMicro).
        HStack(spacing: DesignTokens.chromePaddingMicro) {
            PaneTrailingIconButton(
                icon: "bold",
                tooltip: "加粗 (**)",
                action: { wrapSelection(open: "**", close: "**") }
            )
            PaneTrailingIconButton(
                icon: "italic",
                tooltip: "斜体 (*)",
                action: { wrapSelection(open: "*", close: "*") }
            )
            PaneTrailingIconButton(
                icon: "heading",
                tooltip: "标题 (#)",
                action: { prefixCurrentLine(with: "# ") }
            )
            PaneTrailingIconButton(
                icon: "code",
                tooltip: "行内代码 (`)",
                action: { wrapSelection(open: "`", close: "`") }
            )
            PaneTrailingIconButton(
                icon: "list",
                tooltip: "列表项 (-)",
                action: { prefixCurrentLine(with: "- ") }
            )
        }
    }

    // MARK: - Helpers

    /// v0.34 B-20: wrap the current cursor selection (or insert at
    /// cursor if no selection) with `open` + `close` MD markers.
    /// Selection tracking is approximated (= we don't have access
    /// to the TextEditor's NSRange without NSViewRepresentable),
    /// so this implementation targets the WHOLE draft as the
    /// wrap range (= fallback behavior; = same as Obsidian's
    /// inline format toolbar without explicit selection).
    /// Real selection-aware wrapping is v0.35+ ticket (= needs
    /// NSTextView delegate bridge).
    private func wrapSelection(open: String, close: String) {
        // Fallback: append at end. Real selection = future ticket.
        draft = draft + open + "text" + close
    }

    /// v0.34 B-20: prefix the current line with `prefix`. Fallback
    /// (= no cursor info): append a new line at end with the prefix.
    /// Future ticket: parse draft by lines + insert at cursor line.
    private func prefixCurrentLine(with prefix: String) {
        draft = draft + "\n" + prefix
    }
}

/// P2 #19 (WIRE-PARAGRAPH-002): testable static helper that
/// contains the pure paragraph_ai pipeline (= prompt prefix +
/// connector send + first .text block extraction). Extracted
/// out of `EditorPlaceholder.applyParagraphAI` so the test
/// target can exercise the behavior without instantiating the
/// SwiftUI view graph (= no AppState, no BookStore, no file
/// watcher plumbing required).
///
/// Apple-API-first: this helper is a thin orchestration layer
/// over the v0.35 `LLMConnector` protocol (= already wired in
/// `ChatView.startLongRunningGoal` + `WenshuConductor.handle`)
/// and the P1 #10 `EditorTransformTools` actor (= the Swift
/// port of hermes `agent/editing/editor_tools.py`). Zero new
/// types; zero new dependencies.
struct EditorParagraphAI {

    /// Run the paragraph transform pipeline (= build prompt
    /// prefix + call connector + extract first .text block) and
    /// return the rewritten text. Throws on connector failure
    /// (= transport / auth / decode); the caller (= the View)
    /// owns the S4 graceful-degradation wrapper.
    ///
    /// - Parameters:
    ///   - selectedText: the user's selected text (= empty
    ///     short-circuits to "" per the wenshu defensive-defaults
    ///     rule; matches `disabled(selectedText.isEmpty)` on the
    ///     toolbar).
    ///   - transform: which of the 6 `EditorTransform` cases to
    ///     apply.
    ///   - connector: the active `LLMConnector` (= injected for
    ///     testability; production calls
    ///     `WenshuAppDelegate.activeLLMConnector()` (= the
    ///     module-internal bridge added in apple-001 Q1 slice 2 so
    ///     the test target can resolve a connector without mounting
    ///     the full WorkspaceView); tests inject `MockLLMConnector`).
    ///   - options: the per-call `LLMCallOptions` (= model +
    ///     maxTokens).
    /// - Returns: the rewritten paragraph (= the first .text
    ///     block of the connector response; "" if the connector
    ///     returned no text blocks).
    static func apply(
        selectedText: String,
        transform: EditorTransform,
        connector: any LLMConnector,
        options: LLMCallOptions
    ) async throws -> String {
        guard !selectedText.isEmpty else { return "" }
        let tools = EditorTransformTools()
        let prefix = await tools.promptPrefix(for: transform)
        let prompt = "\(prefix)\n\n\(selectedText)"
        let response = try await connector.send(
            messages: [LLMMessage.user(prompt)],
            options: options
        )
        let text = response.blocks.first { block in
            if case .text = block { return true }
            return false
        }.flatMap { block -> String? in
            if case let .text(s) = block { return s }
            return nil
        } ?? ""
        return text
    }
}

/// P2 #19 (WIRE-PARAGRAPH-002): paragraph_ai toolbar. 3 buttons
/// with keyboard shortcuts (= ⌘⇧E expand, ⌘⇧H shorten, ⇧R
/// rephrase) + a Menu for the 3 less-common transforms (= shiftTone,
/// simplify, dramatize).
///
/// Sits next to the mode toggle in the editor top-bar (= the same
/// HStack the mode toggle lives in; = one row, Apple HIG
/// single-row toolbar pattern). Each button uses `.help(...)` for
/// the native NSWindow tooltip (= per the wenshu-apple-api-first
/// hard rule) and `.keyboardShortcut(...)` for the global key
/// binding (= Apple SwiftUI native; = no third-party shortcut
/// lib required).
///
/// Disabled rules (= matches the boss spec's
/// `disabled(vm.selectedText.isEmpty)` line):
/// - `selectedText.isEmpty`: nothing to transform.
/// - `isApplying`: an LLM call is already in flight (= prevent
///   double-fire; = Apple HIG actionable-control-while-busy).
///
/// Icon system: SF Symbols for the 3 primary buttons (= Apple
/// built-in icon font; = boss 2026-08-27 OOB carve-out for system
/// symbols). Lucide icons for the dropdown menu (= consistent
/// with the rest of the editor zone's chrome). The mix matches
/// the v0.34 FormatToolbarButtons precedent (= it uses Lucide
/// for the inline format buttons but SF Symbol-equivalents are
/// acceptable for the paragraph_ai row since the boss spec
/// calls them out as `Image(systemName:)` in the wire-up
/// snippet).
///
/// Performance: the toolbar is a pure View; no @State. The
/// selection snapshot + busy flag come in via parameters (= host
/// owns the truth; = Apple HIG parent-owns-data pattern).
