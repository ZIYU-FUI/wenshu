// BookOutlineView.swift · Wenshu (Wenshu) · v0.03.0 (document module)
//
// v53 (= 老板 8/15 17:48 + 17:53 '在第二栏里, 显示书的所有章节, 设定,
// 资料库, 这里的文档需要分类, 我想要卡片, 卡片显示文档的中心思想'):
// the second column of the layout (= the EDITOR zone today) becomes
// a card grid of MD documents grouped by category (= FCP Browser
// filmstrip pattern).
//
// Three category sections (= Apple HIG `List + Section`):
//   章节 (chapter)   📖 book.closed
//   设定 (setting)   ⚙️ gearshape.2
//   资料库 (research) 📚 books.vertical.fill
//
// Each card displays:
//   - SF Symbol icon (= wenshu has no thumbnails; the symbol carries
//     the visual weight, FCP Browser does the same when no poster frame
//     exists)
//   - title (TextField-extracted from H1, or filename)
//   - summary (auto-extracted first ~100 chars; frontmatter stripped,
//     newlines collapsed to spaces, word-boundary ellipsized)
//   - byte size + relative time (= "1.2 KB · 3 min ago")
//
// Click the card → selectedDocumentId (= the EDITOR will read the
// full body in v0.04+; v53.3 just sets the selection).
//
// Apple HIG components used (= no custom UI):
//   ScrollView + LazyVGrid     responsive cards grid
//   Section header             with category icon + display name + count
//   Label                      icon + 2-line title/summary
//   RoundedRectangle           card background
//   .contextMenu                right-click delete (= v0.04+ adds rename)
//
// Empty state (= no book selected): renders a centered hint. Empty
// category section (= book has no documents of that type yet): renders
// a subtle inline hint.

import SwiftUI

struct BookOutlineView: View {
    @Bindable var library: WenshuLibrary

    var body: some View {
        Group {
            if let bookId = library.selectedBookId {
                content(bookId: bookId)
            } else {
                noBookSelected
            }
        }
        .frame(minWidth: 280)
    }

    @ViewBuilder
    private func content(bookId: UUID) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(BookCategory.allCases, id: \.self) { category in
                    categorySection(bookId: bookId, category: category)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func categorySection(bookId: UUID, category: BookCategory) -> some View {
        let docs: [Document] = (try? library.documents(in: bookId, category: category)) ?? []
        VStack(alignment: .leading, spacing: 12) {
            // Section header (= category icon + display name + count)
            HStack(spacing: 8) {
                WenshuIcon.image(name: category.icon, size: 18, foregroundStyle: .secondary)
                Text(category.displayName)
                    .font(.headline)
                Text("\(docs.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if docs.isEmpty {
                emptyCategory(category: category)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(docs) { doc in
                        DocumentCard(
                            document: doc,
                            isSelected: library.selectedDocumentId == doc.id
                        )
                        .onTapGesture {
                            library.setSelectedDocument(id: doc.id)
                        }
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                try? library.deleteDocument(
                                    id: doc.id,
                                    bookId: bookId,
                                    category: category
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyCategory(category: BookCategory) -> some View {
        Text("这个分类还没有内容")
            .font(.callout)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var noBookSelected: some View {
        VStack(spacing: 8) {
            WenshuIcon.book.image(size: 38, foregroundStyle: .tertiary)
            Text("先在左边选一本书")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Document card

private struct DocumentCard: View {
    let document: Document
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                WenshuIcon.image(name: document.category.icon, size: 16, foregroundStyle: .secondary)
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(document.summary.isEmpty ? "（无内容预览）" : document.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Text(formatBytes(document.byteSize))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(formatRelative(document.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }

    private func formatRelative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "zh_CN")
        return f.localizedString(for: date, relativeTo: .now)
    }
}