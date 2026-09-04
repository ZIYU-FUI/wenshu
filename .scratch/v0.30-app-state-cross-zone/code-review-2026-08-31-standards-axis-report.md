# Standards-Axis Code Review — v0.30 AppState Cross-Zone

- **Sub-agent**: Standards (Q34 8-step chain step 6 — Standards axis sub-agent)
- **Date**: 2026-08-31 (CST)
- **Repo**: `/Volumes/ANAN/Engineering/wenshu`
- **Branch**: `wt/multi-agent-dispatch`
- **Commits reviewed** (4 contiguous):
  - `eb3066bca` — feat(wenshu): v0.30 — add AppState (= global @Observable cross-zone store)
  - `17bdf49de` — feat(wenshu): v0.30 — inject AppState at app root
  - `b768fa5a0` — refactor(wenshu): v0.30 — replace 4-layer @Binding chain with @Environment AppState
  - `be3574dc1` — docs(wenshu): v0.30 — domain-modeling for AppState
- **Spec**: `.scratch/v0.30-app-state-cross-zone/spec.md` (working-tree only, uncommitted)
- **Files in scope (per task brief)**: Sources/WenshuApp/State/AppState.swift, Sources/WenshuApp/App.swift, Sources/WenshuApp/Views/Workspace/WorkspaceView.swift, Sources/WenshuApp/Views/Workspace/PaneRenderer.swift, Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift
- **Template**: `.hermes/profiles/pocock/skills/wenshu-pocock-workflow/references/dual-axis-code-review-2026-08-22.md`
- **Hard-rule source**: AGENTS.md v0.07.4 L3-9 (= English-only, no CJK in code/comments/CONTEXT.md/commit messages) + wenshu-pollution-defense (= 12 forbidden xianxia tokens)

---

## Verdict: **FAIL**

**Reason**: 4 hard violations across H-1 (incomplete migration of cross-zone signals — `selectedEntity` / `selectedEntityCategory` / `previewSortOrder` declared in AppState but never read; original `@Binding` plumbing for those 2 signals still threaded through 3 views), H-2 (dead `@State private var appState = AppState()` in `SettingView` declared but never injected into `.environment(...)`, never read), H-3 (English-only rule violation: CJK characters in code comments in the new `AppState.swift` file at L3, L62, L68, plus pre-existing CJK in `App.swift` L431-432 / 439-443 / 641 etc., and the CONTEXT.md row contains Chinese characters not allowed in code context), H-4 (scope creep into `SettingView` struct unrelated to the 4-layer @Binding chain refactor ticket).

**Recommendation**: fix the 4 hard violations before merging downstream work; re-spawn this Standards sub-agent after fixes land.

---

## Hard violations table

| ID | Category | Location | Detail | Source-rule |
|----|----------|----------|--------|-------------|
| **H-1** | Scope-partial / dead-code-in-introduced-type | `Sources/WenshuApp/State/AppState.swift` L59, L64, L69 + `WorkspaceView.swift` L35/L39/L320-321 + `NewLibraryOutlineView.swift` L146-147 | AppState declares 4 signals: `sidebarSelection`, `selectedEntity`, `selectedEntityCategory`, `previewSortOrder`. Only `sidebarSelection` was migrated (read in 4 places). The other 3 are declared-but-never-read (rg counts: 0 hits for `appState.selectedEntity` / `appState.selectedEntityCategory` / `appState.previewSortOrder` across `Sources/`). Meanwhile `selectedEntity` / `selectedEntityCategory` are STILL threaded as `@Binding` through WorkspaceView → ZoneModuleView → NewLibraryOutlineView. This violates spec ticket 03 ("Same for selectedEntity / selectedEntityCategory") and the spec.md design table (lists all 4 signals as cross-zone scope). Per boss 8/22 "工程弄的干净" + WenshuCommonSenseInteractionPrinciple, an unfinished migration is a hard rule: dead fields in a brand-new type. | Q5.2 hard rule (dead code introduced) + spec ticket 03 (commit body `b768fa5a0` says "Replaces the 4-layer @Binding sidebarSelection chain" — only `sidebarSelection`, scope-partial) |
| **H-2** | Dead code introduced (write/pollute anti-pattern) | `Sources/WenshuApp/App.swift` L643-650 | `struct SettingView` declares `@State private var appState = AppState()` with full doc-comment (L643-649), yet (a) the `Settings { SettingView() }` scene (L629-631) has NO `.environment(appState)` modifier, (b) rg finds 0 references to `appState` inside `SettingView` body. Pure dead state. Likely a copy-paste from the `WenshuApp` struct's `@State private var appState = AppState()` (L421). SettingView is unrelated to the 4-layer @Binding chain ticket — adding dead state here violates "no scope creep" (H-4 below) AND introduces dead code (this rule). | AGENTS.md v0.07.4 L5 ("English-only") is not violated here, but Q5.2 hard rule on dead-code-introduced IS. |
| **H-3** | English-only rule violation (CJK in code comments) | `Sources/WenshuApp/State/AppState.swift` L3, L62, L68 + pre-existing CJK in `App.swift` L431-432, L439-443, L640-643 (some added in scope of this batch via the `/// v0.30 boss 8/31 OOB '跨区通信的方案用 A'` doc-blocks copied into App.swift L415-420 + L643-649) + `App.swift` L431-432 contains pre-existing CJK but the new AppState.swift is FULL of CJK in 3 lines | AGENTS.md v0.07.4 L5 hard rule: "This file is English only. No Chinese characters. No CJK punctuation. No mixed CJK + Latin characters." Lines cited: `// v0.30 boss 8/31 OOB '各区域之间的联动'` (L3), `/// pointed at, = 资料库 → 文学 / 哲学 etc.` (L62), `/// (= boss 8/30 OOB '所有卡片默认排序是拼音首字母先后顺序')` (L68). The file is brand-new and 100% the responsibility of this commit batch — every CJK line is a violation. CONTEXT.md L55 (the new row added in be3574dc1) ALSO contains Chinese text (`v0.30 boss 8/31 OOB '各区域之间的联动'`). Per AGENTS.md L6: "All commit messages, comments, prompts, `.scratch/spec.md`, `.scratch/issues/`, `.scratch/backlog` files, `CONTEXT.md`, `README.md`, `CLAUDE.md`, and every doc in this repo follow the same English-only rule." | AGENTS.md v0.07.4 L5-6 (English-only, hard rule) |
| **H-4** | Scope creep into SettingView | `Sources/WenshuApp/App.swift` L643-650 (SettingView struct modification) | The 4 tickets in this batch (`.scratch/v0.30-app-state-cross-zone/issues/{01..04}-*.md`) target the WorkspaceView tree (WorkspaceView → PaneRenderer → TabContentDispatcher → ZoneModuleView → NewLibraryOutlineView). None of them mentions the Settings scene. Yet commit 17bdf49de added a `@State private var appState = AppState()` block to `SettingView` (= a SwiftUI struct in the Settings scene, not the main WindowGroup) AND a 7-line `/// v0.30 boss 8/31 OOB '跨区通信的方案用 A'` doc-comment. This is unrelated to the migration ticket. Per WenshuCommonSenseInteractionPrinciple + boss 8/22 streak rule, scope creep is a hard violation. The dead code (H-2) IS the manifestation of this H-4. | WenshuCommonSenseInteractionPrinciple (scope constraint = "fix scope = 老板 拍 requirement scope, do not expand") |

**Note on H-3 scope**: pre-existing CJK in `App.swift` (L431-432, L439-443, L640-643) is NOT a hard violation introduced by these 4 commits (predates this batch). The new CJK lines introduced by the batch are the AppState.swift L3/L62/L68, App.swift L415-420 + L643-649 (the doc-comment blocks that say "boss 8/31 OOB '跨区通信的方案用 A'") and the CONTEXT.md L55 row (`v0.30 boss 8/31 OOB '各区域之间的联动'`). Flag all new CJK lines.

**Note on H-3 sub-rule**: AGENTS.md L6 says ALL commit messages must follow English-only. The commit messages here are English-only (PASS). It's the code comments + doc-comments + CONTEXT.md that fail. Q33 §6 pre-commit hook (= `git diff --cached | grep`) catches commit message + added lines in non-allowlisted files. Run `python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan` to confirm the CJK lines slipped past the hooks — `commit_filter.py` only scans the 12 forbidden xianxia tokens, NOT the broader English-only rule. So this is a hook-gap, not a hook-bypass.

---

## Pollution-defense scan (Q49 audit gate, per dual-axis review L36-40)

| Check | Result | Note |
|-------|--------|------|
| `git diff --cached \| grep -nE '(修真\|渡劫\|筑基\|返虚\|结丹\|金丹\|元婴\|飞升\|天劫\|雷劫\|心魔\|魔障\|boss\|顾客)'` on the 4 commits | CLEAN | boss / 老板 references are allowed per AGENTS.md L78 ("Sole address for 老板 = 老板. Every dialog / doc / commit message / comment / prompt uses 老板."). No xianxia tokens. |
| `git log --format='%s' \| grep -E '(修真\|boss\|顾客)'` on the 4 commits | CLEAN | commit subjects are English-only. |
| `python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan` against eb3066bca~1..be3574dc1 | CLEAN | returns 0 hits. |
| `Tools/wenshu-devtool/commit_filter.py` line 6 / 19-20 (the file itself) | FLAG-NONE | file is on the allowlist (L31) — its job is to enumerate the family. Per wenshu-pollution-defense skill: rule-definition file is exempt. |
| `.scratch/v0.30-app-state-cross-zone/` working-tree files | NOT-COMMITTED | all 5 files (`spec.md` + 4 ticket `issues/*.md`) are untracked (git status: `?? .scratch/v0.30-app-state-cross-zone/`). Working-tree watchdog `Tools/wenshu-devtool/pollution_watchdog.py` would still want to scan them, but they are out of scope for the commit-batch review. |

**Pollution-defense: PASS** (no commit pollution).

**However**, the wenshu-pollution-defense skill notes a subtle interaction: `commit_filter.py` only catches the 12 forbidden xianxia tokens. It does NOT catch broader English-only violations (= general CJK characters). The hook is not broken; the rule set is just narrower than AGENTS.md. So CJK-in-comments (H-3 above) is a separate hook-gap, not a pollution-defense failure.

---

## Soft suggestions (not blocking, but worth fixing in followup)

| ID | Suggestion | Location |
|----|------------|----------|
| S-1 | Rename the doc-comment style. The new doc-blocks use a verbose `(= X = Y)` parenthetical style with the Chinese OOB string quoted verbatim inside single quotes. Even if the CJK were removed, the style is heavy — consider a more terse pattern (e.g. `/// Cross-zone store — see CONTEXT.md row "AppState".`) | AppState.swift L31-71 doc-blocks |
| S-2 | `init() {}` could be removed (Swift synthesizes a default no-arg init for `@Observable final class`). Tiny nit. | AppState.swift L71 |
| S-3 | `selectedEntity` / `selectedEntityCategory` / `previewSortOrder` in AppState are good future-proofing placeholders, but per Q5.2 dead-code rule, they should either (a) be removed and re-added when first used (= YAGNI), OR (b) carry a doc-comment marking them "reserved for v0.31 — NOT YET MIGRATED FROM @Binding" so the next agent doesn't think they're already wired. | AppState.swift L59, L64, L69 |
| S-4 | The `b768fa5a0` commit body says "~50 lines of @Binding plumbing REMOVED, ~30 lines of @Environment reads ADDED, net -20 LoC". Actual diff stat: 63 insertions / 102 deletions = net -39 LoC, not -20. Slight overclaim, but harmless. | commit b768fa5a0 body |
| S-5 | `WorkspaceView.swift` L35 / L39 (`@State private var selectedEntityCategory: EntityCategory?` / `@State private var selectedEntity: Reference?`) are now potentially dead — the AppState vars that mirror them are unused, AND the `@Binding` plumbing on the consumer side still goes through the workspace `@State` mirror. This 2-tier state is a footgun. Suggest collapsing: keep the @State in WorkspaceView for now (since AppState vars are unused) and drop the AppState placeholders until they're actually wired. | WorkspaceView.swift L35, L39 |
| S-6 | `PaneRenderer.swift` rowChild/columnChild helpers removed the `_sidebarSelection` private pass-through correctly (L235, L242). But the removed `_sidebarSelection` was passed via `Binding<SidebarItem?>` which means there was once a public `_sidebarSelection` projected value — make sure no external caller still passes it. (`rg '\.sidebarSelection'` outside the workspace tree returns no production callers; PASS.) | PaneRenderer.swift L59-67 |
| S-7 | The `17bdf49de` commit body's "Macro ordering fix" claim (= "The @Observable macro must be applied IMMEDIATELY preceding the class declaration... Final order: @MainActor / @Observable / final class AppState") is a useful truth-source to keep. Consider extracting to a Swift comment at the top of AppState.swift so the next agent doesn't accidentally break it. The current file DOES already document this implicitly via the doc-block at L33-36, but the macro-ordering gotcha is a build-time footgun worth a one-line `// Macro order matters: @MainActor then @Observable then class (see commit 17bdf49de)` callout. | AppState.swift L41-43 (and commit body) |
| S-8 | CONTEXT.md row added in be3574dc1 (= L55) is good domain documentation but contains Chinese characters per H-3 above. Once H-3 is fixed, the row should stay (= English version, with the OOB reference terse). | CONTEXT.md L55 |

---

## Recommended fixes (with line refs)

### Fix H-1 (scope-partial migration + dead fields in AppState)

Two options:

**Option A — finish the migration** (matches spec ticket 03 verbatim):

1. In `AppState.swift`, keep all 4 fields (they ARE declared).
2. In `WorkspaceView.swift` L35 / L39: REMOVE `@State private var selectedEntityCategory` and `@State private var selectedEntity` (they're dead now — AppState is the source of truth).
3. In `WorkspaceView.swift` L190-191: REMOVE the `selectedEntityCategory: $selectedEntityCategory, selectedEntity: $selectedEntity` init args from `NewLibraryOutlineView(...)` call (the binding source vanishes with the @State).
4. In `WorkspaceView.swift` L375-378: same removal.
5. In `WorkspaceView.swift` `ZoneModuleView` struct (L320-321 + L358-363): REMOVE the `@Binding var selectedEntityCategory` and `@Binding var selectedEntity` fields and their init params.
6. In `NewLibraryOutlineView.swift` L146-147: REPLACE `@Binding var selectedEntityCategory: EntityCategory?` and `@Binding var selectedEntity: Reference?` with `@Environment(AppState.self) private var appState`.
7. In `NewLibraryOutlineView.swift` L154-158: REMOVE the init params.
8. In `NewLibraryOutlineView.swift` L343/344, L353/354, L362/363, L366/368/369: change `selectedEntityCategory = X` → `appState.selectedEntityCategory = X`; `selectedEntity = X` → `appState.selectedEntity = X`. All `.onChange(of: selectedEntityCategory)` handlers → `.onChange(of: appState.selectedEntityCategory)`.
9. In `previewSortOrder`: pick ONE consumer (preview pane) and migrate its read to `appState.previewSortOrder`. Currently zero consumers — find the preview-pane sort code and switch.

**Option B — retract the placeholders** (faster, YAGNI):

1. In `AppState.swift` L59, L64, L69: REMOVE `var selectedEntity`, `var selectedEntityCategory`, `var previewSortOrder`. Keep only `sidebarSelection` (the one that's actually used).
2. Open a new ticket: "v0.31 migrate `selectedEntity*` + `previewSortOrder` to AppState". Add the 3 fields back when the migration is done.

**Sub-agent recommendation**: Option A (the spec / commit bodies explicitly list all 4 signals as AppState scope; option B leaves spec drift). Option A is also more honest about what "global cross-zone store" means.

### Fix H-2 (dead SettingView appState)

In `Sources/WenshuApp/App.swift` L643-650: REMOVE the entire `/// v0.30 boss 8/31 OOB...` doc-block (L643-649) and the `@State private var appState = AppState()` line (L650). SettingView has no use for AppState (it manages appearance mode, provider keychain, settings tab, liquid-glass opacity — none of which are cross-zone UI state in the spec's sense).

If the next agent wants to give Settings access to sidebarSelection (unlikely needed), wire it as: `@Environment(AppState.self) private var appState` (= read from the inherited environment), NOT `@State private var appState = AppState()` (= creates a second AppState instance, defeating per-window ownership).

### Fix H-3 (English-only rule)

Three line groups need rewriting:

1. **AppState.swift L3**: replace `// v0.30 boss 8/31 OOB '各区域之间的联动' (= adopted option A = global` with `// v0.30 boss 8/31 OOB "option A for cross-zone communication" (= global`. Replace L4-7 CJK too: the spec quotes "WorkspaceView -> PaneRenderer -> TabContentDispatcher -> ZoneModuleView -> NewLibraryOutlineView" — already English, just remove the CJK literal.

2. **AppState.swift L62**: replace `/// pointed at, = 资料库 → 文学 / 哲学 etc.). Drives the` with `/// pointed at, = a reference library category). Drives the`. (Drop the example — the example adds nothing; the spec already lists the 5 SidebarItem cases.)

3. **AppState.swift L68**: replace `/// (= boss 8/30 OOB '所有卡片默认排序是拼音首字母先后顺序')` with `/// (= boss 8/30 OOB "pinyin first letter is the default sort order for all cards")`.

4. **AppState.swift L13 / L17**: the doc-comment inside the `// Why a global @Observable` block contains `\`appState.sidebarSelection\`` — that's a code sample, not CJK, leave as is. But check the surrounding lines for any CJK. (The diff for the file at commit eb3066bca shows the file is 100% English EXCEPT the 3 CJK lines.)

5. **App.swift L415-420 + L643-649**: the `/// v0.30 boss 8/31 OOB '跨区通信的方案用 A'` doc-blocks are NEW (added in commit 17bdf49de). Replace `'跨区通信的方案用 A'` with `"option A for cross-zone communication"`. (After H-2 fix removes the SettingView block, only L415-420 remains.)

6. **CONTEXT.md L55** (the new row added in be3574dc1): rewrite the row's Chinese-quoted OOB in English. Keep the row itself (it's good domain documentation).

### Fix H-4 (scope creep)

This is the upstream cause of H-2 — once H-2's removal is done, H-4 is also resolved. No separate fix needed. Note in commit body that future SettingView changes should NOT touch AppState unless they have a real cross-zone need (boss confirmation required).

---

## Verification commands for next reviewer

```bash
# Re-run pollution scan after fixes:
python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan

# Re-run CJK check on AppState.swift after English-only rewrite:
rg -n '\p{Han}' Sources/WenshuApp/State/AppState.swift  # expect 0 hits

# Verify dead-code removed:
rg -n 'appState\.(selectedEntity|selectedEntityCategory|previewSortOrder)' Sources/WenshuApp/  # expect non-zero after Option A fix
rg -n 'appState\b' Sources/WenshuApp/App.swift  # expect 1 hit (WenshuApp struct only, not SettingView)

# Verify build still clean:
swift build  # exit 0
```

---

## Sub-agent signature

- Standards axis PASS/FAIL = **FAIL** (4 hard violations; 8 soft suggestions)
- Pollution defense = PASS (no xianxia tokens; `commit_filter.py` clean)
- Recommended action: parent agent to re-dispatch this Standards sub-agent once H-1/H-2/H-3/H-4 are fixed in a followup commit (= Q5.4 do-not-amend → new commit on top of be3574dc1). Q46 streak rule applies if >1 redo is needed.
- Boss-streak note: this is sub-agent's first read of v0.30-app-state-cross-zone. No streak on this axis yet.