# The registry's own checks, and the gate that could not fail

Date: 2026-10-24
Cards: `t_ae2cb2c0` (merged as `fa4698fe6b`), `t_2609796b` (merged as
`45296c3837`), `t_6ffa9043` (merged as `5abe0d0d25`)

## 1. What was wrong

Two of the repository's own gates reported a healthy tree as broken, and
one of them reported a broken tree as clean.

**The registry's append marker was gone.** `docs/agents/nfi.md` used to
end with an HTML comment naming where new rows go. Commit `124dad8d9e`
removed it as collateral while fixing the cover route. The registry's own
test suite inserts its fixture rows AT that marker, so every `addrow`
raised `ValueError: substring not found`, both fixture branches committed
nothing, and the merge under test had zero new rows. Two failures, for a
registry that was fine.

**The split check compared whole rows.** `nfi-split.py --check` tested each
historical row against the registry with a plain substring comparison. The
registry's LOC column is a FACTUAL COUNT that rule 1.7 expects to be
refreshed when a file changes, so two rows whose LOC had moved (521 → 520,
514 → 541) were reported as "row missing from the registry". Every
historical row was present: measured by the merge driver's own key rule,
30 historical rows against 122 registry rows, 0 keys missing.

**The dead-code gate could not fail.** `verify-dead.py --ui-components`
with no file arguments looked for `Sources/WenshuApp/UI` and
`Sources/WenshuApp/Views`. Neither exists: the views live in ten
`Features/*/View` directories plus `Shared/UI`. So it scanned nothing and
printed "Summary: 0 files" and "none found = the NSA framework component
catalog is clean", and exited 0. A reader who ran the documented command
got a PASS over an empty sweep. And when the tool was pointed at files by
hand, its candidate rule (a type whose NAME appears in no other file)
flagged seven LIVE types: a type reached through a member read or through
a return type reads as unreachable to a name match.

## 2. What was built

| Card | Change |
| ---- | ------ |
| `t_ae2cb2c0` | The append marker is back at the end of `docs/agents/nfi.md`. `nfi-split.py --check` compares by KEY (the merge driver's own `key_of` = the extracted file = the second column), so a refreshed LOC is a maintenance update and a missing row is a missing key. The two drifted LOC values were refreshed. |
| `t_2609796b` | `Scripts/merge-nfi-registry.py` keeps the file's TAIL: it comes from whichever side has one, and two sides with different tails are a CONFLICT (= the driver exits non-zero), not a silent pick. Four new cases in the registry suite, including a real `git merge` that keeps the tail on disk. |
| `t_6ffa9043` | `verify-dead.py` scans the real view tree (the ten `Features/*/View` directories plus `Shared/UI` = 103 files) and names the directories it scanned. Its candidate rule is reachability, not a name match: a type is alive when another file reads one of its members or receives it from a called function. A new suite (`tests/test_verify_dead.py`) covers all of it on fixtures. `README.md` documents the gate for the first time. |

## 3. The finding that made a third card necessary

Card `t_ae2cb2c0`'s gate was green on its own branch (10/10, split check
exit 0). Rebasing it onto `main` DROPPED the marker, and both gates went
red again. The rebase reported success: the loss was silent.

The cause was the repository's own merge driver. `.gitattributes` wires
`docs/agents/nfi.md` to `merge=nfi-registry`, and `merge_docs` took
everything after the last table row (= the marker) from `ours` alone. In a
rebase `ours` is the branch being rebased ONTO (= `main`, whose tail was
empty), so the card's tail was discarded.

So the card's own "MUST NOT CHANGE" premise ("the merge driver is correct
and other cards depend on them") was false, and the card could not land.
That premise is why the fix went into a separate card (`t_2609796b`) with
its own commit, instead of a quiet edit to a file the card had declared
off limits.

**The rule this leaves behind: a gate that passes on a card's branch is
not proof the card can land. Rebase, then re-run the gate on the
rebased branch, and only then fast-forward `main`.**

## 4. Verification (all run on `main`, all exit 0)

```
python3 Tools/wenshu-devtool/tests/test_verify_dead.py     → 5 passed, 0 failed
bash    Tools/wenshu-devtool/tests/test_nfi_registry.sh     → nfi registry: all tests passed
python3 Tools/wenshu-devtool/tests/test_probe_index.py      → 5 passed, 0 failed
python3 Tools/wenshu-devtool/nfi-split.py --check           → 30 rows verified by key
python3 Tools/wenshu-devtool/verify-dead.py --ui-components → 103 files, 10 dirs,
                                                              ALIVE 99 / PARTIAL 4 / DEAD 0
```

Both directions of the dead-code gate were proved:

- The seven live types (`WordCount`, `WikiLinkNavigationResult`,
  `EditorPersistenceReloadResult`, `OpenCardResult`,
  `InspectorStatusSelection`, `InspectorStatusScope`,
  `InspectorStatusStateStyle`) appear nowhere in the scan's output.
- A type with no reader anywhere IS still reported, with a non-zero exit
  code.

## 5. Not done, on purpose

- The old editor header chain was already gone from `main` before these
  cards started (removed by `413b46d3be`). There was nothing left to
  clean, so no card was raised for it.
- The seven live types were NOT deleted. The tool's report was wrong
  about them; the types are reachable and the tool now agrees.
