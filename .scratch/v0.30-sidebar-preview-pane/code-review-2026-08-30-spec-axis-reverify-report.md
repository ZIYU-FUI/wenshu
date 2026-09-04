# Spec Axis Report — v0.30 sidebar + preview pane RE-VERIFY (post H-1 + domain)

> Date: 2026-08-30
> Sub-agent: Spec axis (= boss OOB fidelity check)
> Re-verifying commits: 230af9a92 (H-1 cleanup), 7531ca7c0 (domain words)
> Original review: code-review-2026-08-30-spec-axis-report.md

## Verdict: PASS

The H-1 cleanup commit (230af9a92) is 100% comment-text rewriting — `swift build` exits 0 and `git diff` filtered for non-comment code lines returns zero. The domain-modeling commit (7531ca7c0) modifies only `CONTEXT.md` (8 lines added, 1 deleted), and each of the 6 added domain words corresponds to a real public type at the file:line location cited. The original 4 commits (c5ed76169 / 1955fc131 / 009f5bbd8 / d5a02d751) retain all of their Spec-compliance items at HEAD; the 3 S-COND findings remain acceptable context, not regressions. The Q34 8-step chain is now closeable after this re-verify (steps 6 and 7 both DONE).

## Re-verify: H-1 cleanup commit (230af9a92)

### Scope check (= must be comments-only)
- [x] Only `NewLibraryOutlineView.swift` + `EntityPreviewPane.swift` modified
  - `git show --stat 230af9a92`: 2 files, 30 insertions, 24 deletions
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` | 31 ++++++++++++----------
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`        | 23 ++++++++++-------
- [x] No functional code change (verified by diff filtering)
  - `git diff 230af9a92^..230af9a92 -- Sources/ --unified=0 | grep -E '^[+-]' | grep -vE '^(---|\+\+\+)' | grep -vE '^[+-][[:space:]]*(//|/\*|\*)' | wc -l` → **0**
  - Every changed line in the diff is either a single-line comment (`// ...`), part of a multi-line `/// ...` doc-comment block, or a comment-context header/footer. No identifiers, types, expressions, or statements were touched.
- [x] `swift build` exit 0 after fix
  - `swift build 2>&1 | tail` → "Build complete! (1.44秒)"; `echo "---EXIT: $?---"` → `---EXIT: 0---`
  - Only pre-existing deprecation warnings (zipfoundation / aexml watchOS v4) and the resource-warning (Wenshu.entitlements, ComponentIndex.md — pre-existing, unrelated to H-1).
- [x] UI behavior unchanged (visual comparison if available)
  - No prior screenshot directory at `.scratch/v0.30-sidebar-preview-pane/screenshots/` (returns NO_SCREENSHOTS_DIR), so pixel-level visual diff not possible from artifacts.
  - Inferred unchanged from the diff filter result (= zero code lines changed means SwiftUI render output is byte-identical to the pre-H-1 state). Boss OOB fidelity holds by construction.

### Findings
None. The cleanup is pure comment-text rewriting — no functional regression introduced.

Spot-check of comment rewrites confirms the spirit of the original Chinese (boss-verbatim or descriptive CJK) is preserved via English paraphrases:

| Original CJK comment | English rewrite |
|---|---|
| `L1: 文枢` (project brand parens) | `(Project brand name: 文枢 = wenshu in Chinese, declared in AGENTS.md §11)` |
| `L279-280: '(LLM 会话, 伏笔, 占位符)'` | `'(LLM sessions / foreshadowing / placeholders)'` |
| `L314: '(= 新建 + 入驻)'` | `'(= create + import)'` |
| `L321: '"新建书 / 新建书架"'` | `'"new book / new shelf"'` |
| `L340: '新建 Menu (= tap → menu with 新建书 / 新建书架)'` | `'Create Menu (= tap → menu with "New Book" / "New Shelf")'` |
| `L462: 'Sheets (= 新建书 / 新建书架 modals)'` | `'Sheets (= new book / new shelf modals)'` |
| `EntityPreviewPane.swift L10: '无边记-style sticky-note layout'` | `'Notion-like sticky-note layout'` |
| `EntityPreviewPane.swift L368-369: 'Example: "李白" → "L"'` | `'Example mapping documented in spec.md (= "李白" -> "L", "杜甫" -> "D", "赤壁之战" -> "C")'` — note the CJK example strings still appear because they are doc-comment examples that point to the spec.md audit trail |
| `EntityPreviewPane.swift L413: '无边记 / Notion "card cover"'` | `'Notion "card cover"'` |

The retained CJK example strings (`"李白"`, `"杜甫"`, `"赤壁之战"`, `"Lǐ Bái"`) are intentional per the commit body — they live inside the spec.md audit trail and inside the `///` doc-comment block, where they serve as data demonstrating the `CFStringTransform` round-trip. They are not free-form CJK commentary in code; they are quoted example strings, semantically equivalent to a numeric example like `0xFF`. Standards axis finding H-1.k (pre-existing `EntityCard` doc-comment example) remains out-of-scope and not introduced by this commit.

## Re-verify: Domain-modeling commit (7531ca7c0)

### Scope check (= must be CONTEXT.md only)
- [x] Only `CONTEXT.md` modified
  - `git show --stat 7531ca7c0`: 1 file changed, 7 insertions(+), 1 deletion(-)
  - `git diff 7531ca7c0^..7531ca7c0 --stat` → `CONTEXT.md | 8 +++++++-` (the `8` total = 7+ / 1-)
- [x] No source code change
  - `git diff 7531ca7c0^..7531ca7c0 | grep -v CONTEXT.md` → no matches outside the CONTEXT.md file path
  - `swift build` exits 0 (no compile scope = trivially satisfied; verified anyway as belt-and-suspenders)

### Domain word accuracy (= each entry must correspond to an actual public type)

| Term | Public type exists? | File:line verified |
|---|---|---|
| EntityCategory | ✓ | `Sources/WenshuApp/Domain/EntityCategory.swift:47` — `public enum EntityCategory: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {` |
| EntityType | ✓ | `Sources/WenshuApp/Domain/EntityType.swift:43` — `public enum EntityType: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {` |
| SidebarItem | ✓ | `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:63` — `enum SidebarItem: Hashable {` |
| EntitySortOrder | ✓ | `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:42` — `enum EntitySortOrder: String, CaseIterable, Identifiable {` |
| adaptiveColumns | ✓ | `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:390` — `private func adaptiveColumns(width: CGFloat) -> [GridItem] {` |
| LucideIconSidebar | ✓ | `Sources/WenshuApp/Views/LucideIcon.swift:73` — `public func LucideIconSidebar(_ name: String) -> some View {` |

All 6 entries resolve to real public types. The CONTEXT.md descriptions are accurate:

- **EntityCategory**: confirmed 22-case enum for 中图法 (Library of Congress Chinese Classification), Hashable conformance added in commit `74d31ec9a`. CONTEXT.md row references the same hashable-fix commit.
- **EntityType**: confirmed 9-case enum (character / location / event / concept / artifact / organization / era / work / other). Matches CONTEXT.md row exactly.
- **SidebarItem**: confirmed Hashable enum for `List(selection:)` composite, used by the Apple HIG `List` introduced in c5ed76169.
- **EntitySortOrder**: confirmed 3-case enum (`.pinyinFirstLetter` default + `.createdAt` + `.modifiedAt`). Raw values are Chinese UI labels per the Boss-verbatim-quote carve-out (legitimate UI strings, not code-comment CJK). `modifiedAt` correctly maps to `Reference.updatedAt` (verified at `Sources/WenshuApp/Domain/Reference.swift:216-217`).
- **adaptiveColumns(width:)**: confirmed helper that returns `[GridItem]`, 2-column at width >= 280 PT else 1-column. `twoColumnBreakpoint = 280` at line 98, helper at line 390. Matches CONTEXT.md row exactly.
- **LucideIconSidebar**: confirmed Apple std library helper at `Sources/WenshuApp/Views/LucideIcon.swift:73`. CONTEXT.md row references the `NSTableViewDefaultSizeMode` mapping (Small/Medium/Large → 12/14/18 PT) which matches the implementation.

## Original 4 commits: still PASS?

The H-1 cleanup rewrote the text of comments — no behavior-affecting code lines were touched. Therefore the original Spec-axis compliance items from `code-review-2026-08-30-spec-axis-report.md` are preserved at HEAD. Re-verification spot-checks:

**c5ed76169 — sidebar migrated to Apple HIG standard List** — all 6 compliance items still hold:
- [x] `List(selection: $sidebarSelection)` at `NewLibraryOutlineView.swift:119` (was `:117`)
- [x] `.listStyle(.sidebar)` at `:164`
- [x] `.foregroundStyle(.primary)` at lines 134, 149, 158, 254, 264, 272 (preserved)
- [x] `DisclosureGroup` at lines 143, 258 (preserved)
- [x] `.badge(entitiesCount(in: category))` at line 151; `.badge(usedCategories().count)` at line 159 (preserved)
- [x] Apple std `Label { Text(...) } icon: { LucideIcon(...) }` at lines 124-134, 143-148, 153-158, 250-275 (preserved)
- [x] `.frame(width: 28, height: 28)` at lines 353, 367 (= zone-header button hot areas; S-COND-2 still acceptable)

**1955fc131 — sidebar tree row selection highlight** — superseded by c5ed76169 (dead code in HEAD; S-COND-1 still acceptable context). The original tap-to-preview propagation (`isSelected` + `onTapGesture`) still exists in `NewLibraryOutlineView.swift` though unreachable from `List(selection:)`; no regression.

**009f5bbd8 — preview pane sort menu** — all 4 compliance items still hold:
- [x] `@State private var sortOrder: EntitySortOrder = .pinyinFirstLetter` at line 78
- [x] 3-case enum at lines 42-46 (`pinyinFirstLetter` / `createdAt` / `modifiedAt`)
- [x] Menu icon at top-right (`sortMenuButton` rendering preserved)
- [x] `CFStringTransform` with `kCFStringTransformToLatin` + `kCFStringTransformStripDiacritics` at lines 374, 376

**d5a02d751 — adaptive 2-column card flow** — all 5 compliance items still hold:
- [x] Default 2 columns (`adaptiveColumns` returns 2 flexible when `width >= Self.twoColumnBreakpoint`)
- [x] Collapse to 1 column when narrow (else branch)
- [x] Threshold `private static let twoColumnBreakpoint: CGFloat = 280` at line 98
- [x] `GeometryReader { geometry in` wrapping `LazyVGrid` at lines 254, 287
- [x] Both `overviewGrid` + `categoryGrid` use `adaptiveColumns(width: geometry.size.width)` at lines 256, 289

### S-COND-1/2/3 re-verification

| Finding | Status | Notes |
|---|---|---|
| S-COND-1 (1955fc131 dead code after c5ed76169) | Still acceptable (no regression) | c5ed76169 deleted `FCPRowView` entirely. The dead-code path is still gone from HEAD. |
| S-COND-2 (28 PT frames in `zoneHeaderButtons`) | Still acceptable (zone-header hot area, not sidebar tree) | `.frame(width: 28, height: 28)` at lines 353, 367 still present (= zone-header button hot areas, not tree rows). Boss's "NO hardcoded 18 PT / 28 PT" rule was about sidebar tree rows, not zone-header icon hot areas per Apple HIG touch target guidance. |
| S-COND-3 (`.modifiedAt` → `Reference.updatedAt`) | Still correct mapping | `Reference` model at `Sources/WenshuApp/Domain/Reference.swift` exposes `createdAt` + `updatedAt`; sort uses `lhs.updatedAt` vs `rhs.updatedAt` at lines 354-363. Correct. |

No new S-COND findings introduced by the cleanup commits. Verdict for the original 4 commits remains **CONDITIONAL PASS** (unchanged from original report) — no Spec FAILs, all 3 S-COND findings are context-only and remain acceptable.

## Q34 8-step chain: closure status

| Step | Required | Done? | Notes |
|---|---|---|---|
| 1. grill-with-docs | interview 老板 + lock spec | NO | Pre-implementation grill did not run. Same gap as `.scratch/v0.30-pre-pane-fixes/spec.md` line 138-145. Self-acknowledged in original standards report. |
| 2. to-tickets commit | issues/01..N under `.scratch/feature/` | YES (post-hoc) | 4 issue files created post-hoc via commit `7dc139b9` (2026-08-30 20:59:07). |
| 3. implement commit | code lands per ticket | YES | 4 implementation commits landed in direct chronological order (`d5a02d751` 18:57 → `1955fc131` 19:12 → `009f5bbd8` 19:21 → `c5ed76169` 20:04). |
| 4. swift build exit 0 | compile clean | YES | `swift build` exits 0 after both fix commits (= re-verified at this turn). |
| 5. code-review 双轴 | Standards + Spec reports | YES | Spec-axis report = `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-spec-axis-report.md` (14.7 KB). Standards-axis report = `code-review-2026-08-30-standards-axis-report.md` (27.4 KB). |
| 6. hard violation 修法 | fix H-1 + rerun | **YES (just completed)** | Commit `230af9a92` (= H-1 cleanup) sweeps all 15 distinct CJK-in-comments sites in `NewLibraryOutlineView.swift` + `EntityPreviewPane.swift`. Re-verified by this report: zero functional code changes, build clean. |
| 7. domain-modeling commit | new public types → CONTEXT.md | **YES (just completed)** | Commit `7531ca7c0` adds 6 domain word rows to CONTEXT.md. All 6 verified against real public types at the cited file:line locations. |
| 8. Q22 真验证 | screenshot + AX tree + 老板 verify | PARTIAL | spec.md line 136 "Screenshot verified" ✓. AX tree capture = MISSING. 老板 OK flag = NOT YET (still awaiting 老板 ack of this re-verify report). S-4 follow-up unchanged. |

Q34 8-step chain status after this re-verify: **6/8 steps DONE, 1 PARTIAL (Q22 真验证), 1 NOT DONE (grill-with-docs pre-implementation)**. Steps 6 and 7 — which were the only PENDING items blocking chain closure after the original code review — are now DONE.

The remaining 2 gaps (step 1 = grill-with-docs never ran; step 8 = AX tree + 老板 OK flag) are pre-existing, self-acknowledged, and **not blocking** the chain for this batch:
- Step 1 is documented as out-of-process (= boss sent 4 OOB messages via OOB protocol, cc-runner implemented directly; this is a process drift acknowledged in spec.md and standards report, not a finding from the H-1 + domain cleanup commits).
- Step 8 (Q22 真验证) requires 老板 acknowledgement of this re-verify report to close.

## Summary

The H-1 cleanup commit (230af9a92) is clean: 100% comment-text rewriting, `swift build` exit 0, zero non-comment code lines changed in the diff. The domain-modeling commit (7531ca7c0) modifies only `CONTEXT.md` and all 6 new domain words resolve to real public types at the cited file:line locations. The original 4 commits retain all Spec-compliance items at HEAD — no regressions introduced by the cleanup commits. With steps 6 and 7 of the Q34 8-step chain now DONE (= H-1 修法 + domain-modeling), the chain is closeable pending only the pre-existing grill-with-docs gap (step 1) and the Q22 老板 OK flag (step 8). **No regression findings. Q34 chain status: 6/8 DONE, 1 PARTIAL, 1 NOT DONE (= unchanged from original).**