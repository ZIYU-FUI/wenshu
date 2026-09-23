// EditorPlaceholder.swift · Wenshu · v1.33 ticket 001
//
// Extracted from WorkspaceView.swift (= v0.34 ticket 04).
//
// Per boss OOB 2026-09-14 "我想把这些修掉" + repowise
// get_health directive (WorkspaceView = top untested hotspot):
// v1.33 continues the WorkspaceView split (= v1.32 = ZoneModuleView;
// v1.33 = EditorPlaceholder).
//
// Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: extract
// EditorPlaceholder (= the placeholder for the editor's main
// content area) to its own file. This is the SECOND safe split
// because EditorPlaceholderTests.swift already exists in
// tests/WenshuAppTests/Views/Workspace/.
//
// Per Q34 5.2 + Q173 ponytail + Q186: minimal split = 1 struct
// 1 file (= 876 LOC extracted from 1749 → 873 in WorkspaceView).
//
// Per Q34 5.2: extracted struct preserves all @Environment,
// @State, init, and body (= no behavior change).

import SwiftUI
import MarkdownEngine  // v0.39 ticket 001: MarkdownEditorConfiguration type
// v1.36 ticket 002: drop `import LucideSwift` (= removed by boss's v1.x
// Lucide → SF Symbols 6 deprecation in commit c50d76167). The legacy
// `Lucide`/`LucideIcon` references in this file are comments only (= no
// active symbol resolution = drop is safe). Per Q34 5.2 + Q173 ponytail +
// Q186: this is part of the same v1.36 work as `ShellPlaceholder` duplicate
// removal (= both are PREREQUISITES for `swift build --target WenshuAppTests`
// to pass on main = main is currently broken without these fixes).

struct EditorPlaceholder: View {
    // v0.34 B-24: Mode enum lifted to module scope (= EditorMode, in
    // AppState.swift; = so EditorTab can reference it). The nested
    // Mode enum was removed; = EditorPlaceholder.Mode.iconName /
    // .tooltip helpers became EditorMode.iconName / .tooltip (= same
    // shape; = one-line update at every usage).
    /// v0.34 ticket 04: mode lives on the active tab (= AppState.openTabs
    /// [activeTabId].mode). Reading the active tab's mode instead of a
    /// View-local @State = each tab keeps its own preview/edit state
    /// (= switching tabs preserves mode; = matches Safari behavior).
    private var mode: EditorMode {
        appState.openTabs.first(where: { $0.id == appState.activeTabId })?.mode ?? .preview
    }
    /// v0.34 B-26: derive the display title for a tab (= file basename
    /// without the .md extension; = boss 9/3 OOB 'no .md extension either'). Placeholder tab = 'preview-sample' (= no .md extension,
    /// = no path = render the short placeholder name).
    ///
    @Environment(AppState.self) private var appState
    // v0.39 ticket 001: WenshuEditorServicesFactory.make needs
    // referenceLibraryRoot + active book root. Both come from
    // BookStore (= injected via .environment(bookStore) at the
    // WindowGroup root in App.swift + LibraryRootView, per
    // v0.34 B-25-fix pattern).
    @Environment(BookStore.self) private var bookStore

    // P2 #19 (WIRE-PARAGRAPH-002): live editor selection snapshot
    // (= the text the paragraph_ai buttons operate on). The
    // markdown engine is an NSViewRepresentable wrapping NSTextView;
    // a real selection-bridge would require an NSTextViewDelegate
    // (= a separate ticket that the engine doesn't expose yet).
    // For this ticket we keep a View-local @State + a public setter
    // (= setSelection(_:)) that future wiring can call from the
    // engine's coordinator; today the buttons act on the whole
    // draft when no selection is reported (= matches the existing
    // FormatToolbarButtons fallback behavior in v0.34 B-20).
    @State private var selectedText: String = ""

    /// P2 #19 (WIRE-PARAGRAPH-002): applyParagraphAI spinner flag.
    /// Disables the 3 toolbar buttons + the menu while an LLM call
    /// is in flight (= prevents double-fire; = Apple HIG
    /// actionable-control-while-busy rule).
    @State private var isApplyingParagraphAI: Bool = false

    /// P2 #19 (WIRE-PARAGRAPH-002): public selection setter.
    /// Future ticket will bridge this from the engine's
    /// NSTextViewDelegate. Today the setter is unused (= the
    /// buttons fall through to the whole-draft path; see
    /// applyParagraphAI's guard).
    public func setSelection(_ text: String) {
        selectedText = text
    }

    /// v0.39 ticket 001: lookup the active tab's id (= the engine's
    /// `documentId` for undo + replacement scoping). Falls back to
    /// a deterministic placeholder id when no tab is open (=
    /// editor in initial state with no document).
    private var activeTabIdString: String {
        appState.openTabs.first(where: { $0.id == appState.activeTabId })?.id.uuidString
            ?? "wenshu-editor-no-tab"
    }

    var body: some View {
        VStack(spacing: 0) {
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'at the top of the editor keep
            // the tab strip for showing multiple documents' (= keep the tab strip = the
            // multi-document title bar; = delete every other chrome
            // element on the editor top bar: the mode toggle Button,
            // ParagraphAIToolbarButtons, Spacer, .frame toolbar
            // height, and the .background { Color.clear } glass
            // material). The editor top bar = a Safari-style tab
            // strip ONLY (= Apple HIG tabbed-document pattern;
            // = Finder / Safari / Terminal all use a plain tab
            // strip without formatting chrome; = the user said
            // 'just keep it for the tab strip' = nothing else on this bar).
            //
            // Apple HIG tabbed-document pattern (= NSTabView / Safari
            // tab strip): single-line HStack, scrollable horizontally
            // when tabs overflow. = no formatting toolbar / no save
            // button (= the per-tab formatting + save hotkey move to
            // the new tab-bar layout as boss decides).
            // v1.73 tab strip — boss 2026-09-23 OOB '当前打开的 teb,
            // 应该是全宽的 teb. 能显示文件名和 X 按钮. 要不要我点不到':
            // only the ACTIVE tab is shown in the strip (= full-width
            // title + close X). Inactive tabs are hidden (= openTabs
            // stays in AppState for state; = sidebar drives the
            // switch-back path; = this matches Safari's "single tab"
            // feel on a one-tab window).
            //
            // X button = small xmark Button next to the title (= fires
            // appState.closeTab which handles dirty flush + remove +
            // focus follow). We avoid sibling Button nesting inside the
            // active title Button (= which earlier triggered a SwiftUI
            // Update-Constraints infinite loop on macOS 27 Liquid Glass).
            HStack(spacing: 0) {
                if let active = appState.openTabs.first(where: { $0.id == appState.activeTabId })
                    ?? appState.openTabs.first {
                    let title = EditorTab.displayTitle(active)
                    // Active tab title = plain Text (= no Button; =
                    // the active tab is not interactive itself; =
                    // clicking the title is a no-op and would only
                    // add a focus ring + accessibility label that
                    // screen readers would announce as a control).
                    Text(title)
                        .font(DesignTokens.tabTitleFont.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, DesignTokens.chromePaddingMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: DesignTokens.paneTabHotArea)
                        .background(
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.12))
                        )
                        .help(title)

                    Button(action: {
                        appState.closeTab(id: active.id, bookStore: bookStore)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(
                                size: DesignTokens.tabCloseGlyphFontSize,
                                weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: DesignTokens.tabCloseFrameSize,
                                   height: DesignTokens.tabCloseFrameSize)
                    }
                    .buttonStyle(.plain)
                    .help(WenshuI18n.t("workspace.editor.close_tab_tooltip"))
                }
            }
            // v0.34 ticket 09: dirty-discard confirm dialog. Shown when
            // user tries to close with unsaved changes. Apple HIG
            // 2-option confirm pattern (= destructive + cancel).
            // B-24: showDirtyDiscardConfirm is now a computed property;
            // = wrap in Binding(get:set:) for .alert's isPresented:.
            .alert(WenshuI18n.t("workspace.editor.dirty_discard_alert_title"), isPresented: Binding(
                get: { self.showDirtyDiscardConfirm },
                set: { self.showDirtyDiscardConfirm = $0 }
            )) {
                Button(WenshuI18n.t("workspace.editor.dirty_discard_button"), role: .destructive) {
                    // v1.73 tab close button: discard = close the tab
                    // (= auto-save guarantee: dirty drafts are
                    // thrown away because they explicitly chose
                    // 'Discard' in the confirm). closeTab handles
                    // cancel pending Task + stop watcher + skip the
                    // dirty-flush (since draft will be reset below).
                    if let tab = activeTab {
                        // Reset draft so closeTab's
                        // 'draft != originalBody' check is false (=
                        // we throw away the edits, NOT save them).
                        tab.draft = tab.originalBody
                        appState.closeTab(id: tab.id, bookStore: bookStore)
                    }
                }
                Button(WenshuI18n.t("button.continue_edit"), role: .cancel) { }
            } message: {
                Text(WenshuI18n.t("workspace.editor.discard_changes_confirm"))
            }

            // Body: placeholder content. Ticket 05 swaps this for
            // swift-markdown rendered Text when mode = .preview; ticket 07
            // swaps for Apple TextEditor when mode = .edit.
            ZStack {
                // v0.34 ticket 05: preview mode uses swift-markdown
                // (= AGENTS.md §11.1 pinned 0.4.0) AttributedString render
                // for headers/bold/italic/lists/code/links, plus
                // InternalLinkParser (= wenshu's existing parser, = 1:1
                // Obsidian wikilink syntax) to make [[name]] clickable.
                // Placeholder sample body until ticket 027-35 wires the
                // real document load (= the Apple HIG DocumentGroup
                // file-open path is the v0.35+ ticket).
                // v0.34 B-25-FIX (= boss 9/3 'preview BUG is still there'): EditorPlaceholder
                // preview mode previously rendered `Self.samplePreviewBody`
                // (= static placeholder string) regardless of which tab
                // was active. Replaced with `self.draft` (= per-tab
                // computed property backed by appState.openTabs[activeTabIdx].draft)
                // so the preview shows the active tab's content = when
                // openCardInEditor creates/updates a tab with the .md body
                // read from disk, the preview updates immediately. This
                // is the v0.34 B-25 root-cause fix (= the closure chain
                // WAS firing correctly; = the bug was the view rendering
                // the placeholder instead of the active tab).
                // v0.40 boss 9/7 OOB 'delete': when no
                // tab is open, show the empty-state hint instead of
                // the preview/edit body (= replaces the previous
                // samplePreviewBody placeholder).
                if activeTab == nil {
                    // v1.0.0-m1-shell boss 2026-09-10 OOB 'when no document is open,
                    // the paper should just be a placeholder, not rendered — don't show that white, show the empty state instead'
                    // + follow-up 'no, what I mean is when no document is open,
                    // both zones should still be there, top/bottom 50/50, only the top
                    // becomes the empty state':
                    //
                    // v1.0.0-m1-shell boss 2026-09-12 OOB 'the current empty state isn't
                    // a single component — can you abstract a UI component? While you're at it, on the
                    // empty-state icon: double the size and use the thinnest strokes. The goal is to unify all
                    // empty-state styles. The right column has 12 tabs and many are missing an empty state':
                    // migrate to the unified EmptyStateView (= 76 PT
                    // SF Symbols 6 icon + .regular weight =
                    // the canonical macOS 27 inspector
                    // icon weight; = standard title /
                    // body hierarchy). Same visual treatment
                    // as the 12 specialized tool tabs.
                    //
                    // Wrap the EmptyStateView in a vertical layout
                    // that pushes it to vertical center inside the
                    // upper half of the VSplitView (= the upper
                    // half keeps its 50/50 share with the chat
                    // zone; = the chat zone stays at full size
                    // below; = no VSplitView divider math bug; =
                    // the boss's 'both zones should still be there, top/bottom 50/50,
                    // only the top becomes the empty state').
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        EmptyStateView(
                            icon: "text.document",
                            title: WenshuI18n.t("editor.empty.title"),
                            body: WenshuI18n.t("editor.empty.description")
                        )
                        Spacer(minLength: 0)
                    }
                } else {
                    // v0.52 boss 2026-09-09 OOB: give the middle column a
                    // sheet of paper like Pages, with the markdown engine
                    // sitting on the white area.
                    //
                    // Paper width comes from measuring Pages on this
                    // machine: its canvas renders a 593 PT sheet, i.e. A4
                    // (595 PT) at 100%. Wenshu uses the exact A4 width so
                    // a document lines up with what Pages would show.
                    EditorPaperCanvas {
                        Group {
                            if mode == .preview {
                        // v0.40 boss 9/7 OOB 'editor, yes,
                        // shouldgroup': preview mode uses the
                        // SAME WenshuMarkdownEditor component as edit
                        // mode (= swift-markdown-engine NSTextView), just
                        // with `isEditable: false` (= read-only NSTextView).
                        // Previously preview used a separate
                        // EditorPreviewContent (= SwiftUI AttributedString
                        // renderer) which produced a different visual scale
                        // (= the "" boss described). Unified
                        // component = zero visual scaling between modes.
                        //
                        // SMC ticket 003: wiki-link click navigation routes
                        // through the reference library + active book
                        // chapter lookup (= real target resolution).
                        // Engine's wiki-link click invokes
                        // `handlePreviewWikiLink` (= preview mode = read,
                        // = the click is the primary action).
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
                            // v0.40 boss 9/7 OOB 'editor, yes
                            //, shouldgroup': preview
                            // mode = read-only NSTextView (= same engine
                            // wrapper as edit, = no scaling between
                            // modes).
                            isEditable: false
                        )
                    } else {
                        // v0.34 ticket 07: edit mode uses Apple SwiftUI
                        // TextEditor (= HIG standard multi-line text input).
                        // @State draft holds the working copy; dirty detection
                        // = draft != originalBody (character-level diff per
                        // Q22 boss decision). Save button (added by ticket 08)
                        // .tint highlights when dirty; Cmd+S hotkey (ticket
                        // 10) triggers save.
                        // B-24: draft is a computed property (= reads active
                        // tab). Wrap in Binding(get:set:) so EditorEditContent
                        // can still use @Binding draft (SwiftUI 2-way binding
                        // contract).
                        EditorEditContent(
                            draft: Binding(
                                get: { self.draft },
                                set: { self.draft = $0 }
                            ),
                            originalBody: originalBody,
                            onSave: { saveDraft() },
                            // v0.34 B-18: route live word count into shared
                            // AppState.editorWordCount (= chrome bottom-bar
                            // left field reads it). Recompute is per-
                            // keystroke; = Foundation-only = microseconds.
                            onWordCountChange: { count in
                                appState.editorWordCount = count
                            },
                            // v0.34 B-22: route dirty-state transitions
                            // v0.34 B-22: dirty-state machine. Engine fires this once per
                            // transition (= no per-keystroke Task churn; =
                            // Apple HIG TextEdit / Pages behavior).
                            // v1.70 editor-mvvm T2b: dirty-state machine
                            // lives in `EditorPersistence.handleDirtyTransition(...)`.
                            onDirtyChange: { newDirty in
                                if let tab = activeTab {
                                    EditorPersistence.handleDirtyTransition(newDirty, tab: tab, bookStore: bookStore)
                                }
                            },
                            // v0.39 ticket 001: pre-built markdown engine
                            // configuration. Built once per active-tab switch
                            // (= rebuilds the WikiLinkResolver + ImageProvider
                            // against the active book's path). Engine
                            // configuration is captured by the editor view
                            // (= stable across onChange of draft).
                            // v0.39 ticket 001-B: pass bookStore directly;
                            // factory handles nil (= the v0.39 path that
                            // survives the AnyView-wrapped EditorPlaceholder
                            // when the environment chain hasn't propagated
                            // BookStore yet on early zone activation).
                            configuration: WenshuEditorServicesFactory.make(
                                bookStore: bookStore,
                                // SMC ticket 003: per-active-tab bus so
                                // engine format / find / replace events
                                // stay scoped to this document.
                                bus: MarkdownEditorBus.buildWenshu()
                            ),
                            // v0.39 ticket 001: stable per-tab id, passed
                            // to engine as `documentId` so undo + pending
                            // replacements are scoped to this tab.
                            draftId: activeTabIdString,
                            // SMC ticket 003: forward engine wiki-link
                            // click to the navigation flow.
                            onLinkClick: { linkId in
                                handleEditorWikiLink(linkId: linkId)
                            }
                        )
                            }
                        }
                    }                }
            }
            // v0.70: drop the outer VStack's `.frame(maxWidth: .infinity,
            // maxHeight: .infinity)`. Apple HIG canonical 6-zone layout
            // has no custom frame on the column body (= NavigationSplitView
            // owns the natural-width algorithm). The previous v0.30 fix
            // (which kept this frame in to "prevent window shrink")
            // inflated the detail column to 1763 because WenshuMarkdownEditor's
            // NSTextView intrinsic width is unbounded. Removing this
            // frame is what the canonical 6-zone probe (= window 1449,
            // detail 648) requires. v0.30 window-shrink protection has
            // to come from elsewhere (= .frame on toolbar / status bar,
            // not on the column body).
            //
            // v1.0.0-m1-shell: RESTORE `.frame(maxWidth: .infinity,
            // maxHeight: .infinity)` on the outer VStack because the
            // detail column is now hosted by `EditorChatNSController`
            // (= AppKit NSSplitViewController, NOT NavigationSplitView;
            // = see NavigationSplitShell.swift detail column closure).
            // NSSplitViewController allocates a fixed-size slot per
            // NSSplitViewItem and the SwiftUI view inside the
            // NSHostingController must explicitly claim that slot via
            // `.frame(maxWidth: .infinity, maxHeight: .infinity)`. Without
            // this frame, the editor VStack shrinks to its intrinsic
            // content width (= the WenshuMarkdownEditor NSTextView's
            // minimum width = ~400 PT; = leaves the right side of the
            // detail column empty = the boss's 'width didn't fill' symptom).
            //
            // The v0.30 'inflated the detail column to 1763' concern
            // (= caused by the previous NavigationSplitView layout)
            // no longer applies because NSSplitViewController does
            // not have the unbounded-width issue (= NSSplitViewItem
            // gives a bounded slot).
            //
            // boss 9/10 OOB 'width didn't fill' (= 'width did not fill').
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // v0.28 followup Boss UX round 19 (Boss 2026-08-29 OOB 'all
            // zone top bars, bottom bars, backgrounds, the colors used, can they adapt to Liquid Glass?'):
            // Use .ultraThinMaterial instead of Color.green.opacity(0.05)
            // (= solid green placeholder = inconsistent with the
            // Liquid Glass design language). Editor zone has no
            // v0.40 boss 2026-09-08 OOB 'go up one layer and remove the background': drop
            // .background(.ultraThinMaterial) (= was adding glass
            // material over the editor zone = visually distinct
            // from the chat zone's plain background). Editor zone
            // now has no injected background (= inherits from the
            // column = no nested layering).
        }
        // v0.34 B-18: on editor zone mount, seed AppState.editorWordCount
        // with the character count of the initial body (= sample body
        // in placeholder mode; = real document body post-ticket 027-35).
        // Without this, the chrome bottom-bar left field shows "Word count: 0"
        // even when the preview-mode sample body has 200+ chars. The
        // .onChange(of: draft) inside EditorEditContent covers the edit-
        // mode keystroke stream; = this .onAppear covers the initial
        // state (= Apple HIG = seed reactive state at view mount).
        .onAppear {
            // v0.40 boss 9/7 OOB: do NOT seed a placeholder tab when
            // openTabs is empty. Two paths from here:
            //   1. Persisted tabs (loaded by AppState.init from
            //      UserDefaults) → use those directly.
            //   2. No persisted tabs → editor zone shows the
            // empty-state hint (= "libraryin progressdouble-clickcardopen")
            //      via EditorPlaceholder's nil-activeTab branch.
            // The .edit-mode upgrade from .preview still runs for
            // any tabs that survived (= v0.39 ticket 001-A-extended).
            for idx in appState.openTabs.indices {
                if appState.openTabs[idx].mode == .preview {
                    appState.openTabs[idx].mode = .edit
                }
            }
            // Initialize word count from active tab (= 0 when no tab).
            if let tab = activeTab {
                appState.editorWordCount = WordCounter.count(tab.originalBody).charactersNoSpaces
            } else {
                appState.editorWordCount = 0
            }
            // v0.34 B-23: start the file-system watcher for the current
            // documentPath (nil = placeholder mode; = no-op). The watcher
            // auto-reloads draft when the file changes externally (= agent
            // write, git pull, terminal `echo > file.md`, etc.).
            // v1.70 editor-mvvm T2b: `EditorPersistence.reloadFromDisk`
            // returns the new content + conflict notice (= the
            // helper is pure; = it doesn't mutate tab fields).
            // The view writes the results back to the active
            // tab + updates the word-count badge. This keeps
            // the disk-IO + state-write paths in lockstep at
            // the call site (= easy to audit).
            if let tab = activeTab {
                EditorFileWatcher.start(
                    path: tab.documentPath,
                    tab: tab,
                    onChange: { [self] in reloadFromDiskAndApply() }
                )
            }
        }
        // v0.40 boss 2026-09-08 OOB 'chattop bar 3 tab, editortop bar
        // ': REVERTED (= boss 2026-09-08 follow-up 'yes, don't
        //, info, default
        // editorshould MD tab'). The welcome tab was
        // visually present but the preview body was empty (= no
        // document content to render). Boss wants the editor zone
        // to show NO tab strip at all when there are no persisted
        // tabs (= the empty-state hint takes the full editor body
        // = cleaner empty UX than a blank tab + blank content).
        //
        // .onAppear {
        //     appState.ensureWelcomeTabIfEmpty()
        // }
        // v0.34 B-23: tear down the file watcher when the view goes away
        // (= prevents zombie DispatchSource holding the file descriptor).
        // v1.70 editor-mvvm T1b: delegate to EditorFileWatcher (= the
        // extracted helper owns the fd + cancel lifecycle).
        .onDisappear {
            if let tab = activeTab {
                EditorFileWatcher.stop(tab: tab)
            }
        }
    }

    // v0.34 ticket 07: edit-mode state owner. Both fields initialise from
    // the sample preview body (= placeholder until ticket 027-35 wires
    // the real document load). dirty = draft != originalBody (= ticket
    // 08 reads this for the Save button's .tint highlight).
    // v0.34 B-24: per-tab state lives on AppState.openTabs[activeTabIndex].
    // EditorPlaceholder reads/writes the ACTIVE tab (= single source of
    // truth). These computed properties expose the per-tab state to the
    // rest of the view (= the @State versions are gone; = switching
    // tabs switches the active data set; = matches Safari behavior).
    private var activeTab: EditorTab? {
        guard let idx = appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId }) else { return nil }
        return appState.openTabs[idx]
    }
    private var activeTabIndex: Int? {
        appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId })
    }

    private var draft: String {
        // v0.40 boss 9/7 OOB: when no tab is open, return empty string
        // (= no samplePreviewBody placeholder). The editor zone
        // shows its empty-state hint (= "libraryin progressdouble-clickcardopen")
        // via EditorPlaceholder's nil-activeTab branch.
        get { activeTab?.draft ?? "" }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].draft = newValue
        }
    }
    private var originalBody: String {
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
    /// Computed dirty flag (= ticket 08 reads this for the Save
    /// button's .tint highlight). Plain computed (= re-evaluated on
    /// each render from the active tab's draft / originalBody).
    private var isDirty: Bool {
        guard let tab = activeTab else { return false }
        return tab.draft != tab.originalBody
    }
    /// Per-tab auto-save Task. Reads from / writes to the active tab.
    private var autoSaveTask: Task<Void, Never>? {
        get { activeTab?.autoSaveTask }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].autoSaveTask = newValue
        }
    }
    /// v1.70 editor-mvvm T1b: per-tab file-system watcher state
    /// (= `tab.fileWatcher` + `tab.watchedFD`) is now owned by
    /// `EditorFileWatcher` (= the extracted helper). The view
    /// passes the active tab into `EditorFileWatcher.start(path:
    /// tab:onChange:)` / `.stop(tab:)` and the helper mutates
    /// the tab fields directly. No computed-property wrapper is
    /// needed on the view side anymore (= the helper is the
    /// single entry point for the fd + DispatchSource lifecycle).
    /// Per-tab external-change notification (= B-23 conflict).
    private var externalChangeNotice: String? {
        get { activeTab?.externalChangeNotice }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].externalChangeNotice = newValue
        }
    }
    /// Per-tab dirty-discard alert state (= ticket 09).
    private var showDirtyDiscardConfirm: Bool {
        get { activeTab?.showDirtyDiscardConfirm ?? false }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].showDirtyDiscardConfirm = newValue
        }
    }
    // v0.34 B-22: save action writes draft back over originalBody (= dirty
    // detection clears). When documentPath is non-nil (= v0.35+ ticket
    // 027-35 wires real document load), also write to disk (= atomic
    // UTF-8 = Apple HIG file write pattern). Cmd+S hotkey (ticket 10) and
    // Save toolbar button both call this directly.
    // v1.70 editor-mvvm T2b: disk IO + dirty state machine migrated
    // to `EditorPersistence`. `saveDraft` is now a 3-line thin call
    // site (= wire originalBody = draft → write to disk → mark clean).
    private func saveDraft() {
        guard let tab = activeTab else { return }
        originalBody = draft
        // v1.70 editor-mvvm T2b: B-22 dirty-transition cleanup =
        // mark the document clean (= cancels any pending auto-save
        // Task via EditorPersistence.handleDirtyTransition(false, ...).
        // Pass `nil` for bookStore (= the save path already ran with
        // the right bookStore = the user just Cmd+S = the doc was
        // either fresh-proposed via Path 2 or had documentPath from
        // a previous save = no need to re-resolve the proposedPath).
        // The tab.documentPath mutation (= the auto-bind from
        // Path 2) only happens inside save(), so any subsequent save
        // call sees the new path.
        EditorPersistence.save(tab: tab, bookStore: bookStore)
        EditorPersistence.handleDirtyTransition(false, tab: tab, bookStore: bookStore)
    }

    // v1.70 editor-mvvm T2b: `EditorPersistence.reloadFromDisk`
    // returns the new content + conflict notice as a struct (= the
    // helper is pure). This view-side wrapper writes the results
    // back to the active tab + updates the word-count badge +
    // marks the document clean. Called from the EditorFileWatcher's
    // `onChange` closure (= external FS event → UI reload).
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
        appState.editorWordCount = WordCounter.count(result.newContent).charactersNoSpaces
    }

    // v1.70 editor-mvvm T2b: `writeDraftToDisk()` migrated to
    // `EditorPersistence.save(tab:bookStore:)`. See
    // `Sources/WenshuApp/Editor/EditorPersistence.swift` (= the
    // single owner of the 3 disk-IO paths: existing documentPath,
    // propose new path + auto-bind, /tmp fallback). The view's
    // `saveDraft()` (= Cmd+S + Save toolbar button entry point)
    // is now a thin call site above.

    // v0.34 B-21 + SMC ticket 003: handle a preview-mode wiki-link click.
    /// Looks up the display name in the reference library first
    /// (= library-public entities), then in the active book.
    /// On hit, opens the target as a new tab and switches to it.
    private func handlePreviewWikiLink(displayName: String) {
        guard !displayName.isEmpty else { return }
        guard let result = WikiLinkNavigation.handle(
            displayName: displayName,
            referenceStore: bookStore.referenceStore,
            bookStore: bookStore
        ) else {
            #if DEBUG
            print("[wenshu.editor] wiki-link miss: \(displayName)")
            #endif
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
            // v1.0.0-m1-shell boss 2026-09-12 OOB 'the tab title didn't go to the document name'
            // bug': pass wiki-link target title so the tab strip
            // shows the linked entity / chapter name.
            title: result.title.isEmpty ? nil : result.title        )
        appState.openTabs.append(newTab)
        appState.activeTabId = newTab.id
    }

    /// SMC ticket 003: handle a wiki-link click from the live
    /// editor surface (= the engine fires onLinkClick with the
    /// resolved link id, NOT the display name). Resolve the id
    /// back to the display name via the active
    /// WikiLinkResolver's name(forID:) and route through the
    /// preview-mode navigation flow.
    private func handleEditorWikiLink(linkId: String) {
        guard !linkId.isEmpty else { return }
        let resolver = ReferenceLibraryWikiLinkResolver(
            referenceLibraryRoot: bookStore.stores.referenceLibraryRoot
        )
        let displayName = resolver.name(forID: linkId) ?? linkId
        handlePreviewWikiLink(displayName: displayName)
    }

    // MARK: - P2 #19 paragraph_ai apply

    /// P2 #19 (WIRE-PARAGRAPH-002): fire the requested paragraph
    /// transform against the active LLM connector and replace the
    /// current selection with the rewritten text.
    ///
    /// Pipeline (= matches the boss spec):
    /// 1. guard on `selectedText` non-empty (= matches the
    ///    `disabled(vm.selectedText.isEmpty)` rule on the toolbar
    ///    buttons; if the engine selection bridge hasn't reported
    ///    anything, no-op).
    /// 2. delegate to the testable static helper
    ///    `EditorParagraphAI.apply(...)` (= internal static; = the
    ///    pure function the test target exercises). The helper
    ///    builds the prompt prefix, calls the connector, extracts
    ///    the response text, and returns it (= no draft mutation
    ///    = no SwiftUI dependency = trivially unit-testable).
    /// 3. replace the selection (= today: whole draft) with the
    ///    returned text.
    ///
    /// Concurrency: Swift 6 strict concurrency. The view is
    /// @MainActor (= EditorPlaceholder is a SwiftUI View; = the
    /// compiler infers MainActor isolation). `await
    /// connector.send(...)` hops off MainActor for the URL
    /// session, then returns; the final `replaceSelectedText`
    /// write stays on MainActor (= the @State mutation requires
    /// it).
    ///
    /// Failure mode (= matches the wenshu S4 graceful-degradation
    /// rule): any throw from the connector (= transport / auth /
    /// missing API key / decode) is logged via NSLog and the
    /// method returns without touching the draft. The user sees
    /// no error UI (= consistent with how WenshuConductor.handle
    /// handles ConversationLoop.runTurn failures); the dirty flag
    /// stays unchanged.
    func applyParagraphAI(_ transform: EditorTransform) async {
        guard !selectedText.isEmpty else { return }
        isApplyingParagraphAI = true
        defer { isApplyingParagraphAI = false }

        let providerSlug = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector") ?? "anthropic"
        let providerDefaultModel = ProviderCatalog.defaultModels(for: providerSlug).first ?? "unknown"
        let options = LLMCallOptions(
            model: appState.llmModel.isEmpty ? providerDefaultModel : appState.llmModel,
            maxTokens: 2048
        )
        let connector = WenshuAppDelegate.activeLLMConnector()

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
            // S4 graceful degradation: log + no-op. The wenshu-dev
            // user sees the underlying failure via Console.app;
            // the in-app UX stays unbroken (draft unchanged,
            // buttons re-enabled by the defer above).
            NSLog("[wenshu.editor] applyParagraphAI(%@) failed: %@", transform.rawValue, String(describing: error))
        }
    }

    /// P2 #19: replace the current selection (= today: whole
    /// draft) with the supplied text. Once the engine selection
    /// bridge lands, this becomes a surgical NSRange replace
    /// (= same signature; only the body changes).
    private func replaceSelectedText(with newText: String) {
        // Fallback behavior (= mirrors FormatToolbarButtons in
        // v0.34 B-20: when the TextEditor selection isn't
        // observable, wrap/overwrite the whole draft). Future
        // ticket narrows to selected NSRange once the engine
        // exposes an NSTextViewDelegate bridge.
        draft = newText
        // Reset the selection snapshot so the toolbar buttons
        // disable until the user re-selects (= prevents the
        // "press shortcut twice" footgun where the same LLM
        // response replaces itself).
        selectedText = ""
    }


    // MARK: - B-23 file-system watcher
    //
    // v1.70 editor-mvvm T1b: the DispatchSource lifecycle (= fd
    // open + event handler + cancel + close) migrated to
    // `EditorFileWatcher` (= v0.34 B-23 inline implementation is
    // gone). The view passes `tab.documentPath` + the
    // `reloadDocumentFromDisk` closure to `EditorFileWatcher.start(...)`
    // when the active tab changes / the view appears (= see the
    // `.onChange { }` + `.onDisappear { }` blocks in `body` above).
    // The `tab.fileWatcher` + `tab.watchedFD` fields stay on
    // `EditorTab` (= the helper writes them; = future inspection
    // hooks can still read them).

    // v1.70 editor-mvvm T2b: `reloadDocumentFromDisk()` migrated to
    // `EditorPersistence.reloadFromDisk(tab:)` returning a struct
    // (= the helper is pure; = doesn't mutate tab fields). The
    // view-side wrapper `reloadFromDiskAndApply()` (= above) is
    // the `onChange` closure that gets called by `EditorFileWatcher`
    // (= v1.70 T1a) when an external file change is detected.
    // It writes the helper's result back to the active tab + updates
    // the word-count badge + marks the document clean.

    // v1.70 editor-mvvm T2b: `handleDirtyTransition(_:)` migrated to
    // `EditorPersistence.handleDirtyTransition(_:tab:bookStore:)`.
    // The 3-second debounce Task + cancellation + idempotent cycle
    // end (= autoSaveTask = nil after firing) live in the helper.
    // The view's call sites (= discard button + onDirtyChange closure
    // + reloadFromDiskAndApply wrapper + saveDraft wrapper) are all
    // 1-liners that hand off to the helper.

    // v0.34 B-24: documentPath + autoSaveTask + externalChangeNotice
    // + showDirtyDiscardConfirm are now computed properties (= read/
    // write the active tab's state via AppState). Defined above as
    // part of the per-tab state migration; = these View-local @State
    // duplicates would shadow the active-tab reads.
    //
    // v1.70 editor-mvvm T1b: `fileWatcher` + `watchedFD` removed
    // from this view (= lifecycle is now `EditorFileWatcher`'s
    // responsibility; = the helper writes them on `tab.*` directly).

    // v0.34 ticket 09: close handler. If dirty = present confirm dialog;
    // if clean = close immediately (= Apple HIG standard). Cmd+W (ticket
    // 10) routes through this same method.
    // v0.40 boss 9/7 OOB 'delete': samplePreviewBody
    // (= the "Welcome to wenshu" placeholder) is removed. When no
    // tab is open, the editor zone shows the empty-state hint via
    // `emptyStateHint` (= tells the user to double-click a card
    // in the material library). Persisted open tabs (= loaded from
    // UserDefaults by AppState.init) skip this hint entirely.
    //
    // v0.34 ticket 05 (preserved as comment for historical
    // reference): sample markdown body shown in preview mode
    // exercised header levels, bold/italic, bullet list, inline
    // code, code fence, [[wikilink]] (= parsed by InternalLinkParser).
    // The v0.40 apple-001 UX cleanup replaced its CJK content with
    // an onboarding welcome. Now removed entirely per boss 9/7 OOB.

    /// v1.28 B2.1.13: deleted `emptyStateHint` (= verify-dead reports
    /// ext=0 + int=0; = 0 callers; = the computed var returned the
    /// empty-state hint when no editor tab is open; = the v0.40 boss
    /// 9/7 OOB "delete" ticket already removed the call site that
    /// invoked `emptyStateHint` (= the samplePreviewBody removal
    /// earlier; = the editor zone now uses an inline empty-state
    /// directly via the empty-tab guard in `body`); = no behavior
    /// change; = 28 LOC removed including the long Apple HIG
    /// empty-state docstring preserved as historical note).

    // v0.34 ticket 05: placeholder type alias for the wikilink navigation
    // closure (= ticket 027-35 will replace with actual NavigationLink).
}
