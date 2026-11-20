# Session close 2026-11-21: the right column is told, instead of asking every second

Scope: phase P1 of the four-zone loading-root-cause plan
(`2026-11-21-loading-root-cause-plan.md`, the boss's instruction of 2026-11-21:
"fix all the slow loading in the asset column, the right column, the editor and
the chat area at the root; if one session cannot finish it, phase it", followed by
"keep pushing to completion, verify it yourself, I am away from the machine").

Branch `wt/perf-right-column-push-2026-11-21`, first round's tip `c2908a161d`,
review round's code tip `5b6095ccda` (= every measurement below was taken on
that tree; this closeout's own commit sits on top of it, and changes no Swift
source), base `origin/main` = `65590f4800`. The second round's code tip is
`a4ac974c89`, and round 3 — the delivery-thread blocker, §9 — is one commit
stacked on it, so §§1-8 stay the readings of the trees their own lines name and
only the numbers §9 marks as moved were re-taken.
Worktree `/Volumes/ANAN/Engineering/wenshu/.worktrees/perf-right-column-push`.
Nothing was merged and nothing was pushed; the review card is the next link,
and §8 is what the first verdict changed.

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
| `Sources/WenshuApp/Features/Agent/Store/AsyncDelegation.swift` (534 LOC) | `// MARK: - Change signal`: `changes() -> AsyncStream<Void>` (`makeStream(bufferingPolicy: .bufferingNewest(1))`, one `yield` at subscribe time, deregistration in `onTermination`), private `signalChanges(_:)`, and TWO private writers: `store(_:)` writes a record, `drop(ids:)` removes them. All 9 `records[...] = handle` assignments became `store(handle)`, and the two paths that used to mutate the table by hand — the LRU eviction in `markCompleted` and the retention `cleanup()` — became `drop` calls. A debug seam (`announcementCounts`, per kind) records which writer spoke. |
| `Sources/WenshuApp/Features/Agent/Model/AsyncDelegationRecord.swift` (new, 183 LOC) | The signal pushed `AsyncDelegation.swift` from 442 to 610 LOC, over the AGENTS 6.6 ceiling, so the five value types a delegation is made of moved out whole. |
| `Sources/WenshuApp/Features/Agent/Service/HermesTodoTool.swift` (504 LOC) | `write(todos:merge:)` calls `postPlanChange()` after the serial-queue block. Posted on the writing thread, like the app's other change notifications, rather than queued to main, and POSTED WITH THE WRITING STORE AS SENDER: the app builds a second `HermesTodoStore` (= `TodoStoreTool.shared`), so an unscoped post would wake mirrors that have nothing of that write to show. `HermesTodoTool.planSender` exposes the store a reader must follow, and a debug `announcementCount` counts this store's own announcements. |
| `Sources/WenshuApp/App/AppNotifications.swift` | `AppStateEvents.todoPlanDidChange` + the `Notification.Name.wenshuTodoPlanDidChange` accessor (one place defines the name). |
| `Sources/WenshuApp/Features/Editor/View/InspectorStatusView.swift` (419 LOC) | `refreshLoop()` deleted; `.task(id: refreshKey) { await model.follow(scope: scope) }`. `follow` returns immediately with no subscription when there is no scope to follow; otherwise it reads on the subscribe signal (first paint does not wait out a window) and coalesces later bursts with a 250 ms quiet window. The file header's "re-reads it on a timer" was rewritten to match. |
| `Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift` (407 LOC at round 3; 375 at round 2) | The same clock deleted; one-shot `.task { model.refresh() }` plus `.onReceive(...wenshuTodoPlanDidChange, object: model.planSource)` — the page follows the one store it reads, not every plan write in the process — and the announcement reaches the draw through `InspectorTodoModel.hoppedToMain(_:)`, so it is answered on the main actor (§9). |
| `Tests/WenshuAppTests/Agent/Store/AsyncDelegationChangeSignalTests.swift` (new, 406 LOC, 12 tests) | see §4 |
| `Tests/WenshuAppTests/Editor/View/InspectorRightColumnPushTests.swift` (new, 379 LOC at round 3 / 239 at round 2, 10 tests / 8) | see §4 |
| `docs/agents/nfi.md` | 3 rows added, and the rows naming a file this change rewrote corrected (419 / 407 / 231 / 406 / 379 — the 407 and 379 cells are round 3's, §9). |

## 3. Two decisions taken inside this session, both stated here because both are contestable

1. **No low-frequency fallback scan.** The plan reserved a ~30 s safety net. It
   was not added. The failure mode the net would catch is "a write path that
   does not announce", and a timer neither diagnoses nor hides that fault usefully:
   it makes the page correct on average while the defect stays. The structural
   answer was taken instead — the record table has exactly two writers,
   `store(_:)` and `drop(ids:)`, both private, both announcing, and
   `recordTableIsWrittenOnlyByAnnouncingWriters` reads this file's own source and
   fails if a third function writes it. In the first round that sentence was
   aspirational (the eviction and `cleanup()` mutated the table beside the
   writer); at this tip it is measured. If the reviewer rejects this, adding the
   net back is three lines.
2. **The column becomes immediate, not lazy.** Announcing makes the right column
   update up to a second earlier than the clock did, which is a cost moved onto
   the frames where a sub-agent's output lands. It was paid for by the
   `bufferingNewest(1)` coalescing in the stream plus the reader's 250 ms window,
   not by re-introducing latency.

## 4. The 22 new tests, and what each one is for

Registry announcements (12): a subscriber learns the state that already exists;
every mutation site announces; the last change of a 40-append burst is never lost
(the stream keeps the newest, it does not drop); two readers are both told; **an
idle registry sends nothing for 300 ms** — the positive proof that the clock is
gone; a cancelled reader is deregistered and the surviving reader is still told.
The review round added five more, all on the half that was unproven: **a
retirement wakes the reader** (a record outside the retention window is enough,
and the one inside it survives), **a retirement that retires nothing wakes
nobody**, **the eviction announces its removal and not only the completion it
rides in** (the writer's own `announcementCounts` is what a reader's wake count
cannot see, because eviction and completion land in one actor step), **one
registry's announcements are not another's**, and **the record table is written
only by functions that announce**, which reads the source and is the test that
makes the no-fallback-scan answer structural instead of rhetorical.

Column surface (10, was 8 — §9 adds the two delivery-thread cases): a plan write announces exactly once, counted on the store
that wrote it and cross-checked against that store's own `announcementCount`; 20
plan reads announce nothing; **a write to a different `HermesTodoStore` is not
this plan's news** (the app really does build a second store, via
`TodoStoreTool.shared`, and that is why the notification got a sender); neither
page's source contains `while !Task.isCancelled`, `Timer.scheduledTimer` or
`Timer.publish` (a source-shape assertion, following
`Tests/WenshuAppTests/App/UnusedSpmDepRemovalTests.swift:47-51`'s
`SourceLocator.repoRoot` precedent); **each page follows the store it mirrors**,
asserted against the page's own source, folded to single spaces so it cannot
break on a wrap the formatter chose; a record the registry gains reaches the
status page's mirror with no clock running; `follow(scope: nil)` returns without
subscribing.

## 5. Evidence

First-round numbers in this section were corrected at the review tip; the
readings that moved are marked, and §8 carries the mutation arms that replaced
the first round's weakest ones.

- Five per-change gates, run at the tip against `origin/main`: `pollution`,
  `formatting` (8 Swift files), `markdown-newline`, `loc-cap` (8 files),
  `nfi-loc-check` (5 rows: 3 added, 2 rewritten). All rc=0.
- Narrow suites: `swift test --filter
  'AsyncDelegationChangeSignalTests|InspectorRightColumnPushTests|InspectorTodoPageViewTests|AsyncDelegationScopeTests|AsyncDelegationOutputTailTests|SubAgentKanbanCardLifecycleTests|InspectorCardLazinessTests'`
  → `Test run with 54 tests in 7 suites passed` (was 47; +7 tests, §8). Run
  three times in a row at the tip, rc=0 each time. Round 3 moved this reading to
  `56 tests in 7 suites` (= 54 + the 2 new cases, the same filter, the same
  runner line); §9 carries it.
- The two combined filters the reviewer measured red on `a01c919edb` are 10/10
  green each at this tip, and the assertions behind them are instance-scoped, so
  their green is no longer a fact about scheduling (§8, Blocking 1).
- Whole binary at this tip (`5b6095ccda`), twice in the same tree: **17 distinct
  failure SITES over the two runs, 17 in run 1 and 15 in run 2, and run 2's set
  is a subset of run 1's** (`Test run with 151 tests in 34 suites passed` +
  `Test run with 208 tests in 24 suites failed with 2 issues`; 8 suites reported
  failures in run 1, 7 in run 2). The two sites only run 1 has
  (`EditorPersistenceTests.swift:259`, `LongRunningGoalButtonTests.swift:98`) are
  load-sensitive, and this session did NOT have the machine to itself — a sibling
  Hermes session ran its own full binary in another worktree through the same
  window — so the honest reading is 17 with 2 drift, not 17 versus anything.
  Against the first round's published union of 14 and the reviewer's own 15 at
  `a01c919edb`, nothing NEW is attributable to this change: the two suites this
  change owns PASS inside the full run (`Suite "AsyncDelegation change signal
  (the registry says when a record moved)" passed`, and `Suite "Inspector right
  column push (a plan write is announced; the clock is gone)" passed after
  153.676 seconds`), the one registry-named site
  (`AsyncDelegationRegistryTests.swift:104`) is red in isolation and pre-existing,
  and `SSEReaderLiveTests.swift:20/:40` are the provider's HTTP 429 quota (4
  occurrences of the quota message in each log, and this session made no provider
  call). The three deterministic baseline sites recorded in
  `docs/agents/2026-11-03-session-close-the-review-lane-cost-and-its-four-tools.md:227-229`
  appear on both sides.
  The first round's control checkout (`.worktrees/p1-base-control`) was removed
  after use and this round did NOT rebuild it, so the comparison above is against
  the published site set, not against a fresh `origin/main` run.

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

## 8. What the first verdict changed (`t_b01fbb2c`, changes_requested on `a01c919edb`)

Two blocking findings, both about evidence rather than about behaviour, and both
were right.

**Blocking 1 — the plan assertions were not hermetic.** The notification carried
no sender (`object: nil`) and the tests observed with no sender, so their
counters saw every plan write in the process. The reviewer measured
`--filter 'InspectorRightColumnPushTests|InspectorTodoPageViewTests'` red in 7
of 12 runs at the "announced once" assertion, and
`--filter 'InspectorRightColumnPushTests|HermesTodoToolTests'` red in 4 of 6.
The dangerous half is not a flaky test: a co-running suite's write can satisfy
the expectation while the real announcement is lost, so the plan half of this
closeout's evidence could have been green by accident.

The fix gives the announcement an identity instead of a filter.
`HermesTodoTool.swift:243` posts `object: self` (the writing
`HermesTodoStore`), `HermesTodoTool.swift:409` exposes it as `planSender`,
`InspectorTodoPageView.swift:224` holds it as `planSource`, and
`InspectorTodoPageView.swift:46` subscribes with `object: model.planSource`.
A test that wants to know whether a write announced no longer has to listen to
a broadcast it does not own: `HermesTodoTool.swift:139` counts this store's own
announcements, and the expectation reads that. Two new tests hold the boundary —
a write to a second store leaves this store's count where it was, and the page's
own source must name `object: model.planSource` (folded to single spaces, so the
assertion is about the wiring and not about where the formatter chose to wrap).

Re-measured at this tip, 10 consecutive runs each, every run green: the first
combined filter `19 tests in 2 suites` 10/10, the second `21 tests in 2 suites`
10/10 (was 5/12 and 2/6).

**Blocking 2 — "one private writer" was 9 of 11.** `store(_:)` owned the nine
record writes, but the LRU eviction did `records.removeValue(forKey:)` plus a
hand-written `signalChanges()`, and `cleanup()` reassigned the whole table plus
another hand-written `signalChanges()`. Deleting both of those left the gate
green (`47 tests in 7 suites`, twice, as measured by the reviewer), so the
suites only bit where `store()` was load-bearing — and the sentence in §3.1 was
a claim about a structure that did not exist.

The fix is a shape change, not more tests: `drop(ids:)` is now the removal twin
of `store(_:)`, and both removal paths call it, so the eviction and the
retention sweep cannot happen without the reader being told, and the completion
queue is pruned in the same step (a queue id naming a dropped record used to
make `recentCompleted()` answer for a delegation the table no longer held).
`cleanup()` now computes the stale ids and hands them to `drop`, which means a
window with nothing stale in it removes nothing AND announces nothing — the old
code woke every reader on every call whether or not anything retired, which is
the "no wake with nothing to show" rule broken in a place no test watched.
Which of the two removal paths is LIVE, stated because the first round's card
did not state it: the eviction rides on `markCompleted`, and
`Features/Agent/Store/SubAgentRunner.swift:337` calls that on every finished
sub-agent run; `cleanup()` has NO caller anywhere in `Sources/` (grep
`cleanup(`), so it is a retention path the app does not yet drive and the tests
drive it directly. The writer pair is the same either way, and a caller that
arrives later inherits the announcement instead of having to remember it.

Five tests were added where the evidence was thin (a retirement wakes the
reader, a quiet retirement wakes nobody, the eviction announces as a removal,
announcements are per registry, and the source-level single-writer check). The
structural one is what §3.1's refusal of a fallback scan now rests on: it reads
this file and fails if any function other than `store` or `drop` writes the
table, so an unannounced mutation is not expressible rather than merely
untested.

`grep -n "records\[" Sources/WenshuApp/Features/Agent/Store/AsyncDelegation.swift`
at this tip returns 12 lines: `:111` and `:132` are the two writes, inside
`store` and `drop`; the other ten (`:131`, `:151`, `:162`, `:178`, `:221`,
`:232`, `:240`, `:251`, `:270`, `:299`) are reads — `guard var handle =
records[id] else`, `return records[id]`, and `.compactMap { records[$0] }` —
which mutate a local copy and hand it back through `writeBack → store`. No
whole-table assignment and no `removeValue`/`removeAll`/`updateValue` remains
anywhere in the file.

Mutation readings, before → after. Each arm is one source edit, the narrow
seven-suite gate, then the file restored byte-exactly (sha compared before and
after). "first round" is the reviewer's own measurement on `a01c919edb`; "this
tip" is `5b6095ccda`.

| mutant | first round | this tip |
| --- | --- | --- |
| delete the `postPlanChange()` call | rc=1, but green whenever a plan-writing suite ran beside it (the reviewer measured 7 of 12 paired runs red) | rc=1, 3 issues — `InspectorRightColumnPushTests.swift:73`, `:74`, `:119` |
| post it to the WRONG identity | invisible, and that is the finding: the observer had no identity either | rc=1, 1 issue — `InspectorRightColumnPushTests.swift:73` |
| the page stops naming its store (`object: model.planSource` deleted) | not expressible to test (nothing pinned the sender) | rc=1, 1 issue — `InspectorRightColumnPushTests.swift:173` |
| delete the removal writer's announce | **rc=0 — `47 tests in 7 suites passed`, twice** | rc=1, 3 issues — `AsyncDelegationChangeSignalTests.swift:228`, `:274`, `:363` |
| delete BOTH writers' announces | **rc=0 (the arm that made the verdict changes_requested)** | rc=1, 13 issues across both suites |
| add a third writer that announces correctly | undetectable | rc=1, 2 issues — `:361`, `:363` (the structural test alone; no behaviour changes, so nothing else could see it) |
| make `forgetChanges` a no-op (a cancelled reader leaks its consumer) | undetectable | rc=1, 1 issue — `:395` |
| positive control: delete `store()`'s announce | rc=1, 9 issues | rc=1, 11 issues |

The narrow set is now `54 tests in 7 suites` (was 47), and the two suites the
change added carry 20 tests (was 13). Round 3 carries both one step further:
`56 tests in 7 suites`, and the two suites at 22 (= 12 + 10), because the
announcement turned out to be answered on the wrong thread (§9).

## 9. Round 3 — the announcement was answered on the writing thread

Round 2's verdict (`t_92883b15`, changes_requested on `a4ac974c89`) closed B1 and
B2 as published and opened one new blocker, quoted rather than paraphrased:

> **Required.** (1) hop in the consumer: `.receive(on: DispatchQueue.main)` on the publisher, or the house `Task { @MainActor in model.refresh() }` inside the action — either is fine, pick one and make `InspectorTodoPageView.swift:45-49` match the sentence at `HermesTodoTool.swift:220-223`. (2) Add the case that drives the write from a non-main task and asserts the refresh landed on main (my probe is the shape; the assertion is `Thread.isMainThread`/main-actor-ness inside the mirror, not a count). Acceptance: published 7-suite filter still `54 tests in 7 suites passed` rc=0, the new case rc=1 with the hop removed and rc=0 with it in, and the crash gone from a run of the probe. (3) If the intent is instead that the poster must hop, the sentence at `:220-223` is a lie about the code and has to go with it — I am not accepting "post on the writing thread" plus a non-hopping consumer either way.

The store's sentence is "a mirror that draws from it hops to the main actor
itself", and at `a4ac974c89` the one real mirror did not hop: `NotificationCenter`
calls its observers on the posting thread, the plan write happens off the main
actor by construction: `Sources/WenshuApp/Features/Agent/Service/HermesTodoTool.swift:390`
declares `struct HermesTodoTool: Tool, Sendable` whose `execute(input:)` is `async
throws` at `:430`, and the file contains no `MainActor` annotation anywhere; it is
invoked from `public actor ToolExecutor`
(`Sources/WenshuAgent/Sources/WenshuAgent/Tool/ToolExecutor.swift:54`, which calls
`tool.execute(input:)` at `:254`), and that actor is not the main actor.
`onReceive` hands its action to that call. The
page's action is main-actor-isolated because `View.body` is, so the runtime
asserted the queue and trapped. Item (3) is answered by keeping the sentence and
fixing the page: `HermesTodoTool.swift:220-223` is now true of the code it
describes, the poster still speaks on its own thread, and the one real mirror is
the thing that hops.

**The fix.** `InspectorTodoModel.hoppedToMain(_:)`
(`Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift:240-264`) puts
`.receive(on: DispatchQueue.main)` on the announcement, and the page's
`.onReceive` (`:51`) subscribes through it. The hop sits on the SUBSCRIPTION,
inside a named function, rather than inline in the draw, and that is a test-shape
decision, not style: a hop whose removal does not compile cannot be shown to be
load-bearing. The app's two existing notification mirrors hop inside their action:
`Sources/WenshuApp/Features/Editor/View/AssetsPane.swift:435-437` runs
`Task { @MainActor in await coverNewDocuments() }` and
`Sources/WenshuApp/Features/Library/View/AppleSidebarView.swift:330-332` runs
`Task { await service?.reload() }`. This page reads differently from both while
honouring the same sentence, because neither of those hops can be removed in a
compile-clean way (deleting the first loses the isolation the call needs,
deleting the second leaves an `await` in a synchronous context), so neither can
be shown load-bearing by mutation.

**The mechanism, measured.** A closure formed inside a `@MainActor` frame carries
that isolation, and Combine calls `sink`'s / `onReceive`'s action on whatever
thread delivered, so the trap fires on the closure's ENTRY: the first version of
the new case printed nothing from inside its own sink and SwiftPM reported
`Process '…/swiftpm-testing-helper …' exited with unexpected signal code 5` —
the same faulting shape the reviewer measured on the page (their
`swiftpm-testing-helper-2026-11-21-061011.ips`). Re-taken as arm 3 below, at this
tip, both ways round. That is why the committed case listens through
`deliveryRecorder`, a consumer built in a `nonisolated` frame: it can stand on
the delivering thread and report it, so a missing hop REDDENS the case instead of
killing the run. The acceptance's "crash gone" half is read off the RUNNER, not
off `~/Library/Logs/DiagnosticReports`: 9 runs at this tip (the seven-suite gate,
the two-suite gate, the pairing ×3, the new case ×5) all ended
`Test run with N tests in M suites passed` with rc=0 and no
`exited with unexpected signal code 5` line, and that line IS the detector — two
deliberate traps in this same session, minutes apart, wrote no `.ips` at all, so
the newest entry there is still the reviewer's `…-061533.ips` whether the process
dies or not. A claim that rested on the absence of a crash report would be a
ruler that selects nothing.

**The two new cases** (`Tests/WenshuAppTests/Editor/View/InspectorRightColumnPushTests.swift`):

| case | what it holds |
| --- | --- |
| `a plan written off the main actor is drawn on the main actor` (`:307-356`) | records the thread of the write, the thread the hopped announcement is delivered on, and the thread of the mirror's own read (via the `readPlan` seam, so it is the DRAW's thread and not the notification's), then asserts `model.todos == ["written off-main"]` — the row the background write put in the store, with nothing else asking. Its first assertion is the premise (`wroteOnMain.value == false`), so the green is not available by writing from main by accident. |
| `the page hops the announcement it subscribes to` (`:362-378`) | reads the page's own source, whitespace-folded, and requires the subscription to be `InspectorTodoModel.hoppedToMain(…publisher(for:.wenshuTodoPlanDidChange,object:model.planSource))` and the hop file to carry `.receive(on:DispatchQueue.main)`. Round 2's `object: model.planSource` assertion (its own line moved, see the shift note below) is untouched and still green. |

Mutation arms, each one source edit, the narrow suite, the file restored
byte-exactly (sha compared before and after):

| arm | reading |
| --- | --- |
| `hoppedToMain` made the identity (`.receive(on: DispatchQueue.main)` deleted; the function, its one call site and its return type all still compile, and the page's call site is unchanged) | **rc=1** on `swift test --filter 'AsyncDelegationChangeSignalTests|InspectorRightColumnPushTests'`: `Test run with 22 tests in 2 suites failed after 0.350 seconds with 5 issues` — the behavioural case at `InspectorRightColumnPushTests.swift:348` (`deliveredOnMain.value == true`), `:350` (`drewOnMain.value == true`), `:354`, `:355`, and the structural case at `:376`. The premise `:344` and "the consumer answered" `:346` stayed green, so the red is the delivery thread and nothing else. |
| the page's `.onReceive` unwrapped to the round-2 shape (helper intact) | **rc=1**, 1 issue — `InspectorRightColumnPushTests.swift:371` (the structural case). The seam alone does not protect the page, and only the source-reading case can see that. |
| the consumer formed in the `@MainActor` test body instead of `deliveryRecorder`, hop deleted | **rc=1 via signal 5**, no expectation output — the trap, reproduced in-suite. With the hop restored the same edit is green (`Test run with 1 test in 1 suite passed`), which is what attributes the trap to the missing hop. |

Numbers this round moved, each re-taken on the Swift this commit records. The
seven-suite gate is `Test run with 56 tests in 7 suites passed` (0.338 seconds,
rc=0) and the two-suite gate is `Test run with 22 tests in 2 suites passed`
(0.345 seconds, rc=0), both at the filters §8 prints verbatim; `swift test
--list-tests` gives the same denominators per suite (12, 10, 11, 9, 3, 3, 8 = 56
and 12 + 10 = 22). The unit is the runner's per-target `Test run with` line, not
the count of `@Test` declarations. The verdict's acceptance named
`54 tests in 7 suites`, and it was written before the case it then asked for
existed: 56 IS 54 plus that case plus the structural one that keeps it honest,
at a byte-identical filter string. The paired run round 1 measured flaky was
re-taken four times on this Swift (`Test run with 21 tests in 2 suites passed`,
0.282 / 0.281 / 0.285 / 0.281 seconds), which is four runs and not twelve.

`wc -l` reads 407 for `Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift`
and 379 for `Tests/WenshuAppTests/Editor/View/InspectorRightColumnPushTests.swift`,
and `docs/agents/nfi.md:352` / `:666` carry those two cells;
`nfi-loc-check.py --base origin/main` is rc=0 at 5 rows. Both files grew above
their old anchors, so every §8 citation inside them moves: `git diff
a4ac974c89 HEAD` shows `import Combine` plus a 5-line comment above the page's
subscription, which is +6 there (the subscription `:46` reads `:52`, and
`planSource` `:224` reads `:230`), and 7 header lines plus `import Combine`
above the test file's cases, which is +8 there (§8's `:73` / `:74` / `:119` /
`:173` read `:81` / `:82` / `:127` / `:181`). The readings themselves are
unchanged; only the line each sits on moved, which is the defect that cost this
lane a round once before.

The status page carries no hop and needs none: its consumer is `for await` inside
a `@MainActor` model, and an `AsyncStream` resumes its consumer on the consumer's
own executor, not on the thread that yielded.
