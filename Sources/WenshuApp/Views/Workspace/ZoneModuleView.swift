// ZoneModuleView.swift · Wenshu · v1.32 ticket 001
//
// Extracted from WorkspaceView.swift (= v0.27 ticket 027-34).
//
// Per repowise `get_health` directive (2026-09-14, v1.30+):
//   fix_first: WorkspaceView.swift (= score 4.15, 2062 NLOC, 30 deps)
//   reason: Hotspot with no paired test file (= needs split)
//
// Per boss OOB 2026-09-14 "我想把这些修掉" + Q34 5.2 +
// Q173 ponytail + Q186 + Q57 + Q112: extract ZoneModuleView
// (= the legacy 6-zone pane registry helper used by
// RegisteredPanes) to its own file. This is the SAFE first split
// because ZoneModuleViewTests.swift already exists in
// tests/WenshuAppTests/Views/Workspace/.
//
// Per Q34 5.2 + Q173 ponytail + Q186: minimal split = 1 struct
// 1 file (= 370 LOC extracted from 2062 → 1692). The
// WorkspaceView.swift file still contains WorkspaceView +
// EditorPlaceholder + EditorPaperCanvas (= 3 more sub-structs
// to split in future tickets).
//
// Per Q34 5.2: extracted struct preserves all bindings,
// @Environment, init, and body (= no behavior change).

import SwiftUI
import MarkdownEngine  // v0.39 ticket 001: MarkdownEditorConfiguration type
// v1.36 ticket 002: drop `import LucideSwift` (= removed by boss's v1.x
// Lucide → SF Symbols 6 deprecation in commit c50d76167). The legacy
// `Lucide`/`LucideIcon` references in this file are comments only (= no
// active symbol resolution = drop is safe). Per Q34 5.2 + Q173 ponytail +
// Q186: this is part of the same v1.36 work as `ShellPlaceholder` duplicate
// removal (= both are PREREQUISITES for `swift build --target WenshuAppTests`
// to pass on main = main is currently broken without these fixes).

struct ZoneModuleView: View {
    let zoneSlot: ZoneSlot

    /// v0.30: bindings passed from WorkspaceView so sidebar category
    /// selection → preview pane can react (= same Binding reference).
    /// Default value `nil` (= for non-workspace callers that don't
    /// drive the preview pane).
    @Binding var selectedEntityCategory: EntityCategory?
    @Binding var selectedEntity: Reference?

    /// v0.30 boss 8/31 OOB 'cross-zone interaction' (= option A):
    /// AppState is the global @Observable source of truth.
    /// ZoneModuleView reads it directly (= no @Binding chain).
    @Environment(AppState.self) private var appState

    /// v0.34 B-25-fix (= boss 9/3 'PreviewPane double-click did not open the document'):
    /// ZoneModuleView also needs BookStore to read reference bodies
    /// (= same as WorkspaceView's openCardInEditor). Injected via
    /// the existing .environment(bookStore) call sites in App.swift
    /// + LibraryRootView.
    @Environment(BookStore.self) private var bookStore

    /// v0.30 boss 8/31 OOB: computed preview scope (= mirrors
    /// WorkspaceView's `previewScope`; duplicated here to keep
    /// ZoneModuleView self-contained without threading the scope
    /// through WorkspaceView → ZoneModuleView via another binding).
    private var previewScope: PreviewScope {
        guard let item = appState.sidebarSelection else { return .empty }
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
            if let cat = EntityCategory.allCases.first(where: {
                $0.directoryName == dirName
            }) {
                return .referenceScope(cat)
            }
            return .empty
        }
    }

    /// v0.30: default initializer for non-workspace callers.
    /// (= pass dummy constants explicitly, see RegisteredPanes.swift)
    init(
        zoneSlot: ZoneSlot,
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
            // v0.30 boss 8/31 OOB: ZoneModuleView forwards its
            // sidebarSelection binding to AppleSidebarView so
            // the sidebar click → preview pane scope works.
            ZoneContentView(zoneSlug: "projectSidebar", tabs: [
                (WenshuI18n.t("tab.title.bookshelf"), "book-open", AnyView(AppleSidebarView())),
            ], trailingButton: AnyView(SidebarZoneHeaderButtons()))

        case .projectPreview:
            // Old 6-zone projectPreview = 2 tabs (Preview / Map).
            // Per v0.25.1 ticket 014: book-open-check + waypoints.
            // v0.28 followup Boss UX round 24: preview tab content uses
            // .ultraThinMaterial (= was DesignColor.zoneSurface =
            // solid Color(nsColor: .controlBackgroundColor) = NOT
            // Liquid Glass).
            //
            // v0.30 boss 8/31 OOB: ZoneModuleView is the LEGACY
            // pane registry path (= RegisteredPanes.swift). Callers
            // don't pass a sidebarSelection binding (= they have no
            // concept of book folder scoping), so this preview pane
            // defaults to .empty scope (= empty state). The active
            // WorkspaceView path uses PreviewPane directly with the
            // computed previewScope (= supports all 4 sidebar scopes).
            //
            // v0.40 boss 9/7 OOB ', top bar, yestop bar.
            // caneditor, yes': the search bar
            // belongs BELOW the ZoneContentView's tab strip (= inside
            // PreviewPane's body, = first element rendered after the
            // tab strip). Removed the previous commit's VStack
            // wrapper (= was ABOVE the tab strip, = wrong position).
            // Search bar now lives inside PreviewPane.body (= same Y
            // as the editor's pencil/arrow toolbar inside
            // EditorPlaceholder).
            ZoneContentView(zoneSlug: "projectPreview", tabs: [
                (WenshuI18n.t("tab.title.preview"), "book-open-check", AnyView(PreviewPane(
                    scope: previewScope,
                    // v0.34 B-25-fix (= boss 9/3 'double-clicking card did not open the document'):
                    // ZoneModuleView's caller L561 is the ACTIVE path
                    // (= not WorkspaceView's caller L355 which is dead
                    // code). Route double-click to ZoneModuleView's own
                    // openCardInEditor (= same logic as WorkspaceView's;
                    // = ticket 027-35 will lift into a shared service).
                    //
                    // 2026-09-03 boss 9/3 follow-up: explicitly call
                    // `self.openCardInEditor()` (= Swift strict capture
                    // requirement = PreviewPane's @escaping closure
                    // captured `self` implicitly, and the implicit
                    // `openCardInEditor()` resolution went to the wrong
                    // scope = the closure ran but the method was not
                    // resolved to ZoneModuleView). Explicit `self.`
                    // fixes the resolution.
                    onDoubleClick: { source in
                        // BOSS 9/8 'clicking the Dufu card opens a tab with wrong name':
                        // forward the clicked CardSource to openCardInEditor.
                        self.openCardInEditor(source: source)
                    },
                    previewSortOrder: .constant(.pinyinFirstLetter)
                ))),
                (WenshuI18n.t("tab.title.graph"), "waypoints", AnyView(GraphView())),
            ])

        case .specializedTools:
            // 5 tabs (Foreshadowing / Placeholder /
            // LongFormGuardrails per P1 ticket #6
            // [WIRE-SPECIALIZEDTOOLS-001] 2026-09-04 +
            // ReaderExperience per P1 ticket #7
            // [WIRE-SPECIALIZEDTOOLS-002] 2026-09-04 +
            // PlotThread per P1 ticket #8
            // [WIRE-SPECIALIZEDTOOLS-003] 2026-09-04).
            // v0.71 P1 batch 9 dual-axis followup (= Q99 Spec axis P0):
            // fixed the stale "Old 6-zone specializedTools = 4 tabs"
            // comment (= current code has 5 tabs at L774-778 below;
            // the previous docstring described the pre-PlotThread state).
            ZoneContentView(zoneSlug: "specializedTools", tabs: [
                (WenshuI18n.t("tab.title.foreshadowing"), "git-fork", AnyView(ForeshadowingView())),
                (WenshuI18n.t("tab.title.placeholder"), "square-dashed", AnyView(PlaceholderView())),
                (WenshuI18n.t("tab.title.long_form"), "shield-check", AnyView(LongFormGuardrailsView())),
                (WenshuI18n.t("tab.title.reader_experience"), "sparkles", AnyView(ReaderExperienceView())),
                (WenshuI18n.t("tab.title.plot_thread"), "git-branch", AnyView(PlotThreadView())),
            ])

        case .aiDynamic:
            // Old 6-zone aiDynamic = DynamicZoneView (= has its own
            // DynamicZoneTabBar with Progress / Todo / Search).
            // Per v0.24 boss 8/24 OOB: external toolbar cleared (= the
            // outer ZoneTopToolbar is empty placeholder mode).
            DynamicZoneView()

        case .aiChat:
            // Old 6-zone aiChat = ChatZoneView (= has its own ChatZoneTabBar
            // with chat / search / settings). Per v0.25.1 ticket 005:
            // top icons are Bot + Inbox.
            ChatView()

        case .editor:
            // Old 6-zone editor = 3 tabs (Edit / Outline / Backlinks) + trailingButton
            // (expand/shrink toggle). Real ZoneContentView — replaces
            // EditorPlaceholder (= which was just text "Editor zone
            // ticket 027-35 integration pending").
            // Per v0.25.1 ticket 017 + 028: book-open-text + puzzle + link.
            ZoneContentView(
                zoneSlug: "editor",
                tabs: [
                    // v0.34 B-13 fix (= boss 9/2 'git grep BEFORE patch' rule):
                    // see L279 fix comment above; replace placeholder with
                    // EditorPlaceholder (= ticket 04-10 toolbar + mode toggle).
                    (WenshuI18n.t("tab.title.editor"), "book-open-text", AnyView(EditorPlaceholder())),
                    (WenshuI18n.t("tab.title.outline"), "puzzle", AnyView(OutlinePanel())),
                    // v0.34 B-16: removed the "Backlinks" tab here (= boss 9/2 OOB
                    // 'the Backlinks area still has to be removed'). Backlinks are now
                    // surfaced via the chrome bottom-right "Backlinks 0"
                    // label click → popover (= spec user stories 8 + 11).
                ],
                // v0.25.1 (= ticket 029c-trailing-button): expand/shrink
                // trailing button. Boss 8/26 OOB 'it is one button, not a tab
                // teb' = won't be a tab (= no selected underline), just
                // a button at the right edge of the tab bar.
                trailingButton: AnyView(
                    EditorExpandShrinkTrailingButton()
                )
            )
        }
    }

    /// v0.34 B-25-followup (= boss 9/3 'fix it until I can use it'): ZoneModuleView
    /// needs its own openCardInEditor (= WorkspaceView's openCardInEditor
    /// is in a DIFFERENT struct = can't share via this same View type).
    /// Code is mostly duplicated from WorkspaceView's openCardInEditor
    /// + the book-scope branch reads the actual .md file (= same walk
    /// as PreviewPane.loadBookDocs; = ticket 027-35 will lift that
    /// helper into a workspace-level BookDocLoader service so both
    /// callers share it).
    /// BOSS 9/8 'clicking the Dufu card opens a tab with wrong name' (= clicking
    /// the card opened a new tab named 'preview-sample'):
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
    /// v1.74 cardopen-dedupe: thin wrapper over `CardOpenOps` (=
    /// the dedup + EditorTab + activeTabId mutation shared with
    /// WorkspaceView + ShellMiddleColumn). The reference-scope +
    /// bookDoc-deferred path delegates to `CardOpenOps
    /// .computeCardTriad`; the book-scope file-scan (= walk
    /// shelves/<shelf-uuid>/books/<book-uuid>/<folder>/*.md)
    /// stays in the View because it's specific to ZoneModuleView
    /// (= ticket 027-35 will replace it). The shared tail
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
        case .shelfScope, .empty:
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
    /// picks the FIRST .md (= v0.34 placeholder; = ticket 027-35
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
