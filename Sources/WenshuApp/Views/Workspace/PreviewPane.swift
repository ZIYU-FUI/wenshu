// Sources/WenshuApp/Views/Workspace/PreviewPane.swift
//
// v0.30 boss 2026-08-30 OOB '实体分类在目录树里是最后一层, 点击后,
// 实体文档要用随心记的卡片流样式显示在素材管理区, 然后双击卡片才会在
// 编辑器里打开. 这就是我为什么说想实现编辑器和数据流, 得把这些前置
// 做完的原因'. Ticket 2 (= the entity card flow).
//
// v0.30 boss 2026-08-31 OOB '点 sidebar row → 右边素材区显示该目录的
// 文档, 控制目录范围': extended PreviewScope to cover both reference
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

// MARK: - Sort order (v0.30 boss OOB)
//
// Boss 2026-08-30: '所有卡片默认排序是拼音首字母先后顺序, 在素材预览顶栏
// 右边加 icon, 实现重排序功能. 目前选项, 首字母, 创建时间, 修改时间'.
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
    /// folder labels where they overlap (= 世界观 / 角色 / 章节大纲 /
    /// 小说正文 / 小说草稿) and uses a Chinese label for the 3
    /// sidebar-hidden folders (= 会话 / 伏笔 / 占位符).
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
enum PreviewScope: Hashable {
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

    /// Callback when user double-clicks an entity card (= boss Ticket
    /// 3). Reference-only callback (= book docs aren't wired to editor
    /// yet; deferred to v0.31 ticket).
    let onEntityDoubleClick: (Reference) -> Void

    /// v0.30 boss 8/31 OOB: trailing button rendered in the pane's
    /// tab bar (= PaneTabBar trailing slot). Used by the project
    /// preview scope to host the sort menu (= sorts the card grid
    /// by 首字母 / 创建时间 / 修改时间). Default = nil = no trailing
    /// button (= the scope just renders its tab bar + content).
    var trailingButton: AnyView? = nil

    /// v0.30 boss OOB: '所有卡片默认排序是拼音首字母先后顺序'.
    /// Default = .pinyinFirstLetter (= boss spec). Owned by
    /// WorkspaceView (= shared with PreviewSortMenuButton via
    /// the @State binding) so changing the sort via the tab
    /// bar trailing button re-renders this view's card grid.
    @Binding var previewSortOrder: EntitySortOrder

    /// Explicit init: required for @Binding in struct (= memberwise
    /// init doesn't support @Binding in non-result-builder structs).
    /// Pass-through of all other fields + wraps the binding.
    init(
        scope: PreviewScope,
        onEntityDoubleClick: @escaping (Reference) -> Void,
        previewSortOrder: Binding<EntitySortOrder>
    ) {
        self.scope = scope
        self.onEntityDoubleClick = onEntityDoubleClick
        self._previewSortOrder = previewSortOrder
    }

    /// v0.30 boss OOB: '卡片多列显示, 默认两列, 如果区域被拖拽宽度变窄,
    /// 不够两列, 自动适配成一列, 人话就是卡片流, 宽度自适应'.
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
    /// - If user drags the preview divider to shrink it (< 280 PT),
    ///   falls back to 1 column automatically
    private static let twoColumnBreakpoint: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            // v0.30 boss 8/31 OOB: scope-driven dispatch. Each scope
            // branch handles its own toolbar (some hide toolbar, e.g.
            // empty state).
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
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scope subviews

    /// Reference library scope: existing entity card flow (= boss 8/30
    /// OOB: '随心记的卡片流'). category nil = overview (= all
    /// entities, flat grid per boss 8/30 OOB); non-nil = category filter.
    @ViewBuilder
    private func referenceScopeView(category: EntityCategory?) -> some View {
        let allEntities = loadAllEntities()
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
        let docs = loadBookDocs(bookId: bookId, folderName: folderName)
        VStack(spacing: 0) {
            if docs.isEmpty {
                emptyState(
                    message: folderName != nil
                        ? "该目录下暂无文档"
                        : "该书暂无文档"
                )
            } else {
                bookDocsGrid(docs: docs)
            }
        }
    }

    /// Shelf scope: empty state with hint to drill into a book.
    @ViewBuilder
    private func shelfScopeView() -> some View {
        emptyState(message: "选中书查看文档")
    }

    /// Empty scope: empty state with hint to select a sidebar item.
    @ViewBuilder
    private func emptyScopeView() -> some View {
        emptyState(message: "请选择左侧目录查看文档")
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
                    Text("[\(entity.entityType.displayName)]")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let cat = entity.category {
                        Text(cat.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text(entity.title)
                    .font(.largeTitle)
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
                        .font(.body)
                        .textSelection(.enabled)
                } else {
                    Text("(空文档)")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(24)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                LucideIcon(category.icon, size: 24)
                    .foregroundStyle(.tint)
                Text(category.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("(\(inCategory.count))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if inCategory.isEmpty {
                emptyState(message: "该分类下暂无实体")
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                            ForEach(inCategory) { entity in
                                EntityCard(entity: entity) {
                                    onEntityDoubleClick(entity)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    /// Mode 3: all-entities overview grid (= group by category inline).
    @ViewBuilder
    private func overviewGrid(allEntities: [Reference]) -> some View {
        if allEntities.isEmpty {
            emptyState(message: "资料库里还没有实体.\n导入研究材料后 LLM 会自动分类.")
        } else {
            // v0.30 boss OOB '因为素材预览区只显示当前选定目录的卡片,
            // 所以只需要卡片流, 一直铺下去即可' + '素材预览区不需要这个标题,
            // 卡片平铺即可'.
            //
            // Single flat LazyVGrid (= no per-category section headers,
            // no global count header). Cards flow continuously
            // (= 无边记 sticky-note style). Sort by current `previewSortOrder`
            // (= boss 8/30 OOB: default 拼音首字母; user can pick
            // 创建时间 or 修改时间 via top-right sort menu icon).
            let sorted = sortEntities(allEntities, by: previewSortOrder)
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                        ForEach(sorted) { entity in
                            EntityCard(entity: entity) {
                                onEntityDoubleClick(entity)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    /// Empty-state placeholder (= boss UX 8/27 '...no markdown body
    /// = leave a clear empty state, not a blank white pane').
    @ViewBuilder
    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            LucideIcon("circle-help", size: 48)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        BookDocCard(doc: doc)
                    }
                }
                .padding(.vertical, 8)
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

    /// v0.30 boss OOB: 卡片多列显示, 默认两列, 宽度不够自动 1 列.
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
/// card a strong visual identity at a glance (= matches 无边记 / Notion
/// "card cover" pattern).
///
/// Future: when entities get real images (= e.g. character portrait,
/// location map), NukeUI's LazyImage will replace the type icon. The
/// image-pipeline integration is deferred to v0.31+ (= needs image
/// storage infrastructure that doesn't exist yet).
private struct EntityCard: View {
    let entity: Reference
    let onDoubleClick: () -> Void

    /// Track tap count for double-click detection.
    @State private var tapCount = 0
    @State private var lastTapTime: Date = .distantPast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // THUMBNAIL: type icon as a large prominent header
            // (= boss OOB: 卡片要加缩略图). 64 PT icon on a tinted
            // gradient background = the card's "cover" image.
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.18),
                        Color.accentColor.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LucideIcon(entity.entityType.icon, size: 64)
                    .foregroundStyle(Color.accentColor.opacity(0.85))
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            // TEXT content below the thumbnail
            VStack(alignment: .leading, spacing: 6) {
                // Type badge + modified-time chip (= condensed header).
                // v0.30 boss 8/31 OOB: previously showed category
                // shortName (= duplicated the title for category-less
                // entities like the help docs). Now shows the
                // formatted last-modified time (= at-a-glance
                // freshness indicator, no duplication with the title).
                HStack(spacing: 4) {
                    Text("[\(entity.entityType.displayName)]")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                    Text(formatRelativeTime(entity.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                // Title
                Text(entity.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                // Summary
                if !entity.summary.isEmpty {
                    Text(entity.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onTapGesture {
            // Single tap = no-op for now (= preview mode selection wired
            // by sidebar tap, not card tap). Double-tap → open in editor.
        }
        .help("\(entity.entityType.displayName) — 双击在编辑器中打开")
    }
}


// MARK: - Last-modified time formatter
//
// v0.30 boss 8/31 OOB: card top-right now shows the entity's
// last-modified time (= relative format = "刚刚 / 5 分钟前 / 昨天 /
// 3 天前 / 2 周前 / 2025-08-15"). The helper uses macOS RelativeDate
// TimeFormatter via Foundation (.relative formatting style), with
// a fallback to absolute date string for entities older than 30 days.
private func formatRelativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    formatter.dateTimeStyle = .named
    let now = Date()
    let delta = now.timeIntervalSince(date)
    if delta < 60 * 60 * 24 * 30 { // < 30 days
        return formatter.localizedString(for: date, relativeTo: now)
    } else {
        // > 30 days: show absolute date (= YYYY-MM-DD)
        let absFormatter = DateFormatter()
        absFormatter.dateFormat = "yyyy-MM-dd"
        absFormatter.locale = Locale(identifier: "zh_CN")
        return absFormatter.string(from: date)
    }
}
/// Card view for a single .md document in a book folder.
/// Boss 8/31 OOB '点 sidebar row → 右边素材区显示该目录的文档':
/// every BookDoc renders as a card in the preview pane. Folder
/// badge (= [世界观] etc.) identifies which folder the doc came
/// from (= boss UX: visible at-a-glance folder context).
///
/// Interaction: tap = no-op for now (= future ticket wires single-
/// tap → preview pane detail mode + editor). Double-tap → editor
/// (= deferred to v0.31; the editor binding for book .md files
/// isn't wired yet).
private struct BookDocCard: View {
    let doc: BookDoc

    /// Resolve the BookFolder enum from the raw folder name string.
    /// Falls back to nil for unknown folders (= e.g. if user creates
    /// a non-standard folder manually).
    private var folderEnum: BookFolder? {
        BookFolder(rawValue: doc.folderName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // THUMBNAIL: folder icon as a large prominent header
            // (= matches the EntityCard thumbnail style for visual
            // consistency between scopes).
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.18),
                        Color.accentColor.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LucideIcon(
                    folderEnum?.icon ?? "file-text",
                    size: 56
                )
                .foregroundStyle(Color.accentColor.opacity(0.85))
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            // TEXT content below the thumbnail
            VStack(alignment: .leading, spacing: 6) {
                // v0.30 boss 8/31 OOB '换成最后一次编辑的时间, 没有
                // 生效': the previous version of this HStack showed
                // doc.title (= duplicate of the card heading below).
                // Now shows formatRelativeTime(doc.modifiedAt) = the
                // last-modified time (= matches EntityCard pattern).
                HStack(spacing: 4) {
                    Text("[\(folderEnum?.displayName ?? doc.folderName)]")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                    Spacer()
                    Text(formatRelativeTime(doc.modifiedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                // Title (= filename without .md extension)
                Text(doc.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                // Summary (= first 200 chars of body)
                if !doc.body.isEmpty {
                    Text(doc.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .help("\(doc.displayPath) — 双击在编辑器中打开 (= 后续 ticket)")
    }
}
