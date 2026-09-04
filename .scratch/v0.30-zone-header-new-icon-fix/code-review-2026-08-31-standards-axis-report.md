# Standards Axis Report — v0.30 zone header 新建 icon fix

> Date: 2026-08-31
> Sub-agent: Standards axis (AGENTS.md §5-6 hard rules + boss-protocol carve-outs)
> Commit reviewed: c24c2f3a13b43113aa5a8497d7cca1424de11b33
> Branch: wt/multi-agent-dispatch
> Reviewer tools: ripgrep (CJK + pollution scan), git show/diff/blame, python CJK classifier, `CONTEXT.md` domain-word grep, `.scratch/` audit
> Carve-out precedent: `.scratch/v0.30-batch3/code-review-2026-08-30-standards-axis-report.md` (Boss-verbatim-quote carve-out), `.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` (S-12 single-address carve-out)
> Spec: `.scratch/v0.30-zone-header-new-icon-fix/spec.md` (55 lines)
> Ticket: `.scratch/v0.30-zone-header-new-icon-fix/issues/01-zone-header-new-icon-renders.md` (27 lines)

## Verdict: CONDITIONAL PASS

`CONDITIONAL PASS` (= 1 hard violation cluster + 3 soft findings). The commit `c24c2f3a1` is shippable in terms of functionality: it implements the boss OOB scope (= 新建 icon renders in zone-header trailing slot), the fix is mechanically correct (= Menu → plain Button + intermediate `NewChoiceSheet`), the build is clean (= `swift build exit 0` per commit body), the new `NewChoiceSheet` public type is documented in `CONTEXT.md` line 116, and the spec + ticket are present in `.scratch/v0.30-zone-header-new-icon-fix/` (= Q5.6 post-hoc satisfied before this code-review). However, one HARD finding (H-1) and three soft findings (S-1, S-2, S-3) need cleanup before the v0.30 final cut:

1. **H-1 (highest priority, blocker for v0.30 ship)**: 9 in-scope comment lines + 8 in-scope commit-body lines contain CJK OUTSIDE the established `Boss <date> OOB '...'` quote-bracket carve-out. Per the precedent report `.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` S-12 + `.scratch/v0.30-batch3/code-review-2026-08-30-standards-axis-report.md` line 296-301, the AGENTS.md §5-6 English-only hard rule tolerates CJK ONLY inside the `Boss <date> OOB '...'` audit-marker bracket (= Boss verbatim quote carve-out). All other CJK in code-line comments and commit-body prose is a hard violation.
2. **S-1 (process)**: Q34 step 1 (grill-with-docs) was NOT executed. Self-acknowledged in `01-zone-header-new-icon-renders.md` line 20 ("1. grill | post-hoc (= boss sent OOB directly)"). Same pattern as the prior 3 standards reports; closing this gap requires human/boss action outside the code-review sub-agent's authority.
3. **S-2 (process)**: Commit subject line `fix(wenshu): v0.30 — zone header 新建 icon renders (= replace Menu with Button + sheet)` carries CJK (`新建`) outside the `Boss <date> OOB '...'` carve-out bracket. Per H-1 above; subject-line CJK is particularly visible (= every git log viewer surfaces it).
4. **S-3 (process)**: Q34 step 8 (Q22 真验证 = pixel screenshot + AX tree + 老板 OK) not yet executed. Spec.md line 50-55 "Boss verifications (= pending Q22 visual)" self-acknowledges. Requires APP launch + boss manual verify.

The remaining 8 rules pass cleanly: no 修真 tokens, no forbidden modals (12+1 Chinese modal list — see Rule 3), Q124 atomic-coupling trivially satisfied (= 1 file / 1 commit = no coupling concern), commit-message format `fix(wenshu):` PASS, single address to 老板 (= only `Boss <date> OOB` English audit markers used per established carve-out), 1-ticket-1-commit mapping PASS (= `01-zone-header-new-icon-renders.md` references commit `c24c2f3a1` line 4).

## Findings

### Finding H-1: CJK in commit-body + code-line comments OUTSIDE `Boss <date> OOB '...'` carve-out bracket

- **Commit**: c24c2f3a1
- **File**: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` (+ commit body)
- **Rule violated**: AGENTS.md §5-6 — English-only hard rule. "All commit messages, comments, prompts, `.scratch/spec.md`, `.scratch/issues/`, `.scratch/backlog` files, `CONTEXT.md`, `README.md`, `CLAUDE.md`, and every doc in this repo follow the same English-only rule." Carve-out precedent (`.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` line 235-237 + `.scratch/v0.30-batch3/code-review-2026-08-30-standards-axis-report.md` line 296-301): CJK is permitted ONLY inside `Boss <date> OOB '...'` quote-bracket form (verbatim boss quote audit marker). CJK in implementation prose is a hard violation.
- **Severity**: HARD. The prior H-1 cleanup commit `230af9a92 fix(wenshu): v0.30 — H-1 CJK-in-comments cleanup` (= 2026-08-30) cleaned residual CJK in code-line comments of this exact file (see `git blame L289-293` showing commit `c5ed76169f` for the data tuples — separate from this report's scope, those data tuples are user-visible data, not code-line comments). This commit `c24c2f3a1` re-introduces 9 code-line comment hits + 8 commit-body hits outside the carve-out bracket.

**Verbatim code excerpts (= in-scope lines added by c24c2f3a1):**

H-1.a — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:95`

```
    // intermediate sheet (= "新建书 / 新建书架" two-button choice) to
```

Line 94 carries the `Boss 8/31 OOB '...'` audit marker (= carve-out bracket); line 95 continues the comment prose and contains `新建书 / 新建书架` OUTSIDE the bracket. The CJK description should be moved INSIDE the bracket (= "Boss 8/31 OOB '... 新建书 / 新建书架 two-button choice ...'") or translated to English.

H-1.b — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:346-348`

```
        // to render the 新建 icon inside the ZoneContentTabBar trailing
        // slot (= only the 入驻 Button rendered). Replaced with a
        // simple Button pattern that mirrors the 入驻 Button =
```

Three consecutive code-line comments carrying CJK (`新建`, `入驻`) in implementation prose, NOT in a `Boss <date> OOB '...'` quote-bracket. The same observation that "only the 入驻 Button rendered" appears at line 14 of the commit body OUTSIDE the verbatim quote.

H-1.c — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:351`

```
            // 新建 plain Button (= tap opens the "新建书 / 新建书架"
```

CJK at comment-line start (`新建 plain Button`) — should be `New Button (= tap opens the ...)` or equivalent English term. The same pattern in the commit body subject + body lines L1, L19, L20, L21.

H-1.d — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:353`

```
            // "新建书" / "新建书架" two-button UI.
```

CJK in code-line comment, outside the carve-out bracket. The `Boss 8/31 OOB '... 新建书 / 新建书架 ...'` quote could absorb these terms.

H-1.e — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:364`

```
            // 入驻 plain Button (= tap directly fires .wenshuImportRequested
```

CJK in code-line comment (continuation of the pre-existing 入驻 plain Button comment block; this commit ADDED the `.help("入驻")` line below but the surrounding 3-line comment is the pre-existing context from prior commit bca226704). This specific line is inside the diff hunk per `git show` L341-389 — confirming it's in-scope.

H-1.f — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:566`

```
// Menu-based "新建书 / 新建书架" picker (= failed to render inside
```

CJK in the NewChoiceSheet section header comment, outside the `Boss <date> OOB '...'` quote bracket. Line 565 starts the bracket (`Boss 8/31 OOB '...'`); line 566 continues in implementation prose with CJK.

**Verbatim commit-body excerpts (= subject + body, OUTSIDE Boss quote bracket):**

H-1.g — `c24c2f3a1` commit body L1 (SUBJECT LINE)

```
fix(wenshu): v0.30 — zone header 新建 icon renders (= replace Menu with Button + sheet)
```

The commit subject contains `新建` (= "new") in implementation prose, NOT inside a `Boss <date> OOB '...'` quote bracket. Per `.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` S-12 + `.scratch/v0.30-batch3/code-review-2026-08-30-standards-axis-report.md` line 296-301, the audit-marker pattern uses `Boss` (English Latin word) + CJK verbatim quote. The subject line is implementation prose and should be English-only. Proposed rewrite: `fix(wenshu): v0.30 — zone header new-icon renders (= replace Menu with Button + sheet)`. Subject-line CJK is particularly visible because every `git log --oneline`, every PR list, and every code-review header surfaces it.

H-1.h — `c24c2f3a1` commit body L4, L10, L14, L15, L18, L19, L20, L21

```
    ICON 没有了'.
...
    新建 Menu was constructed with:
...
    ZoneContentTabBar trailing slot (= only the 入驻 plain Button
    survived rendering). The 新建 Menu was invisible to the user.
...
    that mirrors the 入驻 Button (= no nested Menu). Tapping the
    新建 icon opens an intermediate sheet ('新建书 / 新建书架'
    two-button choice picker) → tap '新建书' opens showNewBookSheet,
    tap '新建书架' opens showNewShelfSheet. Apple HIG canonical sheet
```

L4 is the trailing line of the verbatim Boss-quote (`'顶栏右边的新建 ICON 没有了'`) — that single-quoted chunk is carve-out. L10, L14, L15, L18, L19, L20, L21 are root-cause + fix prose containing CJK (`新建`, `入驻`, `新建书`, `新建书架`) OUTSIDE any verbatim-quote bracket. The fix prose should be English-only with the CJK terms replaced by code identifiers (`showNewBookSheet`, `showNewShelfSheet`, `zoneHeaderButtons`, etc.) or by English equivalents (e.g., `new`, `import`).

### Finding S-1: Q34 step 1 (grill-with-docs) NOT executed

- **File**: `.scratch/v0.30-zone-header-new-icon-fix/issues/01-zone-header-new-icon-renders.md:20`
- **Verbatim excerpt**:

```
| 1. grill | post-hoc (= boss sent OOB directly) |
```

- **Rule**: AGENTS.md Q34 8-step chain — `grill-with-docs → spec → tickets → implement → code-review → domain-modeling`. Step 1 = interview 老板 + lock spec.
- **Severity**: SOFT — self-acknowledged. Same gap as `.scratch/v0.30-batch3/spec.md` line 95-101 + `.scratch/v0.30-polish-fixes/spec.md` line 132-138. Boss sent OOB directly via `Boss 2026-08-31 OOB '顶栏右边的新建 ICON 没有了'`; cc-runner implemented without a structured grill-with-docs session. Closing this gap requires human/boss action outside the code-review sub-agent's authority.
- **Note**: this code-review (= this report) is the missing link in the chain. After this report lands, Q5.6 + Q34 step 5 are fully satisfied for Q34 progress (the spec.md + ticket exist post-hoc; the code-review report is the missing step 5).

### Finding S-2: Commit subject line CJK in implementation prose

- **File**: `c24c2f3a1` commit body L1 (subject)
- **Verbatim excerpt**: `fix(wenshu): v0.30 — zone header 新建 icon renders (= replace Menu with Button + sheet)`
- **Rule**: AGENTS.md §5-6 English-only hard rule. Per `.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` line 235-237, CJK in commit subjects = implementation prose, not a verbatim Boss quote (= NOT a carve-out candidate).
- **Severity**: SOFT (subsumed by H-1.g above; called out separately because subject-line CJK has outsized visibility in `git log --oneline` + PR lists). The H-1 cleanup commit must address the subject line in addition to the comment lines.

### Finding S-3: Q34 step 8 (Q22 真验证) NOT executed

- **File**: `.scratch/v0.30-zone-header-new-icon-fix/spec.md:50-55`
- **Verbatim excerpt**:

```
## Boss verifications (= pending Q22 visual)

- Boss manually opens APP after build
- Tap zone header 新建 icon → expect NewChoiceSheet appears
- Tap 新建书 / 新建书架 button → expect existing sheet opens
- Tap 入驻 icon → expect NSOpenPanel (= unchanged behavior)
```

- **Rule**: Q34 step 8 = Q22 真验证 = pixel screenshot + AX tree capture + 老板 OK flag.
- **Severity**: SOFT — self-acknowledged in spec.md line 50 + ticket line 26 ("8. Q22 真验证 | pending (= needs APP launch + boss manual verify)"). Requires APP launch + boss manual verify. Not a blocker for code-review; the dual-axis review (Standards + Spec) runs without it; the Q22 verification happens after code-review.

## Rule-by-rule compliance table

| # | Rule | Status | Evidence |
|---|---|---|---|
| 1 | AGENTS.md §5-6 English-only hard rule (code comments + commit messages + docs) | **FAIL (H-1)** | 9 code-line comments + 8 commit-body lines outside Boss-quote bracket. See H-1.a through H-1.h. Carve-out precedent at `.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` S-12 + `.scratch/v0.30-batch3/code-review-2026-08-30-standards-axis-report.md` line 296-301. UI-string carve-out (Text/Button/Label/Placeholder/Help) = PASS (15 user-facing strings: Text("资料库") L159, .help("新建") L363, .help("入驻") L377, Text("新建书") L494/L588, TextField("书名"/"作者") L501/L503, Button("取消"/"保存") L509/L511/L550/L552, Text("新建书架") L537/L599, TextField("书架名 (例如 长篇网文)") L544, Button("取消") L579, Text("新建") L577). Data-string carve-out (folder displayName tuples L289-293) = PASS — pre-existing from c5ed76169, out of c24c2f3a1 scope. |
| 2 | AGENTS.md 修真 12-token forbidden list (§8) | **PASS** | None of `修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障` in the diff. |
| 3 | AGENTS.md 12+1 English forbidden modals (可/应当/或许/可能/应该/建议/考虑/试图/尽量/大概/也许/或/任意/大概率/通常/一般来说) | **PASS** | None of the 16 forbidden modal tokens in the commit body. (Verified via Python grep against `git show c24c2f3a1` body.) |
| 4 | AGENTS.md Q5.6 partial commit 接管规范 (spec/ticket must exist in `.scratch/feature/`) | **PASS** | `.scratch/v0.30-zone-header-new-icon-fix/spec.md` (55 lines, mtime 2026-08-31 09:59) + `.scratch/v0.30-zone-header-new-icon-fix/issues/01-zone-header-new-icon-renders.md` (27 lines, mtime 2026-08-31 10:00) BOTH present BEFORE this code-review report. Post-hoc acceptable per rule; timing requirement met. |
| 5 | AGENTS.md Q34 8-step chain (grill → spec → tickets → implement → code-review → domain-modeling) | **CONDITIONAL PASS** | Steps 2-5 satisfied. Step 1 (grill) = post-hoc (S-1). Step 6 (hard violation cleanup) = pending (depends on H-1 fix). Step 7 (domain-modeling) = `NewChoiceSheet` IS added to `CONTEXT.md` line 116 (PASS — pre-emptive add). Step 8 (Q22 真验证) = pending (S-3). |
| 6 | Atomic-coupling rule (boss 8/22 = Q124): multi-file commits must justify coupling | **PASS (trivial)** | 1 file / 1 commit. No coupling concern. |
| 7 | Commit message format (`feat(wenshu):` / `fix(wenshu):` / `docs(wenshu):` / `refactor(wenshu):`) | **PASS** | Subject = `fix(wenshu): v0.30 — zone header 新建 icon renders (= replace Menu with Button + sheet)` — uses `fix(wenshu):` prefix correctly. |
| 8 | CONTEXT.md domain-word update (any new public type adds a domain word) | **PASS** | New public type `NewChoiceSheet` IS documented in `CONTEXT.md` line 116 with full description, Apple HIG citation, commit message, and version tag. Row text: `NewChoiceSheet (v0.30 zone-header 新建 picker) | SwiftUI sheet view presenting the "新建书 / 新建书架" two-button choice. ...`. |
| 9 | Single address to 老板 (every commit body, comment, doc uses 老板) | **PASS** | Per established carve-out precedent (`.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` S-12 PASS line 278-286), commit bodies use English `Boss <date> OOB '...'` audit marker (= NOT CJK `老板`). No non-standard honorific forms (= `老板您` / `老板大大` / `老大` / `兄弟` / `老板好`) found in the commit body or comments. |
| 10 | 1 ticket 1 commit (Q29) | **PASS** | 1 commit (c24c2f3a1) + 1 ticket (`01-zone-header-new-icon-renders.md`). Ticket line 4 `Fix commit: c24c2f3a1 (= implementation)` confirms the mapping. |
| 11 | Verbatim findings (exact file path + line number + verbatim code excerpt) | **PASS (this report)** | All findings H-1.a through H-1.h include exact file path + line number + verbatim code excerpt per the rule. |

## Per-commit summary table

| Commit | Subject | Files | Insertions / Deletions | Findings | Build | Q34 step | Standards verdict |
|---|---|---|---|---|---|---|---|
| c24c2f3a1 | fix(wenshu): v0.30 — zone header 新建 icon renders (= replace Menu with Button + sheet) | `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` | 78 + / 10 - | **H-1** (CJK in 9 comment lines + 8 commit-body lines outside Boss-quote bracket), S-1 (Q34 step 1 post-hoc), S-2 (subject-line CJK), S-3 (Q22 pending) | clean (= `swift build exit 0`) | 4/8 (= implement done; review + cleanup + Q22 pending) | **CONDITIONAL PASS** (H-1 cleanup required before v0.30 ship) |

## Q34 8-step chain compliance table

| Step | Description | Status | Evidence |
|---|---|---|---|
| 1 | grill-with-docs (interview 老板 + lock spec) | **post-hoc (S-1)** | Ticket line 20 self-acknowledges: "1. grill \| post-hoc (= boss sent OOB directly)". Boss sent OOB directly via `Boss 2026-08-31 OOB '顶栏右边的新建 ICON 没有了'`; cc-runner implemented without structured grill session. Same gap as `.scratch/v0.30-batch3/spec.md` line 95-101 + `.scratch/v0.30-polish-fixes/spec.md` line 132-138. |
| 2 | to-spec (write `.scratch/v0.30-zone-header-new-icon-fix/spec.md`) | **DONE** | spec.md = 55 lines, mtime 2026-08-31 09:59. Covers: problem (L6-10), root cause (L12-23), fix (= commit c24c2f3a1, L25-31), files modified (L33-39), acceptance criteria (L41-48), boss verifications (L50-55). |
| 3 | to-tickets (write `.scratch/v0.30-zone-header-new-icon-fix/issues/01-*.md`) | **DONE** | 01-zone-header-new-icon-renders.md = 27 lines, mtime 2026-08-31 10:00. Covers: 6 acceptance criteria (L9-14), Q34 progress table (L18-27) mapping 8 steps. |
| 4 | implement (commit c24c2f3a1) | **DONE** | 1 file changed, 78 + / 10 -, build clean. |
| 5 | 双轴 code-review (Standards + Spec) | **IN PROGRESS** | This report = Standards axis. Spec-axis report pending (separate sub-agent). After both reports land, Q34 step 5 closes. |
| 6 | hard violation 修法 (cleanup commit for H-1) | **PENDING** | H-1 (CJK cleanup) is the blocker. After H-1 cleanup commit lands, step 6 closes. |
| 7 | domain-modeling (CONTEXT.md row for NewChoiceSheet) | **DONE (pre-emptive)** | NewChoiceSheet IS documented in `CONTEXT.md` line 116 (pre-emptive add per Q34 step 7). The row was added before this code-review; PASS. |
| 8 | Q22 真验证 (pixel + AX tree + 老板 OK) | **PENDING (S-3)** | spec.md line 50-55 self-acknowledges. Requires APP launch + boss manual verify. Out of code-review sub-agent's authority. |

## Summary

The commit `c24c2f3a1 fix(wenshu): v0.30 — zone header 新建 icon renders` is functionally correct: it replaces the failing `Menu(.borderlessButton)` + `.menuIndicator(.hidden)` pattern with a canonical `Button + .sheet` pair, introduces a public `NewChoiceSheet` view (= the intermediate "新建书 / 新建书架" two-button picker), and is documented in `CONTEXT.md` line 116 (= Q34 step 7 satisfied). Spec + ticket exist in `.scratch/v0.30-zone-header-new-icon-fix/` BEFORE this code-review (= Q5.6 post-hoc satisfied), the Q124 atomic-coupling rule is trivially satisfied (= 1 file), no 修真 tokens appear, no forbidden modals appear, the `fix(wenshu):` commit prefix is correct, and the 1-ticket-1-commit mapping is clean. The single blocker is H-1: 9 code-line comments + 8 commit-body lines (including the SUBJECT line) carry CJK outside the established `Boss <date> OOB '...'` quote-bracket carve-out, violating AGENTS.md §5-6 English-only hard rule per the project precedent set by `.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` S-12. The Q34 chain has 3 soft gaps (S-1: grill post-hoc, S-3: Q22 pending, plus the S-2 subject-line CJK which is subsumed by H-1). Cleanup path: one H-1 cleanup commit that (a) translates the 9 in-scope code-line comments to English, (b) rewrites the commit subject line to `fix(wenshu): v0.30 — zone header new-icon renders (= replace Menu with Button + sheet)`, and (c) replaces the implementation-prose CJK in the commit body with code identifiers (= `showNewBookSheet`, `showNewShelfSheet`, etc.) — all within the `.scratch/v0.30-zone-header-new-icon-fix/` ticket scope. After that cleanup commit + the parallel Spec-axis report + boss Q22 visual verify, the Q34 8-step chain fully closes for this ticket. Verdict: **CONDITIONAL PASS**.
