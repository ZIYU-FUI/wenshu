# 02 — sidebar folder count badge (= show .md count per folder)

**What to build:**

Boss 2026-08-30 OOB '为什么角色, 世界观, 后面没有显示数字' = sidebar
folder rows should show the count of `.md` files inside each folder.

Pre-fix: folder rows showed only name, no count.

Fix: added `folderDocumentCount(bookId:folderDirectoryName:)` helper +
count badge in `folderRow`.

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `09c6521e2`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### Modified: `Sources/WenshuApp/State/BookStore.swift`

New helper:
```swift
func folderDocumentCount(bookId: UUID, folderDirectoryName: String) -> Int {
    let folderPath = stores.shelvesRoot
        .appendingPathComponent("books", isDirectory: true)
        .appendingPathComponent(bookId.uuidString, isDirectory: true)
        .appendingPathComponent(folderDirectoryName, isDirectory: true)
    guard FileManager.default.fileExists(atPath: folderPath.path) else { return 0 }
    let entries = (try? FileManager.default.contentsOfDirectory(
        at: folderPath,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )) ?? []
    return entries.filter { $0.pathExtension == "md" }.count
}
```

### Modified: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`

- `standardFolderNodes(for book:)` populates `count: folderDocumentCount(...)`
- Pre-v0.30 file used a separate `FCPTreeNode` per (book, folder) tuple; v0.30
  Apple List uses Label rows directly.

## Acceptance

- [x] Sidebar shows count badge per folder (= 角色 (6), 世界观 (1), etc.)
- [x] Missing folder → 0 (forgiving)
- [x] Build exit 0
- [x] Screenshot verified

## Out-of-scope

- Total book count (= shown separately in status bar)
- Recursive count (= current = top-level only; nested subfolders not counted)
