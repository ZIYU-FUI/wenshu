# Ticket 1: Preview Pane Scope = Sidebar-Driven

## Goal

让 `PreviewPane` (= 改名 from `EntityPreviewPane`) 根据 sidebar selection 显示对应范围的文档:
- book row → 该书所有 folder 的 .md
- folder row → 仅该 folder 的 .md
- 资料库 root → 所有 entities
- 资料库 category → 该分类 entities
- shelf row / nothing selected → empty state

## Files

- `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift` → rename file to `PreviewPane.swift`
- Add `enum PreviewScope` (= 4 cases)
- Add `func loadBookDocs(bookId:folderName:)` reading filesystem .md files

## Implementation

### 1. PreviewScope enum

```swift
enum PreviewScope: Hashable {
    case referenceScope(EntityCategory?)  // nil = reference library root (all)
    case bookScope(bookId: UUID, folderName: String?)  // folderName nil = all folders
    case shelfScope(shelfId: UUID)  // = empty state
    case empty  // = nothing selected
}
```

### 2. PreviewPane struct

```swift
struct PreviewPane: View {
    @Environment(BookStore.self) private var bookStore
    let scope: PreviewScope
    @State private var sortOrder: EntitySortOrder = .pinyinFirstLetter
    // ... existing body code, refactored to switch on scope
}
```

### 3. Book docs loader

```swift
private func loadBookDocs(bookId: UUID, folderName: String?) -> [BookDoc] {
    let bookDir = bookStore.stores.shelvesRoot
        .appendingPathComponent(bookStore.shelfIdForBook(bookId).uuidString)
        .appendingPathComponent(bookId.uuidString)
    let folders: [String]
    if let folderName { folders = [folderName] }
    else { folders = BookFolder.allCases.map(\.directoryName) }
    var docs: [BookDoc] = []
    for folder in folders {
        let dir = bookDir.appendingPathComponent(folder)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
        for url in entries where url.pathExtension == "md" {
            let body = (try? String(contentsOf: url)) ?? ""
            docs.append(BookDoc(folderName: folder, fileName: url.lastPathComponent, body: body))
        }
    }
    return docs
}
```

### 4. BookDoc model

```swift
struct BookDoc: Identifiable, Hashable {
    let id: UUID = UUID()
    let folderName: String  // = "world", "characters", etc.
    let fileName: String    // = "文枢是什么.md"
    let body: String        // = full .md content
    var title: String { (fileName as NSString).deletingPathExtension }
}
```

### 5. View modes refactor

```swift
var body: some View {
    Group {
        switch scope {
        case .referenceScope(let cat):
            entityScopeView(category: cat)
        case .bookScope(let bookId, let folderName):
            bookScopeView(bookId: bookId, folderName: folderName)
        case .shelfScope:
            emptyState(message: "选中书查看文档")
        case .empty:
            emptyState(message: "请选择左侧目录查看文档")
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

### 6. Book card (= 跟 entity card 类似)

```swift
private struct BookDocCard: View {
    let doc: BookDoc
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: folder badge + file icon
            HStack {
                Text("[\(doc.folderName)]")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                LucideIcon("file-text", size: 14)
                    .foregroundStyle(.tertiary)
            }
            Text(doc.title)
                .font(.headline)
                .lineLimit(2)
            if !doc.body.isEmpty {
                Text(String(doc.body.prefix(150)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
```

## Acceptance criteria

1. 点 book row → 素材区显示该书 8 folder 的所有 .md (= flat card flow, 不分组)
2. 点 folder row → 素材区只显示该 folder 的 .md
3. 点 shelf row → empty state
4. 点资料库 root → entities (existing mode, unchanged)
5. 点资料库 category → entities (existing mode, unchanged)
6. 排序在 book scope / reference scope 都生效

## Verification

- Run APP + create / select shelf/book/folder → verify preview pane shows expected docs
- Sort menu should work on both scopes

## Out of scope

- 双击 .md 卡片 → editor (Ticket 4)
- 实体卡片 / book 卡片联动 (= cross-scope search)
- 全局搜索