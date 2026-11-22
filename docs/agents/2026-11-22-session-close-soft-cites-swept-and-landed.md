# Session close — the soft Apple-HIG citations in Sources comments swept, landed after four review rounds

## The symptom

The apple-ui-craft audit's residual P3 item: `Sources/` comments attributed
numbers, rules and file-forms to "the Apple HIG", "Apple's HIG", "Apple
Tahoe" or "per the HIG" at hundreds of sites, and a large share of those
attributions were soft — the cited figure was not on the cited page, the
page did not publish a figure at all, or the rule came from in-tree habit
that had picked up an Apple label over time. The lane's honesty rule: every
number, quote and rule attributed to Apple traces to an HIG-original line,
an SDK declaration, or a locally re-printable measurement.

## The root cause (two classes, both shipped by earlier comment authors)

1. **Transcribed provenance.** Comments wrote an API name, figure or
   quoted path from memory instead of from the page — including paths that
   do not exist at all (`View > List > Standard row accessories`, measured
   0 hits on the lists and sidebars pages), a macOS tap-target figure
   (28 PT) that belongs to a WWDC session, not to the HIG, and a "13pt
   default" the typography page does not publish.
2. **Collateral damage from rewriting.** Replacing the attribution word in
   place ("Apple HIG" -> "the product") damaged three kinds of sentence it
   touched: (a) refutations lost their quoted string — a comment whose job
   is to record what an old header said and refute it had the QUOTED
   string itself rewritten, inventing provenance no tree ever carried;
   (b) negations changed subject — "Apple HIG does not define a sidebar
   row icon width" became "product does not define…", contradicting the
   `sidebarWidth { 16 }` declaration printed below it; (c) grammar —
   article agreement (`an product`) and a doubled determiner (`The the
   product way`).

## The fix

- Soft attributions demoted to what they really are: "the product" (an
  in-tree decision), "the transcript's minimum", or an impersonal absence
  ("the HIG publishes no X").
- Real cites kept and made self-contained: the cited sentence is inlined
  verbatim next to the venue page name (e.g. the sf-symbols outline-variant
  sentence now carries the rule in five files; materials, segmented-controls
  and pop-up-buttons quotes re-fetched from the JSON API each round).
- Refutation quotes restored byte-identical to the string the tree really
  carried, with `git log --all -S` provenance; the one sentence whose sha
  pointer was wrong had the quote and the pointer deleted and the decision
  stated instead.
- Fabricated paths and dangling corpus ids (`[H-33]`-style references to
  an unversioned scratch file) removed outright.
- swiftformat is the authority for comment indentation: where it wanted a
  different column, the column moved to the formatter's position, never an
  exception declared around it.

## Measured before/after (read from the merged tree)

```
git grep -nE "Apple HIG|Apple's HIG|Apple Tahoe|per the HIG" c015b8eb5c -- Sources | wc -l
git grep -nE "Apple HIG|Apple's HIG|Apple Tahoe|per the HIG" HEAD        -- Sources | wc -l
```

The first prints the base census, the second the landed census; the ratio
is carried on the cards, not here. The delta is comment-layer-only: the
only non-comment added Swift lines are four `case` trailing-comment
whitespace lines in `IconStyles.swift` whose code part is unchanged, and
`Tests/` was not touched (the selector's `Tests/` census is identical at
base and at HEAD).

The residual list is structural, not asserted: every surviving line blames
to a commit OTHER than the landing commit. It is (a) four captioned
refutation quotes in `DesignTokens.swift` whose quoted strings the tree
really carried, (b) three lines carrying CJK in negation phrases where any
rewrite re-charges the base text under the comment-lineage gate, and (c)
one registry row in `SFRegions.md` that resolves to a real OOB entry.

`docs/agents/nfi.md` row corrections of record: two registry cells were
stale AT base — the Lifecycle and Layout rows — and this lane set them to
the value `wc -l` printed at base AND at HEAD. They are registry
corrections, not code deletions:

```
git show origin/main:Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Lifecycle.swift | wc -l
git show origin/main:Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Layout.swift | wc -l
```

## Gates, tests, landing

All gates ran at the reviewed sha and again on the merged tree (the merge
is fast-forward, so the two trees are byte-identical): build green; the
four `ci_change_gate` checks rc=0; `comment_lineage.py` offending 0;
`nfi-loc-check.py` rc=0; narrow source-text suites green:

```
swift test --filter 'IconStylesTests|Round6StandaloneSweepTests|FinalSweepArcClosureTests|StackSpacingMagicSweepTests|EmptyStateViewTests'
```

The full suite at the landing sha introduced no new failure against the
base control; both logs are attached to the landing card
(t_d7ff443f) and read back from the card's attachments directory.
Load-sensitive timing reds (`CoverRemovalRefreshTests`,
`HermesTodoStoreConcurrencyTests:268`, `ConversationLoopStreamingTests:67`,
`PromptCachingE2ETests:58`) appear in base runs and tip runs
interchangeably under parallel load and pass in isolation; they are the
pre-existing family.

Landing: `54c2c3895f` fast-forwarded to `main`, pushed to both remotes,
read back equal. This push carried no sibling commits that were not
already on the primary remote; the second remote was brought up to date
and its catch-up range belongs to earlier approved lanes (including this
lane's own earlier batches at `6c72b6c4fa`, `7f48fe46a6` and `c015b8eb5c`)
— pushing them is maintenance of the shared server state, not authorship.

## Open items

1. `t_7b9da001` (triage): the same selector still prints its full census
   inside `Tests/` and inside `Vendor/ Board/ Tools/ docs/`. This lane's
   scope was Sources comments; the follow-up prices the rest. The verdict
   also flags one line for that list — `LibraryStoring.swift:76` reads
   "edited first, product Finder 'Recents' convention", a wording the
   landing card chose not to re-word on an already-open file.
2. Sentence-shape residue measured by the final review: a third of the
   lane's added lines continue a sentence in lowercase after a full stop,
   copied from the prescribed impersonal phrasing. Not this round's class;
   the next pass that opens these files should capitalise them.
3. Two prose claims on the landing card were refuted by the reviewer and
   left unpriced under the published ceiling: the reason printed for not
   re-wording (1) above, and two small count-vs-list slips in the card's
   own summary. They are corrected here rather than by reopening the card.
4. Ruled and closed by the boss during this lane, recorded so nobody
   re-litigates: toolbar-icon font ride the dynamic body font (done,
   landed earlier batch); the chrome-glass redesign was dropped —
   `.ultraThinMaterial` stays as is, no ticket.

## Stopping rule

This closeout does not log its own review rounds; the verdicts, the four
rounds' findings and the server proofs live on the board
(t_24fc8ead -> t_f822bd36 -> t_726907ee -> t_d7ff443f) where each carries
its sha and its re-printable commands. The closure doc gets its own
card and gates; the doc's last word is this paragraph, and a finding that
is only wording after this point is a defect of the process, not of the
document.
