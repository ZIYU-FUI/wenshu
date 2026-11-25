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


## Corrected census and the citation-honesty guard (review card t_854a7ca0, 2026-11-22)

The dev work carried no board card. The id this document's first draft cited
(`t_5820e21e`) was never created: the session that built the change runs as a
delegated-child context, and every Kanban write it attempted was refused. The
section below is the spec of record, and `t_854a7ca0` is the outside check.

The first half of this document says the residual list "is structural, not
asserted: every surviving line blames to a commit OTHER than the landing commit",
and names eight surviving lines in three categories. Measured against the whole
tree with the nine attribution phrases, that sentence is a quantifier hung on one
grep — the same defect class this lane exists to catch. The base tree carries 90
attribution lines in 45 files, and the shipped classifier calls **69 of them** claims
with no source on the page, in 39 files. (36 is the count the rejected block rule
printed; it is quoted from that commit below, not reproduced here.) The three categories the
document lists are real and they do survive (= DesignTokens' refutation quotes
and the `SFRegions.md` registry row are both accounted for by the guard's
negation rule and its one whitelist entry); they are just not the residual.

**Census, re-printable** (run in the repo root, at the base commit
`29b5a8371f` = the tree these numbers were read in; keyed on `HEAD` they would print
this commit's numbers instead):

```
git grep -nE "Apple HIG|Apple's HIG|per the HIG|the HIG|HIG-correct|HIG canonical|Apple canonical|Apple-standard|Apple follows" 29b5a8371f -- Sources | wc -l      # 90
git grep -lE "Apple HIG|Apple's HIG|per the HIG|the HIG|HIG-correct|HIG canonical|Apple canonical|Apple-standard|Apple follows" 29b5a8371f -- Sources | wc -l       # 45
git grep -ciE canonical 29b5a8371f -- Sources | awk -F: '{s+=$3} END {print s}'                                                                                      # 581
```

90 attribution lines in 45 files. The bare word `canonical` appears on 581 lines,
almost all of them non-Apple senses (= "the canonical form of a path", "the
canonical key"), which is why a probe keyed on that word would have been noise
and the guard is keyed on the nine attribution phrases instead. Of the 90 lines,
**69 were claims with no source behind them** (= the count the guard shipped on the
day printed for that tree; the guard has since been widened — same tree pointed at
today's guard prints `attribution lines: exact(case-sensitive) 90 | anchored(case-insensitive) 94 | uncited: 72`, via
`git archive cbf080f310^ Sources` plus `WENSHU_CITATION_ROOT=<that tree>/Sources
swift test --filter CitationHonestyTests`),
spread over 39 files. The rejected block rule printed **36** for the same tree (= the
number quoted from that commit below; = not this guard's reading). After this change:
**0**, in the 39 edited Sources files, plus the guard. The widened scan finds three
lines the day-of reading missed (= 72 against 69: the casings the case-sensitive
matcher was blind to, one of them charged in the widening card below).

**What the matcher reads.** The violation scan charges `enforcementPattern` — the
nine phrases anchored on word boundaries and matched case-insensitively — and prints
the exact case-sensitive count beside it. Both counts are reproducible with
`git grep -nE`/`-niE` over the nine phrases plus the `.swift`/`.md`/`.plist` filter.
The widening (= t_71990706) closed the blindspot this section used to disclose: it
removed every `the high…` prose noise an unanchored reading used to fire on, and made
a URL credit a claim only when the claim names the page's own path subject. On the
tree that card ships on: **37** lines case-sensitively, **41** anchored. The four
lines only the widened reading charges are real claims, and all four pass on their
evidence: `Sources/WenshuApp/DesignTokens.swift:63` and `:158` deny the figure
themselves, `Sources/WenshuApp/Features/Editor/View/InspectorStylePageView.swift:69`
and `Sources/WenshuApp/Shared/UI/IconStyles.swift:212` quote the page they name.
Before-and-after on the widening card's own base tree (`4667aed5e3`), printed by the
shipped guard: `39 | 44 | uncited: 3` → `37 | 41 | uncited: 0` on the delivered tree.
The three were `Sources/WenshuApp/App/WenshuAppMain.swift:246` (a lowercase
`apple canonical` the case-sensitive reading could not see),
`Sources/WenshuApp/Features/Agent/Service/ImportService.swift:162` and
`Sources/WenshuApp/Features/Agent/View/ImportSheetViewPieces.swift:107`; all three had
their attribution reworded away rather than cited, because no page stands behind them.

**The ledger.** One row per claim the card named, plus the ones the sweep caught
that the card did not. `RE-VERIFY` is one command from the
`apple-hig-lookup` skill (`HIG=~/.hermes/shared/local-skills/apple-hig-lookup/scripts/hig_fetch.py`);
`search` reads the cached corpus, `page` fetches live and falls back to it.

| # | the sentence as it stood | source verdict | disposition | RE-VERIFY |
| --- | --- | --- | --- | --- |
| E1 | `ImportServiceFileSystem.swift:61` under "Apple canonical" — "skip directories and symlinks pointing outside the source tree" | **true about the code, wrong in its scope, and the sweep's own first verdict on it was the false one.** `isRegularFileKey` does NOT resolve the link: a probe on a symlink to a regular file prints `link.txt isRegularFile: Optional(false)`, so the walk skips *every* symlink, inside the tree or out — the comment's "pointing outside the source tree" describes something narrower than the code does. | the comment now states the measured behaviour and says the key does not resolve the link. No behaviour card filed: there is no hole, and "should a symlinked asset import?" is a product question with no demand behind it. The half of this that IS silent: a symlinked **directory** is enumerated as one entry (`isRegularFile: false, isDirectory: false, isSymbolicLink: true`) and the walk never descends into it, so a folder that is a link imports zero files without a word — measured, and stated in the comment as "skips EVERY symlink" | `swift Tools/wenshu-devtool/probes/symlink_walk.swift` (= the committed probe: a root with `top.txt`, a real `sub/`, `real/a.txt` and `linkdir -> real/`; it prints the five entries the walk yields, asserts that no `linkdir/a.txt` ever appears, and fails loudly if Foundation's answers move. Output recorded in `Tools/wenshu-devtool/probe-index.md` under `symlink_walk.swift`) |
| E2 | `ChatInputBarView.swift:73` — "Apple HIG canonical Messages / Slack pattern: focus stays in the input after a send" | **half true, wrongly sourced.** The HIG has a focus page and its sentence supports the behaviour; what is not Apple's is naming Messages / Slack. The Messages / Slack pattern repeats on 5 lines here (4 at the parent) and the focus sentence itself is on 1 line. | the rule now quotes Apple's own sentence with the slug, and keeps the boss's OOB directive as the origin of the Messages/Slack observation | `python3 $HIG search "Avoid changing focus"` |
| E3 | the working note this card inherited: "the HIG: a numeric count in the status bar is a distraction", cited as `menuBars` line 63 | **not in the corpus, and never was.** `search "numeric counts"` → 0 pages. The real slug is `the-menu-bar`, and its line 63 is the *Page Setup…* row of the File-menu table. | no code fix needed — `git grep -c "avoiding displaying numeric counts" HEAD -- Sources` = 0, nothing in the tree ever quoted it. Recorded because the fabrication was in the ORCHESTRATOR'S OWN NOTE, not in a comment, and it survived three rounds of review until someone re-ran the command | `python3 $HIG search "numeric counts"` · `git grep -c "avoiding displaying numeric counts" HEAD -- Sources` |
| E4 | `LabelSegmentedControl.swift:40` — "a standard component picks the material up automatically", and `:51` — "do so sparingly" | **true**, verbatim: materials — "Standard components from system frameworks pick up the appearance and behavior of this material automatically. If you apply Liquid Glass effects to a custom control, do so sparingly." | kept, URL added (= an uncited true claim is still a fail under the guard) | `python3 $HIG search "pick up the appearance"` |
| E5 | `LibraryExportEngine.swift:143` — "`/usr/bin/zip` (= Apple canonical tool shipped with macOS)" | **not a design claim** — a fact about the OS. | de-attributed to "the `zip` binary that ships with macOS" | `ls -l /usr/bin/zip` |
| E6 | `ComponentIndex.md` — the 52 PT unified title bar, the "11 text styles mandated by the HIG", the "14/17/20/26 PT ladder", 28 PT control height, 4 PT corner, the 16/20/13 PT sidebar glyph table, the "Apple canonical" status bar and hover wash | **mixed, and the HIG's own numbers cut against the comment.** typography states "macOS 13 pt default, 10 pt minimum" (= the table), so the "14/17/20/26 ladder" attributed to the HIG inverts the table it cited; `search "control height"` → 0 pages (= the 28 PT hit in the corpus is the accessibility tap-target table); `search "sidebar toggle"` → 0 pages; `search "extends the window"` → 0 pages; the 16/20/13 PT glyph table and the 4 PT corner were measured by `2026-10-12-macos-spec-audit.md`, not published by Apple. | 11 lines rewritten: where Apple states a number the row now quotes it with the slug (= the 13 PT body size, restored), and where Apple states none the row says it is wenshu's, pointing at the audit file (= a repo file the next reader can open) | `python3 $HIG page typography` · `search "control height"` · `search "sidebar toggle"` |
| E7 | `PreviewPaneModels.swift:137` — "The Apple Swift API design guideline §\"Make illegal states unrepresentable\"" | **false attribution.** `search "illegal states"` → 0 pages; the phrase is a community maxim, not an Apple sentence. | the enum's rule is stated as the project's own (iron-rule 4) and the maxim is labelled as a maxim | `python3 $HIG search "illegal states"` |
| E8 | `DisplayStateMachine.swift:62` / `ChatHelpTextOverlay.swift:93` — "The outline variant works well in toolbars, lists, and other places where you display a symbol alongside text" | **true**, verbatim, sf-symbols | kept, URL added | `python3 $HIG search "outline variant works well"` |
| E9 | `SidebarRowView.swift:15` — the per-row context-menu arrangement is "Apple canonical pattern (= macOS 14+ Finder / Mail / Notes sidebar)" | **unsourced observation presented as a rule, and this row's own RE-VERIFY command was the wrong one.** The corpus has a `context-menus` page — `search "context menu"` prints 22 lines — where `search "contextual"` prints nothing, so the earlier "no HIG page in the corpus covers this" was an artefact of the keyword, not a finding. What the page does say, verbatim: "To reveal a context menu, people generally choose a view or select some content and then perform an action", "**Support context menus consistently throughout your app.**", and "a context menu displays only the actions that are relevant to the currently selected view or content". What no page says is which selection model a row's menu has to follow (= the pointer's hit target versus the list's selection) — that half stays unclaimed. | reworded to "the pattern wenshu copied from Finder / Mail / Notes", and the menu's behaviour is justified by the responder-chain and hit-target reading in the code, not by an Apple sentence | `python3 $HIG page context-menus \| grep -n "select\|consistent"` |

**The two root causes of the survivors.** (a) *transcribed provenance* — the
citation belonged to the original code being described (= an audit's own citation
ladder, a migration note), and a rewrite left it attached to a new topic; (b)
*collateral damage* — a prose rewrite about a neighbouring subject (a removed
icon, a measured number) silently dropped the words that made the citation
honest (= "per the 2026-10-12 audit", "the HIG asks", "(no HIG citation)"). Both
shapes are invisible to a word-list probe, which is why the guard reads the
sentence's shape: attribution phrase → URL within 6 lines, or an explicit
negation, or a named whitelist entry.

**The guard:** `Tests/WenshuAppTests/UI/DesignSystem/CitationHonestyTests.swift`
(nfi row 694). Eight tests: the tree scan (= the 9 alternatives, the ±6-line URL
window, the comment-block negation scoped to the sentence, one whitelist entry —
`ComponentDocs/SFRegions.md`, whose line cites the boss's own HIG-first directive
to `OOB.md`); the orphan rule (= a `.md` that shows a `developer.apple.com` URL
must have that URL leaned on by some `.swift`, which is root cause (a) caught
mechanically); four teeth probes planted in a temporary directory, on the code
path the real scan uses (= the file walk, the sentence scoping, the orphan
comparison, the classifier's four verdicts); a collector-count assertion that
fails when the walk finds nothing; and a diagnostic that re-runs the whole scan
against any tree named by `WENSHU_CITATION_ROOT`, so "what does this rule say
about the tree before the change" is one command and not a memory.

The negation is scoped to the **sentence** because a block-wide negation lets any
honest-looking word anywhere in the block launder an unsupported claim. The file
walk has to visit every file because a walk that stops at the first extension
mismatch returns nothing, and a rule over nothing reports clean forever — which
is what the orphan rule was doing until this version: the collector stopped at
the first file whose extension differed, so over a `Sources/` that holds
648 `.swift` files and 10 `.md` files it returned nothing on both sides and
compared an empty set with an empty set, printing "no orphans".

**v4's reading of both trees**, from `WENSHU_CITATION_ROOT=<the parent checkout>/Sources
swift test --filter CitationHonestyTests`, the parent checkout being a `git worktree
add --detach` of this commit's parent:

```
attribution lines in Sources/           90  →  38      (git grep -nE "<the 9 phrases>" -- Sources | wc -l)
  in files                              45  →  22
uncited by the guard (v4 semantics)     69  →   0      (the external scan, then the normal run)
developer.apple.com URLs in Sources/    27  →  45      (git grep -n 'developer.apple.com' -- Sources | wc -l)
  in files                              18  →  33
```

69 and 36 are both counts of the same base tree, taken by two versions of this
guard. The 36 is what the rejected version of this change printed, and it is
quoted from that commit rather than reproduced: `git show -s --format=%B
cbf080f310 | grep -c '36 of the 90'` prints 1. It was reached with a negation
rule that read the whole comment block, so a denial anywhere within it excused
every attribution line in that block. The 69 is the same tree read one sentence at a time. Neither
figure is the claim this commit ships — the claim is the 0 on the right, and the
20 comment lines it took to get there (= each one either gained its page URL, or
moved its denial inside its own sentence, or stopped attributing the decision to
Apple: `AppRootScene`, `SettingView`, `ChatMessageView`, `BookStyleSheet`,
`Character`, `Document`, `World`, `LibraryBookmark`, `ImportSheetHelpers`,
`ImportServiceFileSystem`, `InspectorStylePageView`, `LibraryRootView`,
`DesignTokens` ×4, and the four `WenshuData/Repositories` headers).

**What was deliberately not done.** Nothing was fetched from the network and then
paraphrased: every quoted sentence above is `search`-verifiable in the cached
corpus. No comment was deleted to silence the probe — the attribution was removed
or made true, the constraint stayed. Where the HIG states a number and the code
already matches it (= 13 pt body), the citation was put back rather than dropped.

**One of this round's own verdicts was wrong, and it is recorded here rather
than quietly corrected.** E1 was first adjudicated as "the comment is false about
the code: `isRegularFileKey` resolves the link, so symlinks ARE imported". That
sentence was reasoning, not measurement. The probe (`swift Tools/wenshu-devtool/probes/symlink_walk.swift`,
a symlink to a regular file read through `resourceValues(forKeys:)`) prints
`isRegularFile: Optional(false)`: the key does not resolve the link, the walk
skips every symlink, and the original comment was right about the behaviour and
only wrong about its scope. The ledger row and the comment now carry the
measured version. (2) `BookStyleSheet`'s ladder is 12 /
13 / 14 PT, so its middle step *is* the HIG's stated macOS default (= 13 pt) and
the smallest is above the stated minimum (= 10 pt) — the citation is now
supported rather than dropped. What is *not* the HIG's is the comment's
"print minimum for a novel's body is size 5 (10.5 pt)" framing: a print
typography reference, kept labelled as ours.
