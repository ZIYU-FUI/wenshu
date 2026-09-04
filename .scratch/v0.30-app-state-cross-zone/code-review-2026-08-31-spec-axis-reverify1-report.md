# v0.30 AppState — Spec Axis RE-VERIFY1 (2026-08-31)

**Repo:** `/Volumes/ANAN/Engineering/wenshu`
**Branch:** `wt/multi-agent-dispatch`
**Commits re-checked:** `eb3066bca` + `17bdf49de` + `b768fa5a0` + `be3574dc1` + **``e93139e0d`** (followup)
**Prior review:** `.scratch/v0.30-app-state-cross-zone/code-review-2026-08-31-spec-axis-report.md` (8 PASS / 1 FAIL / 1 PARTIAL)
**Spec:** `.scratch/v0.30-app-state-cross-zone/spec.md`
**Build status:** `swift build` exit 0 (16.77s, only the two pre-existing resource warnings — no new warnings).

---

## Verdict at a glance

| # | Criterion | Prior verdict | **Re-verify verdict** | Δ |
|---|---|---|---|---|
| 1 | App launches → first frame renders (no layout regression) | PASS | **PASS** | UNCHANGED |
| 2 | Click shelf → preview shows "选中书查看文档" | **FAIL** | **PASS** | **FIXED** |
| 3 | Click book → preview shows that book's .md files | PASS | **PASS** | UNCHANGED |
| 4 | Click folder → preview shows only that folder's .md files | PASS | **PASS** | UNCHANGED |
| 5 | Click 资料库 category → preview shows that category's entity cards | PASS | **PASS** | UNCHANGED |
| 6 | Click 资料库 root → preview shows all entity cards (overview) | PASS | **PASS** | UNCHANGED |
| 8 | Close + reopen → sidebarSelection restored via @AppStorage + onChange | PASS | **PASS** | UNCHANGED |
| 9 | Drag splitter → weights change visually | PASS | **PASS** | UNCHANGED |
| 10 | Add new cross-zone signal → only 1 file edit (AppState.swift) | PARTIAL PASS | **PARTIAL PASS** | UNCHANGED (expected — v0.31 backlog) |

**Overall: 9 PASS / 0 FAIL / 1 PARTIAL** (prior: 8 PASS / 1 FAIL / 1 PARTIAL). The followup commit `e93139e0d` flipped #2 from FAIL to PASS without regressing any other criterion. Build is clean. **Spec-axis gate is now open.**

---

## Re-verification detail

### #2 — Click sidebar shelf row → preview pane shows "选中书查看文档"

**Verdict: PASS** (was FAIL)

**What changed in `e93139e0d`:**

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:63-70` — `previewScope` case `.shelf` now binds `shelfId` and returns `.shelfScope(shelfId: shelfId)`. The old code mapped `.shelf` → `.empty` (= generic "请选择左侧目录查看文档"). The new comment explicitly cites spec criterion #2 and names the FAIL finding it fixes.
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:341-342` — `ZoneModuleView.previewScope` (the duplicate inside the same file) was updated in lock-step: `case .shelf(let shelfId): return .shelfScope(shelfId: shelfId)`. Both `previewScope` implementations are now byte-for-byte identical for the shelf case, so there is no path-divergence between WorkspaceView and ZoneModuleView.

**Sink verified:**

- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:141-148` — `case shelfScope(shelfId: UUID)` exists.
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:240-249` — body switch dispatches `case .shelfScope:` → `shelfScopeView()` (associated value omitted — compiler accepts without warning).
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:296-300` — `shelfScopeView()` returns `emptyState(message: "选中书查看文档")`, the exact string the spec criterion requires.

**End-to-end chain verified by `rg`:** `appState.sidebarSelection = .shelf(id)` at `NewLibraryOutlineView.swift:1076` → `.shelf(let shelfId)` pattern match in `WorkspaceView.previewScope:63` → `.shelfScope(shelfId: shelfId)` → `PreviewPane.body:245` → `PreviewPane.shelfScopeView():298` → `emptyState(message: "选中书查看文档")`. Path is complete and correct.

**Minor style nit (not blocking):** `PreviewPane.body:245` uses `case .shelfScope:` (no associated-value binding) when the enum carries `shelfId: UUID`. Swift accepts this, but binding it (e.g. `case .shelfScope(let shelfId):` with `_ = shelfId`) would make the associated value forwardable to a future `shelfScopeView(shelfId:)` overload if a per-shelf view ever needs to render shelf metadata. Out of scope for v0.30; flagging for future awareness only.

---

### #10 — Add a NEW cross-zone signal → only 1 file edit (AppState.swift)

**Verdict: PARTIAL PASS** (unchanged from prior review — expected)

The followup commit does not change this verdict. AppState.swift still satisfies the "1 file edit to add a var" claim, but consumers that need to *read* the new var still need a 1-line `@Environment(AppState.self) private var appState` injection (or read it via a parent that already has it). The architectural claim holds; the consumer edits are unavoidable.

**In fact this criterion is now *easier* to satisfy post-followup** — removing the 3 dead vars means the AppState.swift edit surface is genuinely 1 line per signal. The 3 dead vars made it look bigger than necessary (the prior review flagged them as architectural drift in "Other observations #1"). The followup's H-1 fix tightened this.

Expected to remain PARTIAL in v0.30; the consumer-edit clarification belongs in v0.31 backlog (= the spec says "proves extensibility", which is met as long as the *declaration* cost is 1 line, and that's now strictly true).

---

### Re-check of the 8 previously-PASS criteria

No regressions. Spot-checks of each:

- **#1** — `WenshuApp` (`App.swift:422`) still owns `@State private var appState = AppState()` and `.environment(appState)` (`App.swift:438`) on the root view inside `WindowGroup`. AppState init (`AppState.swift:61`) leaves the only surviving var (`sidebarSelection`) at its default `nil`. First render = `.empty` = `PreviewPane.emptyScopeView()` = documented empty state. Build exit 0.
- **#3** — `.book(let bookId)` → `.bookScope(bookId: bookId, folderName: nil)` (`WorkspaceView.swift:59-60` and `:337-338`) → `PreviewPane.bookScopeView` (`:280-294`). Untouched by the followup. PASS.
- **#4** — `.folder(let bookId, let folderName)` → `.bookScope(bookId:bookId:folderName:)` (`:61-62` and `:339-340`) → folder-filtered `loadBookDocs` (`:280-294`). Untouched by the followup. PASS.
- **#5** — `.referenceCategory(let dirName)` → `.referenceScope(.some(EntityCategory))` after `EntityCategory.allCases.first(where: { $0.directoryName == dirName })` lookup (`:71-80` and `:343-352`). The followup's removal of `selectedEntityCategory` from AppState does not affect this path — `previewScope` never read `selectedEntityCategory`, only `sidebarSelection`. Untouched. PASS.
- **#6** — `.referenceCategory("__root__")` → `.referenceScope(nil)` → overview grid (`PreviewPane.swift:267-273`). The `__root__` sentinel still defined at `NewLibraryOutlineView.swift:78`. Untouched. PASS.
- **#8** — Persistence unchanged. `@AppStorage("wenshu.sidebarSelection")` (`WorkspaceView.swift:51`), `.onAppear` restore (`:116-125`), `.onChange` save (`:128-136`), and `SidebarItem.Codable` round-trip (`NewLibraryOutlineView.swift:80-136`). The followup did not touch any of these. PASS.
- **#9** — Splitter drag handler untouched. `PaneRenderer.swift:128-180` (horizontal) and `:189-216` (column) still use `unit`-based weight math (`let dW = Double(delta) / Double(unit)` at `:150`/`:198`). `WorkspaceStore.adjustSplitWeights` exists at `Sources/WenshuApp/State/WorkspaceStore.swift:249` (single UserDefaults write path). PASS.

---

## (d) H-1 followup: 3 unused AppState vars removed cleanly?

**Verdict: PARTIAL** (3 vars + 1 stale doc-block removed, 1 stale doc-block and 1 stale doc reference left behind — see "new spec gaps" below)

What the followup actually deleted:

| Var | Pre-followup | Post-followup | Verified clean? |
|---|---|---|---|
| `var selectedEntity: Reference? = nil` | declared, never read | **removed** | ✅ `rg '\.selectedEntity\b' Sources/WenshuApp/State/AppState.swift` returns 0 hits |
| `var selectedEntityCategory: EntityCategory? = nil` | declared, never read | **removed** | ✅ `rg 'selectedEntityCategory' Sources/WenshuApp/State/AppState.swift` returns 0 hits |
| `var previewSortOrder: EntitySortOrder = .pinyinFirstLetter` | declared, never read | **removed** | ✅ `rg 'previewSortOrder' Sources/WenshuApp/State/AppState.swift` returns 0 hits |

**Global consumer check** (`rg -n 'selectedEntity|selectedEntityCategory|previewSortOrder' Sources/`):
- All matches are inside `WorkspaceView.swift` (local `@State` shadows), `ZoneModuleView` (`@Binding`), `NewLibraryOutlineView.swift` (`@Binding`), `App.swift` (doc-block reference at line 419-420).
- **Zero** matches in `AppState.swift` for any of the 3 deleted names — confirming the declarations are gone everywhere.

`AppState` is now 1 var (`sidebarSelection`) + 1 empty `init()`. This is the cleanest possible AppState for v0.30: every var maps to an active cross-zone signal. The followup correctly applied YAGNI (= the sub-agent recommendation option B from the prior review) and the 3 vars can be re-added in a v0.31 ticket when consumers appear.

The H-1 fix is **substantively complete**. The minor hygiene misses are listed under "New spec gaps" below — they don't break compilation but they're inconsistencies that a careful reviewer (or a future grep) will surface.

---

## New spec gaps introduced by the followup

These are **non-blocking hygiene inconsistencies** the followup left behind. They don't affect any acceptance criterion verdict, but they will catch a future reviewer's eye:

### Gap A — Orphan doc-block in `AppState.swift`

**File:** `Sources/WenshuApp/State/AppState.swift:54-58`

The followup deleted the `var selectedEntity: Reference? = nil` line, but the 5-line doc-block immediately above it survived. Result: between `sidebarSelection` (line 52) and `init() {}` (line 61), there are now 5 lines of `///` doc comments describing a variable that doesn't exist. The diff shows this clearly:

```diff
-    var selectedEntity: Reference? = nil
-
-    /// Reference library category (= which category the sidebar
-    /// pointed at, = 资料库 → 文学 / 哲学 etc.). Drives the
-    /// `referenceScope(.some)` branch of PreviewPane.
-    var selectedEntityCategory: EntityCategory? = nil
-
-    /// Preview pane sort order (= applies to both entity-scope and
-    /// book-scope card flows). Default = pinyin first letter
-    /// (= boss 8/30 OOB '所有卡片默认排序是拼音首字母先后顺序').
-    var previewSortOrder: EntitySortOrder = .pinyinFirstLetter
```

The patch removed the 3 `var` lines but left the doc-block for `selectedEntity` intact (lines 54-58 of the new file: `/// Reference library entity detail selection (= the entity card currently being viewed in single-card detail mode). Separate from `sidebarSelection` (= = the sidebar tree selection) so detail mode can render without changing which tree row is highlighted.`). It's a small file-hygiene miss — the comment describes a `var` that was just removed.

**Suggested fix:** delete lines 54-58 in `AppState.swift` (no behavioral impact, dead documentation).

### Gap B — Stale doc-block in `App.swift` listing removed vars

**File:** `Sources/WenshuApp/App.swift:415-421`

```swift
/// v0.30 boss 8/31 OOB "option A for cross-zone communication"
/// (= global @Observable store). Per-window @State (= each
/// WindowGroup instance gets its own AppState = boss 8/27 OOB
/// multi-window future-proofing). All cross-zone UI signals
/// (sidebarSelection / selectedEntity / selectedEntityCategory /
/// previewSortOrder) live in this single observable object.
/// Descendants read it via `@Environment(AppState.self) var appState`.
```

After the H-1 followup, `AppState` only contains `sidebarSelection`. The doc-comment still names `selectedEntity / selectedEntityCategory / previewSortOrder` as if they live in AppState. The H-3 fix correctly translated CJK → English (per AGENTS.md L5-6) but didn't reconcile the doc to the new (smaller) AppState.

**Suggested fix:** replace the parenthetical on line 419-420 with `All cross-zone UI signals (currently sidebarSelection) live in this single observable object.` — or, if there's an intent to re-add the 3 vars in v0.31, leave the doc as-is and add a TODO comment that the vars will re-appear.

### Gap C — `case .shelfScope:` without associated-value binding (style)

**File:** `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:245`

```swift
case .shelfScope:
    shelfScopeView()
```

The enum at `PreviewPane.swift:145` declares `case shelfScope(shelfId: UUID)`. Swift accepts omitting the associated value, but if `shelfScopeView` ever grows a `(shelfId:)` parameter, this switch arm will silently drop the value. Not a v0.30 problem (the message is identical for every shelf), so flagging only as awareness.

### Gap D — Pre-existing dead `@Binding` chain not addressed (not a followup regression)

This was already in the prior review's "Other observations #1". Worth re-stating for completeness: `selectedEntity` and `selectedEntityCategory` still live as `@State` in `WorkspaceView.swift:35,39`, as `@Binding` in `ZoneModuleView` (`:322-323`) and `NewLibraryOutlineView.swift:146-147`, and are still written from the sidebar `.onChange` handlers at `NewLibraryOutlineView.swift:343-369`. The followup removed the AppState declarations but did not touch the binding chain. **Net effect: the binding chain shrank from 4 layers to 3, not 1, for these two signals** — exactly as the prior review noted. The v0.30 spec's "remove 4-layer @Binding chain" claim was overstated for these two signals; this is unchanged by the followup.

If the next v0.31 ticket (the "re-add 3 vars when consumers appear" backlog) adds the AppState vars back, the binding chain in WorkspaceView/ZoneModuleView/NewLibraryOutlineView should be ripped out at the same time. Otherwise the AppState vars will land as fresh dead state, exactly as the v0.30 H-1 finding flagged.

---

## Q5.4 loop-gate status

The prior review's gate (`Q5.4`) said: "re-verify after followup commits; only PASS/PARTIAL/UNCHANGED/REGRESSED/NEW entries are accepted at the next gate."

| Entry | Triggered? | Notes |
|---|---|---|
| PASS | ✅ (#2) | #2 went FAIL → PASS |
| UNCHANGED | ✅ (8 criteria) | All 8 prior PASS criteria still PASS |
| PARTIAL | ✅ (#10) | Expected; documented as v0.31 backlog |
| REGRESSED | ❌ | No regression in any prior PASS |
| NEW | ✅ (Gaps A, B, C, D) | 4 new hygiene gaps surfaced (none blocking #1-#10) |

**Final verdict: spec axis PASS.** Spec criterion #2 is now satisfied end-to-end, no other criterion regressed, build is clean, and AppState is the minimal 1-var form it should have been from the start. The 4 new hygiene gaps (A: orphan doc-block, B: stale doc-block, C: switch arm style, D: pre-existing dead binding chain) are not spec-criterion violations — they belong in a v0.31 cleanup pass or a followup commit. The Q5.4 loop gate can close for the spec axis.

---

## Files reviewed (re-verification)

- `.scratch/v0.30-app-state-cross-zone/spec.md` (lines 1-136 — acceptance criteria 1-9 listed)
- `.scratch/v0.30-app-state-cross-zone/code-review-2026-08-31-spec-axis-report.md` (prior report)
- `Sources/WenshuApp/State/AppState.swift` (entire, 61 lines — post-followup)
- `Sources/WenshuApp/App.swift` (lines 410-440, 415-421, 639-645 — doc-block + SettingView deletion)
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (lines 1-90, 320-360 — both `previewScope` implementations)
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift` (lines 140-330 — scope dispatch + subviews)
- `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` (lines 80-220, 1070-1080, 1170-1180 — sidebar tag + binding writes)

No source files were modified. Build verified clean (`swift build` exit 0, 16.77s, no new warnings). This report is the only file produced.