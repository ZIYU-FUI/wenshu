# Session close: the code block's slab and the chat's full-width band

Date: 2026-11-11

Scope: the boss's 2026-11-10 requirement, as written in
`.scratch/2026-11-10-code-block-and-chat-bubble/spec.md` (151 lines). This
closeout covers that requirement's scope only.

Landed state (= = the state this record measured, = = and `main` may have
moved on since):

- `main` = `d21bc040b0951a11d2b8bdf6a700b7e8f1dc7e26`
- `origin/main` (gitcode) = the same sha
- `old-origin/main` (github) = the same sha
- the base the change landed on = `dee3dbdb6507fcdcdbad6b8b349e34f8e469e0f2`

= = ⇒ These three shas are the SNAPSHOT this record was measured on, = =
and they are still the tree's own history (= = `d21bc040b0` is on `main`),
= = but `main` itself may point further along. = = ⇒ So a reader who wants
TODAY's `main` reads it from the repository (= = `git rev-parse main`), = =
and this record's shas say WHICH tree the numbers below were measured on.

## 1. The requirement, row by row

One row per requirement, in the boss's own business language. The carrier
column is the commit on `main` that carries the requirement. The proof
column is an ANCESTRY fact, not a tip: the carrier commit IS the sha the
approved card ruled on, so the ruling covers the carrier by construction.

| # | Requirement (business language) | Carrier on `main` | Author | Approved card | Reviewed sha | Proof |
|---|---|---|---|---|---|---|
| 1 | The editor's code block must not be a big white slab; if it stays at all it must lose its fill, and its corners must be the system's | `d21bc040b095` | Hermes Agent | `t_6b8daa4a` | `d21bc040b09` | the carrier IS the reviewed sha |
| 2 | The chat's user bubble must not sit in a full-width background band; if the band cannot go it must be transparent | `d21bc040b095` | Hermes Agent | `t_6b8daa4a` | `d21bc040b09` | the carrier IS the reviewed sha |

**Commits in this scope that are NOT mine.** None: `d21bc040b0` is the only
commit this scope landed, and it was written by this session (`pocock`, in
the tree as `Hermes Agent`). The three review cards are the `wenshu-review`
profile's, = = and they carry no commits, = = only verdicts.

**Commits this closeout's PUSH carried that are a sibling's.** The push
that carried this scope's carrier (`d21bc040b0`) to the remotes also
carried three commits a sibling session had already merged into `main`
(= = `bc317f0d81`, `f11f689d3a`, `10c74666a7`, = = the render path's
caching work, = = ruled `approved` on `t_10c607bc`). They are not this
scope's work and are not claimed here; = = they were on `main` before this
closeout committed, = = and pushing them was maintenance of the shared
server state, = = not authorship. The three commits this closeout's OWN
push added (= = `d21bc040b0` and `0eec88e721`) are this scope's.

**The three review rounds.** The scope went through three review cards, and
the middle one is a `changes_requested` verdict that is still on the board:

| Card | Sha under review | Verdict | What the round was about |
|---|---|---|---|
| `t_dc081a55` | `c77ac86bf1` | `approved` | the first round; it confirmed all seven claims and both mutation proofs, and it found that the card's OWN body put the sha in its third paragraph (= = so the merge gate could not read it) and that the rewritten comment carried a stale figure |
| `t_fbb6b4f2` | `74e20f1640` | `changes_requested` | the second round; it confirmed the first round's two body fixes and REJECTED on a real defect in the change's own diff (= = the two NEW test files did not carry the repository's formatting, = = and the CI formatting gate charges every unformatted line a change ADDS) |
| `t_6b8daa4a` | `d21bc040b0` | `approved` | the third round; it re-derived the formatting gate on its own (= = and proved it not vacuous by running the SAME command in a throwaway worktree at the second round's sha, = = where it prints "27 unformatted line(s) added by this change", exit 1), and it re-proved both mutation proofs at this sha |

## 2. What was measured, before and after

Every number below is a measurement on the running app or on the rendered
pixels, not a reading of the source.

**The code block's slab.** On the boss's screenshot (= = 3002x1966, the two
red boxes), the slab measured `rgb(247,247,247)` (= = the
`calibratedWhite 0.95` fill) and ran the full width of the editor column
while the code text occupied only its first few hundred pixels; the page
around it measured `rgb(204,204,204)` above and `rgb(209,209,209)` below.

After the change, a capture of the landed build against the capture of the
pre-change build, diffed pixel by pixel:

| tone pair | pixels | region |
|---|---|---|
| `rgb(52,52,52)` -> `rgb(37,37,37)` | 24,092 | x 926-1158, y 467-729 (= = the code block's own region) |
| `rgb(50,50,50)` -> `rgb(37,37,37)` | 1,072 | inside the same region |
| `rgb(49,49,49)` -> `rgb(37,37,37)` | 1,072 | inside the same region |

= = ⇒ So 26,236 pixels of the highlighter's fill became the page's own
surface, and the region they occupy is exactly where the code block was.
The remaining changed pixels are the chat band's own edge (= = 4,443 +
4,357 + 2,962 + 2,962 + 2,940 + 1,072 + 180 + 143 + 82 + 80 pixels in the
band's rows) and the selection highlight, not the code.

**The code's ink on the page it now sits on.** 5.43:1 in the light
appearance (= = the code's ink `rgb(72,75,84)` on the page `rgb(204,204,204)`,
= = and WCAG AA body text needs 4.50:1) and 11.07:1 in the dark one (= = the
ink `rgb(219,219,219)` on the page `rgb(37,37,37)`). The change removes the
code block's GROUND and touches no INK, = = so only the ground can move
contrast.

**The chat's band.** The band's tone sat 55 luma steps from the column's
own surface; with no band the difference is 0, so the row's tone matches
the column's exactly.

**The trade the change makes, measured.** The material layer was not
decoration: it covered the replies that scroll in behind the pinned row.
With it gone, 12.6% of the pinned row's pixels carry reply content, against
3.4% with the band. The alternatives were measured and none of them keeps
the strip: `scrollEdgeEffectStyle` (= = `.soft` and `.hard`) masks nothing
for a pinned section header, = = and an AppKit behind-window material
samples a different source than the column's surface, = = so it does not
match either. The user named transparency as the fallback for this band,
= = and the pinned row IS transparent. This is the accepted trade of the
requested change, and it is stated here so the next reader knows it was
measured rather than discovered.

## 3. How the change was built, and why it is shaped this way

**The code block's fill needed a knob of its own.** A fenced code block
took its fill from the syntax highlighter's background, and that background
reached the screen by two paths at once: the attributed string's background
AND the renderer's own container. The vendored engine had no knob for it,
so the only way to stop it was to change the highlighter's background
itself, = = and that would have taken the inline code's background with it.
So the engine now carries a fenced-only knob (`CodeBlockStyle.fill`, = =
`CodeBlockFill.highlighter` is the upstream default and changes nothing,
= = `.none` writes no background attribute for a fenced block), and the
app's own editor configuration asks for `.none`. The inline code keeps its
background either way.

**The chat's band was a modifier, not a layout.** The transcript's pinned
user row carried a `.background(.regularMaterial)` that spanned the whole
chat column, = = so the user's rounded bubble sat on a second, wider slab.
Deleting that one modifier removes the layer; the bubble keeps its own
rounded surface, = = and the row paints no surface of its own.

## 4. The gates, and how to re-run them

Three suites, each a pixel measurement rather than an inspection, and both
app-side gates were MUTATION-PROVEN (= = so they are not vacuous):

| Gate | What it proves | The mutation that breaks it |
|---|---|---|
| `CodeBlockFill` (= = the engine's package) | the default paints the highlighter's background (= = the upstream behaviour), `.none` paints none, and the inline code keeps its background | = = |
| `EditorCodeBlockSurface` | the app's OWN editor configuration paints no slab | re-setting `fill = .highlighter` fails it on 2 expectations |
| `ChatPinnedHeaderBand` | the pinned user row paints no surface of its own | re-adding `.background(.regularMaterial)` fails it on `banded.count <= 2` |

```bash
cd /Volumes/ANAN/Engineering/wenshu
swift test --filter 'EditorCodeBlockSurface|ChatPinnedHeaderBand|ChatUserBubbleReadability'
cd Vendor/MarkdownEngine && swift test --filter 'CodeBlockFill'
python3 Tools/wenshu-devtool/pre_review_gate.py --base dee3dbdb65 --card <the card body>
```

The repository's own house gates on the merged tree, read at this sha:
`ci_change_gate.py --check formatting` = = "the change adds no unformatted
line (4 changed Swift file(s) checked)", exit 0; = = `--check pollution` =
= "the change adds no forbidden vocabulary", exit 0; = = the CJK audit = =
"no new CJK comment line (701 added line(s) scanned)"; = =
`nfi-loc-check.py` = = "every rewritten file's row carries its own count (3
row(s) checked)"; = = `verify-dead.py` = = ALIVE 122 / PARTIAL 4 / DEAD 0.

**THE FULL SUITE ON THIS BRANCH.** 3,578 tests, 5 issues in 4 files. The
same 5 reproduce at the base (`dee3dbdb65`) in the same throwaway-worktree
method, = = and `EditorPersistenceTests` passes in isolation at both base and
HEAD (= = a parallelism/timing flake, = = not a regression). Failures on the
branch that are not on the base: 0.

## 5. The board record

| Card | Status | Verdict |
|---|---|---|
| `t_dc081a55` | done | `approved` by `wenshu-review` |
| `t_fbb6b4f2` | done | `changes_requested` (= = the finding was real, = = and it was fixed in the next round) |
| `t_6b8daa4a` | done | `approved` by `wenshu-review` |

The merge gate reads the landed branch: `review_gate.py --card t_6b8daa4a`
= = "approved  approved by wenshu-review", and
`review_gate.py --branch wt/code-block-chat-bubble --sha d21bc040b0...`
= = "CARD t_6b8daa4a". `Scripts/merge-preflight.sh wt/code-block-chat-bubble`
= = "CLEAN". The branch and its worktree are gone (= = the change landed and
was cleaned up), and both remotes read the sha (= = `git ls-remote` per
remote, = = because a push that reported success on one remote says nothing
about the other).

## 6. Not in this scope

- **The third review round's two non-blocking findings** were in the CARD
  BODY, not in the diff (= = per AGENTS.md 1.16), = = and both are fixed in
  the body on the board: the command that proves the engine's default now
  names the TIP (= = the knob is introduced BY this change, = = so the base
  cannot carry it), = = and the file list carries the files' own line counts
  (198 and 244).
- **The vendored tree's nested `.build/`** is a pre-existing hygiene item:
  `swiftlint lint` reports 2 error-severity violations inside
  `Vendor/MarkdownEngine/.build/checkouts/` (= = gitignored, = = not in the
  commit), = = and the same 2 reproduce at the base. CI never builds inside
  `Vendor/`, so CI is unaffected. It is not this change's defect.
- **The masking trade** (= = section 2's last paragraph) is a decision the
  boss named (= = "if it cannot go, make it transparent"), = = not a gap.

## 7. The lessons that outlive this scope

1. **A NEW FILE IS AN ADDED FILE, = = SO EVERY LINE IN IT COUNTS.** The
   formatting gate charges the unformatted lines a change ADDS. A MODIFIED
   file is charged only for its added lines (= = so the two production files
   were charged 0), = = but a NEW test file is charged for every line in it.
   Measured: 27 unformatted lines across two new test files, = = exit 1.
2. **THE CARD BODY IS READ BY A MACHINE.** `pre_review_gate.py` parses the
   card body and RUNS what it finds, = = so a card with no `## GATES`
   section has its PROSE parsed as gate lines, = = a filter whose name
   wrapped onto the next line is unreadable, = = and a filter that does not
   resolve at the repo root (= = a vendored package's suite) runs, matches
   nothing, = = and is reported as "it measured NOTHING". The change this
   review cleared was sound, = = and the CARD was not readable.
3. **A COMMITTED BRANCH MUST NOT BE PROVED BY STASHING.** `prove_the_gate.py`
   proves ARM A by stashing and popping; on a branch whose work is already
   committed there is nothing to stash, = = so the script pops a DIFFERENT
   session's stash. Use a throwaway DETACHED worktree and check the old file
   out over the new one there.
4. **THE REVIEWER'S FINDINGS ARE ABOUT THE TREE, NOT ABOUT MY INTENT.**
   Round 2 rejected a change whose CODE was right because two of its NEW
   files did not carry the repository's formatting, = = and that was not a
   style opinion: = = it was the CI gate failing on the change's own diff.
