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
        // Step 1 = resolve the triad. Reference-scope uses
        // CardOpenOps (= shared with WorkspaceView / ShellMiddleColumn);
        // book-scope uses this view's local file-scan (= walk the
        // 8 standard folders for the first .md; = same as before).
        let scope = previewScope
        let triad: CardOpenOps.CardTriad
        switch scope {
        case .referenceScope:
            // Delegate (= shared code path with WorkspaceView).
            triad = CardOpenOps.computeCardTriad(
                source: source,
                previewScope: scope,
                bookStore: bookStore
            )
        case .bookScope(let bookId, let folderName):
            // Local file-scan (= not shared with WorkspaceView or
            // ShellMiddleColumn; = preserved verbatim per ticket
            // 027-35's deferred plan to lift into a workspace-
            // level BookDocLoader service).
            if case .bookDoc(let doc) = source {
                triad = CardOpenOps.CardTriad(path: nil, content: doc.summary, title: doc.title)
            } else {
                triad = scanFirstBookDoc(bookId: bookId, folderName: folderName)
            }
        case .shelfScope, .empty, .tagScope:
            // v2.6 facet model: .tagScope is a preview-pane
            // filter scope (= the same as .referenceScope in
            // terms of what to open; = the openTab result
            // uses the scope's sourceScope for tab routing;
            // = a .tagScope result opens the card in the
            // editor the same way a .referenceScope result
            // does). The empty triad here means "no
            // pre-resolved content" (= the editor opens
            // the document by id; = see CardOpenOps.openTab).
            triad = CardOpenOps.CardTriad(path: nil, content: "", title: "")
        }
        _ = CardOpenOps.openTab(
            triad: triad,
            previewScope: scope,
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

}
