#  2026-11-13 = = the session's closeout: = = every requirement, = = its commit, = = its verdict, = = its proof
#
#  One row per requirement the boss stated. = = The commit carries it, = =
#  the verdict is the INDEPENDENT one (= = never the implementer's own),
#  = = and the proof is the SERVER-SIDE artifact (= = a gate's output, = =
#  a mutation, = = a re-run), = = not an assertion. = = Every sha below is
#  the LANDED one on `main`.
#
#  ⇒ ⇒  THIS IS A CLOSEOUT RECORD, = = NOT A REPORT. = = Every row is
#  checkable by running the command it names.

| # | Requirement (the boss's words) | The commit that carries it | The independent verdict | The server-side proof |
| --- | --- | --- | --- | --- |
| 1 | "any requirement = = look at Apple's official answer first" (= = AGENTS.md §1.17 + OOB.md) | `efe1692522` | `t_7ff7d29c` **approved** (= = a different profile) | `Scripts/merge-preflight.sh` = = CLEAN; = = the reviewer ticked 9 claims green against their named commands |
| 2 | The gate must SEE the shared Apple skills (= = `apple-` prefix + `~/.hermes/shared/local-skills`) | `aa266622ea` | `t_e33cebdd` **approved** | The reviewer's own mutation: = = a fake `apple-totally-made-up-skill` was CAUGHT, = = and the two real ones were not flagged |
| 3 | The streamed chat part must keep its identity (= = B1, = = the one per-frame defect that was confirmed) | `6337ac9b1e` | `t_99e1c1e8` **approved** | The reviewer's three-arm mutation: = = with the fix = = passes, = = with it reverted = = exactly TWO identity assertions fail, = = restored = = byte-identical; = = and `swift test --filter StreamingUpdateTests` = = 5/5 on merged main |
| 4 | "Wenshu's UI performance is bad; it stutters" = = the full render-path sweep (= = the findings, = = their costs, = = their risks) | `b33605b82b` | `t_258485da` **approved** (= = after THREE CHANGES REQUESTED rounds, = = `t_f242876a` = = `t_f90d38f2` = = `t_ad22f54c`) | Every Apple quote re-read against its page with a positive control; = = the pollution and formatting gates CLEAN; = = the numbers re-measured at the floor (= = min, = = not mean) |
| 5 | "non-compliance with HIG can itself cost performance" = = the HIG axis (= = and the class total it exposes) | `f2401ff78e` | `t_5fb86128` = = F2 on the caption, = = **F1 withdrawn** after the reviewer's own counter-test | `Tools/wenshu-devtool/probes/render_path_reload_total.swift` measures ONE whole reload (= = both walks in one call) = = **1,589.667 us min**, = = and the reviewer's own D4 re-run spread (= = 3.32%) is the 3rd-tightest of 11 rows |
| 6 | The prioritized fix list (= = the ORDER the boss asked for: = = which fix first, = = what it costs, = = what it risks) | `db7c404a08` + the four corrections after it | `t_bedecdbe` **approved** at the branch tip `7ca3f3f1cd` | All 26 of the sweep's findings have a row or an exclusion; = = every figure in the list appears in the sweep (= = 14/14); = = every `File.swift:NN` cite resolves (= = 113/113); = = the two documents state the same composed total |
| 7 | The numbers must be RE-MEASURABLE (= = the probes had no home) | `ae6ed03d01` + `befbf1e65d` + `7ca3f3f1cd` | in `t_bedecdbe` | The probes are in `Tools/wenshu-devtool/probes/`; = = `test_probe_index.py` = = 5/5 (= = the index and the directory agree both ways); = = both build, = = both print their commit, = = and the figures reproduce (= = a RE-RUN on this machine, = = not the sweep's floors: = = 0.041 us Hasher, = = 118.959 us for the 12-tag set, = = 1,585.083 us for the whole reload) |

## What the sweep found, = = and what it did NOT

| Class | The measured floor | The largest item |
| --- | --- | --- |
| Per keystroke | **276.042 us** (= = two walks of the same 4,731-character document) | A1 + A2 = = the editor's counter and the status bar's = = ONE walk each, = = both below Apple's 500 us line |
| Per frame while streaming | a COUNT, = = not a microsecond figure | the trailing row rebuilt 60x/s = = **FIXED and LANDED** (= = B1) |
| Per body pass | 542 card bodies + 490 markdown parses per board pass; = = 4 stat syscalls at the root | the board's plain `VStack` instead of a `LazyVStack` (= = visible change, = = boss's eye) |
| Per sidebar reload | **1,589.667 us** (= = D1's ten folder counts + D3's shelves walk, = = measured together) | both halves are on the same `reload()` |
| Per launch | every reference-library row's identity changes | the `Hasher`-seeded UUID, = = which is a CORRECTNESS bug, = = not a speedup |

**⇒ ⇒  WHAT WAS FALSIFIED, = = AND WHAT WAS NOT MEASURED.** = = The
sweep's biggest open question (= = "is the editor's configuration
rebuilt on every body pass?") = = was **falsified**: = = the shape is
real, = = but the cost is 0.125 us, = = so it is not the biggest cost in
the tree. = = ⇒ ⇒ **NO USER-VISIBLE BEHAVIOUR WAS CHANGED** in
anything shipped: = = the only landed code change (= = B1) = = renders
the same text. = = ⇒ ⇒ **NO INSTRUMENTS TRACE EXISTS**, = = because the
boss directed the work to code audit and micro-benchmarks rather than
to reproducing the stall. = = So the claim "these are the causes of the
user's stall" is NOT made; = = the claim is "these are the measured
wastes in the render path, = = and here is what each one costs".

## The order of work, = = by fix RISK (= = not by cost)

| Group | Meaning | The findings |
| --- | --- | --- |
| 0 | the open question, = = now answered | the editor's per-body-pass factory (= = **falsified**, = = and a landmine the day the book directory is wired) |
| 1 | invisible to the user, = = semantics unchanged, = = provable by a test | B1 (= = **DONE**), = = A1, = = A2, = = B2, = = B3, = = B4, = = B5, = = B6, = = B7, = = D2, = = D3 |
| 2 | invisible in the output, = = but touches a data path or a value others read | D1, = = C2, = = C3, = = C4, = = C6, = = C7, = = C9, = = C11, = = E1 |
| 3 | the user sees it, = = or the fix changes an interaction | B8, = = C1, = = C5, = = C8, = = C10, = = C12 |
| 4 | what the sweep deliberately did NOT claim | the prior audit's settled findings, = = and the open questions |
| 5 | the HIG axis | four findings (= = C5, C8, C12, B8) = = and four surfaces CHECKED and found CLEAN |

**⇒ ⇒  THE HIG AXIS PRODUCED NO GROUP-1 FINDING.** = = Every
HIG-compliant fix that would cost nothing visible turned out to be
already done, = = or to be worth less than its risk. = = And the four
HIG surfaces that were CHECKED (= = the board's single `ScrollView`, = =
the sidebar's `List`, = = every loading surface, = = the sidebar's
hierarchy) are recorded as CLEAN, = = so the axis was READ, = = not
skipped.

## What the boss has to look at

= = These five change what the user SEES, = = so they are the boss's
call, = = not the implementer's. = = The fix order's own column of that
name carries SIX (= = it also lists B8, = = whose fix changes WHEN the
transcript scrolls = = a change of interaction, = = not of appearance).

| # | The change | What the user sees |
| --- | --- | --- |
| C1 | the board's `VStack` = = `LazyVStack` | = = 542 card bodies = = ~15 per pass; = = but `GlassEffectContainer` depends on its children's geometry, = = and a lazy container reports only what it realised |
| C5 | the detail column stops animating on every search keystroke | = = one animation per keystroke = = none, = = for the 9 of 10 panes that never read the query |
| C8 | the forever-repeating symbol effect stops | = = the icon visibly stops looping |
| C10 | the video cover players arm lazily | = = when a video card starts playing |
| C12 | the progress animation stops restarting per tick | = = the progress bar's motion changes |

## The skills this session built (= = and they are the point)

| Skill | What it does | Where it lives |
| --- | --- | --- |
| `apple-hig-lookup` | Apple's HIG as a QUOTABLE source (= = 173 English pages + 173 Chinese, = = cached locally, = = so a quote can be searched and checked without the network) | `~/.hermes/shared/local-skills/apple-hig-lookup/` |
| `apple-doc-search` | Apple's WHOLE documentation as a discovery layer (= = the search endpoint, = = the JSONL diff replay, = = the three metadata shapes) | `~/.hermes/shared/local-skills/apple-doc-search/` |
| `swiftui-performance-audit` | the render-path path classes, = = the min/median/p95 harness rule, = = and the quote-verification discipline | `~/.hermes/profiles/pocock/skills/software-development/swiftui-performance-audit/` |
| `wenshu-iron-rules-audit` v4 | the 42 Wenshu rules, = = now with "Apple's official answer comes first" as rule 1 | `~/.hermes/shared/wenshu-skills/wenshu-iron-rules-audit/` |

**⇒ ⇒  THE THREE-LAYER CHAIN IS THE DELIVERABLE THAT OUTLIVES THIS
SESSION:** = = `apple-doc-search` (= = what Apple HAS) = = →
`apple-hig-lookup` (= = what Apple SAYS) = = → the SDK on disk (= =
what the symbols ARE). = = Every number and every rule above came
through it.
