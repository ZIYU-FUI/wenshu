# Spec — v0.30 batch 3 polish (EntityPreviewPane + folder count + help-doc split + 18 PT padding)

> Date: 2026-08-30
> Author: wenshu agent (pocock profile)
> Boss OOB (cumulative, 2026-08-30 turn):
> - "实体分类在目录树里是最后一层，点击后，实体文档要用随心记的卡片流样式显示在素材管理区" (= preview pane card flow)
> - "为什么角色, 世界观, 后面没有显示数字" (= folder count badges)
> - "角色一个文件拆成六个吧，正常以后也是一个角色一个文档" + "功能模块也是，一个功能模块拆成一个文档"
> - "目录树后面的数字，距离右边距没有留空隙，留出来 18pt 的空隙"

## Business language (老板-facing)

- Click an entity category in sidebar (= e.g. 资料库 → 哲学、宗教) → preview
  pane shows that category's entities as card grid (= Notion-like / 无边记
  card flow style).
- Sidebar tree folders show entity count badge (= 角色 (6), 世界观 (1), etc.)
  — helps users see content density at a glance.
- Help documents in default book are split 1-to-many:
  - 角色 (1 file → 6 files, one per agent role)
  - 功能模块 (1 file → 9 files, one per zone)
- Sidebar tree count badges (= 5, 9, etc.) have 18 PT trailing padding
  (= breathing room between number and sidebar right edge).

## Why these changes (= scope)

| Commit | Boss OOB driving |
|---|---|
| `291487322` | "实体分类在目录树里是最后一层，点击后，实体文档要用随心记的卡片流样式" |
| `09c6521e2` | "为什么角色, 世界观, 后面没有显示数字" (= folder count badges) |
| `bf86a0b2b` | "角色一个文件拆成六个吧" + "功能模块也是" |
| `a8bebb858` | "目录树后面的数字，距离右边距没有留空隙，留出来 18pt 的空隙" |

## Root-cause chain (= 4 bugs)

### 1. Preview pane was a stub (= 291487322)

- Pre-fix: preview pane rendered `PreviewTabBackground` (= `Color.clear`
  stub). No card flow, no entity rendering.
- Boss OOB: click category → preview shows entity cards.

### 2. Sidebar folders had no count badge (= 09c6521e2)

- Pre-fix: sidebar showed folder names without `.md` file counts.
- Boss OOB: "为什么后面没有显示数字".
- Implementation: added `folderDocumentCount(bookId:folderDirectoryName:)`
  helper that scans `shelvesRoot/books/<book-id>/<folder>/*.md`.

### 3. Help docs were merged (= bf86a0b2b)

- Pre-fix: 1 character file (`六个Agent.md`) + 1 module file
  (`功能模块说明.md`).
- Boss OOB: split each into 1 file per item (= 6 + 9 = 15 files).
- Implementation: created `Scripts/split-help-docs.py` (= idempotent).

### 4. Count badge was right against sidebar edge (= a8bebb858)

- Pre-fix: count text = no padding from sidebar right edge.
- Boss OOB: "留出来 18pt 的空隙".
- Implementation: `.padding(.trailing, 18)` on each tree row.

## Fix plan (= 4 commits, all in repo)

### Commit 1 — `291487322` — EntityPreviewPane (card flow)

- **Scope**: 1 new file (`Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`,
  ~270 lines) + WorkspaceView refactor.
- **What**: real preview pane with 3 modes (single entity / category-scoped /
  overview).

### Commit 2 — `09c6521e2` — sidebar folder count badge

- **Scope**: 2 files (BookStore + NewLibraryOutlineView), 77 + / 8 -.
- **What**: `folderDocumentCount(bookId:folderDirectoryName:)` helper +
  count badge in `folderRow`.

### Commit 3 — `bf86a0b2b` — split help-doc files

- **Scope**: 1 new script (`Scripts/split-help-docs.py`, 636 lines).
- **What**: splits `characters/六个Agent.md` → 6 files; splits
  `chapters/功能模块说明.md` → 9 files. Idempotent.

### Commit 4 — `a8bebb858` — sidebar tree row trailing padding 18 PT

- **Scope**: 1 file (`NewLibraryOutlineView.swift`), 10 + / 0 -.
- **What**: `.padding(.trailing, 18)` on each FCPRowView.

## Acceptance criteria (= post-hoc, all verified)

- [x] Click category → preview shows cards (= EntityPreviewPane wired)
- [x] Folder count badges show `.md` count per folder
- [x] 6 agent files in `characters/` + 9 module files in `chapters/`
- [x] Count badge has 18 PT right padding
- [x] Build exit 0

## Q34 audit (= post-hoc)

This batch was implemented without the Q34 8-step chain (= no grill, no
spec/ticket pre-write, no code-review sub-agent). Spec + tickets committed
post-hoc (= this batch + the previous 3 batches).

Going forward: every new ticket walks full chain.
