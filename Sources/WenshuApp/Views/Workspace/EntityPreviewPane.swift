// Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift
//
// v0.30 boss 2026-08-30 OOB '实体分类在目录树里是最后一层, 点击后,
// 实体文档要用随心记的卡片流样式显示在素材管理区, 然后双击卡片才会在
// 编辑器里打开. 这就是我为什么说想实现编辑器和数据流, 得把这些前置
// 做完的原因'. Ticket 2 (= the entity card flow).
//
// = The material management zone (projectPreview) content for entities.
// Replaces PreviewTabBackground's stub (= Color.clear) with a real
// card-flow grid (= 无边记-style sticky-note layout).
//
// 3 view modes (boss OOB):
// 1. All entities (= when nothing selected) — show all 9 seeded entities
//    as cards in a grid (per category grouping)
// 2. Category selected — show only entities in that category as cards
// 3. Entity selected — show single entity detail card (= large card
//    with full summary + metadata)
//
// Double-click on a card (= will be wired to editor in Ticket 3 = boss:
// '双击卡片才会在编辑器里打开'). For now, single-click selects the entity.
//
// Grid uses LazyVGrid (= Apple standard for variable-height grid; matches
// Finder icon view style). Cards are reference cards (= already defined
// in ReferenceLibraryOutlineView.swift = ReferenceCard) but with the
// type badge added.

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
enum EntitySortOrder: String, CaseIterable, Identifiable {
    case pinyinFirstLetter = "首字母"
    case createdAt = "创建时间"
    case modifiedAt = "修改时间"

    var id: String { rawValue }

    /// Lucide icon for the menu picker (= chevron-up-down for "sort").
    var menuIcon: String {
        switch self {
        case .pinyinFirstLetter: return "arrow-down-a-z"
        case .createdAt: return "clock"
        case .modifiedAt: return "square-pen"
        }
    }
}

/// Content for the material management zone (= projectPreview).
/// Renders entity cards in 3 modes:
/// - selectedEntity != nil → single detail card
/// - selectedCategory != nil → category-scoped grid
/// - else → all-entities overview grid
struct EntityPreviewPane: View {
    @Environment(BookStore.self) private var bookStore

    /// Currently selected category (= set by sidebar tap). nil = all.
    let selectedCategory: EntityCategory?

    /// Currently selected entity (= set by card tap). nil = no detail.
    let selectedEntity: Reference?

    /// Callback when user double-clicks a card (= boss Ticket 3).
    let onEntityDoubleClick: (Reference) -> Void

    /// v0.30 boss OOB: '所有卡片默认排序是拼音首字母先后顺序'.
    /// Default = .pinyinFirstLetter (= boss spec).
    @State private var sortOrder: EntitySortOrder = .pinyinFirstLetter

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
        let allEntities = loadAllEntities()

        VStack(spacing: 0) {
            // Top toolbar (= sort menu on right).
            // Hidden in singleEntityDetail mode (= detail mode shows
            // its own back-button + entity metadata; sort doesn't apply).
            if selectedEntity == nil {
                previewTopBar()
            }
            Group {
                if let entity = selectedEntity {
                    singleEntityDetail(entity)
                } else if let category = selectedCategory {
                    categoryGrid(category: category, allEntities: allEntities)
                } else {
                    overviewGrid(allEntities: allEntities)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Top toolbar shown when cards are displayed (= NOT in detail mode).
    /// Boss 8/30 OOB: '在素材预览顶栏右边加 icon, 实现重排序功能'.
    ///
    /// Layout: empty leading + Spacer + sort menu on right.
    /// Sort menu icon shows current sort (= boss can always see which
    /// sort is active without expanding the menu).
    @ViewBuilder
    private func previewTopBar() -> some View {
        HStack {
            Spacer()
            sortMenuButton
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    /// Apple-standard `Menu` (dropdown picker) for sort order.
    /// Triggered by a button with the current sort icon + chevron-down
    /// (= macOS standard pattern, e.g. Finder "Group By" / "Sort By").
    private var sortMenuButton: some View {
        Menu {
            ForEach(EntitySortOrder.allCases) { order in
                Button {
                    sortOrder = order
                } label: {
                    Label {
                        Text(order.rawValue)
                    } icon: {
                        LucideIcon(order.menuIcon, size: 14)
                    }
                    if order == sortOrder {
                        // Mark current selection with a checkmark via
                        // the system "selected" affordance.
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                LucideIcon(sortOrder.menuIcon, size: 16)
                    .foregroundStyle(.tint)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)  // hide default chevron (we draw our own)
        .help("排序方式: \(sortOrder.rawValue)")
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
            // (= 无边记 sticky-note style). Sort by current `sortOrder`
            // (= boss 8/30 OOB: default 拼音首字母; user can pick
            // 创建时间 or 修改时间 via top-right sort menu icon).
            let sorted = sortEntities(allEntities, by: sortOrder)
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
                // Type badge + category chip (= condensed header)
                HStack(spacing: 4) {
                    Text("[\(entity.entityType.displayName)]")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                    if let cat = entity.category {
                        Text(cat.shortName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }
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