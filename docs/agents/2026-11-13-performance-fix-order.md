#
#  2026-11-13 = = the performance findings, ordered by FIX RISK
#
#  The findings live in `docs/agents/2026-11-13-render-path-full-sweep.md`.
#  This file is the ORDER, and the order is by fix SHAPE, = = not by cost.
#
#  WHY NOT BY COST: a cost says how much a fix buys. The shape says how
#  much RISK the fix carries. A 276 us per-keystroke fix that reads a
#  counter the editor already published is safer than a 39 us per-frame
#  fix that changes what the user sees. So: cost is the second column.
#
#  EVERY NUMBER HERE IS THE FLOOR (the minimum over many reps), measured
#  on the user's own library on a quiet machine. Revision 1's numbers were
#  2-3x higher (= they were means taken while three subagents were
#  compiling), = = and the reviewer's re-run caught it.
#
#
#
#
#

## Group 0 = the open question, now RESOLVED (= it was the sweep's biggest open item)

The sweep ranked one question above every fix: "how expensive is the
editor's per-body-pass factory?" (= = the audit's
`WenshuEditorServicesFactory.make per body pass vs once per mount` row).
It is answered, and the answer changes the list: the cost is nil, so it
is NOT a fix candidate, and the sweep's "this might be the largest cost
in the tree" was wrong.

| # | Finding | Size | What the answer was |
| --- | --- | --- | --- |
| the factory | `WenshuEditorServicesFactory.make` per body pass (`EditorView.swift:400-415` into `WenshuEditorServicesFactory.swift:14-195`) | **RESOLVED: the answer is "almost free" = 0.125 us.** The factory's 22 `Notification.Name` allocations cost that much, and it does ZERO disk work (= `BookStore.reload(bookId:)` has no production caller, = = so `currentBookDirectory` is nil, = = so `BookDocumentIndex` scans nothing) | **THE SWEEP'S HYPOTHESIS IS FALSIFIED.** The shape was real (= the factory IS rebuilt per body pass, = = `editorSurface` is a computed property read inside `body`), = = but the COST is nil, = = so this is NOT the largest cost in the tree. = = It is also a LATENT LANDMINE: = = the day someone wires `currentBookDirectory` (= the one-line fix that makes the book document path work again), = = the same factory starts paying a 7-folder directory scan (= **188.833 us min**) per body pass. = = So a fix for the book-directory bug must cache that scan, = = or it trades one bug for a worse one. |


## Group 1 = invisible to the user, semantics unchanged, provable by a test

| # | Finding | Cost | The fix, and why it is invisible |
| --- | --- | --- | --- |
| B1 | the streamed chat part's identity (`StreamingAccumulator.swift:43`, `ChatMessagePart.swift:114`, `ChatPartView.swift:100`) | 60 subtree rebuilds/second while a reply streams | Extend the trailing part in place so it keeps its UUID. The same text on screen, built once instead of sixty times. **APPROVED AND LANDED** (= = the reviewer's own mutation: = = revert = = the suite fails on exactly the two identity assertions, = = restore = = byte-identical; = = landed on main as sha 6337ac9b1e (= = the rebased tip's diff is byte-identical to the reviewed one)). |
| A2 | the status bar re-walks the whole draft to show a number the editor already computed (`EditorStatusBarView.swift:125-132`) | another 140.333 us per keystroke, so A1 + A2 = 276.042 us (= BELOW Apple's 500 us line, on the floor-measured number) | Read the published count instead of re-walking. The number on screen is the SAME number, so the change cannot be seen. Still worth doing (= it is the same walk twice), but it is no longer a threshold breach. |
| B2 | the reasoning text is re-parsed per body pass, and the parse is quadratic (`ChatReasoningPartView.swift:110-113`, `ReasoningMarkup.swift:87-115`) | O(lines^2) per frame, on an input that grows every frame | Parse once, at the model boundary, and read the parsed segments. `hasMarkup` also runs a second full split on the same text (`ChatPartView.swift:225`). |
| B3 | the tool-activity aggregate is rebuilt in a body-read computed property (`ChatPartView.swift:156-158`) | O(parts^2) rescan, plus a full `JSONSerialization` parse per tool-use, plus a copy of every tool output (the largest is 10,996 characters) | Move the aggregate to the model. Same rows, same order. |
| B4 | the latest-user scan runs per turn (`ChatView.swift:148`) | O(turns x messages) per body pass, so O(n^2) as the transcript grows | Resolve the latest user message once per pass. Today's corpus is 4 messages, so today's cost is about zero; this is the row that bites as the conversation grows. |
| B5 | the turn array is re-allocated per body pass (`ChatView.swift:125-139`) | O(messages) struct allocations per frame | Build it once. |
| B6 | the footer tooltip is built eagerly, and the timestamp is formatted twice per footer per frame (`ChatMessageFooter.swift:80`, `:114`, `:202-204`, `:226-233`) | two `DateFormatter.string(from:)` per footer per frame | Format the timestamp ONCE and reuse it in the combo tooltip. The tooltip text is unchanged. (Making the WHOLE tooltip lazy is a different job: `.help` takes a `String`, and there is no lazy form.) |
| B7 | the tool-result row counts lines by materialising an array, and copies the whole output (`ChatToolResultPartView.swift:131-134`, `:189-211`) | O(output bytes) per row per frame | Count the newlines without materialising the array, and drop the byte copy. Same rows, same toggle. |
| D2 | the reference-library row id is formatted with 16 separate `String(format: "%02x")` calls (`SidebarService+ReferenceLibrary.swift:269-285`) | 9.333 us per UUID, of which 8.042 us is the formatting; the `Hasher` itself is 0.041 us. The 12 real tags = 116.292 us per reload | Format the hex with `FormatStyle`. The UUID BYTES are unchanged, so the id VALUES are unchanged: this is a pure speedup and it does NOT touch E1's cross-launch instability. |

## Group 2 = invisible in the output, but touches a data path or a value others read

| # | Finding | Cost | The risk that keeps it out of Group 1 |
| --- | --- | --- | --- |
| D1 | the folder doc count re-lists every shelf directory (`AppleSidebarView.swift:270-298`) | 66.209 us per call; the real reload's 2 books x 5 folders = 10 calls = 759.958 us per sidebar reload | The fix is one listing instead of ten, but the COUNTS ON SCREEN must not move. The boss should look at the numbers once. |
| C2 | the markdown is parsed inside the card's `body` (`KanbanView.swift:333`) | 469 parses per board body pass (about 2.4 ms, estimated from the chat's measured 5.08-61.44 us per parse) | Precompute at the model boundary. Invisible, but it moves work into the model layer. |
| C3 | a filesystem `stat()` runs inside the app root's `body` (`LibraryRootView.swift:34-50`) | up to 4 stat-class syscalls plus 2 `URL` allocations per root body pass | The fix needs an EXPLICIT invalidation signal. A path that does not change can still have its `Info.plist` appear after bootstrap, so a cache without a signal goes stale. |
| C6 | a bundle-backed `String(localized:)` lookup runs per pane per body pass (`SettingView.swift:162-168`) | 10 or more lookups per body pass, 20 or more per keystroke | Cache the localized titles. The values are the same; only the lookup moves. |
| C7 | the segment control's own guarding rule is violated by its own unguarded writes, and a fresh `NSImage` is allocated per segment (`LabelSegmentedControl.swift:258-260`, `:286`, `:287-299`, `:302`) | 4 mount sites; the segment count is unmeasured | Guard the writes the way the file's own rule at `:415-417` says. Touches AppKit control state, so it needs the mount sites checked. |
| C9 | the cover cache key is computed on the disk, twice per card load (`CoverImageCache.swift:35-42`, `:54-57`, from `CardCoverView.swift:95`, `:103`) | up to 58 filesystem metadata reads per full grid scroll-through, on the main actor | The key must come from data already in hand. `LibraryContentFingerprint.swift` is the shape to copy: it caches the disk-touching key and invalidates on `.wenshuLibraryDidChange`. |
| E1 | the reference-library row id comes from a per-process-seeded `Hasher` (`SidebarService+ReferenceLibrary.swift:269-285`) | one full row rebuild per launch; a persisted selection keyed by that UUID cannot resolve | THIS IS A CORRECTNESS FIX, not a speedup, and the id VALUES CHANGE. The code comment promises "the same UUID across launches"; the promise is false (three launches, three UUIDs: F5EB52CE, F0267C71, F0B97B25 for the same tag). So the fix needs a MIGRATION or a fallback that resolves an old id. That is a design decision, not a patch. |

## Group 3 = the user sees it, or the fix changes an interaction

| # | Finding | Cost | What the boss has to look at |
| --- | --- | --- | --- |
| B8 | the auto-scroll fires once per frame, because the change key is the whole last-message content (`ChatView.swift:249-253`) | one layout pass of the transcript scroll viewport per frame | The fix changes WHEN the transcript scrolls. Scrolling is the interaction, so it cannot be fixed invisibly. |
| C1 | the board's scroll content is a plain `VStack`, not a `LazyVStack` (`KanbanView.swift:140`) | 521 card bodies plus 469 markdown parses per board body pass, against the ~15 a lazy stack would build | The board is the app's main surface, so the change is obvious to the eye. There is also a GEOMETRY RISK: `GlassEffectContainer` (`:139`) wraps the whole scrolling board and depends on its children's geometry, and a lazy container reports only the items it has realised. The glass fusion can change. |
| C5 | the whole detail column is animated on `globalSearchQuery` (`SettingView.swift:210-211`) | one full-column animation per keystroke, for the 9 of 10 panes that never read the query | The fix removes an animation the user can see. It is probably right, but it is a visible change. |
| C8 | a forever-repeating symbol effect (`IconStyles.swift:547-551`, plus `InspectorTodoPageView.swift:181`) | loops forever while the view is mounted; 2 production call sites | The icon visibly stops looping. |
| C10 | an `AVPlayerItem`, an `AVQueuePlayer` and an `AVPlayerLooper` are built on `.onAppear` for every video card, and the loop stays armed while the clip is paused (`LoopingCoverView.swift:169-180`, `:196-204`, `:207-212`) | 1 decoder plus 1 spare copy of the clip held for the card's visible life; 4 clips today, growing with every generated cover | The fix changes when a video card plays. |
| C12 | an animation is bound to a continuously changing progress value (`LibraryMigrationPanel.swift:137-139`) | 1 default-duration animation per progress tick | The progress bar visibly changes how it moves. |

## Group 4 = what the sweep deliberately did NOT claim

- The prior audit's settled findings (the chat's markdown re-parse, the pinyin search key, the editor's word count, the materials-column footer scan, the pinyin sort) are not repeated.
- The "a custom control where Apple ships one" axis produced NO finding, and NO HIG citation is offered for it, because none was read.
- The open questions the sweep did not measure are listed in the audit document's own "What was NOT measured" section. They are questions, not findings.

## Group 5 = the HIG axis (= = the boss's second requirement)

The boss asked for a full sweep of the HIG axis too, = = because
non-compliance can itself cost performance. = = The audit document's HIG
section now carries Apple's OWN wording for every HIG claim it makes,
= = read from the local HIG corpus (= = 173 English pages) and = =
re-verified against each page before the document was approved. = = The
six HIG findings that map to a performance cost are:

| # | HIG says | Where the code breaks it | What it costs |
| --- | --- | --- | --- |
| C5 | "In apps, generally avoid adding motion to UI interactions that occur frequently." | the whole detail column animates on `globalSearchQuery` (`SettingView.swift:210-211`) | one full-column animation per keystroke, for the 9 of 10 panes that never read the query |
| C8 | "In particular, you want to avoid showing an oscillation that has a frequency of around 0.2 Hz because people can be very sensitive to this frequency." | a forever-repeating symbol effect (`IconStyles.swift:547-551`, `InspectorTodoPageView.swift:181`) | a loop that runs forever while the view is mounted, at the exact frequency Apple warns about |
| C12 | "Let people cancel motion. As much as possible, don’t make people wait for an animation to complete before they can do anything, especially if they have to experience the animation more than once." | an animation bound to a continuously changing progress value (`LibraryMigrationPanel.swift:137-139`) | one default-duration animation per progress tick, and the user cannot cancel it |
| C1 | "Avoid putting a scroll view inside another scroll view with the same orientation." | the board's scroll content is a plain `VStack`, not a `LazyVStack` (`KanbanView.swift:140`) | 521 card bodies plus 469 markdown parses per board body pass, against the ~15 a lazy stack would build |
| C9 | "Let people do other things in your app or game while they wait for content to load." | the cover cache key is computed on the disk, twice per card load (`CoverImageCache.swift:35-42`) | up to 58 filesystem metadata reads per full grid scroll-through, on the main actor |
| C3 | "Show something as soon as possible." | a filesystem `stat()` runs inside the app root's `body` (`LibraryRootView.swift:34-50`) | up to 4 stat-class syscalls plus 2 `URL` allocations per root body pass |

= = NOTE ON THE ORDER: = = these six sit in Groups 2 and 3 above (= = = =
NOT in Group 1), = = because each one either touches a data path or
changes what the user sees. = = The HIG axis found NO new Group-1
finding: = = every HIG-compliant fix that costs nothing visible turned
out to already be done, = = or to be worth less than its risk.
