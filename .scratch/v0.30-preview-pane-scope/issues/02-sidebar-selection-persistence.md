# Ticket 2: Sidebar Selection Persistence

## Goal

Sidebar selection 在 APP 退出 → 重启后自动恢复 (= 选中的 row 还是高亮的, preview pane 还是显示该 scope 的内容).

## Implementation

### 1. SidebarItem Codable

`SidebarItem` 当前只有 `Hashable`. 加 `Codable` (= 用 JSON dict 编码).

JSON shape:
```json
{ "case": "book", "book": "UUID" }
{ "case": "shelf", "shelf": "UUID" }
{ "case": "folder", "book": "UUID", "folder": "world" }
{ "case": "referenceCategory", "dirName": "文学" }
{ "case": "referenceLibraryRoot" }
```

Switch on `case` string + decode associated values from the dict.

### 2. Persistence via @AppStorage

`@AppStorage("wenshu.sidebarSelection") private var persistedSidebarSelection: String = ""`

Store JSON string (= "" = nothing). On change, encode + write back.

### 3. WorkspaceView state

```swift
@State private var selectedSidebarItem: SidebarItem?

// On launch:
.onAppear {
    if selectedSidebarItem == nil, !persistedSidebarSelection.isEmpty {
        if let data = persistedSidebarSelection.data(using: .utf8),
           let item = try? JSONDecoder().decode(SidebarItem.self, from: data) {
            selectedSidebarItem = item
        }
    }
}

// On selection change:
.onChange(of: selectedSidebarItem) { _, newValue in
    if let item = newValue,
       let data = try? JSONEncoder().encode(item),
       let json = String(data: data, encoding: .utf8) {
        persistedSidebarSelection = json
    } else {
        persistedSidebarSelection = ""
    }
}
```

### 4. NewLibraryOutlineView binding

Currently `sidebarSelection` is `@State private`. Change to `@Binding var sidebarSelection: SidebarItem?`. WorkspaceView passes binding to NewLibraryOutlineView.

### 5. Scope computation in WorkspaceView

```swift
var previewScope: PreviewScope {
    guard let item = selectedSidebarItem else { return .empty }
    switch item {
    case .book(let id): return .bookScope(bookId: id, folderName: nil)
    case .folder(let bookId, let folderName): return .bookScope(bookId: bookId, folderName: folderName)
    case .shelf(let id): return .shelfScope(shelfId: id)
    case .referenceCategory(let dirName):
        if dirName == "__root__" { return .referenceScope(nil) }
        else if let cat = EntityCategory.allCases.first(where: { $0.directoryName == dirName }) {
            return .referenceScope(cat)
        }
        return .empty
    }
}
```

## Files

- `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`
  - SidebarItem: add Codable
  - Change `@State sidebarSelection` → `@Binding sidebarSelection`
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`
  - Add `@State selectedSidebarItem` + `@AppStorage persistedSidebarSelection`
  - Add `previewScope` computed
  - Pass `selectedSidebarItem: $selectedSidebarItem` to NewLibraryOutlineView
  - Replace EntityPreviewPane wiring with PreviewPane(scope:)

## Acceptance criteria

1. 点 shelf "从这里开始" → 关闭 APP → 重开 → sidebar 默认选 "从这里开始"
2. 点 book "帮助" → 关闭 → 重开 → 默认选 "帮助"
3. 点 folder "世界观" → 关闭 → 重开 → 默认选 "世界观" + preview pane 显示 "世界观" .md
4. 点资料库 category "文学" → 关闭 → 重开 → 默认选 "文学"
5. 首次启动 (无持久化) → 默认什么都不选
6. UserDefaults read after launch: contains `wenshu.sidebarSelection` JSON

## Verification

- Open terminal: `defaults read com.wenshu.app wenshu.sidebarSelection`
- After closing + reopening APP: verify same JSON in UserDefaults
- Visually verify sidebar tree highlights the matching row

## Out of scope

- Persist sidebar EXPANDED state (= which DisclosureGroup is open) — only selection matters per boss
- Multiple selection
- Migration: any existing installed user has empty AppStorage = behaves like first launch (= OK)