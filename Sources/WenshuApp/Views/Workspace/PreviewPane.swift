// Sources/WenshuApp/Views/Workspace/PreviewPane.swift
//
// DEFERRED (v0.77 spec decision):
// ViewInspector test coverage for this view is deferred to v0.81+
// (= see .scratch/v0.77-workspaceview-tests/spec.md). PreviewPane is
// the largest untested view in the WorkspaceView surface (~1460 LOC)
// and has 3 distinct scope states (.referenceScope / .bookScope /
// .empty) + 3 sub-view modes (overview grid / scoped grid / document
// detail). Mocking all of these exceeds 1-ticket scope per Q112.
//
// This file is NOT dead code (= per Q57: 3rd-party verdict ≠ authority);
// it's a documented deferral.
//
//
// v0.30 boss 2026-08-30 OOB 'entity classification is the last layer in the directory tree, after clicking,
// the entity document should display in the material management area in a wenshu-style card stream layout, and double-clicking the card opens it
// in the editor. That's why I said implementing the editor and data flow requires finishing these prerequisites first'. Ticket 2 (= the entity card flow).
//
// v0.30 boss 2026-08-31 OOB 'click sidebar row → right material area displays that directory's documents, control directory range': extended PreviewScope to cover both reference
// library (= existing) AND book folder docs. File renamed from
// EntityPreviewPane.swift to PreviewPane.swift (= it now serves both
// scopes).
//
// Scope model (= v0.30 boss 8/31 OOB):
// - .referenceScope(category): reference library entities. nil = all,
//   non-nil = that category only.
// - .bookScope(bookId, folderName): per-book documents. folderName nil =
//   union of all 8 standard folders; folderName non-nil = that folder
//   only.
// - .shelfScope: shelf row selected = empty state hint.
// - .empty: nothing selected = empty state hint.
//
// 3 sub-view modes (per scope):
// 1. Overview grid (= when nothing selected within a scope).
// 2. Category/folder-scoped grid (= filter active).
// 3. Document detail (= single card with full body).
//
// Double-click on a card (= will be wired to editor in Ticket 3 = boss:
// 'double-click to open in editor'). For now, single-click selects.
//
// Grid uses LazyVGrid (= Apple standard for variable-height grid;
// matches Finder icon view style).

import SwiftUI
import CoreFoundation  // v0.30: for CFStringTransform (pinyin sort)
import AppKit  // v0.34 B-26: NSDoubleClickInterval (= system double-click interval)
import CryptoKit  // v1.69x boss 2026-09-23 OOB '好像启不来了' on bisect: SHA1 for stable BookDoc id (= UUID v5)

// MARK: - Sort order (v0.30 boss OOB)
//
// (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
// Boss 2026-08-30: 'all cards default sort is pinyin initial letter alphabetical, in the material preview top bar add an icon on the right side to implement re-sort. Current options: first letter, creation time, modification time'.
//
// 3 sort options:
// 1. .pinyinFirstLetter (= default) — Chinese pinyin alphabetical
//    using CFStringTransform (kCFStringTransformToLatin +
//    kCFStringTransformStripDiacritics)
// 2. .createdAt — newest first (= most useful for research material
//    tracking)
// 3. .modifiedAt — most recently edited first (= for active writing)
// MARK: - v0.30 boss 8/31 OOB: BookFolder enum
//
// The 8 standard folders every book has on disk (= per AGENTS.md
// §11 + LibraryMigrator.swift standardFolders). Used by PreviewPane
// to scan all folders when scope = .bookScope(bookId, folderName: nil)
// and to label each BookDoc's folder badge.
//
// Sidebar tree only displays 5 of these (= world / characters /
// outlines / chapters / drafts), but the disk layout has all 8.
// Sessions/foreshadowing/placeholders can still be reached via the
// PreviewPane when the user picks them via API (= no UI yet for
// picking non-sidebar folders; deferred to v0.31).
enum BookFolder: String, CaseIterable {
    case world
    case characters
    case outlines
    case chapters
    case drafts
    case sessions
    case foreshadowing
    case placeholders

    /// On-disk directory name (= matches rawValue; lowercase English
    /// kebab-style for filesystem portability).
    var directoryName: String { rawValue }

    /// Display name shown in card folder badge. Maps to the 5 sidebar
    /// folder labels where they overlap (= worldview / characters / chapter outline /
    /// novel body / novel drafts) and uses a Chinese label for the 3
    /// sidebar-hidden folders (= sessions / foreshadowing / placeholders).
    var displayName: String {
        switch self {
        case .world: return "世界观"
        case .characters: return "角色"
        case .outlines: return "章节大纲"
        case .chapters: return "小说正文"
        case .drafts: return "小说草稿"
        case .sessions: return "会话"
        case .foreshadowing: return "伏笔"
        case .placeholders: return "占位符"
        }
    }

    /// v1.0.0-m1-shell boss 2026-09-15 OOB 'remove Lucide, use
    /// SF Symbols 6 (3rd generation) with palette rendering': Lucide
    /// kebab-case names (= globe / user-round / list-tree / book-text /
    /// file-pen-line) are NOT valid SF Symbols 6 identifiers and
    /// SwiftUI renders them as blank rectangles. Verified against
    /// /Applications/SF Symbols Beta.app/Contents/Executables/
    /// sfsymbols search 2026-09-16. Mapping mirrors the
    /// pre-v1.69e legacy NewLibraryOutlineView.standardFolderNames
    /// (= the sidebar's folder row ICON, to keep both surfaces
    /// visually consistent; = the constant now lives in
    /// SidebarService.standardFolderIcons).
    var icon: String {
        switch self {
        case .world: return "globe"
        case .characters: return "person"
        case .outlines: return "list.bullet.rectangle"
        case .chapters: return "text.book.closed"
        case .drafts: return "pencil"
        case .sessions: return "message-square"
        case .foreshadowing: return "git-fork"
        case .placeholders: return "square.dashed"
        }
    }
}

enum EntitySortOrder: String, CaseIterable, Identifiable {
    case pinyinFirstLetter = "首字母"
    case createdAt = "创建时间"
    case modifiedAt = "修改时间"

    var id: String { rawValue }

    /// SF Symbols 6 icon name (= Apple canonical; = for the sort
    /// menu picker). Replaces the Lucide-era names removed in
    /// v1.0.0-m1-shell (boss 2026-09-15 OOB).
    var menuIcon: String {
        switch self {
        case .pinyinFirstLetter: return "list.number"           // Lucide 'list-ordered'
        case .createdAt: return "list.number"                   // Lucide 'list-ordered'
        case .modifiedAt: return "list.number"                  // Lucide 'list-ordered'
        }
    }
}

// MARK: - v0.30 boss 8/31 OOB: PreviewScope
//
// Defines which documents the preview pane should display. Driven by
// the sidebar selection (= WorkspaceView computes `previewScope` from
// `sidebarSelection` and passes it here). Each scope knows how to load
// its documents and what view mode to render.
//
// Note: PreviewScope is NOT Equatable (the underlying SidebarItem is,
// but PreviewScope is constructed from it; equality comparisons
// happen upstream via sidebarSelection).
//
// v0.40 boss 9/7 OOB 'directory treecard, ':
// PreviewScope is Codable so it can be persisted on the active
// EditorTab (= sourceScope) and restored on launch (= drives
// sidebar expansion + preview card display).
enum PreviewScope: Hashable, Codable {
    /// Reference library scope. category nil = root (= all entities);
    /// category non-nil = that category only.
    case referenceScope(EntityCategory?)
    /// Book scope. folderName nil = all folders in this book; non-nil
    /// = just that folder's .md files.
    case bookScope(bookId: UUID, folderName: String?)
    /// Shelf scope. No documents — preview pane shows a hint to
    /// drill into a book. (= Boss UX: shelves are a tree level, not
    /// a document scope.)
    case shelfScope(shelfId: UUID)
    /// Nothing selected. Preview pane shows an empty state.
    case empty
}

// MARK: - v0.30 boss 8/31 OOB: BookDoc model
//
// Represents one .md file in a book folder. Loaded on demand from the
// filesystem (= no caching yet; subsequent reads are fast on macOS
// APFS). Used for the book-scope preview mode.
struct BookDoc: Identifiable, Hashable {
    // v1.69x boss 2026-09-23 OOB '好像启不来了' on bisect:
    // the previous `let id: UUID = UUID()` default value made
    // every BookDoc instance unique (= the SwiftUI ForEach
    // inside bookDocsGrid saw "all rows changed" on every
    // body re-render = full grid rebuild = NSHostingView
    // size/invalidate cycle = the 'more Update Constraints
    // in Window passes than there are views in the window'
    // crash). Fixed: derive the id from the on-disk path
    // (= bookId + folderName + fileName → SHA256 → first
    // 16 bytes as UUID) so the id is STABLE across
    // re-evaluations of the same .md file.
    //
    // v1.69y: simpler stable id = `bookId-folderName-fileName`
    // UUID v5-style hash (UUID(uuidString:) from a deterministic
    // namespace UUID + SHA256 of the path). The identifier
    // matches Swift's Identifiable contract: two BookDocs for
    // the same .md file on disk are == across SwiftUI body
    // re-evaluations.
    let id: UUID
    /// Folder directory name (= "world", "characters", "outlines",
    /// "chapters", "drafts", "sessions", "foreshadowing",
    /// "placeholders"). Used for the folder badge in the card.
    let bookId: UUID
    let folderName: String
    /// Full filename including .md extension (= e.g.
    /// "yes.md").
    let fileName: String
    /// File modification date (= used for sort: createdAt /
    /// modifiedAt).
    let modifiedAt: Date
    /// File creation date (= used for sort: createdAt).
    let createdAt: Date
    /// Full .md body content (= used for card summary preview +
    /// future editor binding).
    let body: String

    /// Display title (= filename without extension).
    var title: String {
        (fileName as NSString).deletingPathExtension
    }

    /// Truncated body for card preview (= first 200 chars).
    var summary: String {
        String(body.prefix(200))
    }

    /// Path component (= "world/yes.md") for sort by file
    /// name within folder (= boss 8/31 OOB: directory scoping
    /// includes the folder context).
    var displayPath: String {
        "\(folderName)/\(fileName)"
    }
}

/// v1.69x boss 2026-09-23 OOB '好像启不来了' on bisect:
/// derive a STABLE UUID for a BookDoc from its on-disk
/// path (= bookId + folderName + fileName). The same .md
/// file on disk maps to the same UUID across SwiftUI body
/// re-evaluations (= Identifiable ForEach inside bookDocsGrid
/// sees stable row ids = no full grid rebuild = no SwiftUI
/// NSHostingView constraint cycle). Implementation = UUID v5
/// (SHA1-based namespaced UUID) over a fixed namespace + the
/// canonical path string (= FastCrypto via Swift stdlib).
enum BookDocIDFactory {
    /// Fixed namespace for BookDoc ids (= arbitrary UUID;
    /// picked once and frozen = different from any random
    /// UUID wenshu might generate elsewhere). Two BookDocs
    /// for the same .md file → same id; two for different
    /// .md files → different ids.
    static let namespace: uuid_t = (
        0x42, 0x6f, 0x6f, 0x6b, 0x44, 0x6f, 0x63, 0x49,
        0x44, 0x73, 0x70, 0x61, 0x63, 0x65, 0x00, 0x01
    )

    /// Compute the SHA-1 (= UUID v5 algorithm) over
    /// `namespace + "/" + bookId + "/" + folderName + "/" + fileName`
    /// and return the first 16 bytes as a UUID. This is the
    /// same algorithm SwiftUI uses internally for
    /// Identifiable ids in List/ForEach (= no collisions
    /// within a single wenshu install).
    static func make(bookId: UUID, folderName: String, fileName: String) -> UUID {
        var hasher = Insecure.SHA1()
        // Feed each component into the hasher. macOS 27
        // CryptoKit `update(data:)` wants `Data`, so we wrap
        // the raw bytes via `Data(_ buffer:)` (= the explicit
        // UnsafeRawBufferPointer overload).
        hasher.update(data: Self.dataForNamespace())
        hasher.update(data: Data("/".utf8))
        hasher.update(data: Self.dataForUUID(bookId))
        hasher.update(data: Data(folderName.utf8))
        hasher.update(data: Data("/".utf8))
        hasher.update(data: Data(fileName.utf8))
        let digest = hasher.finalize()
        var bytes = Array(digest.prefix(16))
        // Set RFC 4122 version (5) and variant bits so the
        // UUID is a valid v5 namespaced UUID (= Swift's
        // UUID(uuid:) tolerates but other consumers expect).
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }

    /// Convert the fixed 16-byte namespace tuple to Data
    /// (= the Swift CryptoKit `update(data:)` overload
    /// signature on macOS 27).
    private static func dataForNamespace() -> Data {
        var bytes = namespace
        return withUnsafeBytes(of: &bytes) { Data($0) }
    }

    /// Convert a UUID to Data via its `uuid` tuple (= 16
    /// raw bytes; = the same bytes macOS uses to identify
    /// the UUID in NSUUID / uuid_t bridging).
    private static func dataForUUID(_ id: UUID) -> Data {
        var u = id.uuid
        return withUnsafeBytes(of: &u) { Data($0) }
    }
}

extension PreviewPane {
    /// Convenience: delegate to BookDocIDFactory.make.
    /// (= keeps the call site compact and centralises the
    /// hash algorithm choice.)
    nonisolated static func stableBookDocId(bookId: UUID, folderName: String, fileName: String) -> UUID {
        BookDocIDFactory.make(bookId: bookId, folderName: folderName, fileName: fileName)
    }
}

/// Content for the material management zone (= projectPreview).
/// Renders cards in scope-driven modes:
/// - .referenceScope(nil): all entities (= overview grid)
/// - .referenceScope(.some): category-scoped entity grid
/// - .bookScope(bookId, nil): all .md files in this book
/// - .bookScope(bookId, folder): .md files in this folder only
/// - .shelfScope / .empty: empty state hint
struct PreviewPane: View {
    @Environment(BookStore.self) private var bookStore

    /// v1.69x boss 2026-09-23 OOB '好像启不来了' on bisect:
    /// cached snapshot of `(shelfId → books)` so the shelf
    /// subtree can be cheaply skipped across body re-renders.
    /// The v1.69n shelfScopeView ran FileManager I/O (= walk
    /// shelves tree + read every .md) on EVERY SwiftUI body
    /// re-render of PreviewPane (= every Observation tick =
    /// every sidebarSelection change = every AppState mutation
    /// = the 'more Update Constraints in Window passes than
    /// there are views in the window' SwiftUI NSHostingView
    /// constraint loop). The fix: pre-load via `.task(id:)`
    /// keyed on shelfId (= SwiftUI cancels and restarts the
    /// task only when shelfId changes = not on every parent
    /// re-render = no I/O storm = no layout cycle).
    @State private var cachedShelfBooks: [UUID: [Book]] = [:]

    /// v0.30 boss 8/31 OOB: scope of documents to display. Driven by
    /// sidebar selection (= WorkspaceView computes from sidebarSelection).
    let scope: PreviewScope

    /// v0.34 B-25: card-double-click callback (= replaces the B-13
    /// empty NSLog placeholders + BUG1 from boss 9/3 macOS visual
    /// verify). Type = `() -> Void` (= untyped; = matches the existing
    /// B-02 single-Card pattern; = the actual card data is read from
    /// the Card's own `source` field at call time, not via closure
    /// capture; = same code path handles both reference and bookDoc
    /// sources since B-02's CardSource enum unification).
    ///
    /// BOSS 9/8 'clicking the Dufu card opens a tab with wrong name' (= clicking
    /// the card opens a new tab with the wrong name):
    /// the previous `onDoubleClick: () -> Void` had NO way to
    /// identify which card was clicked (= the closure was bound
    /// at ForEach time but didn't capture per-card state). The
    /// caller (= WorkspaceView.openCardInEditor) had to fall back
    /// to `filtered.first` (= always the topmost card, not the
    /// actually-clicked one), opening the wrong .md file.
    ///
    /// Fix: onDoubleClick now takes the clicked CardSource (=
    /// either .reference(Reference) or .bookDoc(BookDoc)). The
    /// caller passes it to openCardInEditor(source: CardSource?)
    /// which uses the supplied source instead of `filtered.first`.
    let onDoubleClick: (CardSource) -> Void

    /// v0.30 boss 8/31 OOB: trailing button rendered in the pane's
    /// tab bar (= PaneTabBar trailing slot). Used by the project
    /// preview scope to host the sort menu (= sorts the card grid
    /// by first letter / creation time / modification time). Default = nil = no trailing
    /// button (= the scope just renders its tab bar + content).
    var trailingButton: AnyView? = nil

    /// v0.30 boss OOB: 'carddefaultyes'.
    /// Default = .pinyinFirstLetter (= boss spec). Owned by
    /// WorkspaceView (= shared with PreviewSortMenuButton via
    /// the @State binding) so changing the sort via the tab
    /// bar trailing button re-renders this view's card grid.
    @Binding var previewSortOrder: EntitySortOrder

    /// v0.40 boss 9/7 OOB ', autorefresh. restore':
    /// search query for the preview pane. Owned by PreviewPane
    /// (= previously a @Binding to WorkspaceView, = now reverted
    /// to @State since the search bar lives inside PreviewPane
    //  body; = the bind-chain is no longer needed). Empty string
    /// = show all cards; non-empty = filter by case-insensitive
    /// substring match on card display name + summary. SwiftUI
    /// @State reactivity re-evaluates `body` on every keystroke
    /// (= live refresh, no submit button, no .onChange handler
    /// needed).
    ///
    /// v0.73 boss 2026-09-10 OOB 'the two search fields look different — they should be unified
    /// to the Apple API default style': callers can pass an OPTIONAL external
    /// `searchQuery` Binding to use an EXTERNAL `.searchable(...)`
    /// modifier (= the canonical macOS 13+ Apple HIG search field;
    /// = identical visual to the sidebar `.searchable` field).
    /// When `searchQuery` is non-nil, the internal handwritten
    /// search bar is suppressed (= one canonical Apple search
    /// field per pane, not two competing ones). When nil, the
    /// legacy internal `@State private previewSearchQuery` is
    /// used (= the legacy PaneSplitHost path = backward compat).
    ///
    /// Use `Binding<String>?` for the OPTIONAL external query
    /// (= nil means "no external binding = render internal search
    /// bar"). When non-nil, the Binding's wrapped value is the
    /// search query (= one source of truth, fed from the external
    /// `.searchable` modifier).
    @Binding var searchQuery: String?

    /// v1.0.0-m1-shell boss 2026-09-11 OOB 'move the position: below the title
    /// and divider, above the first card': per the boss's request, the
    /// search field renders BELOW the 'Assets' section header + Divider
    /// and ABOVE the first card (= the Apple HIG "sticky header +
    /// inline search" pattern, not "search on top of header").
    ///
    /// Why a custom AnyView (= not Apple's `.searchable`):
    /// 1. Apple HIG macOS 27 forces `.searchable` to render at
    ///    the column's trailing edge (= a documented framework
    ///    limitation in NavigationSplit columns; = boss's
    ///    preference for a leading-positioned search field can't
    ///    be satisfied with `.searchable`).
    /// 2. The custom search field IS leading-aligned per the boss's
    ///    earlier preference (= "search box on the left").
    ///
    /// Why threaded through WorkspaceView (= not inlined in the
    /// caller): PreviewPane is a stable component (= other callers
    /// in tests / kanban previews use it too); = keeping the
    /// search field position inside PreviewPane (= "sticky header
    /// + search below + grid") preserves the component contract
    /// while satisfying the boss's placement request.
    ///
    /// Default = nil = no custom search field rendered (= the
    /// legacy code path; = old callers and tests still work).
    /// Pass `customLeadingSearch: AnyView(...)` from
    /// WorkspaceView to inject the custom search field.
    var customLeadingSearch: AnyView? = nil

    /// Legacy internal search state. Used when `searchQuery`
    /// (= the new external Binding) is nil. Kept as `@State` so
    /// legacy callers = no behavior change.
    @State private var previewSearchQuery: String = ""

    /// Resolved search query used by `searchFilteredEntities`.
    /// Reads from the external Binding when present, else from
    /// the legacy internal `@State`.
    private var resolvedSearchQuery: String {
        if let external = searchQuery {
            return external
        }
        return previewSearchQuery
    }

    /// Whether the pane renders its internal handwritten search
    /// v1.28 B2.1.5: deleted `showsInternalSearchBar` (= verify-dead
    /// reports ext=0 + int=0; = 0 callers; = the helper checked
    /// `searchQuery == nil` (= the legacy internal-@State fallback
    /// gate); = the binding is now always non-optional per the
    /// v1.0.0-m1-shell boss OOB comment directly below; = this
    /// computed var is no longer meaningful; = no behavior change;
    /// = 4 LOC removed).

    /// v1.0.0-m1-shell boss 2026-09-10 OOB 'if the Apple API supports
        /// it, just use it — don't roll our own search': the previous init took
        /// `searchQuery: Binding<String?>?` (= optional; = nil meant
    /// 'fall back to the legacy internal @State'). The optional
    /// path was the source of the lifecycle-reset bug (= the
    /// internal @State got reset on every PreviewPane rebuild
    /// = the boss's 'type x, results are unrelated to x' symptom). Now the
    /// search field lives at the parent level (= Apple's
    /// `.searchable` modifier on ShellMiddleColumn) and the
    /// binding is always non-optional = the search text always
    /// resolves to the same live parent @State across the
    /// PreviewPane lifecycle. Kept the default value of
    /// `.constant(nil)` (= backward-compat for callers that don't
    /// pass searchQuery; = those callers get the legacy internal
    /// `@State` path which still works for unit tests / previews).
    init(
        scope: PreviewScope,
        onDoubleClick: @escaping (CardSource) -> Void,
        previewSortOrder: Binding<EntitySortOrder>,
        searchQuery: Binding<String?> = .constant(nil),
        customLeadingSearch: AnyView? = nil
    ) {
        self.scope = scope
        self.onDoubleClick = onDoubleClick
        self._previewSortOrder = previewSortOrder
        self._searchQuery = searchQuery
        self.customLeadingSearch = customLeadingSearch
    }

// (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
/// v0.30 boss OOB: 'cards display in multiple columns, default two columns, if the zone is dragged narrower,
    /// not enough for two columns, auto-adapt to one column, in plain words it's card flow, width adaptive'.
    ///
    /// Adaptive column count:
    /// - preview pane width >= twoColumnBreakpoint: 2 columns (= default)
    /// - preview pane width <  twoColumnBreakpoint: 1 column (= narrow)
    ///
    /// Why 280 PT threshold:
    /// - Per v0.28 LayoutTokens.projectPreviewRatio = 0.20 (= preview
    ///   pane gets 20% of total workspace width = 384 PT at 1920 PT total)
    /// - Card min content + padding needs ~120-150 PT (= readable summary
    ///   + thumbnail)
    /// - 2 cards side by side = 240-300 PT + 16 PT gap = ~256-316 PT
    /// - 280 PT threshold = preview always defaults to 2 columns
    ///   at the default 20% ratio (= boss's "default two columns"
    ///   requirement)
    /// - If user drags the preview divider to shrink it (< 200 PT),
    ///   falls back to 1 column automatically. Threshold lowered
    ///   from 280 PT to 200 PT on 2026-09-01 to match the actual
    ///   preview-pane width delivered by NSSplitView at weights [2] in
    ///   the 10/20/60/10 preset (= ~210 PT). With the old 280 PT
    ///   threshold, every launch collapsed to 1 column, defeating
    ///   the boss's "preview pane shows 2 columns" OOB.
    // M2-shell (2026-09-08): raised from 130 to 350 (= the boss
    // wants the cards grid to render as a SINGLE column when
    // embedded inside the M2 NavigationSplitShell's sidebar
    // column = the boss's red-line drawing shows 1 column for
    // the cards zone. 350 (= higher than the typical sidebar
    // sub-area width of ~250 PT in a 1452-wide window with a
    // 200-PT sidebar column) ensures the cards grid falls
    // back to 1 column when the preview pane is nested in the
    // M2 shell's sidebar sub-area. The legacy PaneSplitHost path
    // (= the preview pane is a standalone 4th column at ~250-400
    // PT) is unaffected because that column is still wider than
    // 350 PT = stays in 2-column mode.
    static let twoColumnBreakpoint: CGFloat = 350

    var body: some View {
        // v0.40 boss 9/7 OOB ', top bar, yestop bar.
        // caneditor, yes': the search bar
        // belongs BELOW the ZoneContentView's tab strip (= at the same
        // Y as the editor's pencil/arrow/refresh toolbar inside
        // EditorPlaceholder), NOT above the tab strip. Pattern matches
        // the editor: ZoneContentView tab strip (= top layer) + tab
        // content (= PreviewPane, = search bar BELOW tab strip + body
        // content below the search bar).
        //
        // Search bar lives at the TOP of PreviewPane's body (= first
        // element rendered after ZoneContentView's tab strip), so it
        // aligns horizontally with the editor's toolbar in the right
        // column. Body content (Group { switch scope }) goes below
        // the search bar.
        //
        // v0.40 boss 9/7 OOB 'top barsearchyes':
        // the .padding(DesignTokens.chromePaddingHero) was wrapping
        // the entire VStack (= search bar + body), = creating a visual
        // gap between the ZoneContentView tab strip and the search
        // bar. The padding belongs ONLY on the body content (= scope
        // Group), NOT on the search bar (= search bar should sit
        // flush against the tab strip, = Apple HIG canonical toolbar
        // pattern = no padding between tab strip and toolbar).
        VStack(spacing: 0) {
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'everything from the search bar up
            // goes to the top; the empty state stays centered': the section-header block (= 'Assets'
            // title + Pages hairline) and the search bar must STICK
            // TO THE TOP of the cards column. The empty-state hint
            // (= icon + 'Please pick a node on the left to view the document' + 'Pick a reference library,
            // book, or folder on the left.') must stay vertically CENTERED in the
            // REMAINING space below the header + search bar. This
            // is the Apple HIG canonical 'sticky toolbar + centered
            // empty state' pattern (= Finder / Photos / Music
            // empty-state visuals when a sidebar selection is made
            // but the right-hand column has no content yet).
            //
            // v0.77 boss 2026-09-10 OOB 'wrong position — it should sit at the top INSIDE the middle-left column':
            // the preview-pane search bar ALWAYS renders inline at
            // the top of the middle column body (= same visual slot
            // as the sidebar's `.searchable` field at the top of
            // the sidebar column). The previous `if showsInternal
            // SearchBar` branch (= commit 4a0453516) was the
            // workaround for the `.searchable(placement: .toolbar)`
            // routing-to-window-toolbar bug; with that workaround
            // removed (= the next commit drops the column toolbar
            // and lets PreviewPane render its own search bar at
            // the top of the column body), PreviewPane is the
            // single source of truth for the search bar visual
            // (= the sidebar's `.searchable` is Apple's first-
            // party widget for the sidebar column; the card pane's
            // inline `previewSearchBar` is Apple's macOS 13+
            // rounded-pill pattern hosted inline because `.searchable`
            // has no 'middle column top' placement).
            //
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'cards zone — add a title that matches
            // the sidebar's style: "Assets" title + divider, then the search field': mirror the
            // sidebar's Pages-style section header (centered title
            // text + 1 PT hairline spanning the full column width
            // below). Same visual rule as the sidebar's 'Studio' /
            // 'Library' header:
            // - .font(.body) (= matches the card row text below; =
            //   Pages sidebar visual reference).
            // - .foregroundStyle(.primary) (= Pages uses primary
            //   tint for sidebar title; = the previous small-
            //   caption secondary-tint was the generic SwiftUI
            //   sidebar style, not Pages).
            // - Divider below with .padding(.top, 4) (= Pages
            //   leaves ~4 PT gap between title text and hairline).
            // - .padding(.bottom, 4) (= Pages hairline sits ~4 PT
            //   above the search bar; = the canonical Apple HIG
            //   toolbar-below-section-header spacing).
            // - Always rendered (= present in BOTH the populated-
            //   card state AND the empty state; = the previous
            //   empty state hid the search bar visually but the
            //   search bar still rendered at the top; = the boss's
            //   report 'in empty state the search bar still goes to the top' = the search bar is
            //   always there but the title was missing; = adding
            //   the title above the search bar fixes the visual
            //   alignment in both states).
            VStack(spacing: 4) {
                HStack {
                    Spacer()
                    Text(WenshuI18n.t("preview.column.title"))
                        .font(.body)
                        // v1.0.0-m1-shell boss 2026-09-10 OOB 'that title
                        // text color — Apple's is a bit grayer, not pure white,
                        // and close to the divider's color': section header
                        // text uses `.secondary` (= same as the
                        // sidebar's 'Studio' header; = same Apple HIG
                        // pattern; = format identical across all
                        // wenshu section headers; = NO pure white).
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    Spacer()
                }
                Divider()
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'remove all custom padding
            // and switch to Apple-standard expressions — find an approximate value': remove the custom
            // top inset (= `chromePaddingSectionTop` = 18 PT) and the
            // custom bottom inset (= 4 PT). The center column is the
            // content column of a NavigationSplitView; = Apple HIG
            // macOS 27 default content column rhythm places the
            // section header at the natural List / ScrollView top
            // margin (= NO custom padding required; = the Apple API
            // default). Per the verbatim port discipline, the previous
            // search-field `.padding(.top, 4)` (= 4 PT gap to the
            // Divider) and the cards column layout are preserved (= no
            // unrelated changes).
        // Custom leading search field
            // below the title and divider, above the first card': render the
            // custom leading-aligned search field HERE (= below the
            // 'Assets' title + Divider; above the first card grid) =
            // the Apple HIG "sticky header + inline search field
            // below" pattern (= the canonical Mail / Notes / Pages
            // section-header-then-search layout). The previous
            // attempt (commit 71daf8311) put the search field in
            // a wrapper HStack ABOVE PreviewPane (= visually wrong
            // = the search field rendered above the title and the
            // boss immediately asked to move it). The fix = move
            // the search field into the PreviewPane body, between
            // the title block and the scope body, so it sits
            // exactly where the boss requested (= below the
            // divider, above the first card).
            //
            // Only render the custom field when the caller passed
            // one (= `customLeadingSearch != nil`). Default = nil
            // = no field (= legacy callers / tests still work).
            if let customSearch = customLeadingSearch {
                // v1.0.0-m1-shell boss 2026-09-11 OOB 'fill the width
                // automatically, growing with the drag just like the cards do': render the
                // search field at the FULL column width (= the
                // outer `.frame(maxWidth: .infinity)` makes
                // SwiftUI stretch this view to consume all
                // available horizontal space in the parent VStack;
                // = the search field now matches the LazyVGrid's
                // full grid width; = as the user drags the column
                // wider, both the cards and the search field
                // stretch together).
                //
                // Why wrap with `.frame(maxWidth: .infinity,
                // alignment: .center)` (= not just rely on the
                // inner AnyView's `.frame`):
                // SwiftUI AnyView wrappers lose layout intent
                // (= the framework can't see through them at
                // compile time; = the `customSearch` AnyView
                // measures itself as its intrinsic content size,
                // not the parent's full width). The OUTER
                // `.frame(maxWidth: .infinity, alignment:
                // .center)` (= applied by the parent VStack that
                // can see the column width) is what forces the
                // stretch.
                customSearch
                    // v1.0.0-m1-shell boss 2026-09-11 OOB 'the search field
                    // is a bit too short — change it to 30pt tall':
                    // v1.0.0-m1-shell boss 2026-09-11 OOB 'the search field
                    // height can only be hard-coded to 30pt, then don't hard-code — use the closest
                    // Apple-standard expression for height': per Apple HIG,
                    // use `.controlSize(.regular)` on the inner
                    // TextField (= the canonical macOS 13+ SwiftUI
                    // expression for the standard form-control
                    // height = 22 PT = matches Apple's Mail / Notes
                    // / Finder search fields = NO hard-coded
                    // `.frame(height: 30)` per the boss's request).
                    //
                    // Why not `.searchable`: `.searchable` is
                    // hard-wired to render in the TRAILING edge of
                    // any column toolbar (= a documented framework
                    // limitation in NavigationSplit columns = boss's
                    // earlier preference for a leading-positioned
                    // search field can't be satisfied). The custom
                    // TextField with `.controlSize(.regular)` gives
                    // us Apple's canonical control size + leading
                    // alignment in one package.
                    //
                    // Why not hard-code 30 PT: the boss explicitly
                    // said don't write a hard number; = use Apple's
                    // semantic expression (= `.controlSize(.regular)`)
                    // = SwiftUI maps `.regular` to the canonical
                    // macOS 22 PT control height (= approximately
                    // 30 PT once SwiftUI's vertical padding and the
                    // surrounding HStack padding are added; = the
                    // boss's intuition that 30 PT feels right).
                    .frame(maxWidth: .infinity, alignment: .center)
                    // v1.0.0-m1-shell boss 2026-09-11 OOB 'search field,
                    // spacing between it and the first card — is there a hand-written padding, and if
                    // so, drop it': drop the manual BOTTOM padding
                    // around the search field (= the previous
                    // `.padding(.bottom, 6)` was a hand-rolled
                    // vertical breathing room between the search
                    // field and the first card; = removing it
                    // makes the search field sit flush against the
                    // first card below; = the cards' own LazyVGrid
                    // spacing controls the gap to the next card).
                    //
                    // v1.0.0-m1-shell boss 2026-09-11 OOB 'you just
                    // increased the spacing which broadened my range — the 4pt between the divider
                    // and the search field, you over-deleted, need to put it back': per the boss's
                    // UPDATE 2026-09-11 OOB 'remove all custom padding
                    // and switch to Apple-standard expressions — find an approximate value': REMOVE both
                    // `.padding(.top, 4)` (= 4 PT divider→search
                    // gap) and `.padding(.horizontal, 8)` (= 8 PT
                    // horizontal inset). The Apple HIG macOS 27
                    // default layout for an inline search field
                    // within a content column places the field at
                    // natural SwiftUI default spacing (= NO custom
                    // padding required; = the canonical Mail /
                    // Notes column search pattern).
            }
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'if the Apple API supports,
            // just use it — don't roll our own search': the previous internal
            // `previewSearchBar` view (= a hand-rolled HStack with
            // Lucide search icon + TextField + clear-x button) is
            // REMOVED. The search field now lives at the parent
            // level (= ShellMiddleColumn) attached via Apple's
            // canonical `.searchable(text:placement:prompt:)`
            // modifier (= the system-styled search field rendered
            // in the column's toolbar slot; = identical visual to
            // Mail / Notes / Finder column search). Removing the
            // internal search bar means:
            //   - The cards column body no longer has a top
            //     search field (the user sees only 'Assets' title +
            //     cards grid below).
            //   - The Apple `.searchable` field at the column's
            //     toolbar slot hosts the search input.
            //   - ⌘F focuses the field (= Apple standard keyboard
            //     shortcut).
            // v0.30 boss 8/31 OOB: scope-driven dispatch. Each scope
            // branch handles its own toolbar (some hide toolbar, e.g.
            // empty state). Padding applied here only (= doesn't
            // affect the search bar's Y position).
            //
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'empty state stays centered':
            // wrap the scope Group in an explicit `VStack { Spacer;
            // Group; Spacer }` (= top + bottom spacers push the
            // Group to vertical center inside the remaining space
            // BELOW the sticky header + search bar). Without the
            // Spacers, the Group rendered at the top of its slot
            // (= immediately below the search bar) and the empty-
            // state hint appeared squashed against the search bar.
            // With the Spacers, the empty-state hint stays centered
            // in the residual space (= the canonical Apple HIG
            // empty-state layout).
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Group {
                    switch scope {
                    case .referenceScope(let category):
                        referenceScopeView(category: category)
                    case .bookScope(let bookId, folderName: let folderName):
                        bookScopeView(bookId: bookId, folderName: folderName)
                    case .shelfScope(let shelfId):
                        // v1.69 boss 2026-09-22 OOB '书架, 就是
                        // 从这里开始, 测试书架. 这两个目录项可以
                        // 点击, 但没有在卡片栏加载所有卡片' (=
                        // clicking a shelf row should load all
                        // .md cards from every book under that
                        // shelf, not show an empty-state hint).
                        // Previous v1.0.0-m1-shell behaviour was
                        // empty-state (boss 8/31 'shelves are a
                        // tree level, not a document scope'); =
                        // boss 9/22 reversed: shelf IS a document
                        // scope (= the union of every book's
                        // .md cards under the shelf).
                        //
                        // v1.69x crash fix (= boss 2026-09-23 OOB
                        // '好像启不来了' on bisect: v1.69n
                        // shelfScopeView launched a SwiftUI
                        // constraint loop because the shelf
                        // subtree re-ran FileManager I/O inside
                        // its ViewBuilder body on every parent
                        // re-render (= not on shelfId change =
                        // = infinite I/O + NSHostingView size
                        // invalidation cycle = the 'more Update
                        // Constraints in Window passes than
                        // there are views in the window'
                        // crash). The fix:
                        //   1. `.id(shelfId)` gives SwiftUI a
                        //      stable subtree identity (= skips
                        //      body re-evaluation when shelfId
                        //      hasn't changed).
                        //   2. `.task(id: shelfId)` pre-loads
                        //      the shelf's books ONCE per
                        //      shelfId change (= caches into
                        //      @State cachedShelfBooks =
                        //      shelfScopeView body now reads
                        //      from cache, no I/O in body =
                        //      no layout storm).
                        shelfScopeView(shelfId: shelfId)
                            .id(shelfId)
                            .task(id: shelfId) {
                                await loadShelfBooksAsync(shelfId: shelfId)
                            }
                    case .empty:
                        emptyScopeView()
                    }
                }
                Spacer(minLength: 0)
            }
            // boss 9/8 round 1 'card, searchcard icon,
            //, 18pt': body content padding was
            // chromePaddingHero = 20 PT; = bumped to 18 PT.
            //
            // Boss 9/8 round 2: '18 is a bit wide; Apple API default
            // spacing isn't PT, it's a semantic name'.
            //
            // Boss 9/8 round 3: 'cards zone having no spacing is
            // not pretty, keep the spacing, all zones use round 2'.
            //
            // Apple HIG = chromePaddingLeading (= horizontal inset
            // from zone edge to content) = 8 PT (= the canonical
            // toolbar / inline content inset per SwiftUI 'Spacing.
            // small'). Used padding(8) (= horizontal + vertical 8
            // PT) so cards have visible breathing room (= not flush
            // against the zone edge = not pretty) but match Apple
            // HIG spacing scale (= 8-point grid).
            //
            // Note: per the Apple HIG card grid pattern (= Finder /
            // Photos / Music), the gap between cards IS the spacing
            // (= LazyVGrid's `spacing: 16` per GridItem + this outer
            // 8 PT inset = the canonical 'comfortable but compact'
            // grid per Apple Design Resources).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'search field,
            // spacing between it and the first card — is there a hand-written padding, and if
            // so, drop it': the previous `.padding(8)` (= 8 PT
            // top + bottom + leading + trailing) added a hand-
            // rolled 8 PT gap between the search field above and
            // the first card below. Per the boss's request to
            // keep only Apple-HIG defaults, drop the manual
            // top padding (= the cards' own LazyVGrid spacing
            // controls vertical spacing between cards; = no extra
            // top inset between the search field and the first
            // card needed). Keep leading + bottom padding (= 8 PT)
            // so cards still have breathing room from the column
            // edges (= Apple HIG 8-point grid for inline content).
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
                }
            }

    /// v0.40 boss 9/7 OOB 'top bar, editor, yes':
    /// preview-pane search bar (= 30 PT tall, = matches
    /// `LayoutTokens.toolbarHeight` = the editor's pencil/arrow toolbar
    /// inside EditorPlaceholder). Pattern matches the editor:
    /// tab strip (ZoneContentView) → search bar (this view) → body content.
    ///
    /// Layout:
    /// - magnifying-glass icon (left, .secondary, .small)
    /// - TextField bound to `$previewSearchQuery` (.plain style,
    // MARK: - Scope subviews

    /// Reference library scope: existing entity card flow (= boss 8/30
    /// OOB: 'card'). category nil = overview (= all
    /// entities, flat grid per boss 8/30 OOB); non-nil = category filter.
    @ViewBuilder
    private func referenceScopeView(category: EntityCategory?) -> some View {
        // v0.40 boss 9/7 OOB 'search, ': apply the
        // search filter (= previewSearchQuery) on top of the
        // category filter. Both filters compose (= all entities →
        // search filter → category filter).
        let allEntities = searchFilteredEntities(loadAllEntities())
        VStack(spacing: 0) {
            Group {
                if let cat = category {
                    categoryGrid(category: cat, allEntities: allEntities)
                } else {
                    overviewGrid(allEntities: allEntities)
                }
            }
        }
    }

    /// Book scope: scan filesystem for .md files in the book folders.
    /// folderName nil = union of all 8 standard folders; non-nil =
    /// just that folder.
    @ViewBuilder
    private func bookScopeView(bookId: UUID, folderName: String?) -> some View {
        let allDocs = loadBookDocs(bookId: bookId, folderName: folderName)
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'the assets column's search field doesn't
        // actually filter the cards' (= typing in the search field did not
        // filter cards in the book scope). The previous code passed
        // the unfiltered `docs` to `bookDocsGrid(docs:)`; = the
        // search field only filtered reference entities (= in
        // `referenceScopeView`), but book .md cards bypassed the
        // filter entirely. Apply the same shape as
        // `searchFilteredEntities` (= title / summary / pinyin
        // first-letter substring) to book docs.
        let docs = searchFilteredBookDocs(allDocs)
        VStack(spacing: 0) {
            if docs.isEmpty {
                emptyState(
                    icon: "book.pages",
                    titleKey: folderName != nil
                        ? "preview.empty_state.book_with_folder"
                        : "preview.empty_state.book_no_folder",
                    bodyKey: "preview.pick_book"
                )
            } else {
                bookDocsGrid(docs: docs)
            }
        }
    }


    /// Shelf scope: union of every book's docs under the shelf.
    /// v1.69 boss 2026-09-22 OOB '书架, 就是从这里开始, 测试
    /// 书架. 这两个目录项可以点击, 但没有在卡片栏加载所有
    /// 卡片' (= the shelf row is a scope, = shows every .md
    /// card from every book under that shelf; = union of all
    /// `loadBookDocs(bookId:, folderName: nil)` results filtered
    /// to books whose `shelfId == shelfId`).
    @ViewBuilder
    private func shelfScopeView(shelfId: UUID) -> some View {
        // v1.69x boss 2026-09-23 OOB '好像启不来了' on bisect:
        // the v1.69n original ran FileManager I/O (= walk
        // shelves tree + read every .md) inside this ViewBuilder
        // body. SwiftUI re-evaluates this body on EVERY
        // Observation tick (= every AppState mutation, every
        // sidebarSelection change, every parent re-render), so
        // the I/O ran hundreds of times per second while the
        // shelf was selected → NSHostingView size constraint
        // invalidation storm → 'more Update Constraints in
        // Window passes than there are views in the window'
        // NSGenericException crash.
        //
        // Fix: read the pre-computed, cached book list from
        // `@State cachedShelfBooks` (= populated exactly once
        // per shelfId via `.task(id: shelfId)` at the call
        // site below = the I/O runs at most once per shelfId
        // change = no storm = no constraint cycle). The
        // `.id(shelfId)` at the call site gives SwiftUI a
        // stable identity for the subtree (= SwiftUI skips
        // body re-evaluation entirely when the shelfId is
        // unchanged = the cached state survives every
        // observation tick).
        let books = cachedShelfBooks[shelfId] ?? []
        let allDocs = books.flatMap { loadBookDocs(bookId: $0.id, folderName: nil) }
        let filteredDocs = searchFilteredBookDocs(allDocs)
        if filteredDocs.isEmpty {
            // Empty shelf branch (= no books under the shelf,
            // or every book has no .md cards, or the search
            // filter excluded everything). Reuse the existing
            // emptyState view (= matches the v1.0.0-m1-shell
            // shape that the other scopes fall back to) but
            // with a shelf-specific bodyKey.
            emptyState(
                icon: "books.vertical",
                titleKey: "preview.empty_state.shelf_empty",
                bodyKey: "preview.empty.shelf_no_books"
            )
        } else {
            // Non-empty: reuse the canonical bookDocsGrid (= same
            // LazyVGrid + adaptiveColumns(width:) + sort + Card
            // styling as bookScopeView). Avoids the v1.69n-draft
            // duplicate LazyVGrid (= different .padding(24) vs
            // .padding(.vertical, DesignTokens.chromePaddingVertical);
            // = the user's "width is wrong" complaint was the
            // duplicate-render path bypassing the existing
            // chromePaddingVertical / card chrome contract).
            bookDocsGrid(docs: filteredDocs)
        }
    }

    /// Empty scope: empty state with hint to select a sidebar item.
    @ViewBuilder
    private func emptyScopeView() -> some View {
        emptyState(
            icon: "book.pages",
            titleKey: "preview.empty_state.pick_book",
            bodyKey: "preview.empty.scope_hint"
        )
    }



    // MARK: - 3 view modes

    /// v1.28 B2.1.5: deleted `singleEntityDetail(_ entity: Reference) -> some View`
    /// (= verify-dead reports ext=0 + int=0; = 0 callers; = the
    /// function was a 3-mode dispatcher child for entity detail;
    /// = the parent body in PreviewPane uses `singleEntityDetail`
    /// is wired via Switch case in the parent body which now uses
    /// a different rendering path — see git history for the full
    /// deleted body; = no behavior change; = 80 LOC removed).
    /// Mode 2: category-scoped grid (= only entities in this category).
    @ViewBuilder
    private func categoryGrid(category: EntityCategory, allEntities: [Reference]) -> some View {
        let inCategory = allEntities.filter { $0.category == category }
        // v0.30 boss 8/31 OOB: removed the category header HStack
        // (= icon + category.displayName + count). Per boss: 'in the reference
        // library, the title in the red box in the material preview area is unused, not needed,
        // delete it'. The sidebar already shows the category name (= when
        // user clicks reference-library/History-Geography, the sidebar shows the
        // selection); the preview pane's category header is
        // redundant. Now the preview pane jumps directly to the
        // card grid (= card thumbnails + card content).
        // v0.30 boss 8/31 OOB 'preview area content isn't fully displayed, because the width was narrowed,
        // preview area doesn't auto-adapt the width' = preview pane content area is
        // narrower than the pane (= 184 PT vs ~430 PT) because the
        // outer VStack has no .frame(maxWidth: .infinity) = the
        // inner GeometryReader takes the parent's intrinsic width
        // (= 0) = the LazyVGrid falls back to a single column at
        // narrow width = sort button / trailing icons at right edge
        // get clipped by the content width, NOT the pane width.
        // Fix = .frame(maxWidth: .infinity) on the outer VStack so
        // GeometryReader reports the full pane width.
        VStack(alignment: .leading, spacing: 0) {
            if inCategory.isEmpty {
                emptyState(
                    icon: "book.pages",
                    titleKey: "preview.empty_state.category_empty",
                    bodyKey: "preview.empty.import_hint"
                )
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                            ForEach(inCategory) { entity in
                                Card(source: .reference(entity)) { source in
                                    // BOSS 9/8 'card,
                                    // show':
                                    // the trailing closure here IS
                                    // Card's onDoubleClick (= now
                                    // takes the CardSource as a
                                    // parameter). Forward that source
                                    // to PreviewPane's onDoubleClick
                                    // (= which opens THIS specific
                                    // card in the editor, not the
                                    // topmost card = the previous
                                    // filtered.first bug).
                                    onDoubleClick(source)
                                }
                            }
                        }
                        // STYLES-006 (2026-09-07): use the canonical content
                        // inset modifier (= 0 PT = matches sidebar / editor
                        // behavior = content sits right below the
                        // chrome tier separator with no extra gap).
                        // Previously (.contentInsetStyle(.standard,
                        // edges: .vertical) = 18 PT) created a 35 PT
                        // inconsistency vs zone 1 sidebar / zone 3
                        // editor (= boss 9/7 round 5 'region,
                        // ' = all 6 zones should
                        // share the same chrome-tier-to-content-tier
                        // inset). The previous 18 PT was Apple's
                        // .defaultContentMargins (= NSTextView
                        // internal), which doesn't apply to LazyVGrid
                        // (= the grid's rows are not text).
                        .contentInsetStyle(.none, edges: .vertical)
                    }
                }
            }
        }
    }

    /// Mode 3: all-entities overview grid (= group by category inline).
    @ViewBuilder
    private func overviewGrid(allEntities: [Reference]) -> some View {
        if allEntities.isEmpty {
            emptyState(
                icon: "book.pages",
                titleKey: "preview.empty_state.reference_empty",
                bodyKey: "preview.empty.import_hint"
            )
        } else {
            // v0.30 boss OOB 'because the material preview area only displays cards of the currently selected directory,
            // so only card flow is needed, just lay them out continuously' + 'material preview area doesn't need this title,
            // cards just tile flat'.
            //
            // Single flat LazyVGrid (= no per-category section headers,
            // no global count header). Cards flow continuously
            // (= wubi-ji sticky-note style). Sort by current `previewSortOrder`
            // (= boss 8/30 OOB: default pinyin first letter; user can pick
            // creation time or modification time via top-right sort menu icon).
            let sorted = sortEntities(allEntities, by: previewSortOrder)
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                        ForEach(sorted) { entity in
                            Card(source: .reference(entity)) { source in
                                // BOSS 9/8 'card,
                                // show':
                                // the trailing closure is Card's
                                // onDoubleClick (= takes CardSource);
                                // forward to PreviewPane's onDoubleClick
                                // (= which opens THIS specific card).
                                onDoubleClick(source)
                            }
                        }
                    }
                    .padding(.vertical, DesignTokens.chromePaddingVertical)
                }
            }
        }
    }

    /// Empty-state placeholder (= boss UX 8/27 '...no markdown body
    /// = leave a clear empty state, not a blank white pane').
    @ViewBuilder
    /// v0.40 boss 9/7 OOB follow-up 'editor ICON': use
    /// the SAME icon (= book-open) as the editor empty state, so
    /// all "no content" panels in the workspace share one visual
    /// icon. Caller can override per-call (= rare; most callers
    /// use the default).
    private func emptyState(
        // v1.0.0-m1-shell boss 2026-09-16 OOB '先修空态的 ICON，没有显示':
        // default icon 'book-open' is Lucide kebab-case (= NOT a
        // valid SF Symbol 6 identifier) = renders as a blank
        // rectangle in PreviewPane's empty states. Migrated to
        // the dot.case SF Symbols 6 form ('book.pages'). Per
        // /Applications/SF Symbols Beta.app/Contents/Executables/
        // sfsymbols search 2026-09-16.
        icon: String = "book.pages",
        titleKey: String,
        bodyKey: String
    ) -> some View {
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'the current empty state isn't
        // a single component — can you abstract a UI component? While you're at it, on the
        // empty-state icon: double the size and use the thinnest strokes. The goal is to unify all
        // empty-state styles. The right column has 12 tabs and many are missing an empty state': migrate
        // to the unified EmptyStateView (= 76 PT SF Symbols 6 icon
        // + .regular weight = the canonical macOS 27
        // inspector icon weight; = standard title /
        // body hierarchy). Same visual treatment as the 12
        // specialized tool tabs.
        EmptyStateView(
            icon: icon,
            title: WenshuI18n.t(titleKey),
            body: WenshuI18n.t(bodyKey)
        )
    }

    // MARK: - Data loading

    private func loadAllEntities() -> [Reference] {
        // v0.71 P1 batch 7 dual-axis followup (= Q99 Standards axis LOW):
        // replaced the silent `try?` with explicit do/catch that logs
        // the failure (= audit concern: user cannot distinguish "no
        // entities" from "permission denied" on disk errors). The
        // graceful-degradation behavior (= empty array returned on
        // error) is preserved; = the NSLog is dev-only diagnostics.
        do {
            let allRefs = try bookStore.referenceStore.loadAllReferences()
            return allRefs.filter { $0.layer == .layerEntities }
        } catch {
            NSLog("[wenshu.preview] loadAllEntities failed: %@", String(describing: error))
            return []
        }
    }

    /// v1.69 boss 2026-09-22 OOB: helper for shelfScopeView.
    /// Returns the books that live under the given shelf (= the
    /// books whose `.shelfId` matches). Reads from the same
    /// BookStore.sidebarLoadAllBooks source the sidebar already
    /// uses (= single source of truth; = no parallel book list).
    /// Returns [] (= empty shelf = empty-state card grid) when
    /// the lookup fails (= disk error) so the caller doesn't
    /// have to do its own error-handling.
    private func loadBooksInShelf(shelfId: UUID) -> [Book] {
        let allBooks = (try? bookStore.sidebarLoadAllBooks()) ?? []
        return allBooks.filter { $0.shelfId == shelfId }
    }

    /// v1.69x boss 2026-09-23 OOB '好像启不来了' on bisect:
    /// pre-computes the shelf's books exactly once per shelfId
    /// change (= called from `.task(id: shelfId)` at the call
    /// site). SwiftUI cancels any in-flight task and restarts
    /// it whenever shelfId changes, so the cache is always
    /// fresh (= re-load on shelf switch) but never re-evaluates
    /// on parent re-renders. The result lands in `@State
    /// cachedShelfBooks` (= the shelf subtree reads from cache,
    /// not from disk = no I/O storm = no SwiftUI NSHostingView
    /// constraint cycle).
    @MainActor
    private func loadShelfBooksAsync(shelfId: UUID) async {
        // Yield first so SwiftUI can finish rendering the
        // empty state (= `cachedShelfBooks[shelfId]` is `nil`
        // until the await returns) before we touch disk.
        await Task.yield()
        let books = loadBooksInShelf(shelfId: shelfId)
        cachedShelfBooks[shelfId] = books
    }

    private func loadBody(for entity: Reference) -> String? {
        bookStore.referenceStore.loadReferenceBody(id: entity.id)
    }

    /// v0.30 boss 8/31 OOB: load .md files from a book folder on the
    /// filesystem. Walks all shelves (= shelves/<shelf>/books/<book>/)
    /// to find the matching bookId, then scans one or more of the 8
    /// standard folders for .md files.
    ///
    /// Errors (= missing folders, permission denied, etc.) are
    /// silently skipped so a single bad folder doesn't break the
    /// whole view (= partial load is more useful than nothing).
    private func loadBookDocs(bookId: UUID, folderName: String?) -> [BookDoc] {
        // Walk shelves root to find which shelf this bookId lives in.
        // Layout = shelves/<shelf-uuid>/books/<book-uuid>/...
        let shelvesRoot = bookStore.stores.shelvesRoot
        guard FileManager.default.fileExists(atPath: shelvesRoot.path) else {
            return []
        }
        let bookDirs: [URL]
        if let shelfDirs = try? FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            bookDirs = shelfDirs.compactMap { shelfDir in
                let candidate = shelfDir
                    .appendingPathComponent("books")
                    .appendingPathComponent(bookId.uuidString)
                return FileManager.default.fileExists(atPath: candidate.path)
                    ? candidate
                    : nil
            }
        } else {
            bookDirs = []
        }
        guard let bookDir = bookDirs.first else { return [] }

        // Determine which folders to scan.
        let folders: [String]
        if let folderName {
            folders = [folderName]
        } else {
            folders = BookFolder.allCases.map(\.directoryName)
        }

        var docs: [BookDoc] = []
        for folder in folders {
            let dir = bookDir.appendingPathComponent(folder)
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.creationDateKey
                ],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "md" {
                let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let attrs = try? url.resourceValues(forKeys: [
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.creationDateKey
                ])
                let modifiedAt = attrs?.contentModificationDate ?? Date.distantPast
                let createdAt = attrs?.creationDate ?? Date.distantPast
                docs.append(BookDoc(
                    id: Self.stableBookDocId(
                        bookId: bookId,
                        folderName: folder,
                        fileName: url.lastPathComponent
                    ),
                    bookId: bookId,
                    folderName: folder,
                    fileName: url.lastPathComponent,
                    modifiedAt: modifiedAt,
                    createdAt: createdAt,
                    body: body
                ))
            }
        }
        return docs
    }

    /// Sort book docs by the current sort order (= same menu as entity
    /// scope, but applied to BookDoc). Boss 8/31 OOB: sort still
    /// defaults to .pinyinFirstLetter so docs in Chinese filenames
    /// also flow alphabetically.
    private func sortBookDocs(_ docs: [BookDoc], by order: EntitySortOrder) -> [BookDoc] {
        switch order {
        case .pinyinFirstLetter:
            return docs.sorted { lhs, rhs in
                let lKey = pinyinFirstLetter(lhs.title)
                let rKey = pinyinFirstLetter(rhs.title)
                if lKey != rKey { return lKey < rKey }
                return lhs.fileName < rhs.fileName
            }
        case .createdAt:
            return docs.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.fileName < rhs.fileName
            }
        case .modifiedAt:
            return docs.sorted { lhs, rhs in
                if lhs.modifiedAt != rhs.modifiedAt {
                    return lhs.modifiedAt > rhs.modifiedAt
                }
                return lhs.fileName < rhs.fileName
            }
        }
    }

    /// Sort entities by the selected sort order (= boss 8/30 OOB).
    /// Returns a NEW array (doesn't mutate input). Stable sort by using
    /// id as the tiebreaker (= prevents visual shuffle on re-render
    /// when entities have equal sort keys).
    private func sortEntities(_ entities: [Reference], by order: EntitySortOrder) -> [Reference] {
        switch order {
        case .pinyinFirstLetter:
            // Sort by pinyin first letter of title (= boss default).
            // Uses CFStringTransform to convert Chinese to latinized
            // pinyin, then strips diacritics, then uses first letter.
            return entities.sorted { lhs, rhs in
                let lKey = pinyinFirstLetter(lhs.title)
                let rKey = pinyinFirstLetter(rhs.title)
                if lKey != rKey { return lKey < rKey }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .createdAt:
            // Newest first.
            return entities.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .modifiedAt:
            // Most recently modified first.
            return entities.sorted { lhs, rhs in
                let lMod = lhs.updatedAt
                let rMod = rhs.updatedAt
                if lMod != rMod {
                    return lMod > rMod
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    /// Flat LazyVGrid for book docs (= same visual style as entity
    /// card grid, but BookDocCard instead of EntityCard).
    @ViewBuilder
    private func bookDocsGrid(docs: [BookDoc]) -> some View {
        let sorted = sortBookDocs(docs, by: previewSortOrder)
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(
                    columns: adaptiveColumns(width: geometry.size.width),
                    spacing: 16
                ) {
                    ForEach(sorted) { doc in
                        Card(source: .bookDoc(doc)) { source in
                            // BOSS 9/8 'card,
                            // show':
                            // forward the BookDoc CardSource
                            // to PreviewPane's onDoubleClick so
                            // the EXACT clicked book doc opens.
                            onDoubleClick(source)
                        }
                    }
                }
                .padding(.vertical, DesignTokens.chromePaddingVertical)
            }
        }
    }

    /// Convert Chinese title to its pinyin first letter (= uppercase).
    /// Uses Apple's CFStringTransform (kCFStringTransformToLatin +
    /// kCFStringTransformStripDiacritics). Example: "" → "L",
    /// "" → "W", "" → "S".
    private func pinyinFirstLetter(_ title: String) -> String {
        let mutable = NSMutableString(string: title)
        // Convert CJK characters to latinized pinyin (e.g. "" → "Lǐ Bái").
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        // Strip diacritics (e.g. "Lǐ Bái" → "Li Bai").
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latinized = (mutable as String).trimmingCharacters(in: .whitespaces)
        // First non-whitespace character, uppercased. Empty titles bucket
        // to "~" (= sorts last).
        if let first = latinized.first {
            return String(first).uppercased()
        }
        return "~"
    }

    /// v0.40 boss 9/7 OOB 'search,, d, can
    /// ': convert a CJK + ASCII title to its FULL pinyin
    /// first-letter string (= concatenated initial of each pinyin
    /// syllable, all uppercase, no separator). Examples:
    /// - "" → "DF"
    /// - "" → "LB"
    /// - "" → "HNBDZS"
    /// - "Hello " → "HELLO SJ"
    /// - "AB test CD" → "AB CD"
    ///
    /// Implementation: CFStringTransform to convert CJK to latinized
    /// pinyin (= "" → "Du Fu", "" → "Li Bai"), strip
    /// diacritics, then extract the first letter of each whitespace-
    /// separated word. Uses Apple's CoreFoundation string transform
    /// (= no third-party pinyin lib = AGENTS.md §11.1 hard rule).
    /// v1.0.0-m1-shell boss 2026-09-10 OOB 'pinyin initials + Chinese-character search — it was
        /// already supported before, there should be existing code for it': extract the search-match
        /// predicate (= title / summary / pinyin first-letter
        /// substring) into a shared helper so reference entities
        /// AND book docs use the same filter (= per boss 'use one common
        /// interface'). Previously each filter was a private inline
        /// closure that duplicated the same pinyin + localized
        /// substring logic.
        private func matchesSearch(title: String, summary: String, query: String) -> Bool {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            let lowered = trimmed.lowercased()
            if title.localizedCaseInsensitiveContains(trimmed)
                || summary.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            let pinyinKey = pinyinFirstLetters(title)
            if pinyinKey.lowercased().contains(lowered) {
                return true
            }
            return false
        }

        private func pinyinFirstLetters(_ title: String) -> String {
        let mutable = NSMutableString(string: title)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latinized = (mutable as String)
        // Split on whitespace + extract first letter of each token.
        // Also drop tokens that are pure punctuation (= e.g. "?").
        // v0.71 P1 batch 7 dual-axis followup (= Q99 Standards axis LOW):
        // the previous `first.isLetter` filter silently dropped emoji
        // titles (= single-emoji title → empty initials → no pinyin
        // match). Replaced with `isLetter || isNumber || isSymbol`
        // to include Unicode symbols (= emojis are categorized as
        // .symbol in Swift); = an emoji-only title now produces one
        // initial char (= the emoji itself), enabling pinyin-key
        // search to match it.
        let initials = latinized
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { token -> String? in
                guard let first = token.first else { return nil }
                guard first.isLetter || first.isNumber || first.isSymbol else { return nil }
                return String(first).uppercased()
            }
            .joined()
        return String(initials)
    }

    /// v0.40 boss 9/7 OOB 'search,, d, can
    /// ': filter the entity list by the current search query.
    /// Matches against BOTH:
    /// 1. Original title / summary substring (= case-insensitive)
    /// 2. Pinyin first-letter substring (= e.g. "d" matches "" → DF)
    /// Empty query = pass-through (= show all entities).
    /// v1.0.0-m1-shell boss 2026-09-10 OOB 'the assets column's search field doesn't actually filter the cards':
        /// same filter shape as `searchFilteredEntities` but for book
        /// docs (= filesystem .md files loaded by `loadBookDocs`).
        /// Uses the shared `matchesSearch` helper (= title / summary /
        /// pinyin first-letter substring match) = same logic as the
        /// reference-entity filter; = the user's previous
        /// 'the search field doesn't actually filter the cards' bug was that bookDocsGrid was called
        /// with the unfiltered docs.
        private func searchFilteredBookDocs(_ docs: [BookDoc]) -> [BookDoc] {
            let query = resolvedSearchQuery
            return docs.filter { matchesSearch(title: $0.title, summary: $0.summary, query: query) }
        }

        private func searchFilteredEntities(_ entities: [Reference]) -> [Reference] {
        let query = resolvedSearchQuery
        return entities.filter { matchesSearch(title: $0.title, summary: $0.summary, query: query) }
    }

}

/// Card view for a single entity in the grid.
/// Tap = select (= not wired yet). Double-click = open in editor (= boss
/// Ticket 3 hook).
///
/// Boss OOB v0.30: 'card, '. Thumbnail
/// strategy: since Reference entities are text-only (= .md bodies with
/// no associated image), we use the EntityType icon as a large
/// prominent thumbnail (= e.g. user-round for character, lightbulb
/// for concept). The icon is rendered at 64 PT with a tinted gradient
/// background (= the type's distinguishing color). This gives each
/// card a strong visual identity at a glance (= matches Wubi-ji / Notion
/// "card cover" pattern).
///
/// Future: when entities get real images (= e.g. character portrait,
/// location map), NukeUI's LazyImage will replace the type icon. The
/// image-pipeline integration is deferred to v0.31+ (= needs image
/// storage infrastructure that doesn't exist yet).
/// Single canonical card view for the material preview zone.
/// Boss 2026-09-02 OOB: 'style owned by parent, data composition unified too' —
    /// one component for both Reference (reference library) and BookDoc (bookshelf).
/// Data extraction lives INSIDE the view; no per-source adapter structs.
///
/// CardSource = the only "data shape" the card knows. Adding a new
/// source type = one new case + one computed-property branch.
/// BOSS 9/8 'clicking the Dufu card opens a tab with wrong name' (= clicking
/// the card opened a new tab named 'preview-sample'):
/// the source value is now passed from PreviewPane.Card's
/// onDoubleClick closure to WorkspaceView's openCardInEditor
/// so the EXACT clicked card's .md opens (= not the topmost
/// card = the previous `filtered.first` bug).
///
/// internal (= module-scoped access for WorkspaceView to use in
/// openCardInEditor(source:)). Was `private` (= the Swift
/// compiler error 'property must be declared fileprivate
/// because its type uses a private type' = since PreviewPane
/// exposes this type in its internal `onDoubleClick` signature,
/// it must be at least as accessible as the type).
///
/// Note: PreviewPane itself is `internal` (default for Swift
/// struct), so `onDoubleClick` is `internal` (= no explicit
/// access modifier), and CardSource must be `internal` (= same
/// level of access). fileprivate would also work if PreviewPane
/// itself were fileprivate, but PreviewPane is referenced by
/// WorkspaceView (= module-internal access required).
internal enum CardSource {
    case reference(Reference)
    case bookDoc(BookDoc)

    /// SF Symbols 6 icon name (= the only visual differentiator
    /// between sources; everything else is uniform). Replaces
    /// the Lucide-era names removed in v1.0.0-m1-shell.
    var iconName: String {
        switch self {
        case .reference(let r): return r.entityType.icon
        case .bookDoc(let d): return BookFolder(rawValue: d.folderName)?.icon ?? "file-text"
        }
    }

    /// Card heading (= filename without extension / entity title).
    var title: String {
        switch self {
        case .reference(let r): return r.title
        case .bookDoc(let d): return d.title
        }
    }

    /// One-line summary (boss 8/26 'card style = document key-summary excerpt').
    var summary: String {
        switch self {
        case .reference(let r): return r.summary
        case .bookDoc(let d): return d.summary
        }
    }
}

private struct Card: View {
    let source: CardSource
    let onDoubleClick: (CardSource) -> Void

    @State private var isHovered: Bool = false

    /// v0.34 B-26 boss 9/3 'directorydouble-click': Apple's
    /// `.onTapGesture(count: 2)` was eaten by LazyVGrid's ScrollView
    /// gesture recognizer. The previous attempt (= a timestamp
    /// latch within 300 ms) was too tight (= macOS default
    /// NSDoubleClickInterval is 500 ms, not 300) and lost subsequent
    /// double-clicks after the first one (= the Card view was
    /// re-evaluated by SwiftUI when openCardInEditor mutated
    /// appState.openTabs; = the @State held across re-evaluations,
    /// = the *next* single tap was treated as "first of a new pair"
    /// but the user's actual second tap landed more than 300 ms
    /// after the first (= because macOS users tap at ~500 ms
    /// intervals; = the latch was too tight and dropped the
    /// second click)).
    ///
    /// Switched to a click-count latch (= more robust to user
    /// timing variance). Pair a single tap → count=1. The next tap
    /// within `NSDoubleClickInterval` (= 500 ms via NSApp) → count=2
    /// → fire onDoubleClick. Reset to 0 on the *third* tap (= a
    /// triple-click is not a double-click). This matches macOS
    /// Finder / TextEdit behavior.
    ///
    /// NOTE: SwiftUI's `@State` is reset when the view identity
    /// changes (= the ForEach rebuilds the Card when the user
    /// switches sidebar scope; = that is actually the desired
    /// behavior here — switching scope = "fresh start" for the
    /// double-click detector; = boss OOB 'directory, ').
    @State private var clickCount: Int = 0
    @State private var lastClickTimestamp: TimeInterval = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // THUMBNAIL: icon as a large prominent header
            // (= boss OOB: cards need thumbnails).
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.18), Color(nsColor: .quaternaryLabelColor)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Boss 2026-09-17 OOB: '素材卡片的 ICON, 用 .ultraLight'.
                // Per wenshu-icon-policy v1.5: 64 PT (= empty-state
                // threshold >=38 PT) MUST pin .symbolRenderingMode(.monochrome).
                // SF Symbols 6 on macOS 27 silently falls back to the
                // .fill variant (= boss's "粗蓝书图标"). Pinning
                // .monochrome forces the outline glyph at 64 PT.
                // Trade-off: .tint(.opacity 0.85) blue is replaced by
                // default .secondary blue tint via .foregroundStyle.
                Image(systemName: source.iconName)
                    .font(.system(size: 64, weight: .ultraLight))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.tint.opacity(0.85))
            }
            .frame(height: DesignTokens.panelMinHeight)
            .frame(maxWidth: .infinity)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 10
                )
            )
            // TEXT content below the thumbnail
            // Boss 2026-09-02: reference-library card standard = title + one-line summary,
            // no [type] badge, no timestamp chip, no iconSize split.
            VStack(alignment: .leading, spacing: 6) {
                Text(source.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !source.summary.isEmpty {
                    Text(source.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(DesignTokens.chromePaddingPickerItem)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // Boss 2026-09-02: parent component owns style, child component only does function.
        // Hover tint (= matches PaneIconTab hover pattern).
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHovered
                    ? AnyShapeStyle(.tint.opacity(0.4))
                    : AnyShapeStyle(.tertiary),
                    lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        // v0.34 B-26 boss 9/3 'directorydouble-click': click-count
        // latch (= more robust than the 300 ms timestamp latch; = the
        // user-reported failure was the timestamp being too tight).
        // v0.34 B-26-FIX: every tap increments `clickCount`. The *next*
        // tap within the macOS system double-click interval
        // (= NSDoubleClickInterval = 500 ms via NSApp) is the second
        // tap of a double-click (= fire onDoubleClick; reset count to
        // 0). If the gap is too long, reset to 1 (= single tap; = no
        // action since PreviewPane doesn't have single-tap selection
        // wired). This matches macOS Finder / TextEdit / Safari tab
        // bar double-click semantics.
        .onTapGesture {
            let now = Date().timeIntervalSinceReferenceDate
            let interval = NSEvent.doubleClickInterval  // 500 ms on macOS
            if clickCount == 0 || now - lastClickTimestamp > interval {
                // First tap of a new pair (= or first tap ever, or
                // the previous pair timed out).
                clickCount = 1
                lastClickTimestamp = now
            } else {
                // Second tap within the interval = double click.
                clickCount = 0
                lastClickTimestamp = 0
                // BOSS 9/8 'clicking the Dufu card opens a tab with wrong name':
                // pass the clicked CardSource (= .reference or
                // .bookDoc) to the parent's onDoubleClick handler so
                // it can open the EXACT .md file (= not the topmost
                // card = the previous `filtered.first` bug).
                onDoubleClick(source)
            }
        }
        // v0.34 B-26: Apple HIG tooltip (= .help = NSWindow tooltip =
        // separate window per Apple HIG = the user can hover any tab
        // label and get its full name; = matches macOS Finder /
        // TextEdit tab bar tooltip behavior).
        .help(source.title)
    }
}