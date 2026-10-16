//
//  EditorViewEditHelpers.swift
//
//  3 editor view edit helpers extracted from EditorView.swift
//  (= §6.6 god-class split + discoverability: replaceSelectedText
//  + handleEditorWikiLink + saveDraft moved out of the main file
//  into this dedicated cross-file `extension EditorView` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `struct EditorView: View` is 1017 LOC = 1.7x the 600-LOC cap. The
//  3 edit helpers are a single concern (= "small text-edit operations
//  on the editor's text view"). Putting them in a dedicated file
//  named after the concern (= EditorViewEditHelpers.swift) lets the
//  next reader find the edit logic by name.
//
//  The 3 funcs are instance methods on `EditorView` (as a cross-file
//  extension). The `private func` was relaxed to `func` (= internal
//  scope; = required for the cross-file extension access).
//

import Foundation

extension EditorView {
    // save action writes draft back over originalBody (= dirty detection
    // clears). When documentPath is non-nil (= the ticket 027-35 wires real
    // document load), also write to disk (= atomic UTF-8 = Apple HIG file write
    // pattern). Cmd+S hotkey (canonical surface) and Save toolbar button both
    // call this directly. editor- mvvm T2b: disk IO + dirty state machine
    // migrated to `EditorPersistence`. `saveDraft` is now a 3-line thin call
    // site (= wire originalBody = draft → write to disk → mark clean).
    func saveDraft() {
        guard let tab = activeTab else { return }
        originalBody = draft
        // editor-mvvm T2b: B-22 dirty-transition cleanup = mark the document
        // clean (= cancels any pending auto-save Task via
        // EditorPersistence.handleDirtyTransition(false, ...). Pass `nil` for
        // bookStore (= the save path already ran with the right bookStore = the
        // user just Cmd+S = the doc was either fresh-proposed via Path 2 or had
        // documentPath from a previous save = no need to re-resolve the
        // proposedPath). The tab.documentPath mutation (= the auto-bind from
        // Path 2) only happens inside save(), so any subsequent save call sees
        // the new path.
        EditorPersistence.save(tab: tab, bookStore: bookStore)
        EditorPersistence.handleDirtyTransition(false, tab: tab, bookStore: bookStore)
    }


    /// handle a wiki-link click from the live editor surface (= the engine
    /// fires onLinkClick with the resolved link id, NOT the display name).
    /// Resolve the id back to the display name via the active
    /// WikiLinkResolver's name(forID:) and route through the preview-mode
    /// navigation flow.
    func handleEditorWikiLink(linkId: String) {
        guard !linkId.isEmpty else { return }
        let resolver = ReferenceLibraryWikiLinkResolver(
            referenceLibraryRoot: bookStore.stores.referenceLibraryRoot
        )
        let displayName = resolver.name(forID: linkId) ?? linkId
        handlePreviewWikiLink(displayName: displayName)
    }


    /// P2 #19: replace the current selection (= today: whole draft) with the
    /// supplied text. Once the engine selection bridge lands, this becomes a
    /// surgical NSRange replace (= same signature; only the body changes).
    func replaceSelectedText(with newText: String) {
        // Fallback behavior (= mirrors FormatToolbarButtons in when the
        // TextEditor selection isn't observable, wrap/overwrite the whole
        // draft). Future ticket narrows to selected NSRange once the engine
        // exposes an NSTextViewDelegate bridge.
        draft = newText
        // Reset the selection snapshot so the toolbar buttons disable until the
        // user re- selects (= prevents the "press shortcut twice" footgun where
        // the same LLM response replaces itself).
        selectedText = ""
    }


}
