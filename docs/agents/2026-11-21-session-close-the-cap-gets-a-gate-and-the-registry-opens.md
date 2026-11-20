# Session close 2026-11-21: the 600-LOC cap gets a gate that can fail, and the registry rows open again

Two scopes, landed in two commits, no review card (the boss waived the review for this
session on 2026-11-21). Everything below is a number re-taken in this tree, not remembered.

## 1. What was asked

"Is recent work splitting files the way the rule says?" The rule is AGENTS.md 6.6: every
`.swift` file carries a 600-LOC ceiling, `Vendor/` exempt.

## 2. The answer, in the order the evidence arrived

1. **At HEAD the production tree is inside the cap.** `Sources/` holds 585 measured `.swift`
   files, 0 over 600, the largest 565. The 9 production god-classes ADR-0025 deferred are all
   split, which is why the `DEFERRED` flag on row 6.6 was describing a condition that no longer
   holds.
2. **"At HEAD" was not a sufficient answer.** Measured per commit over the 288 commits since
   2026-11-13: `Sources/WenshuApp/Features/Editor/View/EditorView.swift` sat at 610 for **149**
   of them (11-13 to 11-18) and came back inside only at `31b5c3929a` (11-19), and
   `Sources/WenshuApp/Shared/UI/LabelSegmentedControl.swift` reached 670 across **102** commits
   and came back inside only at `124ce32757` (11-19). Six days of feature work shipped while two
   production files were over the cap, and nothing said so.
3. **The blind spot was the test tree, and it is big.** 623 files under `Tests/`, median 144
   lines, p90 340, so the tree is healthy in general; 9 files are not, at this tip:
   1372 / 1087 / 944 / 878 / 752 / 673 / 620 / 603 under `Tests/`, plus
   `Tools/wenshu-devtool/probes/inspector_card_load_cost.swift` at 635. The two largest
   additions were made inside this window: `31b5c3929a` added 1092 lines of tests, and
   `9776b4dc7c` added the 635-line probe.
4. **Why nothing caught any of it.** `AGENTS.md` 6.6 says "every `.swift` file";
   `inventory-measure.py` measures only `Sources/` (it excludes `/Tests/` and `/Vendor/`);
   `nfi-loc-check.py` never mentions 600, it only asks whether a registry cell equals a file's
   count; and `.github/workflows/ci.yml` had no step that compares a file against the ceiling.
   A strict rule, a ruler that looks somewhere else, and no gate: the gap is structural, not
   an accident of one commit.

## 3. The ruling that closed the scope question

Asked directly: do test files owe the cap? The boss ruled **yes, and the split criterion is
the concern a reader would look for, not a line count** (2026-11-21). The reason is the one the
rule already gives itself: a file should be readable in one review pass, and a reader should
find the right file in five seconds. A 1087-line test file holding 29 `@Test` cases under 3
`// MARK` comments fails both. That rules out `Part1` / `Part2` slicing, which names no seam
and leaves the reader worse off than the big file did.

## 4. What landed

`e86e0e06f9` (one commit, 6 files, +491/-4):

- `Tools/wenshu-devtool/ci_change_gate.py` gains a fourth check, `--check loc-cap`. It is a
  **ratchet, not a state check**: a change that shrinks an over-cap file lands, a change that
  grows one or leaves it there is charged, and a path with no blob at HEAD is reported as
  UNMEASURABLE and exits 1 rather than counting as clean. `Vendor/` is the only exemption,
  which `changed_paths` already implements, so the exemption is not special-cased.
- `.github/workflows/ci.yml` runs it as a step named "File-size cap gate", and
  `pre_review_gate.py` runs it before a card goes to review, so it fires on the change instead
  of on the historian.
- `AGENTS.md` row 6.6 loses `DEFERRED (ADR-0025)`, names `Vendor/` as the only exemption, states
  the split-by-concern criterion, and points at the gate.
- `Tools/wenshu-devtool/tests/measure_loc_cap_window.py` is the instrument behind the numbers,
  so the docstring does not have to be trusted. Over the last 300 commits: 81 touched a `.swift`
  file, **17 red, 61 green, 3 excused because they were shrinking** (`124ce32757`, `9639ff9d60`,
  `de3f287f4d`). A state check would have been red on **20**, which is the same 17 plus the three
  commits whose whole subject was fixing the files. That difference is why the gate is a ratchet.
- 7 new cases take `test_ci_change_gate.py` from 19 to 26; all 26 pass.
- The acceptance test the boss set was "a 601-line file must go red". Proven end to end on this
  tree, not by a unit test alone: a throwaway worktree at `main`, a new 601-line `.swift` file,
  and the exact command line CI runs printed `1 changed Swift file(s) over the 600-LOC cap` and
  exited 1.

`c4f3359d7c` (one commit, `docs/agents/nfi.md`): two rows deleted, two appended. The deleted
pair named files that no longer exist and were each already superseded by a row the registry
carries (`410bbeb651` moved `AgentScope.swift` to `Sources/WenshuData/...`, and `4d3bceed8d`
replaced `InspectorStylePresetView.swift` with `InspectorStylePresetPicker.swift`, registered at
row 644). The appended pair covers two files that had no row at all:
`Sources/WenshuApp/Shared/UI/PaneTabStripTitle.swift` (267) and
`Tests/WenshuAppTests/Shared/UI/TabPickerBandGeometryTests.swift` (392), added at the END of the
table per 1.11, with `wc -l` taken at the registering commit.

Deliberately NOT touched: row 554 keeps `ChatPinnedHeaderBandTests.swift` with the tag that
already says `DELETED 2026-11-17`, because a tombstone is only read when a change adds or
rewrites it, and removing it would erase the only note of where that band test went. The 33
`...` shorthand rows stay: nfi.md's own entry rule (189-193) calls that shape an approved
directory roll-up whose number is a sum, and the gate prints it before `not a path` precisely so
an author is not told to repoint a row the rule allows.

## 5. What is knowingly left open

1. **The 9 over-cap files are a backlog, not a clean tree.** The gate will now red any card that
   grows them. The cheapest first, ranked by how many seams their `// MARK` comments already
   name: `WenshuMarkdownEditorAdapterTests.swift` (1372, 20 marks),
   `EditorChatNSControllerTests.swift` (944, 11 marks), then `PaneTabStripCloseTests.swift`
   (1087, 3 marks, the most active line and the hardest split).
2. **No independent verdict on either commit.** `Scripts/merge-preflight.sh` answers exit 3 (the
   verdict owed) for this branch by design; the waiver is recorded in `e86e0e06f9`'s own message
   rather than left silent.
3. `inventory-measure.py` still measures only `Sources/`. The gate is now honest about the whole
   tree, so the census script's narrower scope is a documentation question, not a safety one.

## 6. Measurement traps hit while doing this, so the next reader does not pay them twice

- `git grep -c "" <rev>` matches NOTHING: the empty pattern must be `-e ''`. The wrong form
  reported "0 production files over 600 in the window" as a clean result, which is how a false
  negative gets published as a finding.
- `nfi-loc-check.py --base <sha>` is per-change. Run with a week-old base it compares rows
  written days ago against files that grew since, and reports 11 "mismatches" that the
  registry's own convention calls correct; the checked set is what ONE change added or rewrote.
- A row's LOC cell is only evidence after it has been opened: the gate prints an unopenable row
  as unmeasurable and fails, and a change that merely rewrites a cell without adding a row can
  leave the whole check vacuous.
- `cmd | tail -1; echo $?` reads `tail`, not `cmd`. This session published a wrong exit code from
  that mistake and corrected it by redirecting to a file first.

## 7. Stop rule

This document does not grow a further section to record its own landing. The commits named above
are the record; the board carries no card for this session because the review was waived.
