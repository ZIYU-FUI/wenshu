// Sources/WenshuApp/Views/Workspace/EditorView.swift Editor placeholder shown when no
// editor tab is active (= the workspace shape + CTA). Extracted from
// WorkspaceView.swift into its own file so the parent view stays render-only.
// The extracted struct preserves all @Environment, @State, and
// @EnvironmentObject surface (= the call site compiles without modifier
// changes). Lucide import drop: Apple's SF Symbols is the canonical icon source
// (= built into macOS 27 = zero SPM dependency). because EditorViewTests.swift
// already exists in tests/WenshuAppTests/Views/Workspace/. Minimal split = 1
// struct 1 file (= 876 LOC extracted from 1749 → 873 in WorkspaceView). The
// extracted struct preserves all @Environment, @State, init, and body (= no
// behavior change).

import SwiftUI
import os
import MarkdownEngine

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "editorview")

struct EditorView: View {
    // Mode enum lifted to module scope (= EditorMode, in AppState.swift; = so
    // EditorTab can reference it). The nested Mode enum was removed; =
    // EditorView.Mode.iconName / .tooltip helpers became EditorMode.iconName /
    // .tooltip (= same shape; = one-line update at every usage).
    /// mode lives on the active tab (= AppState.openTabs
    /// [activeTabId].mode). Reading the active tab's mode instead of a
    /// View-local @State = each tab keeps its own preview/edit state
    /// (= switching tabs preserves mode; = matches Safari behavior).
    private var mode: EditorMode {
        appState.openTabs.first(where: { $0.id == appState.activeTabId })?.mode ?? .preview
    }
    /// derive the display title for a tab (= file basename
    /// without the .md extension; = (see OOB.md #2026-09-03) — 'no .md extension either'). Placeholder tab = 'preview-sample' (= no .md extension,
    /// = no path = render the short placeholder name).
    ///
    @Environment(AppState.self) private var appState
    // EditorCounters (= the editor-zone live counter).
    @Environment(EditorCounters.self) private var editorCounters
    // WenshuEditorServicesFactory.make needs referenceLibraryRoot + active book
    // root. Both come from BookStore (= injected via .environment(bookStore) at
    // the WindowGroup root in App.swift + LibraryRootView, per fix pattern).
    @Environment(BookStore.self) private var bookStore
    // chapter-focus-lock 2026-09-28: editor flips to read-only when the user
    // has this tab focused AND the chat zone isn't visible (= the LLM is
    // rewriting this chapter). The chatVisible gate lives here because AppState
    // cannot hold @Environment-bound state (= WorkspaceUIState is
    // environment-injected per P2-06 split; = chatVisible moved from ShellState
    // to WorkspaceUIState in 2026-10-03 overabstraction cleanup).
    @Environment(WorkspaceUIState.self) private var workspaceUI

    // P2 #19 (WIRE-PARAGRAPH-002): live editor selection snapshot (= the text
    // the paragraph_ai buttons operate on). The markdown engine is an
    // NSViewRepresentable wrapping NSTextView; a real selection-bridge would
    // require an NSTextViewDelegate (= a separate ticket that the engine
    // doesn't expose yet). For this ticket we keep a View-local @State + a
    // public setter (= setSelection(_:)) that future wiring can call from the
    // engine's coordinator; today the buttons act on the whole draft when no
    // selection is reported (= matches the existing FormatToolbarButtons
    // fallback behavior).
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
    func setSelection(_ text: String) {
        selectedText = text
    }

    /// lookup the active tab's id (= the engine's
    /// `documentId` for undo + replacement scoping). Falls back to
    /// a deterministic placeholder id when no tab is open (=
    /// editor in initial state with no document).
    private var activeTabIdString: String {
        appState.openTabs.first(where: { $0.id == appState.activeTabId })?.id.uuidString
            ?? "wenshu-editor-no-tab"
    }

    // MARK: - SMC `header:` chrome band (= T-01) 28 PT Apple HIG
    // document-toolbar strip (= Pages / Numbers chrome idiom = title cluster
    // left + chrome-cluster right). Hosted inside `NativeTextViewWrapper`'s own
    // scrolled container (= the engine pins it; the NSTextView scrolls under
    // it). The title segment falls back to "Untitled" until chapter focus-lock
    // resolves (= same shape as SectionHeader but at toolbar height, not
    // 28+10+10 column-header height).
    private var editorChromeHeader: EditorHeaderView {
        EditorHeaderView(
            title: activeTabDisplayTitle,
            // Dirty-state marker (= the dot color follows the same state
            // machine as `EditorPersistence.handleDirtyTransition`): orange =
            // unsaved edits, gray = autosaving, red = external file change with
            // conflict. nil = clean (= no dot).
            dirtyState: isDirty ? .unsaved : nil,
            // Right-side chrome cluster. T-01 ships an autosave pulse (= a tiny
            // spinning icon while `tab.autoSaveTask` is active). Future T-N
            // tickets add code-block count, find- in-document badge, and the
            // spell-check toggle.
            chrome: editorChromeTrailingCluster
        )
    }

    /// Right-side chrome widget cluster (= the autosave pulse for now).
    /// Computed on every view body invocation (= cheap because each
    /// widget is just an SFIcon + .frame; = no business logic on the
    /// render path).
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

    /// Display title for the active editor tab (= shown in the chrome
    /// band's left cluster). Falls back to "Untitled" (= Apple HIG
    /// document-chrome no-document placeholder) until the tab's
    /// `documentPath` resolves. Mirrors the right-side tab strip
    /// title computation but uses a stable, never-empty string so
    /// the chrome band never shows a blank cluster.
    private var activeTabDisplayTitle: String {
        guard let tab = activeTab else { return String(localized: "editor.header.untitled") }
        let display = EditorTab.displayTitle(tab)
        return display.isEmpty ? String(localized: "editor.header.untitled") : display
    }

    /// SMC `placeholder:` slot (= ghost text shown while the document
    /// is empty; the engine hides it on first keystroke). Built once
    /// per SwiftUI body invocation (= cheap = a single
    /// NSAttributedString allocation).
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
    // Pages / Numbers / Keynote document chrome idiom). The bus is the same
    // instance the engine observes internally for selection- state events; =
    // posting here reaches the same listener chain the engine's coordinator
    // reads. We rebuild a fresh bus here (= not cached) because: 1.
    // `MarkdownEditorBus.buildWenshu()` is a single-screen object (= no
    // instance data); = rebuild cost = trivial. 2. The toolbar should NOT
    // survive the editor mount (= if the view is torn down, we want the toolbar
    // to drop too; = each view-body rebuild gets a fresh bus, = each button tap
    // hits the freshly- registered name). Why NOT cached (= one bus per view
    // life): the toolbar lives at the editor zone's outer VStack (= above the
    // scrollable area; = pinned). The NSTextView's view-of-engine never sees
    // this toolbar directly (= it lives outside the engine's `header:` slot for
    // exactly this reason: the toolbar must NEVER scroll away).
    private var editorFormatToolbar: EditorFormatToolbar {
        EditorFormatToolbar(
            bus: MarkdownEditorBus.buildWenshu(),
            // 2026-10-14: the previous `onSave` callback (= the
            // `tray.and.arrow.down` save button in the format toolbar's
            // trailing icon group) was dropped. Wenshu has a built-in autosave
            // mechanism (= the `EditorStatusBarView` shows the green "已保存"
            // indicator when the autosave task writes the active tab's draft to
            // disk; = the user can see the save state in the status bar at the
            // bottom of the editor zone; = a manual save button in the format
            // toolbar is redundant with the always-on autosave; = the boss
            // 2026-10-14 (see OOB.md #2026-10-14) was "因为我们有自动保存机制, 多余"). The
            // `private func saveDraft()` is still available (= Cmd+S menu
            // shortcut + Inspector "Save" button + future call sites can still
            // trigger it; = the helper is not removed because the autosave task
            // and Cmd+S still need it).
            onClose: {
                // per-tab close X uses). The active-tab id is a non-optional
                // `UUID` (= the wenshu standing convention; = the empty-state
                // has `openTabs = []` so we guard on the openTabs count instead
                // of the id).
                guard !appState.openTabs.isEmpty else { return }
                appState.closeTab(id: appState.activeTabId, bookStore: bookStore)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab strip = Safari-style multi-tab bar (Apple HIG tabbed-document
            // pattern). Replaces the ad-hoc HStack that previously showed only
            // the active tab (= boss OOB 2026-10-10 = match Safari behavior).
            // EditorTabStrip is a pure render surface (= 4 closures: onSelect /
            // onClose / onReorder). AppState stays the single source of truth
            // for openTabs + activeTabId (= the strip never holds a copy of the
            // data; = every binding flows through AppState). Drag-reorder feeds
            // back via the onReorder closure (= AppState.openTabs is rewritten
            // + persistOpenTabs fires from AppState's openTabs didSet = single
            // persistence path). Empty-state path (= openTabs.isEmpty = no tab
            // strip) is handled by EditorTabStrip internally (= the strip
            // renders EmptyView when tabs = []; = the editor zone shows its
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
                onReorder: { newOrder in
                    // Reorder AppState.openTabs to match the dragged drop
                    // order. AppState.openTabs's didSet (= on line 64 of
                    // AppState.swift) calls persistOpenTabs() which writes
                    // UserDefaults = the reorder is durable across app
                    // relaunch.
                    let reordered = newOrder.compactMap { id in
                        appState.openTabs.first(where: { $0.id == id })
                    }
                    appState.openTabs = reordered
                }
            )
            // dirty-discard confirm dialog. Shown when user tries to close with
            // unsaved changes. Apple HIG 2-option confirm pattern (=
            // destructive + cancel). showDirtyDiscardConfirm is now a computed
            // property; = wrap in Binding(get:set:) for .alert's isPresented:.
            .alert(String(localized: "workspace.editor.dirty_discard_alert_title"), isPresented: Binding(
                get: { self.showDirtyDiscardConfirm },
                set: { self.showDirtyDiscardConfirm = $0 }
            )) {
                Button(String(localized: "workspace.editor.dirty_discard_button"), role: .destructive) {
                    // tab close button: discard = close the tab (= auto-save
                    // guarantee: dirty drafts are thrown away because they
                    // explicitly chose 'Discard' in the confirm). closeTab
                    // handles cancel pending Task + stop watcher + skip the
                    // dirty-flush (since draft will be reset below).
                    if let tab = activeTab {
                        // Reset draft so closeTab's 'draft != originalBody'
                        // check is false (= we throw away the edits, NOT save
                        // them).
                        tab.draft = tab.originalBody
                        appState.closeTab(id: tab.id, bookStore: bookStore)
                    }
                }
                Button(String(localized: "button.continue_edit"), role: .cancel) { }
            } message: {
                Text(String(localized: "workspace.editor.discard_changes_confirm"))
            }

            // ed-smc-defaults T-02 (= format toolbar pinned above the typing
            // surface). 28 PT Apple HIG document-format toolbar (= bold /
            // italic / highlight / strikethrough / inline-code / heading /
            // blockquote / unordered-list / ordered-list / link / code- block /
            // horizontal-rule). Pinned at the editor zone's outer VStack (=
            // above the scrollable area; = never scrolls away with the
            // document; = canonical Pages / Numbers / Keynote document-toolbar
            // idiom). Why outside the engine's `header:` slot: the engine pins
            // its `header:` to the scrolled content (= scrolls with the
            // document). The format toolbar MUST stay visible while typing (=
            // formatting affects the selection; = the user has to see what mode
            // they're toggling); = a separately-pinned row in the outer VStack
            // is the right place. The engine's `header:` slot still hosts the
            // EditorHeaderView chrome band (= T-01; = title + dirty dot); = the
            // 2 chrome rows stack vertically above the NSTextView (= format
            // toolbar on top, then 28 PT chrome band, then the NSTextView).
            // RATIONALE: a 1 PT hairline separates the segmented control (=
            // above) from the format toolbar (= below); = the rectangle uses
            // `Color(nsColor: .separatorColor)` (= the AppKit canonical
            // hairline color; = the same color SwiftUI's `Divider()` uses
            // internally; = explicit 1 PT height because `Divider()` collapses
            // to 0 PT inside a `VStack(spacing: 0)`). 6 PT top padding
            // separates the hairline from the segmented control above (=
            // `spacingTight` = the wenshu canonical 6 PT tight inset; = the
            // user sees the hairline as a distinct separator rather than as
            // part of the segmented control's bottom border).
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
                .padding(.top, DesignTokens.spacingTight)
            // RATIONALE: 0 PT top padding (= `padding(.top, 0)`; = the user's
            // "工具栏上边距再-2" directive = 2 - 2 = 0 PT; = the format toolbar sits
            // flush with the 1 PT separator = the segmented control and the
            // toolbar form a single chrome band with a 1 PT internal hairline).
            editorFormatToolbar
                .padding(.top, 0)

            // Body: placeholder content. swaps this for swift-markdown rendered
            // Text when mode = .preview swaps for Apple TextEditor when mode =
            // .edit. RATIONALE: the `EditorStatusBarView` (= T-03 chrome band)
            // sits at the bottom of the outer VStack; = the body ZStack grows
            // with `.frame(maxHeight: .infinity, alignment: .top)`; = the
            // status bar is the canonical bottom-of-editor- column chrome
            // surface (= matches the wenshu 1:1 macOS Pages / Numbers format
            // toolbar + status bar rhythm). below the body, not at the bottom
            // of the editor zone. Result = a visible gap between the canvas and
            // the status bar. Apple HIG editor chrome recipe (= Pages / Numbers
            // / Xcode source editor) pins the body to the top of the available
            // height with `.frame(maxHeight: .infinity, alignment: .top)` — the
            // format toolbar stays at the top, the body fills the available
            // space (= the canvas paper stays flush with the toolbar, the rest
            // is below), and the status bar is pushed to the bottom of the
            // zone. = no manual Spacer, no .offset, no per-bar .padding-bottom
            // hack.
            ZStack {
                // preview mode uses swift-markdown (= AGENTS.md §11.1 pinned
                // 0.4.0) AttributedString render for
                // headers/bold/italic/lists/code/links, plus InternalLinkParser
                // (= wenshu's existing parser, = 1:1 Obsidian wikilink syntax)
                // to make [[name]] clickable. Placeholder sample body real
                // document load (= the Apple HIG DocumentGroup file-open path
                // is the ticket). (= (see OOB.md #2026-09-03) — 'preview BUG is
                // still there'): EditorView preview mode previously rendered
                // `Self.samplePreviewBody` (= static placeholder string)
                // regardless of which tab was active. Replaced with
                // `self.draft` (= per-tab computed property backed by
                // appState.openTabs[activeTabIdx].draft) so the preview shows
                // the active tab's content = when openCardInEditor
                // creates/updates a tab with the .md body read from disk, the
                // preview updates immediately. This is the root-cause fix (=
                // the closure chain WAS firing correctly; = the bug was the
                // view rendering the placeholder instead of the active tab).
                // (see OOB.md #2026-09-07) — 'delete': when no tab is open,
                // show the empty-state hint instead of the preview/edit body (=
                // replaces the previous samplePreviewBody placeholder).
                if activeTab == nil {
                    // Empty-state path: when no document is open, the page is a
                    // placeholder, not a rendered body. Top/bottom split =
                    // 50/50 with the top zone as the empty state (= the
                    // canonical Apple HIG empty-state shape). Migrate to the
                    // unified EmptyStateView (= 76 PT SF Symbols 6 icon +
                    // .regular weight = the canonical macOS 27 inspector icon
                    // weight; = standard title / body hierarchy). Same visual
                    // treatment as the 12 specialized tool tabs. Wrap the
                    // EmptyStateView in a vertical layout that pushes it to
                    // vertical center inside the upper half of the VSplitView
                    // (= the upper half keeps its 50/50 share with the chat
                    // zone; = the chat zone stays at full size below; = no
                    // VSplitView divider math bug; = the 'both zones should
                    // still be there, top/bottom 50/50, only the top becomes
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
                    // the markdown engine sitting on the white area. Paper
                    // width comes from measuring Pages on this machine: its
                    // canvas renders a 593 PT sheet, i.e. A4 (595 PT) at 100%.
                    // Wenshu uses the exact A4 width so a document lines up
                    // with what Pages would show.
                    EditorPaperCanvas {
                        Group {
                            // chapter-dialog 2026-09-28 T3: small inline banner
                            // above the editor when the LLM holds the cursor (=
                            // the wrapper cleared the focus lock + is mid-edit
                            // on this chapter). Apple HIG canonical "editing"
                            // affordance (= small label + spinner; = same shape
                            // as Pages' 'Saving...' badge). When the LLM edit
                            // completes, the wrapper restores the snapshot (=
                            // focusedChapterPath reverts = badge disappears,
                            // editor reloads with the LLM's changes).
                            if appState.focusedChapterPath != nil
                                && appState.focusedChapterPath == currentTabDocumentPath
                                && !workspaceUI.chatVisible {
                                ChapterFocusLockBadge()
                            }
                            if mode == .preview {
                        // (see OOB.md #2026-09-07) — 'editor, yes,
                        // shouldgroup': preview mode uses the SAME
                        // WenshuMarkdownEditor component as edit mode (=
                        // swift-markdown-engine NSTextView), just with
                        // `isEditable: false` (= read-only NSTextView).
                        // Previously preview used a separate
                        // EditorPreviewContent (= SwiftUI AttributedString
                        // renderer) which produced a different visual scale (=
                        // the "" described). Unified component = zero visual
                        // scaling between modes. wiki-link click navigation
                        // routes through the reference library + active book
                        // chapter lookup (= real target resolution). Engine's
                        // wiki- link click invokes `handlePreviewWikiLink` (=
                        // preview mode = read, = the click is the primary
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
                            // shouldgroup': preview mode = read-only NSTextView
                            // (= same engine wrapper as edit, = no scaling
                            // between modes).
                            isEditable: false,
                            // ed-smc-defaults T-01 (= Apple HIG
                            // document-toolbar strip): preview mode gets the
                            // chrome band above the typing surface (= the
                            // EditorHeaderView; = 28 PT Apple HIG
                            // document-toolbar idiom). Edit mode (=
                            // EditorEditContent) wires the same chrome in T-02
                            // (= its own booking; = preview-mode chrome first
                            // keeps this commit to 1 file + 1 file per Q112).
                            // RATIONALE: the document-title chrome header (=
                            // `EditorHeaderView` rendered with the title +
                            // bottom-divider) is removed from the white-paper
                            // canvas. SMC engine's `header:` slot) was visually
                            // redundant with the active tab's title in the
                            // `EditorTabStrip` (= the user already knows which
                            // tab is open; = the in-canvas title was a
                            // double-header). Drop the slot (= the `header:`
                            // parameter becomes `nil`; = SMC engine hosts no
                            // header; = the white paper starts at the format
                            // toolbar; = the document body content uses its own
                            // H1 inside the markdown (= the document body's own
                            // first- line H1 is the canonical page title; = the
                            // in-canvas title chrome is redundant with this
                            // H1)).
                            header: nil,
                            placeholder: editorEmptyDocumentPlaceholder
                        )
                    } else {
                        // edit mode uses Apple SwiftUI TextEditor (= HIG
                        // standard multi- line text input). @State draft holds
                        // the working copy; dirty detection = draft !=
                        // originalBody (character- level diff per per the
                        // design (= Apple HIG). Save button .tint highlights
                        // when dirty; Cmd+S hotkey (ticket 10) triggers save.
                        // draft is a computed property (= reads active tab).
                        // Wrap in Binding(get:set:) so EditorEditContent can
                        // still use @Binding draft (SwiftUI 2-way binding
                        // contract).
                        EditorEditContent(
                            draft: Binding(
                                get: { self.draft },
                                set: { self.draft = $0 }
                            ),
                            originalBody: originalBody,
                            onSave: { saveDraft() },
                            // chapter-focus-lock 2026-09-28: compute the
                            // single-focus predicate at the caller boundary (=
                            // no AppState / ShellState coupling inside the
                            // editor view). When the active tab's path matches
                            // AppState.focusedChapterPath AND the user isn't in
                            // chat, the editor flips to read- only so the LLM
                            // holds the cursor.
                            isChapterLockedByLLM: appState.focusedChapterPath != nil
                                && !workspaceUI.chatVisible
                                && appState.focusedChapterPath == currentTabDocumentPath,
                            // route live word count into shared
                            // AppState.editorWordCount (= chrome bottom-bar
                            // left field reads it). Recompute is per-
                            // keystroke; = Foundation-only = microseconds.
                            onWordCountChange: { count in
                                editorCounters.wordCount = count
                            },
                            // route dirty-state transitions dirty-state
                            // machine. Engine fires this once per transition (=
                            // no per- keystroke Task churn; = Apple HIG
                            // TextEdit / Pages behavior). editor-mvvm T2b:
                            // dirty-state machine lives in
                            // `EditorPersistence.handleDirtyTransition(...)`.
                            onDirtyChange: { newDirty in
                                if let tab = activeTab {
                                    EditorPersistence.handleDirtyTransition(newDirty, tab: tab, bookStore: bookStore)
                                }
                            },
                            // pre-built markdown engine configuration. Built
                            // once per active-tab switch (= rebuilds the
                            // WikiLinkResolver + ImageProvider against the
                            // active book's path). Engine configuration is
                            // captured by the editor view (= stable across
                            // onChange of draft). ticket-id (history)-B: pass
                            // bookStore directly; factory handles nil (= the
                            // path that survives the AnyView-wrapped EditorView
                            // when the environment chain hasn't propagated
                            // BookStore yet on early zone activation).
                            configuration: WenshuEditorServicesFactory.make(
                                bookStore: bookStore,
                                // per-active-tab bus so engine format / find /
                                // replace events stay scoped to this document.
                                bus: MarkdownEditorBus.buildWenshu()
                            ),
                            // stable per-tab id, passed to engine as
                            // `documentId` so undo + pending replacements are
                            // scoped to this tab.
                            draftId: activeTabIdString,
                            // forward engine wiki-link click to the navigation flow.
                            onLinkClick: { linkId in
                                handleEditorWikiLink(linkId: linkId)
                            },
                            // ed-smc-defaults T-02: forward the chrome band +
                            // placeholder (= same shape the preview- mode site
                            // forwards in T-01). RATIONALE: boss visual diff
                            // 2026-10-13 — drop the `editorHeader` chrome band
                            // here too (= same reason as the preview-mode
                            // patch: the `EditorTabStrip` already shows the
                            // active tab title; = the in-canvas title was a
                            // double-header). The `editorHeader: nil` keeps the
                            // `EditorEditContent` API surface unchanged but the
                            // rendered chrome is gone (= the white paper starts
                            // at the format toolbar; = the document body's own
                            // H1 is the canonical title).
                            editorHeader: nil,
                            editorPlaceholder: editorEmptyDocumentPlaceholder,
                            // T-03: wire caret-rect callback so the status bar
                            // can show the live cursor position (= writes the
                            // live caret rect to the active tab's `cursorRect`
                            // field; = the status bar reads it back via
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
            // outer VStack (= the wenshu 1:1 macOS Pages / Numbers editor
            // chrome recipe; = the canvas grows to fill the available space via
            // `.frame(maxHeight: .infinity, alignment: .top)`; = the status bar
            // is the single source of truth for the live cursor position +
            // auto-save state). The editor zone uses the sibling-of-body VStack
            // pattern the outer VStack (= the status bar takes up vertical
            // space in the layout; = the body ZStack's available height = zone
            // - toolbar - status bar; = the body ZStack is squashed; = the
            // paper's intrinsic 842 PT A4 sheet overflows the squashed body
            // ZStack and the user perceives the paper "floating in the upper
            // half"). The chat pattern is what we want — FLOAT the status bar
            // over the body ZStack via `.safeAreaInset(edge: .bottom, spacing:
            // 0) { EditorStatusBarView }`. Move the `EditorStatusBarView(...)`
            // call OUT of the outer VStack siblings (= drop it from the outer
            // VStack entirely) and add the `.safeAreaInset(edge: .bottom,
            // spacing: 0) { EditorStatusBarView(...) }` modifier to the body
            // ZStack. The body ZStack's available height = zone - toolbar - tab
            // strip (= the body ZStack fills the remaining height; = the
            // paper's 842 PT A4 sheet has the full body ZStack to render into;
            // = the paper's bottom overflows the body ZStack and the inner
            // `EditorPaperCanvas` ScrollView scrolls naturally). The status
            // bar's `.safeAreaInset` placement (= the chat pattern)
            // automatically pushes the body ZStack's content area up by the
            // status bar's height (= Apple HIG `.contentMargins(.bottom,
            // statusBarHeight, for: .scrollContent)` semantics baked into
            // `.safeAreaInset(edge: .bottom)`), so the last line of the
            // document peeks behind the floating status bar (= the Pages /
            // Numbers inspector- status-row pattern, = the same as the chat
            // input bar pattern). Also drop the `.frame(maxHeight: .infinity,
            // alignment: .top)` on the body ZStack (= the round-1 fix that made
            // the body ZStack fill the editor zone; = with the status bar as a
            // `.safeAreaInset` overlay instead of a VStack sibling, the body
            // ZStack is naturally laid out by SwiftUI at the height of its
            // content; = the body ZStack's content = `EditorPaperCanvas`'s 842
            // PT A4 paper (= ScrollView's intrinsic content size); = the body
            // ZStack does NOT need to be told to fill the zone; = let SwiftUI's
            // natural layout = body ZStack = 842 PT (= the A4 sheet's intrinsic
            // size); = the parent zone's remaining height (= zone - tab strip -
            // toolbar - 842) is left empty below the paper (= the natural
            // SwiftUI behavior for a ZStack whose content is shorter than the
            // available height; = the user perceives a "page" that has chrome
            // above and white space below, = the canonical Pages document
            // surface recipe). T-03: editor status bar (= the bottom chrome
            // band of the editor zone; = 24 PT; = pinned below the NSTextView;
            // = the format toolbar is above and the status bar is below = the
            // canonical Pages / Numbers 3-chrome-band layout = header / toolbar
            // + body / status). Live word count / cursor location / autosave
            // state (= the bar is a dumb renderer; = the parent supplies the 4
            // closures; = the bar re-evaluates them on every body invocation =
            // the standard SwiftUI re-render cadence = no manual subscription
            // needed).
            .safeAreaInset(edge: .bottom, spacing: 0) {
                EditorStatusBarView(
                    textProvider: { self.draft },
                    isDirtyProvider: { self.isDirty },
                    isAutosavingProvider: { self.isAutosaving }
                )
            }
            // drop the outer VStack's `.frame(maxWidth: .infinity, maxHeight:
            // .infinity)`. Apple HIG canonical 6-zone layout has no custom
            // frame on the column body (= NavigationSplitView owns the
            // natural-width algorithm). The previous fix (which kept this frame
            // in to "prevent window shrink") inflated the detail column to 1763
            // because WenshuMarkdownEditor's NSTextView intrinsic width is
            // unbounded. Removing this frame is what the canonical 6-zone probe
            // (= window 1449, detail 648) requires. The window-shrink
            // protection has to come from elsewhere (= .frame on toolbar /
            // status bar, not on the column body). -m1-shell: RESTORE
            // `.frame(maxWidth: .infinity, maxHeight: .infinity)` on the outer
            // VStack because the detail column is now hosted by
            // `EditorChatNSController` (= AppKit NSSplitViewController, NOT
            // NavigationSplitView; = see NavigationSplitShell.swift detail
            // column closure). NSSplitViewController allocates a fixed-size
            // slot per NSSplitViewItem and the SwiftUI view inside the
            // NSHostingController must explicitly claim that slot via
            // `.frame(maxWidth: .infinity, maxHeight: .infinity)`. Without this
            // frame, the editor VStack shrinks to its intrinsic content width
            // (= the WenshuMarkdownEditor NSTextView's minimum width = ~400 PT;
            // = leaves the right side of the detail column empty (= the 'width
            // didn't fill' symptom). The 'inflated the detail column to 1763'
            // concern (= caused by the previous NavigationSplitView layout) no
            // longer applies because NSSplitViewController does not have the
            // unbounded-width issue (= NSSplitViewItem gives a bounded slot).
            // (see OOB.md #2026-09-10) — 'width didn't fill' (= 'width did not
            // fill').
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Liquid Glass adaptation: zone top/bottom bars + backgrounds +
            // colors use `.ultraThinMaterial` instead of
            // `Color.green.opacity(0.05)` (= solid green placeholder is
            // inconsistent with the Liquid Glass design language). Editor zone
            // has no: drop .background(.ultraThinMaterial) (= was adding glass
            // material over the editor zone = visually distinct from the chat
            // zone's plain background). Editor zone now has no injected
            // background (= inherits from the column = no nested layering).
        }
        // on editor zone mount, seed AppState.editorWordCount with the
        // character count of the initial body (= sample body in placeholder
        // mode; = real document body once the editor wiring lands). Without
        // this, the chrome bottom- bar left field shows "Word count: 0" even
        // when the preview-mode sample body has 200+ chars. The .onChange(of:
        // draft) inside EditorEditContent covers the edit- mode keystroke
        // stream; = this .onAppear covers the initial state (= Apple HIG = seed
        // reactive state at view mount).
        .onAppear {
            // (see OOB.md #2026-09-07): do NOT seed a placeholder tab when
            // openTabs is empty. Two paths from here: 1. Persisted tabs (loaded
            // by AppState.init from UserDefaults) → use those directly. 2. No
            // persisted tabs → editor zone shows the empty-state hint (=
            // "libraryin progressdouble-clickcardopen") via EditorView's
            // nil-activeTab branch. The .edit-mode upgrade from .preview still
            // runs for any tabs that survived (= the canonical pre- extended
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
            // placeholder mode; = no-op). The watcher auto-reloads draft when
            // the file changes externally (= agent write, git pull, terminal
            // `echo > file.md`, etc.). editor-mvvm T2b:
            // `EditorPersistence.reloadFromDisk` returns the new content +
            // conflict notice (= the helper is pure; = it doesn't mutate tab
            // fields). The view writes the results back to the active tab +
            // updates the word-count badge. This keeps the disk-IO +
            // state-write paths in lockstep at the call site (= easy to audit).
            if let tab = activeTab {
                EditorFileWatcher.start(
                    path: tab.documentPath,
                    tab: tab,
                    onChange: { [self] in reloadFromDiskAndApply() }
                )
            }
        }
        // 'chattop bar 3 tab, editortop bar ': REVERTED (= (see OOB.md
        // #2026-09-08) follow-up 'yes, don't , info, default editorshould MD
        // tab'). The welcome tab was visually present but the preview body was
        // empty (= no document content to render). The editor zone to show NO
        // tab strip at all when there are no persisted tabs (= the empty-state
        // hint takes the full editor body = cleaner empty UX than a blank tab +
        // blank content). .onAppear { appState.ensureWelcomeTabIfEmpty() } tear
        // down the file watcher when the view goes away (= prevents zombie
        // DispatchSource holding the file descriptor). editor-mvvm T1b:
        // delegate to EditorFileWatcher (= the extracted helper owns the fd +
        // cancel lifecycle).
        .onDisappear {
            if let tab = activeTab {
                EditorFileWatcher.stop(tab: tab)
            }
        }
    }

    // edit-mode state owner. Both fields initialise from the sample preview
    // body (= placeholder until the editor wiring lands the real document
    // load). dirty = draft != originalBody (= ticket 08 reads this for the Save
    // button's .tint highlight). per-tab state lives on
    // AppState.openTabs[activeTabIndex]. EditorView reads/writes the ACTIVE tab
    // (= single source of truth). These computed properties expose the per-tab
    // state to the rest of the view (= the @State versions are gone; =
    // switching tabs switches the active data set; = matches Safari behavior).
    private var activeTab: EditorTab? {
        guard let idx = appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId }) else { return nil }
        return appState.openTabs[idx]
    }
    private var activeTabIndex: Int? {
        appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId })
    }

    // chapter-focus-lock 2026-09-28: convenience accessor for the single-focus
    // lock predicate (= AppState.focusedChapterPath vs the active tab's path).
    // Mirrors what AppState already computes, but here at the call site we can
    // also gate on shellState.chatVisible (= the LLM-can-edit gate).
    private var currentTabDocumentPath: String? {
        activeTab?.documentPath
    }

    private var draft: String {
        // (see OOB.md #2026-09-07): when no tab is open, return empty string (=
        // no samplePreviewBody placeholder). The editor zone shows its empty-
        // state hint (= "libraryin progressdouble-clickcardopen") via
        // EditorView's nil-activeTab branch.
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
    /// Computed dirty flag (= the Save
    /// button's .tint highlight). Plain computed (= re-evaluated on
    /// each render from the active tab's draft / originalBody).
    private var isDirty: Bool {
        guard let tab = activeTab else { return false }
        return tab.draft != tab.originalBody
    }
    /// T-03: cursor rect accessor (= returns the active tab's
    /// live caret rect = the engine posts this via
    /// `onCaretRectChange`; = the tab caches it; = this getter
    /// returns the cached value). nil = no caret yet (= the user
    /// hasn't focused the editor).
    private var cursorRect: CGRect? {
        activeTab?.cursorRect
    }
    /// T-03: autosave-in-progress accessor (= true while a save
    /// task is in flight; = the tab's autoSaveTask is the
    /// canonical source = its presence = "saving").
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
    /// per-tab file-system watcher state
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
    /// Per-tab dirty-discard alert state.
    private var showDirtyDiscardConfirm: Bool {
        get { activeTab?.showDirtyDiscardConfirm ?? false }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].showDirtyDiscardConfirm = newValue
        }
    }
    // save action writes draft back over originalBody (= dirty detection
    // clears). When documentPath is non-nil (= the ticket 027-35 wires real
    // document load), also write to disk (= atomic UTF-8 = Apple HIG file write
    // pattern). Cmd+S hotkey (canonical surface) and Save toolbar button both
    // call this directly. editor- mvvm T2b: disk IO + dirty state machine
    // migrated to `EditorPersistence`. `saveDraft` is now a 3-line thin call
    // site (= wire originalBody = draft → write to disk → mark clean).
    private func saveDraft() {
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

    // editor-mvvm T2b: `EditorPersistence.reloadFromDisk` returns the new
    // content + conflict notice as a struct (= the helper is pure). This
    // view-side wrapper writes the results back to the active tab + updates the
    // word-count badge + marks the document clean. Called from the
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
    // `EditorPersistence.save(tab:bookStore:)`. See
    // `Sources/WenshuApp/Editor/EditorPersistence.swift` (= the single owner of
    // the 3 disk-IO paths: existing documentPath, propose new path + auto-bind,
    // /tmp fallback). The view's `saveDraft()` (= Cmd+S + Save toolbar button
    // entry point) is now a thin call site above.

    // Handle a preview-mode wiki-link click.
    /// Looks up the display name in the reference library first
    /// (= library-public entities), then in the active book.
    /// On hit, opens the target as a new tab and switches to it.
    private func handlePreviewWikiLink(displayName: String) {
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

    /// handle a wiki-link click from the live
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
    /// Pipeline (= matches the spec):
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
    /// @MainActor (= EditorView is a SwiftUI View; = the
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

        let providerSlug = UserDefaultsStore.shared.string(forKey: .llmActiveConnector, fallback: "anthropic")
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
            // S4 graceful degradation: log + no-op. The wenshu-dev user sees
            // the underlying failure via Console.app; the in-app UX stays
            // unbroken (draft unchanged, buttons re-enabled by the defer
            // above).
            wenshuLogger.info("[wenshu.editor] applyParagraphAI(\(transform.rawValue)) failed: \(String(describing: error))")
        }
    }

    /// P2 #19: replace the current selection (= today: whole
    /// draft) with the supplied text. Once the engine selection
    /// bridge lands, this becomes a surgical NSRange replace
    /// (= same signature; only the body changes).
    private func replaceSelectedText(with newText: String) {
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

    // MARK: - B-23 file-system watcher editor-mvvm T1b: the DispatchSource
    // lifecycle (= fd open + event handler + cancel + close) migrated to
    // `EditorFileWatcher` (= v0.34 B-23 inline implementation is gone). The
    // view passes `tab.documentPath` + the `reloadDocumentFromDisk` closure to
    // `EditorFileWatcher.start(...)` when the active tab changes / the view
    // appears (= see the `.onChange { }` + `.onDisappear { }` blocks in `body`
    // above). The `tab.fileWatcher` + `tab.watchedFD` fields stay on
    // `EditorTab` (= the helper writes them; = future inspection hooks can
    // still read them).

    // editor-mvvm T2b: `reloadDocumentFromDisk()` migrated to
    // `EditorPersistence.reloadFromDisk(tab:)` returning a struct (= the helper
    // is pure; = doesn't mutate tab fields). The view-side wrapper
    // `reloadFromDiskAndApply()` (= above) is the `onChange` closure that gets
    // called by `EditorFileWatcher` (= v1.70 T1a) when an external file change
    // is detected. It writes the helper's result back to the active tab +
    // updates the word-count badge + marks the document clean.

    // editor-mvvm T2b: `handleDirtyTransition(_:)` migrated to
    // `EditorPersistence.handleDirtyTransition(_:tab:bookStore:)`. The 3-second
    // debounce Task + cancellation + idempotent cycle end (= autoSaveTask = nil
    // after firing) live in the helper. The view's call sites (= discard button
    // + onDirtyChange closure + reloadFromDiskAndApply wrapper + saveDraft
    // wrapper) are all 1-liners that hand off to the helper.

    // documentPath + autoSaveTask + externalChangeNotice +
    // showDirtyDiscardConfirm are now computed properties (= read/ write the
    // active tab's state via AppState). Defined above as part of the per-tab
    // state migration; = these View-local @State duplicates would shadow the
    // active-tab reads. editor-mvvm T1b: `fileWatcher` + `watchedFD` removed
    // from this view (= lifecycle is now `EditorFileWatcher`'s responsibility;
    // = the helper writes them on `tab.*` directly).

    // close handler. If dirty = present confirm dialog; if clean = close
    // immediately (= Apple HIG standard). Cmd+W (ticket 10) routes through this
    // same method. (see OOB.md #2026-09-07) — 'delete': samplePreviewBody (=
    // the "Welcome to wenshu" placeholder) is removed. When no tab is open, the
    // editor zone shows the empty-state hint via `emptyStateHint` (= tells the
    // user to double-click a card in the material library). Persisted open tabs
    // (= loaded from UserDefaults by AppState.init) skip this hint entirely.
    // ticket-id (history) (preserved as comment for historical reference):
    // sample markdown body shown in preview mode exercised header levels,
    // bold/italic, bullet list, inline code, code fence, [[wikilink]] (= parsed
    // by InternalLinkParser). The v0.40 apple-001 UX cleanup replaced its CJK
    // content with an onboarding welcome. Now removed entirely per (see OOB.md
    // #2026-09-07).

    /// Empty-state hint when no editor tab is open (= columns-workspace-CTA shape).
    /// The computed var returned the empty-state hint when no
    /// editor tab was open. The earlier `emptyStateHint` call site
    /// was removed in the samplePreviewBody cleanup (= the editor
    /// zone now uses an inline empty-state directly via the
    /// empty-tab guard in `body`); = no behavior change; = 28 LOC
    /// removed including the long Apple HIG empty-state docstring
    /// preserved as historical note).

    // placeholder type alias for the wikilink navigation closure (= the
    // wikilink routing lands in a follow-on surface).
}
