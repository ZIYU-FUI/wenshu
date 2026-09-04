# Wenshu v0.28 code review v028-001 — Spec axis

**Commit reviewed:** `3e312d5d6` — *fix(wenshu): v0.28 — NativeSplitter middle drag line fix (boss 8/27 '中间拖拽线不能拖')*
**Repo:** `/Volumes/ANAN/Engineering/wenshu`
**Branch:** `wt/multi-agent-dispatch`
**Diff scope:** `Sources/WenshuApp/Views/Layout/NativeSplitter.swift` (+80 / −20). **No other files touched.** (verified via `git diff-tree --no-commit-id --name-only -r 3e312d5d6` and `git diff 3e312d5d6^ 3e312d5d6 --name-only`.)
**Spec source of truth:** `.scratch/2026-08-28-v0-28-free-layout/spec.md`

---

## Verdict summary

| Axis | Status |
|---|---|
| 1. Boss OOB cross-check (preserve foundation + fix middle drag line + dual reference) | **PASS** |
| 2. Visual identity (3-state feedback, system color tokens) | **PASS** |
| 3. Hit area spec compliance (8 → 12 PT, Apple HIG range) | **PASS** |
| 4. Drag gesture behavior preserved + isDragging now drives visual | **PASS** |
| 5. Foundation preservation (LayoutShellView / WorkspaceState / WorkspaceStore / API call sites) | **PASS** |
| 6. Acceptance criteria (clean build / no new warnings / visual chain / animation / hit testing) | **FAIL** — 3 new "never used" compiler warnings introduced in NativeSplitter.swift (lines 91, 93, 155). Commit body's "No new compiler warnings" claim is FALSE. |
| 7. Out-of-spec scope (no TabKind / v2 schema / LayoutPicker / TreeEditBar / ZoneEditor / 3rd-party deps / removed shell) | **PASS** |

**Overall:** 6 / 7 axes PASS, 1 axis FAIL. **Conditional MERGE** — fix the 3 dead locals (`isActive` × 2, `activeOpacity` × 1) introduced by the refactor, re-verify `swift build` is silent, then the commit is ready to ship.

---

## Axis 1 — Boss OOB cross-check

**Verdict: PASS**

Boss 8/27 OOB verbatim (spec.md §"Boss 8/27 OOB verbatim"):
- "如果是用现代码升级，那要保留现在的基础" (= modernize, keep the foundation).
- "合理解决现在中间拖拽线不能拖拽的问题" (= reasonably solve the middle drag line that can't be dragged).
- "参考 hermes，和那个框架，两个都是参考" (= reference hermes AND bonsplit, both as reference).

| Boss OOB clause | Evidence | Result |
|---|---|---|
| "保留现在的基础" | `git diff 3e312d5d6^ 3e312d5d6 --name-only` returns ONLY `Sources/WenshuApp/Views/Layout/NativeSplitter.swift`. Zero diff on `App.swift` (155578 bytes), `LayoutShellViewModel.swift`, `WorkspaceState.swift`, `WorkspaceStore.swift`, `Package.swift`. `WorkspaceState` still at `version: 1` (file `Sources/WenshuApp/State/WorkspaceState.swift:128`). `LayoutShellView` body at `App.swift:1328` untouched. | PASS |
| "中间拖拽线不能拖" fix | Commit targets `NativeSplitter.swift` with D_h (orientation = `.horizontal`) fix at `App.swift:1394` (the middle drag line between upper band 4 zones and lower band 2 zones). The fix is applied to BOTH `verticalBody` (App.swift:1559 `VSplitter` → `NativeSplitter(.vertical)`) AND `horizontalBody` (App.swift:1394 `NativeSplitter(.horizontal)`) — so consistency is preserved, not just the middle. | PASS |
| Reference hermes + bonsplit, both, read-only | Commit body §"Reference:" cites BOTH: `/Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/renderer/edit-bar.tsx` AND `github.com/almonk/bonsplit/blob/main/Sources/Bonsplit/BonsplitView.swift`. Both labeled "read-only". `Package.swift` diff = 0 lines (confirmed) → no dep added. | PASS |

---

## Axis 2 — Visual identity (boss 8/27 'see and report visual identity' rule)

**Verdict: PASS**

Visual chain verified in `Sources/WenshuApp/Views/Layout/NativeSplitter.swift`:

| State | Spec target | Implementation | Color token | Thickness | Glow | File:line |
|---|---|---|---|---|---|---|
| idle | `Color(nsColor: .separatorColor)` at 1 PT | `.separatorColor` @ `lineThickness = 1` | `.separatorColor` (NSColor token ✓) | 1 PT ✓ | none (`.clear`, radius 0) ✓ | L41, L94-98 |
| hover | `Color(nsColor: .controlAccentColor).opacity(0.25)` at 3 PT | `.controlAccentColor.opacity(0.25)` @ `hoveredThickness = 3` | `.controlAccentColor` (NSColor token ✓) | 3 PT ✓ | `.controlAccentColor.opacity(0.15)` radius 8 ✓ | L42, L94-98, L105-106 |
| dragging | `Color(nsColor: .controlAccentColor).opacity(0.6)` at 4 PT + glow | `.controlAccentColor.opacity(0.6)` @ `draggingThickness = 4` | `.controlAccentColor` (NSColor token ✓) | 4 PT ✓ | `.controlAccentColor.opacity(0.25)` radius 10 ✓ | L60, L94-98, L105-106 |

**Color token compliance:** 100% macOS NSColor tokens. Zero hardcoded hex (`.separatorColor`, `.controlAccentColor` only). Confirms Apple HIG adaptation (system colors automatically respect light/dark mode + accessibility contrast).

**Note:** the `activeOpacity` variable (declared at L93 in `verticalBody`) is computed but never applied — `.fill(activeColor)` uses the color from `Color.opacity(...)` instead of `Color.opacity(activeOpacity)`. This is dead code AND it means the idle state's alpha is hardcoded to 1.0 (fine for `.separatorColor` which is already opaque). Not a visual identity defect (idle looks correct), but it is one of the dead locals flagged in Axis 6.

---

## Axis 3 — Hit area spec compliance

**Verdict: PASS**

| Criterion | Pre-fix | Post-fix | Apple HIG compliance |
|---|---|---|---|
| Hit area thickness | 8 PT | **12 PT** | 12 PT ≥ 5 PT (HIG minimum) ✓ |
| Source | `hitAreaThickness: CGFloat = 8` | `hitAreaThickness: CGFloat = 12` | `Sources/WenshuApp/Views/Layout/NativeSplitter.swift:58` |
| Hit area frame | `.frame(width: 8, height: length)` / `.frame(width: length, height: 8)` | `.frame(width: 12, height: length)` / `.frame(width: length, height: 12)` | L114 / L174 |
| Collision with adjacent zones | 8 PT visible line + 8 PT hit area = could overlap tiny preview when adjacent zone = 12 PT frame | 12 PT visible line (1 PT idle / 3 PT hover / 4 PT drag max) + 12 PT hit area = hit area = visible max + 8 PT padding per side ✓ | safe |

**12 PT** is comfortable for mouse precision (Apple HIG minimum 5 PT, wenshu boss benchmark) and the hit area is centered on the line so it extends 6 PT into each adjacent zone — but the wenshu HStack zones are bounded by the parent layout with min widths ≫ 12 PT, so no false-positive drag on adjacent zone content.

---

## Axis 4 — Drag gesture behavior spec

**Verdict: PASS**

| Behavior | Pre-fix | Post-fix | Result |
|---|---|---|---|
| `DragGesture(minimumDistance: 0, coordinateSpace: .local)` | preserved (L124 / L184) | preserved | PASS |
| `stepDelta` fix (= `lastCumulativeTranslation` baseline + `currentCumulative - last` per callback) | preserved (was L130-135) | preserved (L131-141 / L190-198) | PASS — root cause fix from v0.27 not regressed |
| `isDragging` state now drives visual feedback | NO (only used to reset baseline) | YES (`activeThickness`, `activeColor`, `.animation(... value: isDragging)`) | PASS — new behavior spec'd in commit body §"Fix #2" |

Gesture orientation handling is also unchanged:
- vertical: `value.translation.width` → `onDrag(dx)` → `vm.adjust(splitterIndex, delta:, totalWidth:)` (App.swift:1560)
- horizontal: `value.translation.height` → `onDrag(dy)` → `vm.adjustBandSplit(delta:, totalHeight:)` (App.swift:1395)

---

## Axis 5 — Foundation preservation (boss OOB "保留现在的基础")

**Verdict: PASS**

| Foundation element | Status | Evidence |
|---|---|---|
| `LayoutShellView` body (`App.swift:1328`) | UNTOUCHED | `git diff 3e312d5d6^ 3e312d5d6 -- Sources/WenshuApp/App.swift \| wc -l` = 0 |
| `LayoutShellViewModel` (`Sources/WenshuApp/LayoutShellViewModel.swift`) | UNTOUCHED | diff = 0 |
| `WorkspaceState` schema (`Sources/WenshuApp/State/WorkspaceState.swift`) | UNTOUCHED, still v1 | diff = 0; `var version: Int` at L128 still = 1 |
| `WorkspaceStore` (`Sources/WenshuApp/State/WorkspaceStore.swift`) | UNTOUCHED | diff = 0 |
| `NativeSplitter` API signature `(orientation:length:onDrag:)` | PRESERVED (no breaking change) | still public API at L18-20 |
| 1 D_h call site (`App.swift:1394` — middle drag line) | UNTOUCHED | passes same `(orientation: .horizontal, length: totalW, onDrag:)` |
| 4 D_v call sites via `VSplitter` (`App.swift:1652, 1688, 1704, 1772` → `splitterIndex` 0/1/2/4) | UNTOUCHED | `VSplitter` body at `App.swift:1553-1563` unchanged; still calls `vm.adjust(splitterIndex, delta:, totalWidth:)` |
| `Package.swift` | UNTOUCHED | diff = 0; no new 3rd-party deps |

Note: the spec brief said "5 vertical splitter call sites" — actual count is **4 D_v sites** (splitterIndex 0/1/2/4 = D_v1/D_v2/D_v3/D_v5, where D_v4 doesn't exist in current shell layout). The D_h at App.swift:1394 is the horizontal middle drag line. Total = 5 NativeSplitter instances in the runtime shell, matching boss OOB "5 drag lines".

---

## Axis 6 — Acceptance criteria (from commit body)

**Verdict: FAIL** (1 / 6 sub-criteria fails)

| # | Criterion | Claim | Verification | Result |
|---|---|---|---|---|
| 6.1 | `swift build` clean | TRUE | `swift build 2>&1 \| tail -3` → `Build complete! (0.50秒)`, exit 0 | **PASS** |
| 6.2 | No new compiler warnings | TRUE | **FALSE.** Baseline (commit `7c1f548e0`, v0.27 head) emits 5 pre-existing warnings (`App.swift:1134`, `1152`, `1335`, `1622`, `1624`). Current head (`3e312d5d6`) emits those same 5 PLUS 4 new ones in `NativeSplitter.swift`:<br>• L91 `let isActive` (verticalBody) — never used<br>• L93 `let activeOpacity` (verticalBody) — never used<br>• L155 `let isActive` (horizontalBody) — never used<br>(compiler reports `isActive` twice — once per body — and `activeOpacity` once = 3 distinct dead locals, 4 warning emissions due to repeated compilation passes) | **FAIL** |
| 6.3 | Hit area 8 → 12 | TRUE | diff `-` `hitAreaThickness: CGFloat = 8` → `+` `hitAreaThickness: CGFloat = 12`. Frame widths updated at L114, L174. | **PASS** |
| 6.4 | Three-state visual feedback (idle / hover / dragging) | TRUE | ternary chain at L94-98 (`activeColor`), L92 (vertical `activeThickness`), L156 (horizontal `activeThickness`). All three states covered. | **PASS** |
| 6.5 | `.allowsHitTesting(true)` added | TRUE | L115 (verticalBody) + L175 (horizontalBody) | **PASS** |
| 6.6 | Animation 0.2s → 0.15s | TRUE | L108-109 (verticalBody): `.easeInOut(duration: 0.15)`; L170-171 (horizontalBody): same | **PASS** |

**Required fix for Axis 6:**
- Remove dead local `let isActive = isHovered \|\| isDragging` at `NativeSplitter.swift:91` (verticalBody)
- Remove dead local `let activeOpacity: Double = ...` at `NativeSplitter.swift:93` (verticalBody)
- Remove dead local `let isActive = isHovered \|\| isDragging` at `NativeSplitter.swift:155` (horizontalBody)

Re-verify with `swift build 2>&1 | grep -E "warning:|error:" | grep -v unhandled` returning empty.

---

## Axis 7 — Out-of-spec scope check (what the commit should NOT have done)

**Verdict: PASS** (boss OOB "不实现自由布局" / "不引三方 view framework" / "保留现在的基础")

| OOB constraint | Verification | Result |
|---|---|---|
| Did NOT add new `TabKind` cases (= boss OOB 'v0.28 不做特色工具 / 不做长文 / 不做压缩') | `grep -rn "enum TabKind" Sources/` returns only `Sources/WenshuApp/State/WorkspaceState.swift:67`, unchanged by commit (no diff on that file). Existing cases: `projectSidebar / projectPreview / editor / specializedTools / aiChat / aiDynamic` (v0.27 set). | PASS |
| Did NOT migrate `WorkspaceState` schema to v2 split tree (= boss OOB '不实现自由布局') | `version: Int` field at `WorkspaceState.swift:128` still v1. No `[SplitNode \| PaneNode]` recursive type added. No `normalize()` / `removePane()` / `insertAtGroup()` / `movePane()` pure functions added. | PASS |
| Did NOT introduce `LayoutPicker` / `TreeEditBar` / `ZoneEditor` (= boss OOB '不实现自由布局') | `find Sources/WenshuApp/Views/Workspace -type f` = only `WorkspaceView.swift` (existed since v0.27 commit `7c1f548e0`). No `LayoutPicker/`, `PaneRenderer.swift`, `LayoutEditBar.swift`, `ZoneEditor.swift`, `GridModel.swift`, `LayoutEditMode.swift` directories or files created by this commit (`git diff-tree --no-commit-id --name-only -r 3e312d5d6` shows only NativeSplitter.swift). | PASS |
| Did NOT add third-party deps (= boss OOB '不引三方 view framework' + ADR-0008) | `git diff 3e312d5d6^ 3e312d5d6 -- Package.swift` = 0 lines. Reference citations in commit body are explicitly labeled "read-only". | PASS |
| Did NOT remove `LayoutShellView` (= boss OOB '保留现在的基础') | `App.swift:1206 struct LayoutShellView: View` — present in both pre and post commit (zero App.swift diff). Still mounted in shell as opt-in fallback per spec.md "LayoutShellView stays as the legacy fallback; WorkspaceView is the new default. The two coexist". | PASS |

---

## Findings summary

| ID | Severity | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| F1 | **FAIL** | `NativeSplitter.swift:91` | Dead local `let isActive = isHovered \|\| isDragging` (verticalBody) — never used | Delete line |
| F2 | **FAIL** | `NativeSplitter.swift:93` | Dead local `let activeOpacity: Double = ...` (verticalBody) — never used | Delete line |
| F3 | **FAIL** | `NativeSplitter.swift:155` | Dead local `let isActive = isHovered \|\| isDragging` (horizontalBody) — never used | Delete line |
| F4 | WARN (cosmetic) | `NativeSplitter.swift:68-75` | `isDragging` @State is set in both `verticalBody.onChanged` and `horizontalBody.onChanged` via the same parent view's state. Since `body` is a computed property that returns either `verticalBody` OR `horizontalBody` (not both), only one body's gesture is active at a time — so this works correctly. But the comment block at L68-75 mentions "NativeSplitter 已有 isDragging @State" without making this single-active-gesture invariant explicit. | Optional: tighten comment to note only one body mounts at a time. |
| F5 | SUGGEST | `NativeSplitter.swift:60` | `draggingThickness` doc comment says "Apple HIG 标准" (Apple HIG standard). Apple HIG does not mandate a 4 PT splitter-drag width. 4 PT is consistent with the existing `hoveredThickness = 3` choice and matches bonsplit's accent capsule width — but the "Apple HIG 标准" claim is loose. | Soften comment to "v0.28 drag visual 4 PT (matches hoveredThickness + 1 PT; boss 8/27 OOB drag feedback convention)" |

**No SUGGEST-level items would block the merge.** F1-F3 (the dead locals) MUST be fixed before merge to honor the commit body's own "No new compiler warnings" acceptance criterion.

---

## Recommendation

**Conditional MERGE.** Apply the 3-line dead-local cleanup (F1/F2/F3), re-run `swift build` to confirm `NativeSplitter.swift` warning lines are gone, then ship. Total diff impact = −3 lines. The functional fix (12 PT hit area + 3-state visual + `.allowsHitTesting(true)` + 0.15s animation) is correct and respects all boss OOB scope constraints.

All other 6 axes PASS with concrete evidence; foundation is preserved; no out-of-spec scope was added; both reference sources are cited read-only.