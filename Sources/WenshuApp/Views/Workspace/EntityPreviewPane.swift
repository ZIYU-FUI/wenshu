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

        Group {
            if let entity = selectedEntity {
                singleEntityDetail(entity)
            } else if let category = selectedCategory {
                categoryGrid(category: category, allEntities: allEntities)
            } else {
                overviewGrid(allEntities: allEntities)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // NO header above the card grid (= boss confirmed the title
            // is not needed). Just the flat LazyVGrid of cards.
            // Single flat LazyVGrid (= no per-category section headers,
            // no global count header). Cards flow continuously
            // (= 无边记 sticky-note style). Sort by:
            //   1. category (= alphabetical, = library taxonomy)
            //   2. title (= alphabetical within category)
            // for stable visual order (= doesn't shuffle on re-render).
            let sorted = allEntities.sorted { lhs, rhs in
                // Sort by category rawValue first, then by title
                let lCat = lhs.category?.rawValue ?? "ZZ"  // nil-categorized at end
                let rCat = rhs.category?.rawValue ?? "ZZ"
                if lCat != rCat { return lCat < rCat }
                return lhs.title < rhs.title
            }
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                        ForEach(sorted) { entity in
                            EntityCard(entity: entity) {
                                onEntityDoubleClick(entity)
                            }
                        }
                    }
                    .padding(20)
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