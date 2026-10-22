// Sources/WenshuApp/Views/Workspace/EditorView.swift Editor placeholder shown when no
// … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
// behavior change).
import SwiftUI
import WenshuAgent
import os
import MarkdownEngine

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "editorview")

struct EditorView: View {
    // Mode enum lifted to module scope (= EditorMode, in AppState.swift; = so
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / matches Safari behavior).
    private var mode: EditorMode {
        appState.openTabs.first(where: { $0.id == appState.activeTabId })?.mode ?? .preview
    }
    // / derive the display title for a tab (= file basename without the .md
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / render the short placeholder name).
    @Environment(AppState.self) private var appState
    // EditorCounters (= the editor-zone live counter).
    @Environment(EditorCounters.self) private var editorCounters
    // WenshuEditorServicesFactory.make needs referenceLibraryRoot + active book
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // the WindowGroup root in App.swift + LibraryRootView, per fix pattern).
    @Environment(BookStore.self) var bookStore
    // chapter-focus-lock 2026-09-28: editor flips to read-only when the user
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // to WorkspaceUIState in 2026-10-03 overabstraction cleanup).
    @Environment(WorkspaceUIState.self) private var workspaceUI

    // P2 #19 (WIRE-PARAGRAPH-002): live editor selection snapshot (= the text
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // fallback behavior).
    @State var selectedText: String = ""

    // / P2 #19 (WIRE-PARAGRAPH-002): applyParagraphAI spinner flag. Disables the
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / double-fire; = Apple HIG actionable-control-while-busy rule).
    @State private var isApplyingParagraphAI: Bool = false

    // / P2 #19 (WIRE-PARAGRAPH-002): public selection setter. Future ticket will
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / applyParagraphAI's guard).
    func setSelection(_ text: String) {
        selectedText = text
    }

    // / lookup the active tab's id (= the engine's `documentId` for undo +
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / no tab is open (= editor in initial state with no document).
    private var activeTabIdString: String {
        appState.openTabs.first(where: { $0.id == appState.activeTabId })?.id.uuidString
            ?? "wenshu-editor-no-tab"
    }

    // MARK: - SMC `header:` chrome band (= T-01) 28 PT Apple HIG
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // 28+10+10 column-header height).
    private var editorChromeHeader: EditorHeaderView {
        EditorHeaderView(
            title: activeTabDisplayTitle,
            // Dirty-state marker (= the dot color follows the same state
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // conflict. nil = clean (= no dot).
            dirtyState: isDirty ? .unsaved : nil,
            // Right-side chrome cluster. T-01 ships an autosave pulse (= a tiny
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // spell-check toggle.
            chrome: editorChromeTrailingCluster
        )
    }

    // / Right-side chrome widget cluster (= the autosave pulse for now).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / just an SFIcon + .frame; = no business logic on the render path).
    private var editorChromeTrailingCluster: [EditorHeaderChrome] {
        guard let tab = activeTab, tab.autoSaveTask != nil else {
            return []
        }
        return [
            EditorHeaderChrome {
                SFIcon("arrow.triangle.2.circlepath", style: .paneTab, color: IconColor.secondary)
                    .help(String(localized: "editor.header.autosaving.tooltip"))
                    .accessibilityLabel(String(localized: "editor.header.autosaving.a11y"))
            }
        ]
    }

    // / Display title for the active editor tab (= shown in the chrome band's
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / never-empty string so the chrome band never shows a blank cluster.
    private var activeTabDisplayTitle: String {
        guard let tab = activeTab else { return String(localized: "editor.header.untitled") }
        let display = EditorTab.displayTitle(tab)
        return display.isEmpty ? String(localized: "editor.header.untitled") : display
    }

    // / SMC `placeholder:` slot (= ghost text shown while the document is empty;
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / invocation (= cheap = a single NSAttributedString allocation).
    private var editorEmptyDocumentPlaceholder: NSAttributedString? {
        let paragraph = NSMutableParagraphStyle()
        // No indent (= the engine's own textContainerInset handles margin).
        paragraph.firstLineHeadIndent = 0
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: NSColor.tertiaryLabelColor,
            .paragraphStyle: paragraph
        ]
        return NSAttributedString(
            string: String(localized: "editor.placeholder.start_writing"),
            attributes: attributes
        )
    }

    // MARK: - SMC format toolbar (= T-02) The 12-button document toolbar (=
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // exactly this reason: the toolbar must NEVER scroll away).
    private var editorFormatToolbar: EditorFormatToolbar {
        EditorFormatToolbar(
            bus: MarkdownEditorBus.buildWenshu(),
            // 2026-10-14: the previous `onSave` callback (= the
            // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // and Cmd+S still need it).
            onClose: {
                // per-tab close X uses). The active-tab id is a non-optional
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                // of the id).
                guard !appState.openTabs.isEmpty else { return }
                appState.closeTab(id: appState.activeTabId, bookStore: bookStore)
            }
        )
    }

    // / Chrome band: 1 PT hairline divider (= the .separatorColor rectangle) +
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / the user's "工具栏上边距再-2" directive).
    private var formatToolbarSection: some View {
        Group { Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .padding(.top, DesignTokens.spacingTight)
        editorFormatToolbar
            .padding(.top, 0)
        }
    }

    // / On editor zone mount: upgrade any preview-mode tabs to edit mode, seed
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / external FS events auto-reload the draft.
    private func onEditorAppear() {
    // (see OOB.md #2026-09-07): do NOT seed a placeholder tab when
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // surface).
    for idx in appState.openTabs.indices {
        if appState.openTabs[idx].mode == .preview {
            appState.openTabs[idx].mode = .edit
        }
    }
    // Initialize word count from active tab (= 0 when no tab).
    if let tab = activeTab {
        editorCounters.wordCount = WordCounter.count(tab.originalBody).charactersNoSpaces
    } else {
        editorCounters.wordCount = 0
    }
    // start the file-system watcher for the current documentPath (nil =
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // state-write paths in lockstep at the call site (= easy to audit).
    if let tab = activeTab {
        EditorFileWatcher.start(
            path: tab.documentPath,
            tab: tab,
            onChange: { [self] in reloadFromDiskAndApply() }
        )
    }

    }

    // / On editor zone unmount: stop the file-system watcher (= prevents zombie
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / `onEditorAppear`; = `.stop` here = symmetric pair).
    private func onEditorDisappear() {
        if let tab = activeTab {
            EditorFileWatcher.stop(tab: tab)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab strip = Safari-style multi-tab bar (Apple HIG tabbed-document
            // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // empty- state hint at full size below).
            EditorTabStrip(
                tabs: appState.openTabs,
                selectedTabId: appState.activeTabId,
                onSelect: { newId in
                    appState.activeTabId = newId
                },
                onClose: { closedId in
                    appState.closeTab(id: closedId, bookStore: bookStore)
                },
            )
            // dirty-discard confirm dialog. Shown when user tries to close with
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // property; = wrap in Binding(get:set:) for .alert's isPresented:.
            .alert(String(localized: "workspace.editor.dirty_discard_alert_title"), isPresented: Binding(
                get: { self.showDirtyDiscardConfirm },
                set: { self.showDirtyDiscardConfirm = $0 }
            )) {
                Button(String(localized: "workspace.editor.dirty_discard_button"), role: .destructive) {
                    // tab close button: discard = close the tab (= auto-save
                    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                    // dirty-flush (since draft will be reset below).
                    if let tab = activeTab {
                        // Reset draft so closeTab's 'draft != originalBody'
                        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                        // them).
                        tab.draft = tab.originalBody
                        appState.closeTab(id: tab.id, bookStore: bookStore)
                    }
                }
                Button(String(localized: "button.continue_edit"), role: .cancel) { }
            } message: {
                Text(String(localized: "workspace.editor.discard_changes_confirm"))
            }

            formatToolbarSection

            // Body: placeholder content. swaps this for swift-markdown rendered
            // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // hack.
            ZStack {
                // preview mode uses swift-markdown (= AGENTS.md §11.1 pinned
                // … (= 18 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                // replaces the previous samplePreviewBody placeholder).
                if activeTab == nil {
                    // Empty-state path: when no document is open, the page is a
                    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                    // the empty state').
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        EmptyStateView(
                            icon: "text.document",
                            title: String(localized: "editor.empty.title"),
                            body: String(localized: "editor.empty.description")
                        )
                        Spacer(minLength: 0)
                    }
                } else {
                    // give the middle column a sheet of paper like Pages, with
                    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                    // with what Pages would show.
                    EditorPaperCanvas {
                        Group {
                            // chapter-dialog 2026-09-28 T3: small inline banner
                            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // editor reloads with the LLM's changes).
                            if appState.focusedChapterPath != nil
                                && appState.focusedChapterPath == currentTabDocumentPath
                                && !workspaceUI.chatVisible {
                                ChapterFocusLockBadge()
                            }
                            if mode == .preview {
                        // (see OOB.md #2026-09-07) — 'editor, yes,
                        // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                        // action).
                        WenshuMarkdownEditor(
                            text: Binding(
                                get: { self.draft },
                                set: { self.draft = $0 }
                            ),
                            draftId: activeTabIdString,
                            configuration: WenshuEditorServicesFactory.make(
                                bookStore: bookStore,
                                bus: MarkdownEditorBus.buildWenshu()
                            ),
                            onLinkClick: { linkId in
                                handleEditorWikiLink(linkId: linkId)
                            },
                            // (see OOB.md #2026-09-07) — 'editor, yes ,
                            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // between modes).
                            isEditable: false,
                            // ed-smc-defaults T-01 (= Apple HIG
                            // … (= 21 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // H1)).
                            header: nil,
                            placeholder: editorEmptyDocumentPlaceholder
                        )
                    } else {
                        // edit mode uses Apple SwiftUI TextEditor (= HIG
                        // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                        // contract).
                        EditorEditContent(
                            draft: Binding(
                                get: { self.draft },
                                set: { self.draft = $0 }
                            ),
                            originalBody: originalBody,
                            // chapter-focus-lock 2026-09-28: compute the
                            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // holds the cursor.
                            isChapterLockedByLLM: appState.focusedChapterPath != nil
                                && !workspaceUI.chatVisible
                                && appState.focusedChapterPath == currentTabDocumentPath,
                            // route live word count into shared
                            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // keystroke; = Foundation-only = microseconds.
                            onWordCountChange: { count in
                                editorCounters.wordCount = count
                            },
                            // route dirty-state transitions dirty-state
                            // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // `EditorPersistence.handleDirtyTransition(...)`.
                            onDirtyChange: { newDirty in
                                if let tab = activeTab {
                                    EditorPersistence.handleDirtyTransition(newDirty, tab: tab, bookStore: bookStore)
                                }
                            },
                            // pre-built markdown engine configuration. Built
                            // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // BookStore yet on early zone activation).
                            configuration: WenshuEditorServicesFactory.make(
                                bookStore: bookStore,
                                // per-active-tab bus so engine format / find /
                                // replace events stay scoped to this document.
                                bus: MarkdownEditorBus.buildWenshu()
                            ),
                            // stable per-tab id, passed to engine as
                            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // scoped to this tab.
                            draftId: activeTabIdString,
                            // forward engine wiki-link click to the navigation flow.
                            onLinkClick: { linkId in
                                handleEditorWikiLink(linkId: linkId)
                            },
                            // ed-smc-defaults T-02: forward the chrome band +
                            // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // H1 is the canonical title).
                            editorHeader: nil,
                            editorPlaceholder: editorEmptyDocumentPlaceholder,
                            // T-03: wire caret-rect callback so the status bar
                            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
                            // `EditorView.cursorRect`).
                            editorCaretRectChange: { rect in
                                if let idx = self.activeTabIndex {
                                    self.appState.openTabs[idx].cursorRect = rect
                                }
                            }
                        )
                            }
                        }
                    }                }
            }
            // RATIONALE: the `EditorStatusBarView` sits at the bottom of the
            // … (= 50 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // needed).
            .safeAreaInset(edge: .bottom, spacing: 0) {
                EditorStatusBarView(
                    textProvider: { self.draft },
                    isDirtyProvider: { self.isDirty },
                    isAutosavingProvider: { self.isAutosaving }
                )
            }
            // drop the outer VStack's `.frame(maxWidth: .infinity, maxHeight:
            // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // fill').
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Liquid Glass adaptation: zone top/bottom bars + backgrounds +
            // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // background (= inherits from the column = no nested layering).
        }
        // on editor zone mount, seed AppState.editorWordCount with the
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
        // reactive state at view mount).
        .onAppear { onEditorAppear() }
        // 'chattop bar 3 tab, editortop bar ': REVERTED (= (see OOB.md
        // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
        // cancel lifecycle).
        .onDisappear { onEditorDisappear() }
    }

    // edit-mode state owner. Both fields initialise from the sample preview
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // switching tabs switches the active data set; = matches Safari behavior).
    var activeTab: EditorTab? {
        guard let idx = appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId }) else { return nil }
        return appState.openTabs[idx]
    }
    private var activeTabIndex: Int? {
        appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId })
    }

    // chapter-focus-lock 2026-09-28: convenience accessor for the single-focus
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // also gate on shellState.chatVisible (= the LLM-can-edit gate).
    private var currentTabDocumentPath: String? {
        activeTab?.documentPath
    }

    var draft: String {
        // (see OOB.md #2026-09-07): when no tab is open, return empty string (=
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
        // EditorView's nil-activeTab branch.
        get { activeTab?.draft ?? "" }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].draft = newValue
        }
    }
    var originalBody: String {
        get { activeTab?.originalBody ?? "" }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].originalBody = newValue
        }
    }
    private var documentPath: String? {
        get { activeTab?.documentPath }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].documentPath = newValue
        }
    }
    // / Computed dirty flag (= the Save button's .tint highlight). Plain
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / originalBody).
    private var isDirty: Bool {
        guard let tab = activeTab else { return false }
        return tab.draft != tab.originalBody
    }
    // / T-03: cursor rect accessor (= returns the active tab's live caret rect =
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / hasn't focused the editor).
    private var cursorRect: CGRect? {
        activeTab?.cursorRect
    }
    // / T-03: autosave-in-progress accessor (= true while a save task is in
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / = "saving").
    private var isAutosaving: Bool {
        activeTab?.autoSaveTask != nil
    }
    /// Per-tab auto-save Task. Reads from / writes to the active tab.
    private var autoSaveTask: Task<Void, Never>? {
        get { activeTab?.autoSaveTask }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].autoSaveTask = newValue
        }
    }
    // / per-tab file-system watcher state (= `tab.fileWatcher` +
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / notification (= B-23 conflict).
    private var externalChangeNotice: String? {
        get { activeTab?.externalChangeNotice }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].externalChangeNotice = newValue
        }
    }
    /// Per-tab dirty-discard alert state.
    private var showDirtyDiscardConfirm: Bool {
        get { activeTab?.showDirtyDiscardConfirm ?? false }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].showDirtyDiscardConfirm = newValue
        }
    }
    // (saveDraft extracted to EditorViewEditHelpers.swift in A86; = see that file)
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // EditorFileWatcher's `onChange` closure (= external FS event → UI reload).
    private func reloadFromDiskAndApply() {
        guard let tab = activeTab else { return }
        guard let result = EditorPersistence.reloadFromDisk(tab: tab) else {
            // File missing (= transient FS race or editor in placeholder mode).
            // = silent no-op (= the v0.34 B-23 behavior; = no error UI).
            return
        }
        draft = result.newContent
        originalBody = result.newContent
        if let notice = result.conflictNotice {
            externalChangeNotice = notice
        }
        // Mark the document clean (= cancels any pending auto-save Task).
        EditorPersistence.handleDirtyTransition(false, tab: tab, bookStore: bookStore)
        // Update chrome bottom-bar left (= word count of new content).
        editorCounters.wordCount = WordCounter.count(result.newContent).charactersNoSpaces
    }

    // editor-mvvm T2b: `writeDraftToDisk()` migrated to
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / target as a new tab and switches to it.
    func handlePreviewWikiLink(displayName: String) {
        guard !displayName.isEmpty else { return }
        guard let result = WikiLinkNavigation.handle(
            displayName: displayName,
            referenceStore: bookStore.loadReferenceStore(),
            bookStore: bookStore
        ) else {
            return
        }
        let fingerprint = String(result.body.prefix(200))
        if let existingIdx = appState.openTabs.firstIndex(where: {
            String($0.originalBody.prefix(200)) == fingerprint
        }) {
            appState.activeTabId = appState.openTabs[existingIdx].id
            return
        }
        let newTab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: result.body,
            originalBody: result.body,
            mode: .preview,
            // Pass the wiki-link target title so the tab strip shows the linked
            // entity / chapter name.
            title: result.title.isEmpty ? nil : result.title        )
        appState.openTabs.append(newTab)
        appState.activeTabId = newTab.id
    }
    // (handleEditorWikiLink extracted to EditorViewEditHelpers.swift in A86; = see that file)
    // … (= 22 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // / dirty flag stays unchanged.
    func applyParagraphAI(_ transform: EditorTransform) async {
        guard !selectedText.isEmpty else { return }
        isApplyingParagraphAI = true
        defer { isApplyingParagraphAI = false }

        let providerSlug = UserDefaultsStore.shared.string(forKey: .llmActiveConnector, fallback: "anthropic")
        let providerDefaultModel = ProviderCatalog.defaultModels(for: providerSlug).first ?? "unknown"
        let options = LLMCallOptions(
            model: appState.llmModel.isEmpty ? providerDefaultModel : appState.llmModel,
            maxTokens: 2048
        )
        // AUDIT.md §2.2 partial (2026-10-16 boss "只做把之前的
        // 调用方式改成调用包" arc): route through the
        // public facade (= the canonical source of truth;
        // = the WenshuAppDelegateLLMHelpers helper is now
        // a 1-line forwarder in the facade).
        let connector = WenshuAgent.shared.activeLLMConnector()

        do {
            let rewritten = try await EditorParagraphAI.apply(
                selectedText: selectedText,
                transform: transform,
                connector: connector,
                options: options
            )
            guard !rewritten.isEmpty else { return }
            replaceSelectedText(with: rewritten)
        } catch {
            // S4 graceful degradation: log + no-op. The wenshu-dev user sees
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
            // above).
            wenshuLogger.info("[wenshu.editor] applyParagraphAI(\(transform.rawValue)) failed: \(String(describing: error))")
        }
    }
    // (replaceSelectedText extracted to EditorViewEditHelpers.swift in A86; = see that file)
    // … (= 50 rationale lines collapsed; = A112 docblock collapse per §1.8 high information density)
    // wikilink routing lands in a follow-on surface).
}
