# Ticket A1 — Apple self-check report (the only ticket this session)

- Parent spec: `.scratch/2026-09-04-apple-methodology/spec.md`
- Branch: `wt/apple-001/structure-audit`
- Worktree: `.worktrees/apple-001-structure-audit`
- Cadence: BOSS-APPROVAL SEQUENTIAL (= boss 拍 A1 完才考虑 A2..A11)
- Apple-API-first gate: every verdict in the report must cite Apple tier-1 / tier-2 / tier-3 evidence OR be marked "wenshu-project decision"

## Why this is the only ticket today

Boss OOB-7 = "写工作树, 但先别动手改代码". Boss OOB-4 = "多个会话都在改代码, 你先不动".

Other sessions in flight (= worktree list shows):

- `wt/editor-001` modifies `Package.swift` + `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` + new `Sources/WenshuApp/Editor/` + new `Tests/WenshuAppTests/Editor/`. Touches the very files my audit ticket 002 + 003 would touch.
- `wt/frontend-integration` (= branch still alive, may also have dirty state).
- `wt/multi-agent-dispatch` (= stale branch, but a third candidate).

So any ticket that writes wenshu source code today = merge conflict risk tomorrow. Boss拍 "先贵进" (= "first expensive step" = take the expensive evidence-gathering step first) means:

- today: spend the budget on EVIDENCE (= grep, traces, dead-code verification, Apple-doc quotes)
- not today: spend the budget on CHANGES (= file moves, deletions, renames)

That isolates the high-value work from the merge-conflict work, and gives boss a 1-file artifact (= the self-check report) to decide whether A2..A11 ever need to land.

## Acceptance criteria (= DONE means ALL of these)

- [ ] `Scripts/apple-self-check.sh` exists, runs end-to-end on a fresh shell (= reproducible)
- [ ] `.scratch/2026-09-04-apple-methodology/apple-self-check.md` exists (= the report)
- [ ] Report has 12 rows, one per third-party item (A / B / C1 / C2 / C3 / D1 / D2 / D3 / D4 / E / F / G / H / I — note: 14 letters because A..I = 9 + duplicates F = C1)
- [ ] Each row includes: tier-1 / tier-2 / tier-3 evidence OR "wenshu-project decision" + verdict + grep-result reference
- [ ] D1 / D2 / D3 / D4 rows PASS the 5-stage dead-code grep (= self-def / caller / wiring / stale-test / substring) with output captured
- [ ] C2 row traces the SoT between `WenshuLibrary` and `BookStore` with caller grep
- [ ] NO files written under `Sources/WenshuApp/`, `Tests/WenshuAppTests/`, `Package.swift`, `AGENTS.md`, `Sources/WenshuApp/UI/ComponentIndex.md`
- [ ] report first line + last line = fact (English-only)

## Steps (= the implement step of PO v1.1)

### Step 1: write `Scripts/apple-self-check.sh` (the reproducible evidence tool)

Lives at the repo root. Parameters = none. Runs all 12-item greps end-to-end. Output goes to `grep-evidence/<item>.txt`. Captures dates. Idempotent.

5-stage dead-code grep recipe (Apple-API-first skill "Dead-code grep protocol"):

```
stage 1 — self-definition grep
stage 2 — caller grep with comment/doc exclude
stage 3 — wiring-chain grep (App.swift / WorkspaceView / TabContentDispatcher / PaneRenderer / RegisteredPanes)
stage 4 — stale-test grep (Tests/ dir)
stage 5 — substring grep (basename of file)
```

SoT trace recipe (= trace "which file is the source of truth"):

```
grep -rn 'shelves: \[' Sources/WenshuApp/State/WenshuLibrary.swift Sources/WenshuApp/State/BookStore.swift
grep -rn 'WenshuLibrary\|BookStore' Sources/WenshuApp/App.swift
grep -rn 'WenshuLibrary\|BookStore' Sources/WenshuApp/Views/
grep -rn 'WenshuLibrary\|BookStore' Tests/
```

### Step 2: run the script (= generate evidence + report consumes it)

```bash
cd /Volumes/ANAN/Engineering/wenshu/.worktrees/apple-001-structure-audit
bash Scripts/apple-self-check.sh
ls .scratch/2026-09-04-apple-methodology/grep-evidence/
```

Expected output = 1 file per item + 1 SoT trace file. Each file is small (1-30 lines of grep output).

### Step 3: write `.scratch/2026-09-04-apple-methodology/apple-self-check.md` (= the report)

Report shape:

```markdown
# Apple self-check (wenshu v0.40 / 2026-09-04)

Boss OOB: 老板指令"按你的建议, 先贵进" = evidence first (= today), changes later (= A2..A11 upon boss拍).
Spec: `.scratch/2026-09-04-apple-methodology/spec.md` §3.

For each of 12 third-party items + duplicate (= 13 letters A..H + F = C1 / I self-acknowledge):

| # | Item | Tier-1 evidence | Tier-2 evidence | Tier-3 evidence | Grep result | Verdict | Ticket |
| A | App.swift 1955 lines | developer.apple.com/.../managing-model-data-in-your-app: "@State" + ".environment" pattern | AVCam App.swift <50 LOC | suffix scan App=43.2%, all extracted | n/a (structural only) | REPORT STANDS | A2 (next session, blocks on editor-001 + frontend-integration merge) |
| ... |
```

The grep-result column for D-rows MUST show "5-stage grep confirmed 0 callers / X callers". The C2-row MUST show "SoT trace result: WenshuLibrary is facade, BookStore is SoT (or vice versa)".

Final row MUST be the answers-for-boss summary:

```markdown
## Summary for boss拍 (= one-question decisions, NOT multi-question)

1. Adopt `Scripts/apple-self-check.sh` as a recurring audit tool? (recommend: yes, save 30 min per audit)
2. Approve moving A2 (= App.swift extraction) to next session? (recommend: yes, low risk)
3. Approve moving A3 (= WorkspaceView extraction) AFTER editor-001 + frontend-integration merge? (recommend: yes, no merge conflict)
4. ... (= one row per ticket A2..A11)
```

### Step 4: append to spec.md §3 (= refresh the 12-row verdict table with grep results)

The spec's existing §3 row per item becomes the source; the apple-self-check.md report is the artifact. spec.md §3 grows one column "grep-evidence-path" per row.

## Out of this ticket's scope

- ANY code edit to `Sources/WenshuApp/`, `Tests/WenshuAppTests/`, `Package.swift`, `AGENTS.md`, `UI/ComponentIndex.md` (= boss OOB-7)
- Tickets A2..A11 (= boss拍 this ticket first; we don't pre-author)
- Touching `wt/editor-001` or `wt/frontend-integration` (= those branches are someone else's)
- Migration of any data, deletion of any file, rename of any file in the wenshu source tree

## PO v1.1 step 4 = implement (= this ticket ships a SCRIPT, not a refactor)

The script is .sh, ~50 lines, idempotent, no third-party deps. Lives under `Scripts/` (= wenshu repo convention). Reuses the existing pollution-defense shell style (= `set -e`, `set -u`, `set -o pipefail` at the top).

## PO v1.1 step 5 = code-review (= two axes)

- **Standards axis**: `Scripts/apple-self-check.sh` must follow `Tools/wenshu-devtool/` convention (sh style, `set -eu`, no `eval`, no unquoted vars). Grep report must respect AGENTS.md "first/last line = fact, English-only" + wenshu-pollution-defense hook (= no forbidden tokens in report).
- **Spec axis**: each row in the report must match spec.md §3 verdict (= no drift between the spec and the report). Test = `diff <(grep verdict apple-self-check.md) <(grep verdict spec.md §3)` should be empty.

## Verification (= before declaring this ticket done)

- [ ] `bash Scripts/apple-self-check.sh` exits 0 from a fresh shell (= reproducible)
- [ ] `cat .scratch/2026-09-04-apple-methodology/apple-self-check.md` exists, has ≥ 1 line per row, English-only
- [ ] `git diff main -- Scripts/ AGENTS.md AGENTS.md Sources/ Tests/` (= empty diff for everything except `Scripts/apple-self-check.sh` and `.scratch/2026-09-04-apple-methodology/`)
- [ ] Poll: `python3 Tools/wenshu-devtool/pollution_watchdog.py` exits 0 (= no forbidden tokens in report)
- [ ] `swift build` still exits 0 (= no wenshu source touched)

## Status

- Open, awaiting implement (= step 4 of PO v1.1 chain)
