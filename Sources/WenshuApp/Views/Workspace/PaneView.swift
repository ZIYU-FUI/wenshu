// Sources/WenshuApp/Views/Workspace/PaneView.swift
//
// The per-pane registry helper used by `TabContentDispatcher`.
// Per (see OOB.md #2026-10-03) '' OOB (= strip wenshu-summary
// layers that conflate with the Apple-canonical shape), the
// legacy 'Zone' prefix was retired (= this view hosts 1 pane of
// the multi-column layout, not 1 of the legacy 6 zones).
//
// `PaneViewTests.swift` covers the surface.

import SwiftUI
import MarkdownEngine

/// Per-pane view (= 1 module rendered in 1 pane of the
/// `NavigationSplitView` column layout). The `zoneSlot` enum
/// drives the dispatcher (= which pane hosts which module per
/// `LayoutTreeStore`).
struct PaneView: View {
    let zoneSlot: TabKind

    /// bindings passed from WorkspaceView so sidebar category
    /// selection → preview pane can react (= same Binding reference).
    /// Default value `nil` (= for non-workspace callers that don't
    /// drive the preview pane).
    @Binding var selectedEntityCategory: EntityCategory?
    @Binding var selectedEntity: Reference?

    /// (= option A):
    /// AppState is the global @Observable source of truth.
    /// PaneView reads it directly (= no @Binding chain).
    @Environment(AppState.self) private var appState
    // sidebarSelection moved from ShellState to WorkspaceUIState.
    @Environment(WorkspaceUIState.self) private var workspaceUI

    /// -fix (= (see OOB.md #2026-09-03) — 'PreviewPane double-click
    /// did not open the document'):
    /// PaneView also needs BookStore to read reference bodies
    /// (= same as WorkspaceView's openCardInEditor). Injected via
    /// the existing .environment(bookStore) call sites in App.swift
    /// + LibraryRootView.
    @Environment(BookStore.self) private var bookStore

    /// computed preview scope (= mirrors
    /// WorkspaceView's `previewScope`; duplicated here to keep
    /// PaneView self-contained without threading the scope
    /// through WorkspaceView → PaneView via another binding).
    private var previewScope: PreviewScope {
        guard let item = workspaceUI.sidebarSelection else { return .empty }
        switch item {
        case .book(let bookId):
            return .bookScope(bookId: bookId, folderName: nil)
        case .folder(let bookId, let folderName):
            return .bookScope(bookId: bookId, folderName: folderName)
        case .shelf(let shelfId):
            return .shelfScope(shelfId: shelfId)
        case .referenceCategory(let dirName):
            if dirName == "__root__" {
                return .referenceScope(nil)
            }
            let upper = dirName.uppercased()
            if dirName == "其它" {
                return .referenceScope(.z)
            }
            if let raw = EntityCategory(rawValue: upper) {
                return .referenceScope(raw)
            }
            return .referenceScope(nil)
        case .tag:
            // v2.6 facet model: tag selection maps to the reference
            // library root with the active tag-filter applied (= the
            // preview pane reads shell.activeTagFilter to scope).
            return .referenceScope(nil)
        }
    }

    /// default initializer for non-workspace callers.
    /// (= pass dummy constants explicitly, see RegisteredPanes.swift)
    init(
        zoneSlot: TabKind,
        selectedEntityCategory: Binding<EntityCategory?> = .constant(nil),
        selectedEntity: Binding<Reference?> = .constant(nil)
    ) {
        self.zoneSlot = zoneSlot
        self._selectedEntityCategory = selectedEntityCategory
        self._selectedEntity = selectedEntity
    }

    var body: some View {
        switch zoneSlot {
        case .projectSidebar:
            // Old 6-zone projectSidebar = 1 tab (Bookshelf, with
            // book-open icon) + trailingButton (New + Import =
            // preserved from the pre-v1.69e legacy
            // NewLibraryOutlineView.zoneHeaderButtons).
            // (see OOB.md #2026-08-31) — PaneView forwards its
            // sidebarSelection binding to AppleSidebarView so
            // the sidebar click → preview pane scope works.
            ZoneContentView(tabs: [
                (String(localized: "tab.title.bookshelf"), "book-open", AnyView(AppleSidebarView())),
            ], trailingButton: AnyView(SidebarZoneHeaderButtons()))

        case .projectPreview:
            // Old 6-zone projectPreview = 2 tabs (Preview / Map).
            // Book-open-check + waypoints.
            // followup UX round 24: preview tab content uses
            // .ultraThinMaterial (= was DesignColor.zoneSurface =
            // solid Color(nsColor: .controlBackgroundColor) = NOT
            // Liquid Glass).
            //
            // (see OOB.md #2026-08-31) — PaneView is the LEGACY
            // pane registry path (= RegisteredPanes.swift). Callers
            // don't pass a sidebarSelection binding (= they have no
            // concept of book folder scoping), so this preview pane
            // defaults to .empty scope (= empty state). The active
            // WorkspaceView path uses PreviewPane directly with the
            // computed previewScope (= supports all 4 sidebar scopes).
            //
            // (see OOB.md #2026-09-07) — the search bar belongs
            // BELOW the ZoneContentView's tab strip (= inside
            // PreviewPane's body, = first element rendered after the
            // tab strip). Removed the previous commit's VStack
            // wrapper (= was ABOVE the tab strip, = wrong position).
            // Search bar now lives inside PreviewPane.body (= same Y
            // as the editor's pencil/arrow toolbar inside
            // EditorView).
            ZoneContentView(tabs: [
                (String(localized: "tab.title.preview"), "book-open-check", AnyView(PreviewPane(
                    scope: previewScope,
                    // fix (= (see OOB.md #2026-09-03) — 'double-clicking card did
                    // not open the document'): PaneView's caller
                    // L561 is the ACTIVE path (= not WorkspaceView's
                    // caller L355 which is dead code). Route
                    // double-click to PaneView's own openCardInEditor
                    // (= same logic as WorkspaceView's; = the shared
                    // service land in a follow-on surface).
                    //
                    // 2026-09-03 follow-up: explicitly call
                    // `self.openCardInEditor()` (= Swift strict
                    // capture requirement = PreviewPane's
                    // @escaping closure captured `self` implicitly,
                    // and the implicit `openCardInEditor()`
                    // resolution went to the wrong scope = the
                    // closure ran but the method was not resolved
                    // to PaneView). Explicit `self.` fixes the
                    // resolution.
                    onDoubleClick: { source in
                        // (see OOB.md #2026-09-08) — 'clicking the Dufu card opens a
                        // tab with wrong name': forward the clicked
                        // CardSource to openCardInEditor.
                        self.openCardInEditor(source: source)
                    },
                    previewSortOrder: .constant(.pinyinFirstLetter)
                ))),
                (String(localized: "tab.title.graph"), "waypoints", AnyView(GraphView())),
            ])

        case .specializedTools:
            // 5 tabs (Foreshadowing / Placeholder /
            // LongFormGuardrails per P1 ticket #6
            // [WIRE-SPECIALIZEDTOOLS-001] 2026-09-04 +
            // ReaderExperience per P1 ticket #7
            // [WIRE-SPECIALIZEDTOOLS-002] 2026-09-04 +
            // PlotThread per P1 ticket #8
            // [WIRE-SPECIALIZEDTOOLS-003] 2026-09-04).
            // 
            // fixed the stale "Old 6-zone specializedTools = 4 tabs"
            // comment (= current code has 5 tabs at L774-778 below;
            // the previous docstring described the pre-PlotThread state).
            ZoneContentView(tabs: [
                (String(localized: "tab.title.foreshadowing"), "git-fork", AnyView(ForeshadowingView())),
                (String(localized: "tab.title.placeholder"), "square-dashed", AnyView(PlaceholderView())),
                (String(localized: "tab.title.long_form"), "shield-check", AnyView(LongFormGuardrailsView())),
                (String(localized: "tab.title.reader_experience"), "sparkles", AnyView(ReaderExperienceView())),
                (String(localized: "tab.title.plot_thread"), "git-branch", AnyView(PlotThreadView())),
            ])

        case .aiDynamic:
            // DynamicZoneView owns its own DynamicZoneTabBar
            // (Progress / Todo / Search).
            DynamicZoneView()

        case .aiChat:
            // ChatView + PaneTabBar for the single chat tab.
            // Top icons are Bot + Inbox.
            ChatView()

        case .editor:
            // Editor pane: 2 tabs (Edit / Outline) + trailing
            // expand/shrink button. Backlinks surfaced via the
            // chrome bottom-right "Backlinks 0" label click.
            // Book-open-text + puzzle + link.
            ZoneContentView(
                tabs: [
                    // fix (= (see OOB.md #2026-09-02) — 'git grep BEFORE patch'
                    // rule): see L279 fix comment above; replace
                    // placeholder with EditorView (= the toolbar +
                    // mode toggle surface).
                    (String(localized: "tab.title.editor"), "book-open-text", AnyView(EditorView())),
                    (String(localized: "tab.title.outline"), "puzzle", AnyView(OutlinePanel())),
                    // removed the "Backlinks" tab here (= (see OOB.md #2026-09-02) — 'the Backlinks
                    // area still has to be removed'). Backlinks are
                    // now surfaced via the chrome bottom-right
                    // "Backlinks 0" label click → popover (= spec
                    // user stories 8 + 11).
                ],
                // (= the trailing button surface): expand/shrink
                // teb' = won't be a tab (= no selected underline), just
                // a button at the right edge of the tab bar.
                trailingButton: AnyView(
                    EditorExpandShrinkTrailingButton()
                )
            )
        }
    }

    /// -followup (= (see OOB.md #2026-09-03) — 'fix it until I can
    /// use it'): PaneView needs its own openCardInEditor
    /// (= WorkspaceView's openCardInEditor is in a DIFFERENT
    /// struct = can't share via this same View type).
    /// Code is mostly duplicated from WorkspaceView's openCardInEditor
    /// + the book-scope branch reads the actual .md file (= same walk
    /// As `PreviewPane.loadBookDocs`; the shared service lands in a follow-on surface.
    /// helper into a workspace-level BookDocLoader service so both
    /// callers share it).
    /// (see OOB.md #2026-09-08) — 'clicking the Dufu card opens a
    /// tab with wrong name' (= clicking the card opened a new tab
    /// named 'preview-sample'):
    /// the previous version took no arguments and used
    /// `filtered.first` (= always the topmost card, not the actually
    /// clicked one). New version accepts an OPTIONAL `source`
    /// (= the actually-clicked CardSource from PreviewPane) and
    /// uses IT (= not `filtered.first`) to open the right .md.
    ///
    /// Signature: `source: CardSource?` (= optional for backward
    /// compat with the v0.34 callers that haven't migrated yet).
    /// For the new PreviewPane callers (the post-fix wiring), the
    /// source is always supplied.
    ///
    /// thin wrapper over `CardOpenOps` (=
    /// the dedup + EditorTab + activeTabId mutation shared with
    /// WorkspaceView + ShellMiddleColumn). The reference-scope +
    /// bookDoc-deferred path delegates to `CardOpenOps
    /// .computeCardTriad`; the book-scope file-scan (= walk
    /// shelves/<shelf-uuid>/books/<book-uuid>/<folder>/*.md)
    /// stays in the View because it's specific to PaneView
    /// The shared tail (= canonical surface).
    /// (= dedup + tab creation + activeTabId mutation) delegates
    /// to `CardOpenOps.openTab`.
    private func openCardInEditor(source: CardSource? = nil) {
        // 2026-10-14 v7 (= the boss
        // 2026-10-14 "我双击的
        // 是卡片，这个卡片
        // 的文档目录和文档
        // ID，就应该在卡
        // 片上带的吗 / 无
        // 论我选的是哪个
        // 目录，和我双击
        // 卡片有啥关系"
        // root-cause insight): the
        // double-click handler
        // must NOT route through
        // the sidebar's
        // `previewScope` (= the
        // `WorkspaceUI.previewScope`
        // value the sidebar
        // drives from the user's
        // row selection). The
        // `CardSource` passed in
        // by the double-click
        // carries the
        // source-of-truth
        // identity for the doc
        // (= `BookDoc.id` is a
        // UUID v5 of the file
        // path; = `Reference.id`
        // is the reference's own
        // UUID; = each source
        // self-identifies). The
        // sidebar scope is only
        // relevant for the
        // middle-column card
        // grid rendering
        // (= which docs to
        // LIST in the middle
        // column), NOT for the
        // double-click → editor
        // pipeline (= which doc
        // to OPEN in the
        // editor). The previous
        // `switch scope` router
        // (= .referenceScope /
        // .bookScope /
        // .shelfScope /
        // .tagScope branches)
        // made the open-tab
        // behavior a function of
        // the sidebar row
        // selection (= a
        // side-channel input
        // the user does not
        // control when
        // double-clicking a
        // card; = the user saw
        // the editor open a
        // doc that is NOT the
        // one they clicked; = the
        // boss 2026-10-14
        // "不好用" / "卡
        // 片的文档目录
        // 和文档 ID
        // 就应该在
        // 卡片上带
        // 的" root
        // cause). The
        // `CardSource`-driven
        // rewrite below makes
        // the editor open EXACTLY
        // the doc the user
        // double-clicked, regardless
        // of the sidebar row the
        // user happened to have
        // selected.
        let triad: CardOpenOps.CardTriad
        if let source {
            // 2026-10-14 v7: the
            // double-click source
            // (= `BookDoc` or
            // `Reference`) is the
            // canonical identity.
            // Route through
            // `CardOpenOps.computeCardTriad`
            // (= the shared
            // v2.7-round-66 commit
            // H resolution; =
            // `BookDoc` → full
            // body via
            // `loadBookDoc`; =
            // `Reference` → full
            // body via
            // `loadReferenceBody`;
            // = both return
            // the on-disk file
            // path as the
            // `CardTriad.path`;
            // = the editor's
            // auto-save writes
            // to the canonical
            // file).
            triad = CardOpenOps.computeCardTriad(
                source: source,
                previewScope: .bookScope(
                    bookId: UUID(),
                    folderName: ""
                ),
                bookStore: bookStore
            )
            // The
            // `previewScope`
            // arg above is
            // only a routing
            // hint for the
            // reference-tag /
            // shelf-fallback
            // paths inside
            // `computeCardTriad`;
            // = the
            // `.bookScope`
            // branch is the
            // only one that
            // reads the
            // `source.bookDoc`
            // payload;
            // = the
            // placeholder
            // bookId is
            // ignored
            // (= the
            // BookDoc
            // carries
            // its own
            // bookId
            // via
            // source).
        } else {
            // No source (= the
            // caller tapped the
            // empty area of
            // the middle
            // column; = rare
            // fallback; = the
            // previous v0.34
            // PaneView's
            // behavior was
            // to surface a
            // "pick a card"
            // empty-state
            // hint). The
            // sidebar scope
            // is only consulted
            // in this
            // fallback path
            // (= a caller with
            // no `source` arg
            // gets the
            // scope-based
            // placeholder).
            switch previewScope {
            case .referenceScope:
                triad = CardOpenOps.computeCardTriad(
                    source: nil,
                    previewScope: previewScope,
                    bookStore: bookStore
                )
            case .bookScope(let bookId, let folderName):
                triad = scanFirstBookDoc(
                    bookId: bookId, folderName: folderName
                )
            case .shelfScope(let shelfId):
                triad = scanFirstBookDocInShelf(shelfId: shelfId)
            case .empty, .tagScope:
                triad = CardOpenOps.CardTriad(
                    path: nil, content: "", title: ""
                )
            }
        }
        _ = CardOpenOps.openTab(
            triad: triad,
            previewScope: previewScope,
            appState: appState
        )
    }

    /// Local book-doc scan (= unchanged from the pre-v1.74 inline
    /// implementation; = see the v0.34 B-25-followup doc comment
    /// on `openCardInEditor` above for the full history). Walks
    /// `shelves/<shelf-uuid>/books/<book-uuid>/<folder>/*.md` and
    /// Picks the FIRST .md (= the canonical placeholder surface;
    /// will wire to the SPECIFIC card the user double-clicked).
    private func scanFirstBookDoc(bookId: UUID, folderName: String?) -> CardOpenOps.CardTriad {
        let shelvesRoot = bookStore.stores.shelvesRoot
        let bookDirs: [URL] = {
            guard let shelfDirs = try? FileManager.default.contentsOfDirectory(
                at: shelvesRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return shelfDirs.compactMap { shelfDir in
                let candidate = shelfDir
                    .appendingPathComponent("books")
                    .appendingPathComponent(bookId.uuidString)
                return FileManager.default.fileExists(atPath: candidate.path)
                    ? candidate
                    : nil
            }
        }()
        guard let bookDir = bookDirs.first else {
            return CardOpenOps.CardTriad(path: nil, content: "", title: "book-doc")
        }
        let folders: [String] = {
            if let folderName { return [folderName] }
            // Default = scan all 8 standard folders (= same as
            // PreviewPane.loadBookDocs default).
            return [
                "world", "characters", "outlines", "chapters",
                "drafts", "sessions", "foreshadowing", "placeholders"
            ]
        }()
        for folder in folders {
            let dirURL = bookDir.appendingPathComponent(folder)
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            if let first = entries.first(where: { $0.pathExtension == "md" }) {
                let body = (try? String(contentsOf: first, encoding: .utf8)) ?? ""
                return CardOpenOps.CardTriad(
                    path: first.path,
                    content: body,
                    title: first.deletingPathExtension().lastPathComponent
                )
            }
        }
        return CardOpenOps.CardTriad(path: nil, content: "", title: "book-doc")
    }

    /// 2026-10-14: shelf-scope
    /// variant of
    /// `scanFirstBookDoc`.
    /// Walks all books
    /// under the given
    /// shelf and picks
    /// the first .md
    /// (= the canonical
    /// "open the first
    /// available doc in
    /// the shelf" behavior
    /// the wenshu 1:1
    /// expects). The
    /// shelfId identifies
    /// the shelf dir at
    /// `<shelvesRoot>/<shelfId>/books/...`.
    /// The body + URL are
    /// both returned so
    /// `EditorPersistence.save`
    /// writes the edit to
    /// the canonical
    /// shelves file (= the
    /// boss 2026-10-14 "修
    /// 改不保存" root
    /// cause was the
    /// `path: nil`
    /// `CardTriad`
    /// returned by
    /// the previous shelf
    /// scope branch; = the
    /// editor's auto-save
    /// fell through to
    /// `/tmp`; = the
    /// shelves file was
    /// never updated).
    private func scanFirstBookDocInShelf(
        shelfId: UUID
    ) -> CardOpenOps.CardTriad {
        let shelvesRoot = bookStore.stores.shelvesRoot
        let shelfDir = shelvesRoot.appendingPathComponent(
            shelfId.uuidString
        )
        let booksDir = shelfDir.appendingPathComponent("books")
        guard let bookDirs = try? FileManager.default.contentsOfDirectory(
            at: booksDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return CardOpenOps.CardTriad(
                path: nil, content: "", title: "shelf"
            )
        }
        // Stable sort by name (= the
        // user expects the
        // first doc = the
        // alphabetically-first
        // .md; = this avoids
        // the "open a different
        // doc on each click"
        // race condition that
        // happens when the
        // directory iteration
        // order is not stable
        // across launches on
        // different macOS
        // versions).
        let sortedBookDirs = bookDirs.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let folders = [
            "world", "characters", "outlines", "chapters",
            "drafts", "sessions", "foreshadowing", "placeholders"
        ]
        for bookDir in sortedBookDirs {
            for folder in folders {
                let dirURL = bookDir.appendingPathComponent(folder)
                guard let entries = try? FileManager.default.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }
                if let first = entries.first(where: { $0.pathExtension == "md" }) {
                    let body = (try? String(contentsOf: first, encoding: .utf8)) ?? ""
                    return CardOpenOps.CardTriad(
                        path: first.path,
                        content: body,
                        title: first.deletingPathExtension().lastPathComponent
                    )
                }
            }
        }
        return CardOpenOps.CardTriad(
            path: nil, content: "", title: "shelf"
        )
    }

}
