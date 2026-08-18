# ADR-0004: 书架 = WenshuLibrary / Bookshelf / Book 三层

> Status: accepted
> Date: 2026-08-15
> Decision-maker(s): 老板 (8/15 17:05, 8/18 答 Q2)

## Context

老板 8/15 17:05 拍 "结构不对, 参考 fcp. 书架是父级, 可以点击折叠展开". v0.07 之前 LibraryScaffold 用 HStack of BookshelfListView | splitter | BookListView = 固定两栏, 错. Apple HIG document-based app (Notes / Pages / Finder) 用单一 outline + DisclosureGroup (点击 header 折叠 / 展开, 点击 row 选中).

## Decision

Domain model = `WenshuLibrary: Observable` + `Bookshelf: Identifiable` + `Book: Identifiable` 三层. Bookshelf 是父级, Book 挂在 Bookshelf 下. LibraryScaffold 走 `LibraryOutlineView` (单一 outline + DisclosureGroup) 不再 split.

`Book.length` + `Book.idea` 字段 (8/18 答 Q2) = New Book Creation Wizard 3 fields (name + length + idea).

存储走 `LibraryStoring` 协议 + `FileSystemLibraryStore` 真值 (Apple HIG document-based-app convention = `~/Documents/wenshu/<id>/`). 未来换 CoreData / CloudKit 只换 store 实现, WenshuLibrary 不动.

## Consequences

- 任何 "BookshelfListView | splitter | BookListView" 写法 = 反模式 = 改回 outline
- 存储选型可换, 协议契约不变

## Alternatives considered

- 旧 HStack 两栏 (BookshelfListView + BookListView) — 拒绝, 不符合 Apple HIG
- CoreData 直接绑 UI — 拒绝, 老板 8/15 15:55 "架构需要先定好, 不能没事加个东西"
- iCloud / CloudKit — 推迟, 等 v0.10+ 再说
