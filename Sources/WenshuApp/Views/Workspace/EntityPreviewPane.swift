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

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16, alignment: .topLeading)
    ]

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
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
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

    /// Mode 3: all-entities overview grid (= group by category inline).
    @ViewBuilder
    private func overviewGrid(allEntities: [Reference]) -> some View {
        if allEntities.isEmpty {
            emptyState(message: "资料库里还没有实体.\n导入研究材料后 LLM 会自动分类.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        LucideIcon("square-library", size: 24)
                            .foregroundStyle(.tint)
                        Text("资料库")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("(\(allEntities.count) 个实体 · \(Set(allEntities.compactMap { $0.category }).count) 个分类)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    ForEach(EntityCategory.allCases) { category in
                        let inCat = allEntities.filter { $0.category == category }
                        if !inCat.isEmpty {
                            categorySection(category: category, entities: inCat)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    /// Inline category section in overview grid.
    @ViewBuilder
    private func categorySection(category: EntityCategory, entities: [Reference]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                LucideIcon(category.icon, size: 18)
                    .foregroundStyle(.secondary)
                Text(category.displayName)
                    .font(.headline)
                Text("(\(entities.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(entities) { entity in
                    EntityCard(entity: entity) {
                        onEntityDoubleClick(entity)
                    }
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
}

/// Card view for a single entity in the grid.
/// Tap = select (= not wired yet). Double-click = open in editor (= boss
/// Ticket 3 hook).
///
/// Boss OOB '用随心记的卡片流样式' = 无边记 (= Apple Freeform) sticky-note
/// style. We use a simple rounded card with light background (= Apple
/// standard `.thickMaterial` for cards in iOS/macOS apps).
private struct EntityCard: View {
    let entity: Reference
    let onDoubleClick: () -> Void

    /// Track tap count for double-click detection.
    @State private var tapCount = 0
    @State private var lastTapTime: Date = .distantPast

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: type badge + category chip
            HStack(spacing: 6) {
                LucideIcon(entity.entityType.icon, size: 14)
                    .foregroundStyle(.tint)
                Text("[\(entity.entityType.displayName)]")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let cat = entity.category {
                    Text(cat.shortName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            // Title
            Text(entity.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            // Summary
            if !entity.summary.isEmpty {
                Text(entity.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            // Source (= if present)
            if let source = entity.source, !source.isEmpty {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
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