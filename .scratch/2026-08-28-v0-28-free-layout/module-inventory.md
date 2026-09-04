# Wenshu v0.28 — Functional Module Inventory (boss-locked)

> Boss 2026-08-27 final: the modules are 6 capability boundaries. Boss
> locked Q1 = A (module 1 not split; one tree). Boss deferred Q2 / Q3 / Q4
> (= features in modules 3 / 4 / 6 ship in v0.29+). v0.28 = pure layout
> upgrade, no new modules, no new views, no domain/storage changes.

## The 6 modules (boss's own words)

### 1. 库管理模块 (Library Management)

> 用户的书架 / 资料库 / 书 / 围绕着书产生的一切数据

Boss Q1 = A: this is **one** module, not four. The internal panels
(World / Character / Reference / SmartQuery) all live inside this single
tree. User picks one to view at a time inside the navigation pane.

v0.28 surface (already shipped; just re-host under WorkspaceState):

- `Sources/WenshuApp/Domain/Book.swift` / `Bookshelf.swift`
- `Sources/WenshuApp/Domain/Document.swift` (= 3-class MD: chapter / setting / research)
- `Sources/WenshuApp/Domain/Reference.swift` + 4 LLM Wiki layers
- `Sources/WenshuApp/Domain/World.swift` + `Domain/Character.swift`
- `Sources/WenshuApp/Domain/SmartQuery.swift` + `Domain/SmartQueryParser.swift`
- Views: `NewLibraryOutlineView` + `WorldOutlineView` + `CharacterOutlineView` + `ReferenceLibraryOutlineView` + `SmartQueryView` + their editor sheets
- Modal: `LibraryPropertiesView`

### 2. 编辑器模块 (Editor)

> 类似 Obsidian 的 MD 文件编辑器 + AI 工具（画段 AI 扩写 / 缩写 / 重写）

Boss Q3 = do nothing new in v0.28. The current `TextEditor` inside
`ZoneModuleView .editor` IS the v0.28 editor. AI paragraph toolbar deferred to v0.29+.

v0.28 surface (already shipped):

- `Sources/WenshuApp/Domain/CrossRefInject.swift` (= `@角色.张三` parsing)
- `Sources/WenshuApp/Domain/Document.swift` (= `@<type>.<name>` parser)
- View: `ZoneModuleView .editor` (= plain TextEditor in `Views/Workspace/WorkspaceView.swift`)

### 3. 特色工具模块 (Signature Tools = wenshu moat)

> 伏笔 / 占位 / 情绪曲线 / 角色关系图 / 角色生命周期图 / 新建书 metadata / LLM 时自动调研 / 长文知识库 / 书内设定集约束 — 核心竞争力

Boss Q2 = do nothing in v0.28. All sub-tools deferred to v0.29+.

v0.28 surface: **none new**. Only existing data plumbing:

- `Domain/World.swift` / `Domain/Character.swift` (= per-book entities)
- 8 standard per-book folders (`foreshadowing/`, `placeholders/`, etc.) on disk
- **No editor sheets for foreshadowing or placeholder today** (= deferred)

### 4. Agent 模块 (Multi-Agent Writing)

> 多 agent 写作, 主聊天唯一, 上下文压缩, 上下文管理

Boss Q4 = do nothing in v0.28. Context compression deferred to v0.29+.

v0.28 surface (already shipped; just re-host under WorkspaceState):

- `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` (1 main + 5 sub-agents)
- `Sources/WenshuApp/Core/Agent/WenshuAgentIdentity.swift` + `SubAgentIdentity.swift`
- `Sources/WenshuApp/Core/Agent/MemoryManager.swift` + `MemoryWriteGate.swift`
- `Sources/WenshuApp/Core/Agent/AsyncDelegationRegistry.swift`
- View: `ZoneModuleView .aiChat` (= ChatView inside WorkspaceView)

### 5. 明盒系统 (Transparency Box)

> agent 干活时,除了在聊天里刷自己的进度. agent 看板协作, todo, 等 agent 工作进度

Boss Q1 = no decision needed (this is already shipped as 3 separate views
inside the `.aiDynamic` zone).

v0.28 surface (already shipped):

- `Views/Kanban/SubAgentProgressView.swift` (= progress surface)
- `Views/Kanban/KanbanView.swift` (= per-book kanban)
- `Views/Todo/TodoListView.swift`
- View: `ZoneModuleView .aiDynamic` (= container in WorkspaceView)

### 6. 长文模块 (Long-Form Coherence)

> 约束 / 延续 / 自证 / 人设 / 角色弧光 / 世界观稳定 — 核心竞争力

Boss Q3 = do nothing in v0.28. All 6 mechanism layers deferred to v0.29+.

v0.28 surface: **none new**. Only data plumbing today:

- `Domain/CrossRefInject.swift` (= ref injection = the only constraint layer partially shipped)
- `Domain/Document.characterRefIds` / `worldRefIds` / `referenceRefIds` (= cross-ref storage)

The prompt-level enforcement layers (人设 / 弧光 / 延续 / 自证) = **not implemented**.

---

## v0.28 scope (locked by boss)

**v0.28 = pure layout upgrade**. The 6 modules exist today in some form;
v0.28's job is to re-host them under the dynamic WorkspaceState layout.

Specifically, v0.28 ships:

1. **WorkspaceState + WorkspaceStore** (already drafted in v0.27 027-32+033; closes the v0.27 review rounds)
2. **`TabKind` enum stays at 6 cases** (= no expansion):
   - `.projectSidebar` (= Library outline)
   - `.projectPreview` (= Document cards; covers module 1 sub-panels via 1 selector)
   - `.editor` (= module 2)
   - `.specializedTools` (= today's placeholder; stays placeholder in v0.28)
   - `.aiChat` (= module 4)
   - `.aiDynamic` (= module 5)
3. **Default 6-zone layout** (= the v0.26 LayoutShellView equivalent) becomes the built-in `LayoutPreset.builtinDefault`
4. **Per-(user) layout persistence** (= UserDefaults `wenshu.workspace.json` + `wenshu.workspace.presets`)
5. **User can rearrange** (= drag tabs, split panes, save named layouts, reset to default)
6. **WiredShell flag** controls LayoutShellView (legacy) vs WorkspaceView (new)

## v0.28 NOT-scope (locked by boss)

- **Module 3 sub-tools**: no foreshadowing editor sheet, no placeholder UX, no emotion curve, no character graphs, no lifecycle chart, no LLM-time auto-research trigger, no long-form knowledge base UI
- **Module 6 mechanism layers**: no prompt-level enforcement for 约束 / 延续 / 自证 / 人设 / 弧光 / 世界观稳定
- **Module 4 context compression**: no summarization pipeline, no retention budget logic
- **TabKind enum expansion**: no new tab kinds (= modules 3 + 6 remain logic-only / data-only until v0.29+)
- **New views, new domain types, new storage files**: zero — v0.28 = pure layout plumbing

## Boss decisions pending (next iteration)

All four Q2 / Q3 / Q4 sub-decisions are deferred to v0.29+ planning. The
v0.28 batch is now scoped tight enough to plan in detail.

The v0.28 layout default is locked by boss 8/27:
- **WorkspaceView is the default shell** (= no user-facing legacy toggle by default)
- A Window-menu entry exists for the rare case the boss wants the v0.26
  6-zone fixed shell back (= an explicit opt-in to legacy, not the default)
- Initial state = `LayoutPreset.builtinDefault` (= **NOT a 1:1 mirror of v0.26 LayoutShellView** — boss 8/27 "用新框架推荐的模式，不强制追求和现有的一至")

## Candidate `LayoutPreset.builtinDefault` shapes (boss picks one)

Three proposals, each grounded in one of the three paradigms boss named
when picking Xcode for v0.27 D1. None is a 1:1 mirror of v0.26.

### Candidate I — Xcode paradigm (5 panes)

The Xcode / IntelliJ pattern: project navigator always left, editor center,
inspector right, debug bottom, with chat folded into inspector.

```
┌──────────────────────────────────────────────────────────────┐
│ ┌────────┐ ┌────────────────────────────┐ ┌───────────────┐ │
│ │ SHELF  │ │ EDITOR                     │ │ INSPECTOR     │ │
│ │(=库导航│ │ (Markdown editor           │ │ (Context:     │ │
│ │ + 资料 │ │  on focused document)      │ │  cross-refs / │ │
│ │ 库)    │ │                            │ │  book meta /  │ │
│ │        │ │                            │ │  outline)     │ │
│ │ Module │ │                            │ │               │ │
│ │ 1     │ │ Module 2                   │ │ Module 1 tail │ │
│ └────────┘ └────────────────────────────┘ └───────────────┘ │
│ ┌────────────────────────┐ ┌────────────────────────────────┐ │
│ │ CHAT                  │ │ DYNAMIC                         │ │
│ │ (= agent, Module 4)   │ │ (Kanban + Todo + Sub-agent      │ │
│ │                       │ │  progress, Module 5)            │ │
│ └────────────────────────┘ └────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

Module coverage: 1 ✓ (shelve + inspector right panel), 2 ✓ (editor center),
4 ✓ (chat bottom-left), 5 ✓ (dynamic bottom-right), 6 ✗ (no surface for
long-form coherence layers, deferred), 3 ✗ (no surface for signature tools).

Drag pattern: 4 horizontal splitters + 1 horizontal divider (= 5 total,
same number as v0.26 LayoutShellView).

### Candidate II — FCP Browser paradigm (4 panes)

The FCP Browser + Inspector pattern: outline left, viewer center, inspector
right, **chat = a tab in the inspector** (no separate bottom band).

```
┌──────────────────────────────────────────────────────────────┐
│ ┌────────┐ ┌────────────────────────────┐ ┌───────────────┐ │
│ │ SHELF  │ │ EDITOR                     │ │ INSPECTOR     │ │
│ │ (=库导航│ │ (Markdown editor)          │ │ (Tabs:        │ │
│ │ + 资料 │ │                            │ │  文档卡片 /   │ │
│ │ 库)    │ │                            │ │  Chat /       │ │
│ │        │ │                            │ │  Sub-agent)   │ │
│ │ Module │ │ Module 2                   │ │ Module 1 + 4  │ │
│ │ 1     │ │                            │ │  + 5          │ │
│ └────────┘ └────────────────────────────┘ └───────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

Module coverage: 1 ✓ + 4 ✓ + 5 ✓ + 2 ✓ in 3 panes. 3 ✗ + 6 ✗ deferred.
Drag pattern: 2 horizontal splitters (= simplest of the 3).

### Candidate III — Hermes / IDE hybrid (6 panes)

The Hermes multi-agent + chat pattern: chat gets its own bottom band
(= current v0.26) but reorganized into 6 zones with the inspector at the
right of the editor (instead of being a separate "工具区"").

```
┌──────────────────────────────────────────────────────────────┐
│ ┌────────┐ ┌────────────────────────┐ ┌────────────────────┐ │
│ │ SHELF  │ │ EDITOR                 │ │ INSPECTOR          │ │
│ │ (库导航)│ │ (Markdown editor)      │ │ (cross-refs +      │ │
│ │        │ │                        │ │  context info)     │ │
│ │ Mod 1  │ │ Module 2               │ │ Module 1 tail      │ │
│ │ left   │ │ center                 │ │ right              │ │
│ └────────┘ └────────────────────────┘ └────────────────────┘ │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ CHAT (agent, Module 4) + DYNAMIC (Module 5) side-by-side │ │
│ └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

Module coverage: 1 ✓ + 2 ✓ + 4 ✓ + 5 ✓. 3 ✗ + 6 ✗ deferred.
Drag pattern: 3 splitters upper + 1 splitter lower (= 4 total).

## Boss decision pending

- **028-002** answer = which candidate? I, II, or III?
  - I = Xcode paradigm (5 panes, 5 splitters, matches existing v0.26 split count)
  - II = FCP Browser paradigm (3 panes, 2 splitters, simplest)
  - III = Hermes / IDE hybrid (5 panes upper + 2 lower, 4 splitters, closest to v0.26)