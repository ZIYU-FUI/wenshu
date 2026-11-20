# Session close 2026-11-21: the right column is told, instead of asking every second

Scope: phase P1 of the four-zone loading-root-cause plan
(`2026-11-21-loading-root-cause-plan.md`, the boss's instruction of 2026-11-21:
"fix all the slow loading in the asset column, the right column, the editor and
the chat area at the root; if one session cannot finish it, phase it", followed by
"keep pushing to completion, verify it yourself, I am away from the machine").

Branch `wt/perf-right-column-push-2026-11-21`, tip `c2908a161d`, base `origin/main` = `65590f4800`.
Worktree `/Volumes/ANAN/Engineering/wenshu/.worktrees/perf-right-column-push`.
Nothing was merged and nothing was pushed; the review card is the next link.

## 1. The one root cause this session removed

The four zones do not have four bugs. They have no "a write happened → a view
knows" path, and each zone pays a more expensive compensation for the missing
path. In the trailing column that compensation was a one-second clock, running
twice:

```swift
while !Task.isCancelled {
    await model.refresh(scope: scope)
    try? await Task.sleep(for: .seconds(1))
}
```

`InspectorStatusView.swift` ran it against the delegation registry, and
`InspectorTodoPageView.swift` ran an identical one against the agent's plan
store. The file's own comment claimed "the store will push its changes" — that
comment was false, and this session made it true instead of deleting it.

So this session built the path rather than tuning the beat: the writer
announces, the reader subscribes, both clocks are gone. Acceptance from the plan
(refreshes per second while the column is visible and idle) goes from 1/s to 0/s,
and the latency a poll adds (up to one second per visible change) goes to zero,
because the reader paints on the subscribe signal.

## 2. The change surface

| file | what changed |
| --- | --- |
| `Sources/WenshuApp/Features/Agent/Store/AsyncDelegation.swift` (444 LOC) | `// MARK: - Change signal`: `changes() -> AsyncStream<Void>` (`makeStream(bufferingPolicy: .bufferingNewest(1))`, one `yield` at subscribe time, deregistration in `onTermination`), private `signalChanges()`, and `private func store(_:)` as the only way a record is written. All 9 `records[...] = handle` assignments became `store(handle)`; the eviction branch in `markCompleted` and `cleanup()` announce too, because they also move the table. |
| `Sources/WenshuApp/Features/Agent/Model/AsyncDelegationRecord.swift` (new, 183 LOC) | The signal pushed `AsyncDelegation.swift` from 442 to 610 LOC, over the AGENTS 6.6 ceiling, so the five value types a delegation is made of moved out whole. |
| `Sources/WenshuApp/Features/Agent/Service/HermesTodoTool.swift` | `write(todos:merge:)` calls `postPlanChange()` after the serial-queue block. Posted on the writing thread, like the app's other change notifications, rather than queued to main. |
| `Sources/WenshuApp/App/AppNotifications.swift` | `AppStateEvents.todoPlanDidChange` + the `Notification.Name.wenshuTodoPlanDidChange` accessor (one place defines the name). |
| `Sources/WenshuApp/Features/Editor/View/InspectorStatusView.swift` (419 LOC) | `refreshLoop()` deleted; `.task(id: refreshKey) { await model.follow(scope: scope) }`. `follow` returns immediately with no subscription when there is no scope to follow; otherwise it reads on the subscribe signal (first paint does not wait out a window) and coalesces later bursts with a 250 ms quiet window. The file header's "re-reads it on a timer" was rewritten to match. |
| `Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift` (359 LOC) | The same clock deleted; one-shot `.task { model.refresh() }` plus `.onReceive(...wenshuTodoPlanDidChange)`. |
| `Tests/WenshuAppTests/Agent/Store/AsyncDelegationChangeSignalTests.swift` (new, 231 LOC, 7 tests) | see §4 |
| `Tests/WenshuAppTests/Editor/View/InspectorRightColumnPushTests.swift` (new, 180 LOC, 6 tests) | see §4 |
| `docs/agents/nfi.md` | 3 rows added, and the rows naming a file this change rewrote corrected (419 / 359 / 227). |

## 3. Two decisions taken inside this session, both stated here because both are contestable

1. **No low-frequency fallback scan.** The plan reserved a ~30 s safety net. It
   was not added. The failure mode the net would catch is "a write path that
   does not announce", and a timer neither diagnoses nor hides that fault usefully:
   it makes the page correct on average while the defect stays. The structural
   answer was taken instead — one private writer, so an unannounced mutation is
   not expressible. If the reviewer rejects this, adding the net back is three lines.
2. **The column becomes immediate, not lazy.** Announcing makes the right column
   update up to a second earlier than the clock did, which is a cost moved onto
   the frames where a sub-agent's output lands. It was paid for by the
   `bufferingNewest(1)` coalescing in the stream plus the reader's 250 ms window,
   not by re-introducing latency.

## 4. The 13 new tests, and what each one is for

Registry announcements: a subscriber learns the state that already exists; every
mutation site announces; the last change of a 40-append burst is never lost (the
stream keeps the newest, it does not drop); two readers are both told; **an idle
registry sends nothing for 300 ms** — the positive proof that the clock is gone;
a cancelled reader is deregistered and the surviving reader is still told.

Column surface: a plan write announces exactly once; 20 plan reads announce
nothing; neither page's source contains `while !Task.isCancelled`,
`Timer.scheduledTimer` or `Timer.publish` (a source-shape assertion, following
`Tests/WenshuAppTests/App/UnusedSpmDepRemovalTests.swift:47-51`'s
`SourceLocator.repoRoot` precedent); each page subscribes to the store it mirrors;
a record the registry gains reaches the status page's mirror with no clock
running; `follow(scope: nil)` returns without subscribing.

## 5. Evidence

- Five per-change gates, run at the tip against `origin/main`: `pollution`,
  `formatting` (8 Swift files), `markdown-newline`, `loc-cap` (8 files),
  `nfi-loc-check` (5 rows: 3 added, 2 rewritten). All rc=0.
- Narrow suites: `swift test --filter
  'AsyncDelegationChangeSignalTests|InspectorRightColumnPushTests|InspectorTodoPageViewTests|AsyncDelegationScopeTests|AsyncDelegationOutputTailTests|SubAgentKanbanCardLifecycleTests|InspectorCardLazinessTests'`
  → `Test run with 47 tests in 7 suites passed`.
- Whole binary, twice on the tip and twice on a control checkout of `origin/main`
  in the same directory family (`.worktrees/p1-base-control`, removed after use):
  failure SITES, not counts — base union 14, tip union 14, and the symmetric
  difference is one site each way
  (`WenshuConductorToolRegistryWiringTests.swift:237` on the tip side,
  `ConversationLoopMultiTurnTests.swift:181` on the base side). Both sites pass
  in isolation on BOTH trees (`Test run with 7 tests in 2 suites passed after
  4.1 seconds` in each tree), so they are load-sensitive, as the repository's own
  note expects. `swift_test_compare.py` on each single pair reported one "new"
  site per run, and the two runs named different sites — which is why this closeout
  publishes the two-run union instead of a single verdict. The three deterministic
  baseline sites recorded in
  `docs/agents/2026-11-03-session-close-the-review-lane-cost-and-its-four-tools.md:227-229`
  appear on both sides. **No new failure is attributable to this change.**

## 6. What this session could not measure, and did not pretend to

P0's Instruments per-frame baseline is still not taken. An ad-hoc-signed build on
this machine blocks at launch on the TCC-protected default library root
(`WenshuAppMain.swift:124 LibraryRoot.ensureDefault()` →
`FileSystemLibraryStore.loadShelves()` → `contentsOfDirectoryAtURL`), and the
boss's ruling of 2026-11-19 treats that launch block as environment noise. Under
the same ruling an empty observation window is not a pass, so **this session
issues no UI verdict**: the evidence is code plus tests, and the visual half of
P0 remains open for whoever can drive a signed build.

## 7. Next phases, with their entry condition

- **P2 (keys and fan-out)**: `Sources/WenshuApp/Shared/State/AppState.swift:141-168`,
  where `activeTabId`'s `didSet` writes `UserDefaults` synchronously on the tab
  switch path, read by 9 files. Acceptance: no `UserDefaults` write on the switch
  path, and TEB → editor first frame ≤ 100 ms (Apple's hang threshold for a
  discrete interaction).
- **P3 (editor relayout)**: `Vendor/MarkdownEngine/.../NativeTextViewCoordinator+CodeBlocks.swift:52-56`
  and `+Restyling.swift:150-175`, a scroll-offset-keyed recompute that calls
  `ensureLayout(documentRange:)` for the whole document. Highest risk, last.
- **P4 (streaming identity and follow)**: `StreamingAccumulator.swift:77-108`
  (`liftTraceMarker()`'s remove+insert churns part identity), `ChatView.swift:187-191`
  (the whole reply string is the scroll key and `scrollTo` is unconditional),
  `ChatReasoningPartView.swift:47` (the collapsed state lives in a view `@State`
  defaulting to expanded). **P1 was P4's precondition and is now on the branch.**
