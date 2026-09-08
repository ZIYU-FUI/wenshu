// Sources/WenshuApp/Views/Workspace/PreviewPane.swift
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
// '双击卡片才会在编辑器里打开'). For now, single-click selects.
//
// Grid uses LazyVGrid (= Apple standard for variable-height grid;
// matches Finder icon view style).

import SwiftUI
import CoreFoundation  // v0.30: for CFStringTransform (pinyin sort)
import AppKit  // v0.34 B-26: NSDoubleClickInterval (= system double-click interval)

// MARK: - Sort order (v0.30 boss OOB)
//
// [CJK-TRANSLATE] 2 line(s) awaiting manual translation (see git blame for original CJK text)
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

    /// Lucide icon (= matches sidebar folder icons where they
    /// overlap; placeholder icons for the 3 hidden folders).
    var icon: String {
        switch self {
        case .world: return "globe"
        case .characters: return "user-round"
        case .outlines: return "list-tree"
        case .chapters: return "book-text"
        case .drafts: return "file-pen-line"
        case .sessions: return "message-square"
        case .foreshadowing: return "git-fork"
        case .placeholders: return "square-dashed"
        }
    }
}

enum EntitySortOrder: String, CaseIterable, Identifiable {
    case pinyinFirstLetter = "首字母"
    case createdAt = "创建时间"
    case modifiedAt = "修改时间"

    var id: String { rawValue }

    /// Lucide icon for the menu picker (= chevron-up-down for "sort").
    var menuIcon: String {
        switch self {
        case .pinyinFirstLetter: return "list-ordered"
        case .createdAt: return "list-ordered"
        case .modifiedAt: return "list-ordered"
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
// v0.40 boss 9/7 OOB '目录树和卡片, 都没有对应的持久化':
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
    let id: UUID = UUID()
    /// Folder directory name (= "world", "characters", "outlines",
    /// "chapters", "drafts", "sessions", "foreshadowing",
    /// "placeholders"). Used for the folder badge in the card.
    let folderName: String
    /// Full filename including .md extension (= e.g.
    /// "文枢是什么.md").
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

    /// Path component (= "world/文枢是什么.md") for sort by file
    /// name within folder (= boss 8/31 OOB: directory scoping
    /// includes the folder context).
    var displayPath: String {
        "\(folderName)/\(fileName)"
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
    /// BOSS 9/8 '点杜甫卡片, 新的标签页显示的名字不对' (= clicking
    /// the 杜甫 card opens a new tab with the wrong name):
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

    /// v0.30 boss OOB: '所有卡片默认排序是拼音首字母先后顺序'.
    /// Default = .pinyinFirstLetter (= boss spec). Owned by
    /// WorkspaceView (= shared with PreviewSortMenuButton via
    /// the @State binding) so changing the sort via the tab
    /// bar trailing button re-renders this view's card grid.
    @Binding var previewSortOrder: EntitySortOrder

    /// v0.40 boss 9/7 OOB '每打一个字, 内容自动刷新. 清空恢复全显':
    /// search query for the preview pane. Owned by PreviewPane
    /// (= previously a @Binding to WorkspaceView, = now reverted
    /// to @State since the search bar lives inside PreviewPane
    //  body; = the bind-chain is no longer needed). Empty string
    /// = show all cards; non-empty = filter by case-insensitive
    /// substring match on card display name + summary. SwiftUI
    /// @State reactivity re-evaluates `body` on every keystroke
    /// (= live refresh, no submit button, no .onChange handler
    /// needed).
    @State private var previewSearchQuery: String = ""

    /// Explicit init: required for @Binding in struct (= memberwise
    /// init doesn't support @Binding in non-result-builder structs).
    /// Pass-through of all other fields + wraps the binding.
    init(
        scope: PreviewScope,
        onDoubleClick: @escaping (CardSource) -> Void,
        previewSortOrder: Binding<EntitySortOrder>
    ) {
        self.scope = scope
        self.onDoubleClick = onDoubleClick
        self._previewSortOrder = previewSortOrder
    }

    // [CJK-TRANSLATE] 2 line(s) awaiting manual translation (see git blame for original CJK text)
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
    private static let twoColumnBreakpoint: CGFloat = 130

    var body: some View {
        // v0.40 boss 9/7 OOB '位置错, 在顶栏下方, 不是在顶栏上方.
        // 你可以参考一下编辑器的代码, 看是如何实现的': the search bar
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
        // v0.40 boss 9/7 OOB '这个顶栏和搜索之间是多了什么东西占位了吗':
        // the .padding(DesignTokens.chromePaddingHero) was wrapping
        // the entire VStack (= search bar + body), = creating a visual
        // gap between the ZoneContentView tab strip and the search
        // bar. The padding belongs ONLY on the body content (= scope
        // Group), NOT on the search bar (= search bar should sit
        // flush against the tab strip, = Apple HIG canonical toolbar
        // pattern = no padding between tab strip and toolbar).
        VStack(spacing: 0) {
            // 30 PT tall (= matches LayoutTokens.toolbarHeight =
            // editor's pencil/arrow toolbar inside EditorPlaceholder).
            // NO outer padding (= sits flush against ZoneContentView's
            // tab strip; = Apple HIG canonical toolbar pattern).
            previewSearchBar
            // v0.30 boss 8/31 OOB: scope-driven dispatch. Each scope
            // branch handles its own toolbar (some hide toolbar, e.g.
            // empty state). Padding applied here only (= doesn't
            // affect the search bar's Y position).
            Group {
                switch scope {
                case .referenceScope(let category):
                    referenceScopeView(category: category)
                case .bookScope(let bookId, let folderName):
                    bookScopeView(bookId: bookId, folderName: folderName)
                case .shelfScope:
                    shelfScopeView()
                case .empty:
                    emptyScopeView()
                }
            }
            // boss 9/8 round 1 '卡片预览区, 搜索卡片和 icon, 居左
            // 位置不对, 不够 18pt': body content padding was
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
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// v0.40 boss 9/7 OOB '在顶栏下方, 参考编辑器的代码, 看是如何实现的':
    /// preview-pane search bar (= 30 PT tall, = matches
    /// `LayoutTokens.toolbarHeight` = the editor's pencil/arrow toolbar
    /// inside EditorPlaceholder). Pattern matches the editor:
    /// tab strip (ZoneContentView) → search bar (this view) → body content.
    ///
    /// Layout:
    /// - magnifying-glass icon (left, .secondary, .small)
    /// - TextField bound to `$previewSearchQuery` (.plain style,
    ///   placeholder = `preview.search.placeholder`)
    /// - clear-x button (only when `!previewSearchQuery.isEmpty`)
    ///
    /// SwiftUI @State reactivity re-evaluates `body` (= and any
    /// consumers of `$previewSearchQuery`) on every keystroke
    /// (= live refresh, no submit button, no .onChange handler).
    private var previewSearchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .imageScale(.small)
            TextField(
                WenshuI18n.t("preview.search.placeholder"),
                text: $previewSearchQuery
            )
            .textFieldStyle(.plain)
            // v0.40 boss 9/7 OOB '拼音首字母搜索, 没有实现':
            // .help() on the search TextField advertises the
            // pinyin feature (= Apple canonical tooltip on hover;
            // = discoverable feature without needing docs).
            .help(WenshuI18n.t("preview.search.help_pinyin"))
            if !previewSearchQuery.isEmpty {
                Button {
                    previewSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help(WenshuI18n.t("preview.search.clear"))
            }
        }
        // boss 9/8 round 1 'cards preview zone, search bar and icon, left
        // position wrong, not enough 18pt' = bumped from 6 PT to
        // chromePaddingLeading = 18 PT.
        //
        // Boss 9/8 round 2: '18 is a bit wide; Apple API default
        // spacing isn't PT, it's a semantic name'.
        //
        // Boss 9/8 round 3: 'cards zone having no spacing is
        // not pretty, keep the spacing, all zones use round 2'.
        //
        // Final value: 8 PT (= Apple HIG canonical 'Spacing.small'
        // for inline toolbar items = SwiftUI's standard small
        // spacing = the same value Apple uses for ToolbarItem
        // horizontal spacing + for List row internal padding per
        // the swiftui-patterns design-polish reference).
        //
        // Per the Apple canonical semantic name (= the 'phrase'
        // boss remembers): SwiftUI exposes `.contentMargins(
        // .horizontal, _, for: .scrollContent)` (= the Apple-
        // provided semantic API for content margins per developer.
        // apple.com/documentation/swiftui/view/contentmargins(_:for:)).
        // For non-ScrollView inline toolbars (= this HStack-based
        // search bar) the equivalent = 8 PT (= SwiftUI's standard
        // 'small' spacing semantic = the closest Apple-canonical
        // value for inline controls per HIG spacing).
        //
        // Note: instead of using `.padding(.horizontal,
        // DesignTokens.chromePaddingLeading)`, we use the literal
        // `8` here (= same value as chromePaddingLeading after
        // round 3 token change). The literal preserves the
        // semantic Apple HIG value (= 8 PT) without depending on
        // the broader DesignTokens token (= the search bar is a
        // tight inline toolbar = its inset shouldn't drift with
        // other zone chrome changes).
        //
        // Result: search icon + TextField + clear-x all sit 8 PT
        // from the zone's left edge (= Apple HIG toolbar row
        // inset for inline controls).
        .padding(.horizontal, 8)
        // 30 PT height = matches LayoutTokens.toolbarHeight
        // (= editor's pencil/arrow toolbar + ZoneContentView tab strip).
        .frame(height: LayoutTokens.toolbarHeight)
        .background(Color.clear)
    }

    // MARK: - Scope subviews

    /// Reference library scope: existing entity card flow (= boss 8/30
    /// OOB: '随心记的卡片流'). category nil = overview (= all
    /// entities, flat grid per boss 8/30 OOB); non-nil = category filter.
    @ViewBuilder
    private func referenceScopeView(category: EntityCategory?) -> some View {
        // v0.40 boss 9/7 OOB '拼音首字母搜索, 没有实现': apply the
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // v0.30 fix
    }

    /// Book scope: scan filesystem for .md files in the book folders.
    /// folderName nil = union of all 8 standard folders; non-nil =
    /// just that folder.
    @ViewBuilder
    private func bookScopeView(bookId: UUID, folderName: String?) -> some View {
        let docs = loadBookDocs(bookId: bookId, folderName: folderName)
        VStack(spacing: 0) {
            if docs.isEmpty {
                emptyState(
                    icon: "book-open",
                    titleKey: folderName != nil
                        ? "preview.empty_state.book_with_folder"
                        : "preview.empty_state.book_no_folder",
                    bodyKey: "preview.empty.pick_book"
                )
            } else {
                bookDocsGrid(docs: docs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // v0.30 fix
    }

    /// Shelf scope: empty state with hint to drill into a book.
    @ViewBuilder
    private func shelfScopeView() -> some View {
        emptyState(
            icon: "book-open",
            titleKey: "preview.empty_state.shelf_empty",
            bodyKey: "preview.empty.pick_book"
        )
    }

    /// Empty scope: empty state with hint to select a sidebar item.
    @ViewBuilder
    private func emptyScopeView() -> some View {
        emptyState(
            icon: "book-open",
            titleKey: "preview.empty_state.pick_book",
            bodyKey: "preview.empty.scope_hint"
        )
    }



    // MARK: - 3 view modes

    /// Mode 1: single entity detail (= large card).
    @ViewBuilder
    private func singleEntityDetail(_ entity: Reference) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header: type badge + title
                HStack(spacing: 8) {
                    LucideIcon(entity.entityType.icon, size: 28)
                        .foregroundStyle(.tint)
                    Text(WenshuI18n.t("b5.previewpane.l353.h50033891"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let cat = entity.category {
                        Text(cat.displayName)
                            .font(.caption)
                            .padding(.horizontal, DesignTokens.chromePaddingVertical)
                            .padding(.vertical, DesignTokens.chromePaddingMicro)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
                Text(entity.title)
                    // EDITORFONT-001 (2026-09-07): was .largeTitle (=
                    // 26 PT on macOS 27 Tahoe) which made the editor
                    // title visually dominant vs sidebar items
                    // (".headline" = 13 PT) and kanban cards (=
                    // .headline). Boss 9/7 OOB: '调成其他区一样大' =
                    // align editor MD font to the rest of the app
                    // (= use .headline everywhere chrome uses
                    // .headline). The recent ab2b57021 fix changed
                    // WenshuMarkdownEditor (NSTextView edit mode)
                    // but the PreviewPane's preview-mode render
                    // path uses SwiftUI `Text(...).font(...)` which
                    // .largeTitle had been left untouched = this is
                    // the actual bug the boss saw. .headline here =
                    // 13 PT = matches sidebar/kanban/character-
                    // editor titles. Body below stays .body (= 13 PT
                    // = matches kanban card body).
                    .font(.headline)
                    .fontWeight(.bold)
                if !entity.summary.isEmpty {
                    Text(entity.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Divider()
                // Read-only preview of .md body (= full content)
                if let body = loadBody(for: entity) {
                    Text(body)
                        // EDITORFONT-001: was .body (= 13 PT) which
                        // already aligned with kanban card body.
                        // Explicit comment marks the alignment so
                        // future "make it bigger" requests don't
                        // silently grow the editor away from the
                        // rest of the app chrome.
                        .font(.body)
                        .textSelection(.enabled)
                } else {
                    Text(WenshuI18n.t("auto.previewpane.l381.h62416093"))
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            // ZONE-INSET-002 (2026-09-07): the preview zone content
            // inset = 18 PT all sides is now applied centrally by
            // ZoneContentView (= single source of truth for all 5
            // zones that route through it). Previously
            // .padding(DesignTokens.chromePaddingLeading) was applied
            // here (= 18 PT), now redundant (= ZoneContentView
            // already wraps this content with the same inset).
            // Removed the per-zone call (= boss 9/7 '样式其实可以
            // 抽象统一' = the content view should not own its own
            // edge inset; = the wrapper owns it = one token adjusts
            // all 5 zones).
            .frame(maxWidth: 800, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.clear)
            )
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

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
                    icon: "book-open",
                    titleKey: "preview.empty_state.category_empty",
                    bodyKey: "preview.empty.import_hint"
                )
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                            ForEach(inCategory) { entity in
                                Card(source: .reference(entity)) { source in
                                    // BOSS 9/8 '点杜甫卡片,
                                    // 新的标签页显示的名字不对':
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
                        // editor (= boss 9/7 round 5 '各区域内部元素,
                        // 符合上下左右间距规则' = all 6 zones should
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Mode 3: all-entities overview grid (= group by category inline).
    @ViewBuilder
    private func overviewGrid(allEntities: [Reference]) -> some View {
        if allEntities.isEmpty {
            emptyState(
                icon: "book-open",
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
                                // BOSS 9/8 '点杜甫卡片,
                                // 新的标签页显示的名字不对':
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
    /// v0.40 boss 9/7 OOB follow-up '和编辑器用同一个 ICON': use
    /// the SAME icon (= book-open) as the editor empty state, so
    /// all "no content" panels in the workspace share one visual
    /// icon. Caller can override per-call (= rare; most callers
    /// use the default).
    private func emptyState(
        icon: String = "book-open",
        titleKey: String,
        bodyKey: String
    ) -> some View {
        EmptyStateHint(
            icon: icon,
            title: WenshuI18n.t(titleKey),
            body: WenshuI18n.t(bodyKey)
        )
    }

    // MARK: - Data loading

    private func loadAllEntities() -> [Reference] {
        (try? bookStore.referenceStore.loadAllReferences())?
            .filter { $0.layer == .layerEntities } ?? []
    }

    private func loadBody(for entity: Reference) -> String? {
        try? bookStore.referenceStore.loadReferenceBody(id: entity.id)
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
                            // BOSS 9/8 '点杜甫卡片,
                            // 新的标签页显示的名字不对':
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
    /// kCFStringTransformStripDiacritics). Example: "李白" → "L",
    /// "未分类研究材料" → "W", "宋朝海上丝绸之路" → "S".
    private func pinyinFirstLetter(_ title: String) -> String {
        let mutable = NSMutableString(string: title)
        // Convert CJK characters to latinized pinyin (e.g. "李白" → "Lǐ Bái").
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

    /// v0.40 boss 9/7 OOB '拼音首字母搜索, 没有实现, 比如 d, 可以
    /// 筛出杜甫': convert a CJK + ASCII title to its FULL pinyin
    /// first-letter string (= concatenated initial of each pinyin
    /// syllable, all uppercase, no separator). Examples:
    /// - "杜甫"          → "DF"
    /// - "李白"          → "LB"
    /// - "汉尼拔的战术"  → "HNBDZS"
    /// - "Hello 世界"    → "HELLO SJ"
    /// - "AB 测试 CD"    → "AB CD"
    ///
    /// Implementation: CFStringTransform to convert CJK to latinized
    /// pinyin (= "杜甫" → "Du Fu", "李白" → "Li Bai"), strip
    /// diacritics, then extract the first letter of each whitespace-
    /// separated word. Uses Apple's CoreFoundation string transform
    /// (= no third-party pinyin lib = AGENTS.md §11.1 hard rule).
    private func pinyinFirstLetters(_ title: String) -> String {
        let mutable = NSMutableString(string: title)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latinized = (mutable as String)
        // Split on whitespace + extract first letter of each token.
        // Also drop tokens that are pure punctuation (= e.g. "?").
        let initials = latinized
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { token -> String? in
                guard let first = token.first, first.isLetter else { return nil }
                return String(first).uppercased()
            }
            .joined()
        return String(initials)
    }

    /// v0.40 boss 9/7 OOB '拼音首字母搜索, 没有实现, 比如 d, 可以
    /// 筛出杜甫': filter the entity list by the current search query.
    /// Matches against BOTH:
    /// 1. Original title / summary substring (= case-insensitive)
    /// 2. Pinyin first-letter substring (= e.g. "d" matches "杜甫" → DF)
    /// Empty query = pass-through (= show all entities).
    private func searchFilteredEntities(_ entities: [Reference]) -> [Reference] {
        let query = previewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entities }
        let loweredQuery = query.lowercased()
        return entities.filter { entity in
            // Original text substring match (= Latin + CJK chars both work
            // via String.localizedCaseInsensitiveContains).
            if entity.title.localizedCaseInsensitiveContains(query)
                || entity.summary.localizedCaseInsensitiveContains(query) {
                return true
            }
            // Pinyin first-letter substring match (= "d" → "DF" match).
            let pinyinKey = pinyinFirstLetters(entity.title)
            if pinyinKey.lowercased().contains(loweredQuery) {
                return true
            }
            return false
        }
    }

    /// v0.30 boss OOB: cards display in multiple columns, default two columns, auto-adapt to 1 column if not enough width.
    /// Returns adaptive GridItem array based on the available width.
    /// - width >= twoColumnBreakpoint: 2 columns (= default = boss request)
    /// - width <  twoColumnBreakpoint: 1 column (= narrow, single flow)
    private func adaptiveColumns(width: CGFloat) -> [GridItem] {
        if width >= Self.twoColumnBreakpoint {
            // 2 fixed columns (= 50/50 split with spacing in between)
            return [
                GridItem(.flexible(), spacing: 16, alignment: .topLeading),
                GridItem(.flexible(), spacing: 16, alignment: .topLeading),
            ]
        } else {
            // 1 column (= full width)
            return [GridItem(.flexible(), spacing: 16, alignment: .topLeading)]
        }
    }
}

/// Card view for a single entity in the grid.
/// Tap = select (= not wired yet). Double-click = open in editor (= boss
/// Ticket 3 hook).
///
/// Boss OOB v0.30: '卡片要用我们引入的缩略图的库, 加缩略图'. Thumbnail
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
/// BOSS 9/8 '点杜甫卡片, 新的标签页显示的名字不对' (= clicking
/// the 杜甫 card opened a new tab named 'preview-sample'):
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

    /// Lucide icon name (= the only visual differentiator between
    /// sources; everything else is uniform).
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

    /// v0.34 B-26 boss 9/3 '同目录只有第一次双击响应': Apple's
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
    /// double-click detector; = boss OOB '切换目录后, 会再次识别一次').
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
                LucideIcon(source.iconName, size: 64)
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
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.clear))
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
        // v0.34 B-26 boss 9/3 '同目录只有第一次双击响应': click-count
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
                // BOSS 9/8 '点杜甫卡片, 新的标签页显示的名字不对':
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

    /// v0.34 B-26: derive the display title for a card (= file basename
    /// without the .md extension; = boss 9/3 OOB '.md extension doesn't need to
    /// be shown either'). Placeholder card = 'preview-sample' (= no .md extension,
    /// = no path = render the short placeholder name).
    private func tabDisplayTitle(tab: EditorTab) -> String {
        if let path = tab.documentPath, !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            let basename = url.deletingPathExtension().lastPathComponent
            return basename.isEmpty ? "preview-sample" : basename
        }
        return "preview-sample"
    }
}