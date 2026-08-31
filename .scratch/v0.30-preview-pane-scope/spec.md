# v0.30 Preview Pane Scope = Sidebar-Driven + Persistence

## Boss 2026-08-31 OOB

老板原话 (= 我先记下, 等下实施):

1. **"点 sidebar row → 右边素材区显示该目录的文档"**
   - 点 book row → 素材区显示这本书的 8 个 folder 里所有 .md 文件
   - 点 folder row (= 世界观 / 角色 / 章节大纲 / 小说正文 / 小说草稿 etc.) → 只显示这个 folder 里的 .md 文件
   - 点资料库 root → 显示所有 entities (= 已存在的 mode 3)
   - 点资料库 category → 显示该分类的 entities (= 已存在的 mode 2)
   - 点 shelf row → 不显示文档 (= shelf 不是 doc scope, 显示空状态 + 提示)

2. **"控制目录范围"** = 选什么范围, 素材区就显示什么范围的 doc.

3. **"默认 app 进来是, 选定的是退出时的目录"** = 持久化 sidebar selection across launches.
   - 上次选了 folder "世界观" → 下次启动时默认就选 "世界观"
   - 上次选了 reference library "文学" → 下次启动时默认就选 "文学"
   - 上次点了 shelf "从这里开始" → 下次启动时默认就选 shelf
   - 上次完全没动过 sidebar → 默认还是什么都不选 (= 当前的 default)

## Design (走 Q34 8-step chain)

### Ticket 1: extend preview pane to show book/folder docs

- 把 `EntityPreviewPane` 重命名 → `PreviewPane` (= 因为它现在不只显示 entities)
- 新增 inputs:
  - `scope: PreviewScope` (= enum: .referenceScope(category), .bookScope(bookId, folderName?), .empty)
- 4 个 view mode:
  - **reference scope** (= .referenceScope(category) where category nil = overview, non-nil = category filter): use existing entity loading
  - **book scope** (= .bookScope(bookId, folderName?)): scan filesystem for .md files
    - folderName nil = scan all 8 standard folders + union
    - folderName non-nil = scan only that folder
  - **shelf scope** (= .shelfScope(shelfId)): empty state + message "选中书查看文档"
  - **empty** (nothing selected): empty state + message "请选择左侧目录查看文档"

### Ticket 2: thread sidebar selection through WorkspaceView

- WorkspaceView owns:
  - `selectedSidebarItem: SidebarItem?` (= new @State)
  - converts SidebarItem → PreviewScope → passes to PreviewPane
- NewLibraryOutlineView binds $selectedSidebarItem instead of local sidebarSelection

### Ticket 3: persist sidebar selection across launches

- `@AppStorage("wenshu.sidebarSelection")` storing JSON-encoded SidebarItem
- On app launch: read AppStorage → set selectedSidebarItem → sidebar tree auto-selects matching row
- On sidebar selection change: write back to AppStorage

### Ticket 4: clean up sidebar selection highlight (carry from 76289178e)

- All 6 row types use unified `.background(Color.accentColor.opacity(0.18))` (= done in 76289178e)
- Verify no gray fallback remains

## Acceptance criteria (= boss 真验证)

1. 点 shelf row → 素材区空状态 "选中书查看文档" (= no .md files shown)
2. 点 book row → 素材区显示该书 8 folder 的所有 .md files (= flat card flow, 现有 sort)
3. 点 folder row → 素材区只显示该 folder 的 .md files
4. 点资料库 root → 素材区显示所有 entities (existing mode)
5. 点资料库 category → 素材区显示该分类 entities (existing mode)
6. 退出 APP → 再打开 → 上次选中的 row 自动恢复 (= sidebar highlight + preview pane scope 都对)
7. 首次启动 (= 无持久化) → 默认什么都不选 (= empty state)
8. 所有 sidebar row selection highlight 都是蓝色 (= 76289178e 已搞定, 不需要再做)

## SidebarItem encoding for AppStorage

JSON shape (= round-trip via JSONEncoder/JSONDecoder):
```json
{ "case": "book", "id": "UUID-string" }
{ "case": "shelf", "id": "UUID-string" }
{ "case": "folder", "bookId": "UUID-string", "folderName": "world" }
{ "case": "referenceCategory", "dirName": "文学" }
{ "case": "referenceLibraryRoot" }
```

(Empty = `null` in AppStorage.)

## Out of scope (= 不动)

- 双击 .md 卡片 → 打开编辑器 (= 后续 ticket)
- 编辑器实际读 .md body (= 后续 ticket)
- 搜索 / 过滤 (.md 文件)
- 拖放重排 sidebar row
- 多选 sidebar rows