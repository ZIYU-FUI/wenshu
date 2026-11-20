# Session closeout: the style table drops two roles, and Custom becomes a place a book can sit

## 1. The scope

The editor's right-hand inspector: its format-preset panel and its
current-book-style table (the boss's own wording for both sits in `OOB.md
#2026-11-19`). Five lines the boss gave, and what each one turned into:

- the preset switcher must not be a trap: a book can be on Custom from the first
  moment, Custom starts by reusing the general set, and the user then fine-tunes;
- the existing behaviour that any fine-tune moves the book onto Custom stays,
  under both the print set and the general set;
- the two rows he boxed in red (the picture row and the rule row) are dead weight:
  delete them;
- show him the result;
- and one visual question about the body row sitting between its two dashed rules,
  which is still his eye's to settle (§5).

Delivered as a seventeen-commit stack landed on `main` at `b48942d29f`, from
`f697a2ced0`.

## 2. The trace table (= one row per line the boss gave)

| # | The line, in his words (= rendered) | The commit that carries it | The independent verdict | Server proof |
|---|---|---|---|---|
| L1 | "Adjust how Custom is entered (= the current way reads as a bug): it must be switchable into from the start, begin by reusing the general set, and then the user fine-tunes by hand" | `b4b4280f76` (= `fix(inspector): Custom is entered, not earned`), on top of `4d3bceed8d` which replaced the hand-rolled switcher with Apple's own controls | `t_7c12b4c5` approved the behaviour at `d05242f281`; the stack was rebased four times since, and every later claim was re-measured at the new tip (`t_d4552e4c`, then `t_d00f50ad` approved) | both remotes ANSWERED `b48942d29f…` for `refs/heads/main` at the landing (`git ls-remote`, not a local ref); they now carry this doc's commit on top (§7) |
| L2 | "And keep the existing rule: change a fine-tune under either print or general and the book moves onto Custom" | same commit; pinned by `InspectorStylePresetPickerTests` (the picker suite) and `BookStyleSheetWriteBackTests` | the picker suite ran green at every tip; `t_d4552e4c` re-ran the filtered block at `4241b259fa` | ditto |
| L3 | "The two boxed in red are useless (= delete them)" | `20afb54373` (= `feat(inspector): the style table drops the picture and the rule`), then `df196df334` for the files that still counted eleven, then `b48942d29f` for the registry rows the stack left lying | `t_d4552e4c` P1-P3 at `4241b259fa`: nine cases, nine rows, nine catalog keys, zero hits for the deleted roles, and the mutation measured both ways (= re-adding the two cases reddens `InspectorStylePageRenderTests.swift:58`, `:62`, `:70` and `InspectorStylePreviewVoiceTests.swift:115`; withholding the catalog keys adds `:447`); its F1 (the registry) was closed and re-approved by `t_d00f50ad` | ditto |
| L4 | "Give me a screenshot, I want to see the final effect" | no commit (= an observation, not an edit) | n/a | `look9_preset.png`, 2904×1952, the app's own window at 2x, captured by the app's own screenshot hook against an isolated clone (§4) |
| L5 | "It looks as though the body should sit vertically centred between its two dashed rules" | `35810deeb0` centres the row and its role name (`InspectorStyleRowView.swift:122`; the dashes are drawn between rows at `:209-213`) | UNRESOLVED — no test measures the ink, and the boss's eye is the acceptance (§5) | — |

## 3. The gates, on the tree this doc names (= `b48942d29f`, which is `main`)

Every number below was read out of a log file, not out of a pipeline's status.

| command | answer |
|---|---|
| `python3 Tools/wenshu-devtool/ci_change_gate.py --base f697a2ced0 --check formatting` | exit 0 (= `the change adds no unformatted line (27 changed Swift file(s) checked)`) |
| `… --check pollution` | exit 0 (= `the change adds no forbidden vocabulary`) |
| `… --check markdown-newline` | exit 0 (= 2 changed `.md` files) |
| `python3 Tools/wenshu-devtool/nfi-loc-check.py --base f697a2ced0` | exit 0 (= `every rewritten file's row carries its own count (11 row(s) checked)`) |
| the eleven inspector / style / tab suites, filtered | `Test run with 45 tests in 8 suites passed`, `Executed 25 tests, with 0 failures`, exit 0 |
| the whole suite (= `swift test --skip CSSearchableIndexSearchTests`) | `Test run with 3830 tests in 587 suites failed after 212.882 seconds with 19 issues`; the XCTest side `Executed 12 tests, with 1 test skipped and 0 failures` |
| CJK on added Swift lines | **0** codepoints in the 2,992 added lines (= counted by codepoint on the `+` side only) |
| the role set | 9 enum cases; 9 `row(` calls, counted with `grep -cE '^ *row\('` — a bare `grep -c 'row('` answers 10 because the local `func row(` declaration at `InspectorStylePageView.swift:343` is caught by it too; 9 `inspector.style.role.` catalog keys; 0 hits for either deleted role anywhere in `Sources/` or `Tests/` |

**The 19 issues are not this stack's.** The suites that produce them were run as a
filter, once at `f697a2ced0` (the `main` this stack landed on top of) and once at
`b48942d29f`, in the same scratch tree and one after the other:

```
swift test --scratch-path .build/out --skip CSSearchableIndexSearchTests \
  --filter 'EditorTabStripOverflowTests|EditorPersistenceTests|SidebarTreeReloadTests|PaneTabStripTitleTests|EditorTabTitleTests|ChatViewHistoryShortcutTests|AsyncDelegationRegistryTests'
```

Both answers are `Test run with 59 tests in 7 suites failed … with 17 issues`, and
the failing-test NAME sets are identical (= `comm` both ways prints nothing; 9 names,
eleven of the issues from the editor tab strip's geometry suite, which the tab-strip
lane owns). `EditorPersistenceTests`' two three-second-timer cases are the only items
that differ between the two FULL runs, and they are load-sensitive rather than
stack-caused: green in the filtered run at either tip, red when the whole 3,830-test
run is loaded, on both trees.

One caveat so the comparison can be re-run honestly: the full run's aggregate line is
missing from one of the two logs (that target's per-test failures are all present),
so the axis of the comparison is failing-test names and the filtered re-run, not the
total count in a `Test run with …` line.

## 4. The boss's own look

The panel is not a Settings window (there is no preset window): it is the editor
window's right-hand inspector, the third title-bar icon, hosted by
`InspectorView.swift`. The capture came from an isolated clone of the debug bundle
with its own identifier and a clone of the preferences, launched by its own
executable with `WS_SCREENSHOT=1 WS_SCREENSHOT_PATH=… WS_SCREENSHOT_DELAY=60
WS_SCREENSHOT_EXIT=1`, driven by real pointer events at the tab, so the boss's own
running instance was never touched. What the picture settles: nine rows, the two
boxed rows gone, the print set selected, and the five knobs reading their middle
values (= body size medium, leading standard, first-line indent two characters,
paragraph spacing none, body face Song). What it does not settle: L1's trigger rules and the write-back
(suites, not pixels) and L5's optical centring (pixels, and his eye).

## 5. The open items

1. **L5, the centring question.** `35810deeb0` centred the row; the boss then said
   the body should sit centred between its two dashed rules. The sample block
   carries the book's own leading, and `InspectorStyleRowView.swift` adds that
   leading BETWEEN the sample's two lines (`.lineSpacing(extraLeading)`), so the
   block's optical centre sits below the row's box centre even when the box is
   centred. The candidate fix is symmetric top and bottom padding per row, leaving
   the dashes alone. Not started, unowned: it needs one card and his eye on a
   re-capture.
2. **`t_398b07cd`** still owes its Part B: the registry gate cannot see a row whose
   file is absent (`nfi-loc-check.py:119-121`, `if actual is None: continue`), which
   is exactly how F1 survived to a review round. The sweep that found it is itself
   blind the same way (its column-1 guard drops any row whose cell carries the
   `(now N LOC, under cap)` suffix), so the fix has to widen both readers.
3. **`t_247eff53` / `be6504688f`** (= the `split_pre_check.py` §6 row gate) are
   approved and still unlanded; they ride their own branch, and `main` has moved
   under them since the approval.
4. **`t_c6d23305`** (= name the reviewed sha from any heading) is unlanded, and the
   defect it fixes was hit inside this closeout, before the rebase:
   `merge-preflight.sh` called an approved style-branch tip UNREVIEWED because the sha
   sat outside `## WHAT TO BUILD`. This landing avoided it only because both review
   cards happened to keep their sha in that one heading. Its dispatcher run also timed
   out (`elapsed 1550s > limit 1500s`) and the card is back in `ready`.

## 6. The commits this session pushed that are NOT this session's

None, and the check is a command, not a recollection:

```
git log --format="%h authored=%ad committed=%cd %s" --date=iso f697a2ced0..b48942d29f
```

Seventeen commits, one author, all of them this lane's inspector work (= the format
page, Custom's entry, the two dropped roles, the registry cells, the rebase). The
rebase's committer stamp sits at `2026-11-20 07:35:24` on all sixteen rebased ones and
the seventeenth is the F1 docs fix; an unrelated ride would show an author date outside
this session's window or a subject in another lane's vocabulary, and none does.

## 7. The next session's starting point

- `main` carries the stack tip `b48942d29f`, and this doc's own commits on top of
  it. Where `main` stands is asked of the servers, never of a local ref:
  `git ls-remote origin main` and `git ls-remote old-origin main`. (§2's server
  column is a measurement taken at the landing, not a standing fact.)
- The inspector's style page is `Sources/WenshuApp/Features/Editor/View/`
  `InspectorStylePageView.swift` (533 lines, under the 600 cap), its rows
  `InspectorStyleRowView.swift`, its knob `InspectorStyleKnobView.swift`, its model
  `InspectorStylePreview.swift` (243), the switcher `InspectorStylePresetPicker.swift`
  (147).
- Nine roles, and the set is exhaustive-by-construction: `InspectorStylePreview.resolve`
  switches over the enum, so an added case that is not answered breaks the build.
  Nothing was taken away from the document's rendering — images, rules and captions
  still draw; only the style table stopped offering them as roles.
- If a later change deletes a file, it must sweep `docs/agents/nfi.md` for rows that
  name it and for prose counts it invalidated. The LOC gate will not do it.

## 8. This round's own corrections

Three claims this session made and had to take back, each measured, recorded here so
the next reader does not repeat them:

1. **"the raw `grep -c` over the Han range returns 12, therefore the count is a
   byte-wise locale artifact" — wrong.** The same `grep` under `LC_ALL=en_US.UTF-8` prints the same 12. The twelve
   lines are `-` lines: the change DELETES an old Chinese comment block, and `grep`
   was handed the whole diff, not the added side. The written lesson in
   `wenshu-parallel-dev/references/the-ten-merge-blocking-gates.md` was corrected the
   same session. Lesson: an explanation invented for a number is itself a claim, and
   the next reader tests the number, not the reason.
2. **"the sweep reads 17 dead column-1 rows at tip against 18 at base" — does not
   reproduce.** Run with the registry and the filesystem of the same tree it reads 6
   and 6; the claimed −1 was impossible for a commit that removed two rows whose dead
   names sat in column 2. Column 2 (= the axis that mattered) carried exactly as
   published: 2 at tip, 3 at parent.
3. **"the filter covers 10 suites" — it reports 8.** Two of the ten names are
   XCTest-only or fold into another suite. `45 tests in 8 suites` plus
   `Executed 25 tests` on the XCTest side is the honest line, and round 1's reviewer
   is the one who caught it.

And one process fact worth keeping: the reviewer worked in a detached worktree at the
exact sha in both rounds, asserted `HEAD` against the sha and `git status --porcelain`
empty before and after every mutation arm, and deleted its probe worktrees afterwards.
That is what makes a mutation claim re-runnable by the next reader.
