# v0.30 AppState — Spec Axis Code Review (2026-08-31)

**Repo:** `/Volumes/ANAN/Engineering/wenshu`
**Branch:** `wt/multi-agent-dispatch`
**Commits reviewed:** `eb3066bca` → `17bdf49de` → `b768fa5a0` → `be3574dc1`
**Spec:** `.scratch/v0.30-app-state-cross-zone/spec.md`
**Build status:** `swift build` exit 0 (1.37s, no errors, two unrelated resource warnings).

---

## Scope note

The spec has a single `## Acceptance criteria` section listing **10 numbered items** (1, 2, 3, 4, 5, 6, 8, 9, 10 — number 7 is skipped, appears to be an intentional gap from a prior rebase). This report evaluates all 9 listed items, in order.

The task prompt mentioned "the 4 acceptance criteria sections" — the spec has only one such section. I read it as "the acceptance-criteria section" and report on every item it contains.

---

## Verdict at a glance

| # | Criterion | Verdict |
|---|---|---|
| 1 | App launches → first frame renders (no layout regression) | **PASS** |
| 2 | Click shelf → preview shows "选中书查看文档" | **FAIL** |
| 3 | Click book → preview shows that book's .md files | **PASS** |
| 4 | Click folder → preview shows only that folder's .md files | **PASS** |
| 5 | Click 资料库 category → preview shows that category's entity cards | **PASS** |
| 6 | Click 资料库 root → preview shows all entity cards (overview) | **PASS** |
| 8 | Close + reopen → sidebarSelection restored via @AppStorage + onChange | **PASS** |
| 9 | Drag splitter → weights change visually | **PASS** |
| 10 | Add new cross-zone signal → only 1 file edit (AppState.swift) | **PARTIAL PASS** |

Overall: **8 PASS, 1 FAIL, 1 PARTIAL.** Build is clean and the architectural shape is correct, but criterion #2 fails because `.shelf` selection maps to `.empty` (generic "请选择左侧目录查看文档") rather than `.shelfScope` ("选中书查看文档"), and #10 only holds when no consumer needs to read the new var (see gap note).

---

## Per-criterion analysis

### #1 — App launches, first frame renders (no layout regression)

**Verdict: PASS**

- `Sources/WenshuApp/App.swift` line 422: `@State private var appState = AppState()` — declared on `WenshuApp` (root App struct), so the value is ready before any window's first body evaluation.
- `Sources/WenshuApp/App.swift` line 438: `.environment(appState)` is attached to the root view (`SettingsEnvironmentCapturer(library:appearanceMode:)`) inside `WindowGroup`. Default value of `AppState.init()` (AppState.swift line 71) leaves all four cross-zone vars at their declared defaults (`sidebarSelection = nil`, `selectedEntity = nil`, `selectedEntityCategory = nil`, `previewSortOrder = .pinyinFirstLetter`). First render = no selection = `PreviewScope.empty` = `PreviewPane.emptyScopeView()` (PreviewPane.swift line 304-306), which is the documented empty state.
- `swift build` returns exit 0. No new compile errors, no new warnings beyond the two pre-existing resource warnings (`Wenshu.entitlements`, `ComponentIndex.md`).

No `@Binding` chain was removed that would break initial body evaluation — the only view that previously received a binding and now reads from `@Environment` is the `PreviewPane(scope:)` (driven from `WorkspaceView.previewScope`, line 56-80, which now reads `appState.sidebarSelection` directly).

---

### #2 — Click sidebar shelf row → preview pane shows "选中书查看文档"

**Verdict: FAIL**

**Spec requirement:** preview must show `选中书查看文档` (shelf-specific empty state).

**What the code does:**

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` lines 63-68: `previewScope` maps `.shelf` → `.empty` (with a comment that says selecting a shelf "doesn't reset the working set" and just highlights the shelf row).
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` lines 339-340: the duplicate `previewScope` inside `ZoneModuleView` does the same.
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift` line 304-306: `emptyScopeView()` returns `emptyState(message: "请选择左侧目录查看文档")` — the generic "select something" hint, NOT the shelf-specific hint.
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift` line 298-300: `shelfScopeView()` returns `emptyState(message: "选中书查看文档")` — this is the message the spec asks for, but it's never reached because `.shelf` maps to `.empty`, not `.shelfScope`.

**Spec gap:** Both `previewScope` implementations need to return `.shelfScope` for `.shelf` (matching the new `.shelf(UUID)` SidebarItem case in NewLibraryOutlineView.swift line 69 and line 578 where shelves are tagged). This is a one-line fix per site, but as written the user will see "请选择左侧目录查看文档" when clicking a shelf, violating criterion #2.

---

### #3 — Click book row → preview pane shows that book's .md files

**Verdict: PASS**

- Sidebar selection tap → `appState.sidebarSelection = .book(bookId)` via the custom `Binding(get:set:)` in `NewLibraryOutlineView` line 217-220.
- `WorkspaceView.previewScope` line 59-60: `.book(let bookId)` → `.bookScope(bookId: bookId, folderName: nil)` (all .md files in book).
- `PreviewPane.body` line 243-244: `case .bookScope(let bookId, let folderName):` → `bookScopeView(bookId:folderName:)`.
- `PreviewPane.bookScopeView` line 280-294: calls `loadBookDocs(bookId:folderName:)`, renders either `bookDocsGrid(docs:)` or `emptyState(message: "该书暂无文档")`.

The full chain is wired end-to-end. WorkspaceView's previewScope is the source used by the live `PreviewPane` (the actual rendering path goes through `TabContentDispatcher` in PaneRenderer.swift line 366-496, which constructs `ZoneModuleView(zoneSlot: .projectPreview)` at line 435 — and ZoneModuleView's duplicate previewScope at WorkspaceView.swift line 332-352 produces the same `.bookScope(bookId: bookId, folderName: nil)` for `.book`, so both potential rendering paths agree).

---

### #4 — Click folder row → preview pane shows only that folder's .md files

**Verdict: PASS**

- Sidebar tag: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` line 75 (`case folder(bookId: UUID, folderName: String)`) and the matching `.tag(SidebarItem.folder(...))` in `shelfRow(...)` (referenced by the `.folder` case in the `.onChange` at line 351).
- `appState.sidebarSelection = .folder(bookId, folderName)` flows to `WorkspaceView.previewScope` line 61-62 → `.bookScope(bookId: bookId, folderName: folderName)` (folder-filtered).
- `PreviewPane.bookScopeView(bookId:folderName:)` line 280-294 filters by folder. The empty-state message even differs per scope (`"该目录下暂无文档"` vs `"该书暂无文档"`, line 286-289).

Same-path agreement between WorkspaceView.previewScope and ZoneModuleView.previewScope for the `.folder` case.

---

### #5 — Click 资料库 category → preview pane shows that category's entity cards

**Verdict: PASS**

- Sidebar row tag: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` line 258: `.tag(SidebarItem.referenceCategory(category.directoryName))`.
- `appState.sidebarSelection = .referenceCategory("文学")` → `WorkspaceView.previewScope` line 73-77 → `.referenceScope(.some(EntityCategory))` (after looking up `EntityCategory.allCases.first(where: { $0.directoryName == dirName })`).
- `PreviewPane.referenceScopeView(category:)` line 262: when category is non-nil → `categoryGrid(category:allEntities:)` (filtered cards).

Also: the `.onChange(of: appState.sidebarSelection)` handler in NewLibraryOutlineView line 364-370 mirrors `.referenceCategory(<dir>)` into the still-existing `selectedEntityCategory` binding at line 368, so any consumer reading from that binding also stays in sync — but the primary scope path no longer depends on that binding (it reads `appState.sidebarSelection` via `previewScope`).

---

### #6 — Click 资料库 root → preview pane shows all entity cards (overview)

**Verdict: PASS**

- Root row tag: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` line 275: `.tag(SidebarItem.referenceLibraryRoot)` (= `SidebarItem.referenceCategory("__root__")`).
- `WorkspaceView.previewScope` line 70-72: `if dirName == "__root__"` → `.referenceScope(nil)`.
- `PreviewPane.referenceScopeView(category:)` line 267-273: when category is nil → overview grid showing all entities.

The `__root__` sentinel is defined as a static on `SidebarItem` at line 78 (`static let referenceLibraryRoot = SidebarItem.referenceCategory("__root__")`), and the decode path at line 132-134 round-trips it correctly via the `Codable` conformance.

---

### #8 — Close APP → reopen → sidebarSelection restored (persistence via @AppStorage + onChange)

**Verdict: PASS**

- Storage key: `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` line 51: `@AppStorage("wenshu.sidebarSelection") private var persistedSidebarSelection: String = ""`.
- Restore on launch: `WorkspaceView` lines 114-123: `.onAppear { ... if appState.sidebarSelection == nil, !persistedSidebarSelection.isEmpty, let data = ..., let item = try? JSONDecoder().decode(SidebarItem.self, from: data) { appState.sidebarSelection = item } }`. Guarded by the `appState.sidebarSelection == nil` check so it doesn't clobber a fresh selection.
- Save on change: `WorkspaceView` lines 126-134: `.onChange(of: appState.sidebarSelection) { _, newValue in ... persistedSidebarSelection = json ... }`. Encodes via `SidebarItem.Codable` (NewLibraryOutlineView.swift lines 80-136), which produces a tagged JSON shape (`{"kind":"book","book":"<UUID>"}` etc.).
- Round-trip verified by `SidebarItem.init(from decoder:)` lines 118-136 — all four cases (book, shelf, folder, referenceCategory) decode symmetrically with their `encode(to:)` implementations.

The persistence model exactly matches what the spec described in `### Persistence` (spec.md lines 92-97).

---

### #9 — Drag splitter → weights change visually (no regression of commit cace9337 ratio bug)

**Verdict: PASS**

The actual splitter drag handler is in `Sources/WenshuApp/Views/Workspace/PaneRenderer.swift` lines 128-180 (horizontal row orientation; identical logic for column orientation at lines 189-216). Key elements:

- Line 150 (and 198 for column): `let dW = Double(delta) / Double(unit)` — uses the dynamic `unit` derived from `availableWidth / totalWeight` (line 118-120, helper at line 79-83). This is the corrected formula that replaced the unit-broken `delta / total` from the earlier cace9337 commit (per the comment at line 138-146).
- `dragCache[split.id]` (line 156) holds the in-progress weights for live preview; cleared on drag-end (line 177).
- `onDragEnd` (line 158-179) computes `weightDelta = finalWeights[k] - split.weights[k]` and calls `store.adjustSplitWeights(splitID: childIndex: weightDelta:)` for each changed index (line 174). `WorkspaceStore.adjustSplitWeights` exists at `Sources/WenshuApp/State/WorkspaceStore.swift:249`, confirming the single UserDefaults write path.
- `rowChild` line 235-238 pins pane width to `CGFloat(weight) * unit` (no `maxWidth: .infinity` bleed); `columnChild` line 244-247 does the same for height.

Visually, dragging the splitter moves the adjacent pane width/height live (because `dragCache[split.id]` updates `liveWeights`, which recomputes the `unit` and per-child frame sizes on every render).

---

### #10 — Add a NEW cross-zone signal → only 1 file edit (AppState.swift) — proves extensibility

**Verdict: PARTIAL PASS**

The architectural claim holds: `Sources/WenshuApp/State/AppState.swift` is a single `@Observable` class where every new cross-zone signal is declared as a new `var` line. No `init()` signature to maintain (line 71 is empty), no factory to extend, no protocol conformance to update.

**Caveat:** the "only 1 file edit" claim is only true for the declaration site. Any view that needs to READ the new var must add `@Environment(AppState.self) private var appState` (or read it from a parent that already has it) — which is a 1-line edit per consumer, not zero. The spec wording is interpretable either way ("only 1 file edit (= AppState.swift)" — AppState.swift gets edited, plus zero-or-more consumers). I'd call this acceptable per the spec's stated purpose (proves extensibility), but the consumer edits are real and unavoidable.

**Architectural caveat:** the existing AppState vars `selectedEntity` and `selectedEntityCategory` are currently **declared but never read** anywhere in the codebase (search for `appState.selectedEntity` and `appState.selectedEntityCategory` returns zero matches). They are dead state in this commit. The spec's stated benefit of "1 line per signal" is undermined if those vars stay unused — but that's a hygiene concern, not a spec violation against #10 itself.

---

## Other observations (not blocking)

These are noted because they touch the spec's "Why I picked this scope" claim but don't break any acceptance criterion:

1. **`@Binding` chain not fully replaced.** The spec table (spec.md lines 82-88) says WorkspaceView should "Remove `@State sidebarSelection` / `@AppStorage` / `@State selectedEntity*` / `previewScope` computed with `@Environment(AppState.self) var appState`". The `sidebarSelection` part is done, but `selectedEntityCategory` and `selectedEntity` remain as `@State` in WorkspaceView (lines 35, 39) and as `@Binding` in ZoneModuleView (lines 320-321) and NewLibraryOutlineView (lines 146-147). The two AppState vars of the same names are dead. Net effect: the binding chain shrank from 4 layers to 3, not 1, for these two signals.

2. **`previewScope` duplication.** WorkspaceView.previewScope (lines 56-80) and ZoneModuleView.previewScope (lines 332-352) are byte-for-byte identical except for the host. The spec said "remove duplicated previewScope (= read from AppState)" in the ZoneModuleView row, but the duplication was kept because WorkspaceView doesn't pass its computed scope down. Not a behavior issue, but a code-quality miss against the spec's intent.

3. **Net LoC.** Spec claimed "Net negative LoC (= -10 lines after accounting for new AppState file's body)". Actual `git diff --stat` for the 4 commits: 160 insertions, 102 deletions across `Sources/**` = **+58 lines net**. The spec's "-50 / +40" estimate was optimistic.

4. **`previewSortOrder` is declared but unread.** `AppState.previewSortOrder` (AppState.swift line 69) has zero consumers (`grep appState.previewSortOrder` returns only the declaration). `PreviewPane` keeps its own `@State private var sortOrder` (PreviewPane.swift line 212). Spec criterion #8 specifies persistence for `sidebarSelection` only, so this is technically not a regression — but the AppState var is currently dead weight.

5. **`renderTabByKind` and `renderTab` are dead code** (WorkspaceView.swift lines 168-273). Both are documented as such ("no callers remain after the PaneRenderer refactor", line 266-267). The actual rendering goes through `TabContentDispatcher` in PaneRenderer.swift, which duplicates the dispatch. Pre-existing, not introduced by these commits.

---

## Files reviewed

- `.scratch/v0.30-app-state-cross-zone/spec.md`
- `Sources/WenshuApp/App.swift` (lines 1-500 read; injection site lines 422-438, 645-647)
- `Sources/WenshuApp/State/AppState.swift` (entire, 71 lines)
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (lines 1-500; binding removal, previewScope, onAppear/onChange)
- `Sources/WenshuApp/Views/Workspace/PaneRenderer.swift` (lines 1-500; @Environment reads, drag handlers, TabContentDispatcher)
- `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` (lines 1-500; SidebarItem Codable, Binding(get:set:), onChange handlers)
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift` (lines 190-419; scope dispatch, scope subviews, sort menu)
- `Sources/WenshuApp/State/WorkspaceStore.swift:249` (`adjustSplitWeights` existence)

No source files were modified. Build verified clean (`swift build` exit 0, 1.37s).
