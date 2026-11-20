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
| L1 | "Adjust how Custom is entered (= the current way reads as a bug): it must be switchable into from the start, begin by reusing the general set, and then the user fine-tunes by hand" | `b4b4280f76` (= `fix(inspector): Custom is entered, not earned`), on `35810deeb0`, with `4d3bceed8d` an ancestor two steps under it (= `git log --format='%h %p' -1 b4b4280f76` answers `b4b4280f76 35810deeb0`, and `git merge-base --is-ancestor 4d3bceed8d b4b4280f76` answers 0), which replaced the hand-rolled switcher with Apple's own controls | `t_7c12b4c5` approved the behaviour at `d05242f281`; the stack was rebased four times since, and every later claim was re-measured at the new tip (`t_d4552e4c`, then `t_d00f50ad` approved) | both remotes ANSWERED `b48942d29f…` for `refs/heads/main` at the landing (`git ls-remote`, not a local ref); they now carry this doc's commit on top (§7) |
| L2 | "And keep the existing rule: change a fine-tune under either print or general and the book moves onto Custom" | same commit; pinned by `InspectorStylePresetPickerTests` (the picker suite) and `BookStyleSheetWriteBackTests` | the picker suite ran green at every tip; `t_d4552e4c` re-ran the filtered block at `4241b259fa` | ditto |
| L3 | "The two boxed in red are useless (= delete them)" | `20afb54373` (= `feat(inspector): the style table drops the picture and the rule`), then `df196df334` for the files that still counted eleven, then `b48942d29f` for the registry rows the stack left lying | `t_d4552e4c` P1-P3 at `4241b259fa`: nine cases, nine rows, nine catalog keys, zero hits for the deleted roles, and the mutation measured both ways (= re-adding the two cases reddens `InspectorStylePageRenderTests.swift:58`, `:62`, `:70` and `InspectorStylePreviewVoiceTests.swift:115`; withholding the catalog keys adds `InspectorStylePageRenderTests.swift:447` (= the catalog assertion, in a file of 521 lines; the number once sat there with no file of its own and inherited `InspectorStylePreviewVoiceTests.swift`, which ends at 155 lines, so the citation pointed past the end of the file it appeared to name -- what round 1 of this doc's own review caught. That broken form is described here rather than printed, because quoting a range with no file name re-arms the very check that catches it. The three counts in this cell come from one command: `wc -l Tests/WenshuAppTests/Editor/View/InspectorStylePageRenderTests.swift Tests/WenshuAppTests/Editor/View/InspectorStylePreviewVoiceTests.swift Sources/WenshuApp/Features/Editor/View/InspectorStyleRowView.swift` answers 521, 155 and 169); its F1 (the registry) was closed and re-approved by `t_d00f50ad` | ditto |
| L4 | "Give me a screenshot, I want to see the final effect" | no commit (= an observation, not an edit) | n/a | `look9_preset.png`, 2904×1952 (= `sips -g pixelWidth -g pixelHeight /tmp/look9_preset.png` answers 2904 and 1952), the app's own window at 2x, captured by the app's own screenshot hook against an isolated clone (§4). It sits at `/tmp/look9_preset.png`, outside the tree and untracked: a reader cloning `main` cannot check it, so it is evidence of the ask being answered, not of the ink being right |
| L5 | "It looks as though the body should sit vertically centred between its two dashed rules" | `35810deeb0` centres the row and its role name (`InspectorStyleRowView.swift:122`; the dashes are drawn between rows at `InspectorStylePageView.swift:209-213`, the row's own file ends at 169 lines, the page's at 533 (= `wc -l Sources/WenshuApp/Features/Editor/View/InspectorStylePageView.swift`)) | UNRESOLVED — no test measures the ink, and the boss's eye is the acceptance (§5) | — |

## 3. The gates, on the tree this doc names (= `b48942d29f`, which is `main`)

Every number below was read out of a log file, not out of a pipeline's status.

| command | answer |
|---|---|
| `python3 Tools/wenshu-devtool/ci_change_gate.py --base f697a2ced0 --check formatting` | exit 0 (= `the change adds no unformatted line (27 changed Swift file(s) checked)`) |
| `… --check pollution` | exit 0 (= `the change adds no forbidden vocabulary`) |
| `… --check markdown-newline` | exit 0 (= 2 changed `.md` files) |
| `python3 Tools/wenshu-devtool/nfi-loc-check.py --base f697a2ced0` | exit 0 (= `every rewritten file's row carries its own count (11 row(s) checked)`. The count belongs to the range asked, not to the tree: the same command run at this doc's sha answers `13 row(s)` (= other lanes' rows joined `f697a2ced0..HEAD` since), `--base b48942d29f` at this doc's sha answers `2 row(s)`, and `--base main` answers `the change adds no registry row; nothing to check` -- this commit EDITS a row, and an edited row is the gate's known blind spot (`t_398b07cd` Part B), so the row's own count was checked by hand: `wc -l` of this file is 307 and the row reads 307 (= `## 8.` item 2 is the same lesson from the other side) |
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
   file is absent — in `Tools/wenshu-devtool/nfi-loc-check.py`, the row loop's
   `if actual is None: continue` (measured still present at `main`'s tip) exempts
   exactly the lying rows, which is how F1 survived to a review round. The sweep that
   found F1 is blind the same way from the other side: it reads only rows whose FIRST
   cell is a bare backticked path, so a row whose first cell carries a trailing
   `(now N LOC, under cap)` is skipped before either column is examined. The fix has
   to widen both readers.
3. **`t_247eff53` / `be6504688f`** (= the `split_pre_check.py` §6 row gate) are
   approved and still unlanded; they ride their own branch, and `main` has moved
   under them since the approval.
4. **`t_c6d23305`** (= name the reviewed sha from any heading) is unlanded, and the
   defect it fixes was hit inside this closeout, before the rebase:
   `merge-preflight.sh` called an approved style-branch tip UNREVIEWED because the sha
   sat outside `## WHAT TO BUILD`. This landing avoided it only because both review
   cards happened to keep their sha in that one heading. Its dispatcher history is on
   the board (`hermes kanban runs t_c6d23305`): run 4642 crashed (pid exit 130), run 4680
   timed out (`elapsed 1550s > limit 1500s`), and run 4687 carries the result of the work
   finished by hand off that residue. The card is `done` with `landed: false`; the branch
   waits on its second review round (`t_7cabb456`, on `90dbda01cf`).

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
  `InspectorStylePageView.swift` (533 lines, `wc -l` of that path, under the 600
  cap), its rows `InspectorStyleRowView.swift`, its knob
  `InspectorStyleKnobView.swift`, its model
  `Sources/WenshuApp/Features/Editor/Model/InspectorStylePreview.swift` (243 lines,
  `wc -l` of that path), the switcher
  `Sources/WenshuApp/Features/Editor/View/InspectorStylePresetPicker.swift` (147
  lines, `wc -l` of that path).
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
2. **"the sweep reads 17 dead column-1 rows at tip against 18 at base, and 2 dead
   column-2 rows at tip against 3 at parent" — neither half reproduces, and the reason
   is the method.** The sweep resolves paths against the CURRENT WORKING DIRECTORY and
   takes the registry as an argument, so the published pair came from reading one
   tree's registry against another tree's filesystem. Run properly — from inside each
   tree, against that tree's own `docs/agents/nfi.md`:

   ```bash
   git worktree add --detach /tmp/tree-tip  b48942d29f
   git worktree add --detach /tmp/tree-base f697a2ced0
   for T in /tmp/tree-tip /tmp/tree-base; do (cd $T && /usr/bin/awk -F'|' 'function clean(s){gsub(/^ +| +$/,"",s);return s} function ispath(s){return s ~ /^`(Sources|Tests)\/[^`]+`$/} function path(s){return substr(s,2,length(s)-2)} /^\|/{ if(split($0,a,"|")<5) next; c1=clean(a[2]); if(!ispath(c1)) next; c2=clean(a[3]); rows++; if(!index(path(c1),"...") && system("test -e \"" path(c1) "\"")) d1++; if(ispath(c2) && !index(path(c2),"...") && system("test -e \"" path(c2) "\"")) d2++ } END{print "rows",rows,"dead1",d1,"dead2",d2}' docs/agents/nfi.md); done
   ```

   One program per line, and awk rather than Python, because the block sits inside a list
   item: shell and awk tolerate the leading indent, a Python heredoc does not (= uniformly
   indented module code is an `IndentationError` on its first statement, measured; the
   first version of this block was published broken and was caught by running it back out
   of the doc). No registry tool ships this selector: `dead-sweep-measure.py` rejects a
   positional registry path, and neither `nfi-loc-check.py` nor `verify-dead.py` prints
   these four numbers, so the selector is written out here rather than pointed at a tool.

   Both trees answer the same: **252 guard-table rows at the parent against 251 at the
   tip** (= the stack's net −1 row), **2 dead column-2 rows at each**, **6 dead
   column-1 rows at each**. So this stack neither added nor removed a dead row on the
   axis that mattered, which is the weaker and honest claim: F1's four lines were
   established by checking those four paths one at a time, not by any sweep total.
3. **"the filter covers 10 suites" — it reports 8.** Two of the ten names are
   XCTest-only or fold into another suite. `45 tests in 8 suites` plus
   `Executed 25 tests` on the XCTest side is the honest line, and round 1's reviewer
   is the one who caught it.

And one process fact worth keeping: the reviewer worked in a detached worktree at the
exact sha in both rounds, asserted `HEAD` against the sha and `git status --porcelain`
empty before and after every mutation arm, and deleted its probe worktrees afterwards.
That is what makes a mutation claim re-runnable by the next reader.

## 9. How this doc gets reviewed, and where it stops

One card reads this doc and the registry row beside it, and its job is bounded to
three claims: every sha it cites resolves, every number it publishes is reproduced by
the command printed next to it, and no row it names is absent from the tree. The code
is on `main` and was reviewed twice (rounds on `t_d4552e4c`, `t_d00f50ad`); a round
that re-reviews it is out of budget.

Two invariants the doc holds itself to, each a command: for every `file:N` citation it
prints, `N` is at most `wc -l file` in the tree it names (= the check that caught this
doc's only blocking finding, a range that inherited the wrong file's name), and every
number is reproduced by the command printed beside it.

The first invariant as a command, run from inside a checkout of the sha under review.
It reads a bare range against the last file named in the SAME table cell, which is how
the range went wrong here, and it refuses to answer 0 when the blob it was handed is
empty (= a check on nothing prints a clean number otherwise):

```bash
python3 - <<'PY'
import os, re, subprocess
DOC = "docs/agents/2026-11-20-session-close-the-style-table-drops-two-roles-and-custom-becomes-a-place.md"
NAMED = re.compile(r"([A-Za-z0-9_][\w.\-]*\.(?:swift|py|md|sh)):(\d+)(?:-(\d+))?")
BARE = re.compile(r"(?<![\w.]):(\d+)(?:-(\d+))?(?!\d)")
TRACKED = {}
for path in subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split("\n"):
    if path.endswith((".swift", ".py", ".md", ".sh")) and os.path.isfile(path):
        TRACKED.setdefault(os.path.basename(path), []).append(path)
def check(text, where):
    bad = []
    for number, line in enumerate(text.split("\n"), 1):
        for cell in (c.strip() for c in line.split("|")):
            named = list(NAMED.finditer(cell))
            refs = [(m.group(0), named[-1] if named else None) for m in BARE.finditer(cell)
                    if not any(n.start() < m.end() and n.end() > m.start() for n in named)]
            refs += [(m.group(0), m) for m in named]
            for token, anchor in refs:
                if anchor is None:
                    bad.append((number, "range with no file in its own cell", token)); continue
                cands = TRACKED.get(os.path.basename(anchor.group(1)), [])
                if len(cands) == 0:
                    bad.append((number, "names a file not in the tree", token)); continue
                if len(cands) > 1:
                    bad.append((number, f"basename matches {len(cands)} files", token)); continue
                if cands[0] == DOC:
                    bad.append((number, "the doc cites a range in itself", token)); continue
                n = sum(1 for _ in open(cands[0], encoding="utf8", errors="replace"))
                hi = max(int(g) for g in token.split(":")[-1].split("-") if g.isdigit())
                if hi > n: bad.append((number, "past EOF", token, cands[0], n))
    print(f"{where}: {len(bad)} violation(s)")
    for row in bad: print("   ", row)
    return bad
tip = open(DOC, encoding="utf8").read()
assert "L5" in tip, "the doc read back empty -- a check on nothing must not print 0"
here = check(tip, "this tree")
for sha in ("a6ee591331", "b5a70cf160"):
    shown = subprocess.run(["git", "show", f"{sha}:{DOC}"], capture_output=True, text=True)
    assert shown.returncode == 0 and "L5" in shown.stdout, f"{sha}: blob not read"
    check(shown.stdout, sha)
# The check's own teeth: a citation the tree cannot answer must count as a violation.
# The tokens are assembled at runtime (chr(58) is the colon) because a literal written
# here would be scanned by this very check and flagged as a defect of the doc -- which
# is how this round's own finding arrived, in the flesh.
FAKE = "nope/FakeCitedFile" + ".swift" + chr(58) + "900-999"
# A basename the tree carries more than once (= the last line below prints how
# many tracked paths carry it, so no count is asserted here that a later clone
# cannot re-measure): a range against such a name belongs to no single file, and
# the run must say so instead of quietly measuring whichever one it found first.
DUP = "AGENTS" + ".md"
DUP_N = len([p for p in sum(TRACKED.values(), []) if os.path.basename(p) == DUP])
FAKE2 = "nope/nested/dir/" + DUP + chr(58) + "1-2"
planted = check(tip + "\n| cites " + FAKE + " |\n| cites " + FAKE2 + " |\n", "planted fake")
assert len(planted) == len(here) + 2, "a planted citation was NOT flagged: the check is decoration"
assert any("matches" in str(r) for r in planted), "the ambiguous arm never fired"
print(f"ambiguous arm: {DUP} is carried by {DUP_N} tracked paths")
PY
```

It answers **0 violations in this tree**, **1 at `a6ee591331`**, and **2 at
`b5a70cf160`** (= the two ranges that inherited the wrong file: one pointing past a
155-line test's end, one past a 169-line view's end). The `1` at `a6ee591331` is what
round 2 of this doc's own review rejected: a harness read-fingerprint trailer that got
committed as prose, citing a range against this doc's own name under a path the
repository has never had. The loop names BLOBS, not refs: `main` is a moving ref, and
round 3's run happened to print the same blob for `main` and for `b5a70cf160`, which is
a fact about the day it ran and not something a check may rely on.

Three rules were added to catch what the first version skipped, each with its own red
case printed by the run above. A cited basename the tree does not have is now a
violation; the first version `continue`d past it, which is why a planted citation to a
file outside the repository answered 0. A range cited against this doc's own name is a
violation: the file carries its own line count in the registry, so a self-citation goes
stale by construction -- the trailer above is the proof, and the sentence you are
reading is deliberately a description rather than a quote, because printing the bad
token re-arms the check that flags it. And a basename the tree carries more than once is
a violation, because the range then belongs to no single file: the run plants one and
prints how many tracked paths carry that name, so the count is measured rather than
asserted here.

One residual, stated rather than closed: the pattern captures a FILENAME, not a
directory path, so a citation whose directories are wrong is still resolved by its
basename and the bad prefix stays invisible (= round 3 measured it: a planted path under
a prefix the repository does not have, naming a real basename, answered 0 violations).
Closing it means extending the capture to the whole path and re-reading every citation in
this doc against exact tracked paths, which is its own card and not this doc's landing.

A finding about the doc's numbers is fixed by making the number a command, not by
adding a section. A finding about its wording does not open another round. This
doc's own verdict lives on the board and is deliberately NOT written back here: a
closure doc that logs its own meta-reviews becomes the defect it was written to
report, and each such entry lengthens the file that carries its own line count.
