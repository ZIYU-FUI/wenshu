# Session close — the card's menu removes a moving cover, and the card stops showing it (2026-11-19)

## 1. What was asked

Three requirements, in the owner's own words, in the order they arrived.

1. A right-click menu on a material-column card gets an item that removes
   the card's **moving** cover.
2. The owner then corrected the scope: **if the user has not switched
   "automatic cover" on, the menu's generation options must not appear.**
   The switch governs what the app may create.
3. The owner then found the real defect by using it: **the removal deleted
   the file, and the card went on showing the motion.**

The third requirement is the one this record is mostly about, because it is
the one the first two could not have satisfied on their own.

## 2. What the tree shipped before

The cover block was written **twice** — once for a reference card, once for
a book-document card — in `PreviewPaneCard+Body.swift`, and each copy
offered the same two items in the same shape.

- **No clip removal existed at all.** The only removal in the tree was
  `CardCoverService.removeCover(forKey:)`, and it removed the **whole**
  cover directory: the moving clip AND the still picture. So the one
  removal on offer took the picture with the clip.
- **A card that already carried a clip was offered a second clip.** The
  menu's generation branch asked only "is there a cover?", not "is there
  already a moving cover?", so a card the user had already paid for was
  offered another one.
- **The generation items ignored the switch.** The automatic-cover switch
  (`CoverAutoCoverStore`, the `wenshu.cover.auto.enabled` UserDefaults
  key) governed the *automatic* pass only. Nothing in the card's menu read
  it, so with the switch off the menu still offered to spend an allowance
  the user had not asked for.
- **Nothing told a card that a cover changed.** Making a clip has an
  in-flight phase (`isMakingVideo`) that a card can observe, and the card
  watches it. Removing a clip has **no phase** — the file is gone and
  nothing happens. The card's own cover lookup
  (`coverEntry(for:)` in `PreviewPaneGrids.swift`) reads a cached entry
  and returns it, so the card went on drawing a motion whose file no
  longer existed.

## 3. What the change does

| File | Change |
| --- | --- |
| `Sources/WenshuApp/Features/Editor/View/PreviewPaneCardCoverMenu.swift` | **new.** `CardCoverMenu` = the cover items one card's menu offers, as a RULE. `extension Card { coverMenu, hasDynamicCover }` |
| `Sources/WenshuApp/Features/Cover/Model/CardCoverService.swift` | `removeVideo(forKey:)` — deletes `cover.mp4`, evicts the cache entry, clears the record's clip, **keeps `cover.heic`** |
| `Sources/WenshuApp/Features/Cover/Service/CoverVideoService.swift` | `removeVideo(for:)` — the service-level removal, and it publishes to the signal on **both** paths |
| `Sources/WenshuApp/Features/Cover/Service/CoverGenerationService.swift` | `removeCover(for:)` publishes to the same signal |
| `Sources/WenshuApp/Features/Cover/Model/CoverChangeSignal.swift` | **new.** `shared` + `revision` + `noteCoverChanged()` — a cover changed on the disk, as a count a view can watch |
| `Sources/WenshuApp/Features/Editor/View/PreviewPaneGrids.swift` | the card's one cover lookup reads the signal's revision |
| `Sources/WenshuApp/Features/Editor/View/PreviewPaneCard+Body.swift` | the two copies of the cover block become **one** builder |
| `Sources/WenshuApp/Features/Editor/View/PreviewPaneCard.swift` | the menu's closures and the switch read |
| `Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift` | the four card-building sites wire the removal |
| `Sources/WenshuApp/Resources/Localizable.xcstrings` | `cover_context_menu_remove_dynamic` = `Remove moving cover` (en) and the Chinese label for the same item (zh-Hans) |
| `Tests/WenshuAppTests/Cover/View/CardCoverMenuTests.swift` | **new.** the menu's rules, asked without a window |
| `Tests/WenshuAppTests/Cover/View/CoverRemovalRefreshTests.swift` | **new.** the card asks the disk again after the removal |
| `Tests/WenshuAppTests/Cover/Model/CardCoverServiceTests.swift` | the removal leaves the picture |
| `docs/agents/nfi.md` | four rows for the four new files |

### The three rules the menu now states

1. An item that **MAKES** a cover appears only while the automatic cover
   switch is on. The switch is the user's answer to "make covers for me",
   and a menu that offers to spend an allowance the user has not asked for
   is noise the user dismisses every time.
2. An item that **REMOVES** a cover appears whenever there is something to
   remove, whatever the switch says. **The switch governs what the app may
   CREATE, never what the user may DELETE.**
3. "Make it move" appears only when the card has a picture and no clip. A
   card that already carries a clip is one the user has already paid for,
   so the menu offers the removal instead of a second clip.

### Why the signal is not the library broadcast

`CoverChangeSignal` is its own thing, and the choice is the point of the
third requirement. The library broadcast (`.wenshuLibraryDidChange`)
re-reads every document, and the automatic cover pass then asks about each
one — so a removal that cost the user nothing would **spend a generation**
putting back what the user had just taken away. The signal says "this
cover changed" and nothing else, so a removal stays free.

The removal publishes on the **failure** path too, and that is deliberate:
the file may already be gone when the record write fails, so the disk's
state HAS changed even though the call threw.

## 4. The three claims, and how each was proved

The card named three suites and two mutation arms. The reviewer re-derived
every claim on the round-2 tip in the card's own worktree on a clean tree
(`t_c32629b5`, comment 1875), with its own commands:

| suite | printed | exit |
| --- | --- | --- |
| `swift test --filter "CardCoverMenuTests"` | `Test run with 9 tests in 1 suite passed after 0.001 seconds.` | 0 |
| `swift test --filter "CardCoverServiceTests"` | `Test run with 8 tests in 1 suite passed after 0.030 seconds.` | 0 |
| `swift test --filter "CoverRemovalRefreshTests"` | `Test run with 1 test in 1 suite passed after 1.350 seconds.` | 0 |

The two arms, each run alone, each restored after:

- **(a)** delete `_ = CoverChangeSignal.shared.revision` from
  `coverEntry(for:)` in `PreviewPaneGrids.swift` → `CoverRemovalRefreshTests`
  **FAILS** at its `after != nil` expectation.
- **(b)** silence `noteCoverChanged()` → the same expectation **FAILS**.

The refresh test's witness is `CoverEntryCache`: after the removal evicted
the entry, an entry that is **held again** is an entry a card re-read, and
the answer it re-read carries the picture and no clip. The removal is asked
for through a **different** `CoverVideoService` than the pane holds
(`CoverVideoService.live()` returns a fresh instance), so a signal scoped
to one service instance fails the test.

## 5. The three sha's, and what each one is

This scope's work exists as three commits, and they are **not** three
stacked commits — two of them are the same commit at three bases.

| sha | parent | what it is |
| --- | --- | --- |
| `23728909b78768d3cad54d2ecd98702d3c304e32` | `31b5c3929a` | the **round-1** tip: the menu and the removal, **without** the refresh fix. Approved by `t_ce7c0c11` on this sha. |
| `345e33338cd497b1a49c0a9e8cbb378773f7921b` | `b0ba0e0e2b` | the **round-2** tip: the same work **amended** with the refresh fix, rebased onto a main that had moved. Approved by `t_c32629b5` on this sha. |
| `b5f34f59e0831324e3e5d3806d85f76a3fc3046e` | `876a08f300` | the **LANDED** commit: the round-2 content, rebased once more onto a newer main. |

⇒ **THE LANDED COMMIT'S COVER AND TEST CONTENT IS BYTE-IDENTICAL TO THE
REVIEWED TIP.** The command that prints it:

```
git diff --stat 345e33338c b5f34f59e0 -- \
  Sources/WenshuApp/Features/Cover \
  Sources/WenshuApp/Features/Editor/View/PreviewPaneCardCoverMenu.swift \
  Sources/WenshuApp/Features/Editor/View/PreviewPaneCard+Body.swift \
  Sources/WenshuApp/Features/Editor/View/PreviewPaneGrids.swift \
  Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift \
  Sources/WenshuApp/Features/Editor/View/PreviewPaneCard.swift \
  Tests/WenshuAppTests/Cover
```

It prints **nothing**. The whole-tree diff between the two shas is
`sibling` work only (= the sidebar tree, the tab strip, a sibling's
closeout record, and the registry rows those rows moved), so the review's
verdict still covers the change that landed.

**⇒ AND THE PATCH-ID IS NOT THE PROOF, THE FILE LIST IS.** The two shas
have different `git patch-id` values, because a patch-id is a function of
the diff and the two commits sit on different bases. The cover files'
identity is the claim that matters, and the command above is what prints
it.

## 6. Gates on the MERGED tree

Run on the **merged** tree, not on the branch that was measured before the
merge. The tree moved under this scope twice while it was in review (a
sibling's sidebar commit and a sibling's tab-strip commit), so every
number below is a pair: the base and the tip it was read from.

The gate was run in a **throwaway detached worktree** at the merged tip,
because the shared checkout carries an untracked `scratch/` directory and
`pre_review_gate.py` refuses a dirty tree before it measures anything
(= `pre_review_gate: FAILED / the worktree is dirty, = so a gate would
measure the WRONG tree: ?? scratch/`). The recipe:

```
git worktree add --detach <probe> <merged-tip>
cd <probe> && python3 Tools/wenshu-devtool/pre_review_gate.py \
  --base b5f34f59e0831324e3e5d3806d85f76a3fc3046e \
  --card <the card body>
```

⇒ **A DOC THAT COUNTS ITSELF MUST NOT PUBLISH THE COUNT AT ALL.** The
numbers this record publishes about **other** files are reprintable from
any tree the reader lands on. The numbers about **this** file are not:
the registry row that names this doc quotes this doc's own line count, and
every correction round lengthens the sentences that carry it, so a
self-count is stale in the commit that writes it. ⇒ What is published here
is the **invariant plus the two commands that print it**:

```
grep -c "" docs/agents/2026-11-19-session-close-the-card-menu-removes-a-moving-cover.md
# and the LOC cell that docs/agents/nfi.md carries for this file
# MUST BE EQUAL, read from the tree the reader is standing on.
```

⇒ ⇒ And the same rule applies to the line numbers of the files this
record cites: **cite §N or the bullet's NAME, never "at line 207"**,
because the file moves under the sentence.

## 7. The shipped binary, and the owner's look — GIVEN

AGENTS.md §7.7: for a UI-touching ticket the owner looks at the running
build in person. **The owner's verdict on the running build is GIVEN**
(= 2026-11-19, "no problem"), and the disk carries the same verdict
independently of the owner's word.

- **Which build**: `/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app`,
  rebuilt from the merged `main` with `bash Scripts/build-app.sh` (= exit
  0), adhoc-signed, launched with a plain `open` (= never `open -n`: a
  second instance of the same bundle id aborts BOTH processes).
- **What the owner did**: right-clicked a card that carried a moving cover,
  chose the removal item, and confirmed the card changed immediately and
  did not spring back. The owner then regenerated a cover.
- **The disk's own record of the removal**, read from the owner's library
  (`~/Documents/anbaiqiang.ws/assets/covers/`):

| file | before | after |
| --- | --- | --- |
| `cover.mp4` | 260,377 bytes (mtime 11-19 15:06:43) | **absent** |
| `cover.heic` | present | **present, 46,683 bytes, mtime 10-26 16:12:55** (= untouched) |
| `cover.json` `clipStatus` | `clipReady` | **`clipNone`** |
| `cover.json` `clipAttemptAt` | `2026-11-19T07:06:43Z` | **`null`** |
| `cover.json` `status` | `staticReady` | **`staticReady`** |
| `cover.json` `updatedAt` | `2026-11-19T07:06:43Z` | `2026-11-19T10:36:03Z` |

⇒ **THE STATIC COVER SURVIVED THE REMOVAL.** That is the requirement's own
shape: the removal takes the clip and leaves the picture.

⇒ ⇒ **THE APP'S OWN LOG LINES UP WITH THE DISK.** The shipped app's log
for that window: the card's clip player starts (= `FigVideoReceiverCreate`),
then the removal writes `cover.json`, then the app exits. **Two seconds
separate the removal from the exit.**

⇒ ⇒ ⇒ **AND THE REGENERATION IS RECORDED AS UNCONFIRMED, NOT AS DONE.**
The owner reports regenerating a cover after the removal, and **no file
anywhere corroborates it**: a `find` over the whole library and over every
`cover.mp4` on the machine finds nothing written after the app exited, no
`cover.mp4` newer than the removal, and the tested card's `clipAttemptAt`
is `null`. Two facts explain it without touching this scope: a video
generation takes minutes and the app quit **two seconds** after the
removal, and the provider's video quota was already exhausted in that
window (= `providerFailure(... quotaExhausted, providerSlug: "minimax-cn")`).

⇒ ⇒ ⇒ ⇒ **AND THE REGENERATE PATH IS NOT WHAT THIS CARD CHANGED.** This
scope changed the **removal** path (= the menu item, the service call, the
refresh signal). The generate path's own code is unchanged, and its
availability is governed by the switch (= `wenshu.cover.auto.enabled` = 1,
on). A generation that did not land is a **provider and quota** matter, not
a regression of this card. ⇒ **The owner's "no problem" is a verdict on the
removal, and the removal is what this card shipped.**

⇒ ⇒ ⇒ ⇒ ⇒ **THE BINARY CARRIES THE CHANGE** (= the strings are in the
shipped executable, so the running app is this tree and not an older one):

```
strings -a build/Wenshu.app/Contents/MacOS/WenshuApp | grep -c CoverChangeSignal
strings -a build/Wenshu.app/Contents/MacOS/WenshuApp | grep -c 'video removal failed'
plutil -extract 'cover_context_menu_remove_dynamic' raw \
  build/Wenshu.app/Contents/Resources/zh-Hans.lproj/Localizable.strings
```

⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **APP LEFT RUNNING: yes**, from the merged build. The
instance was restarted after the owner's session ended it, so the app the
owner can still open is the landed one.

## 8. What this scope cost on the board

Two review cards, and the board's own rows are the cost:

| card | runs | rate-limited | wall | verdict |
| --- | --- | --- | --- | --- |
| `t_ce7c0c11` (round 1) | 8 | **7** | 3397 s = 56.6 min | `approved` on `23728909b` |
| `t_c32629b5` (round 2) | 1 | 0 | 979 s = 16.3 min | `approved` on `345e33338c` |

⇒ **Seven of round one's eight runs were `rate_limited`** (= the provider
quota wall, = = each ~60 s). The card's real review was its eighth run
(= 272 s). Round two cost one run.

⇒ ⇒ **⇒ AND THE NOTIFICATION THAT CARRIED THE VERDICT WAS SILENTLY
BROKEN, = = WHICH IS A SEPARATE SCOPE.** This scope's first verdict
reached nobody: the card's subscription named a platform the gateway does
not serve, so the row was written and the gateway skipped it on every tick
(= a DEBUG line, = = zero deliveries). The fix and the audit are recorded
in the shared skill tree
(`wenshu-pocock-workflow/references/a-subscription-to-a-platform-the-gateway-does-not-serve.md`),
not here, because **no line of this scope's code changed for it.** ⇒ ⇒ ⇒
⇒ **⇒ ⇒ ⇒ ⇒ AND THE AUDIT CORRECTED ITS OWN FIRST ANSWER.** The first
pass counted "the branch is gone" as "the requirement is undelivered", and
reported 26 requirements lost. **That was wrong.** Every one of those
requirements had landed on `main` under a **different card id and a
different commit** (= e.g. the export's full-width-colon fix = = `b0985f5a9a`,
the broken-pin fix = = `a7c0e289c8`, the chat column's split = = `9fb8ec32e5`
plus `ChatView+KeyboardShortcuts.swift` already in `main`). The number
that survives re-derivation is **zero** requirements lost. ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒
⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ THE LESSON, WHICH IS GENERAL: A DELETED BRANCH IS NOT A
LOST REQUIREMENT.** To ask whether a requirement shipped, ask two
questions: **does the requirement's SUBJECT appear in a commit that is an
ancestor of `main`, and does `main`'s tree carry the behaviour.** A
proxy metric (= "the branch is gone") answers neither.

## 9. Scope's commits, and the ones that are not

| sha | what it is | mine? |
| --- | --- | --- |
| `b5f34f59e0831324e3e5d3806d85f76a3fc3046e` | **the landed commit** (= 14 files, +664/-102) | yes |
| `345e33338cd497b1a49c0a9e8cbb378773f7921b` | the round-2 tip the reviewer approved | yes (= the same content, an earlier base) |
| `23728909b78768d3cad54d2ecd98702d3c3046e` | the round-1 tip the reviewer approved | yes (= the same content minus the refresh fix) |
| `876a08f300d6b2c79eb0a5ae0845b5fcc81b6097` | the landed commit's parent (= a sibling's closeout record) | **no** |
| `b0ba0e0e2b2bcd6f53e7c403f7d836ed5f01a824` | the round-2 tip's parent (= a sibling's sidebar fix) | **no** |
| `31b5c3929ab7b3cd1b25545b267d584eec7a14b6` | the round-1 tip's parent (= a sibling's tab-strip commit) | **no** |

⇒ **The scope's own landed content is ONE commit** (= §7.8's commit
hygiene: one ticket, one commit). The other two shas are that same commit
at two earlier bases, and the review's verdict names them because a
review reads a tree, not an intent.

⇒ ⇒ **BOTH REMOTES CARRY IT.** `origin` and `old-origin` are two
different hosts, and a push that reported success on one says nothing
about the other:

```
git ls-remote origin refs/heads/main
git ls-remote old-origin refs/heads/main
```

Both read the same sha as `main` at the time this record was written. ⇒ The
sha moves as siblings land, so **this record names the commit and its
ancestry, and the reader reads the tip**: `git rev-parse main`.

## 10. Open items left behind

1. **With the automatic cover switch off, the card menu offers no way to
   make a cover at all** (= no generate, no regenerate, no make-it-move).
   The only remaining door is the material column's footer batch action,
   which this scope put out of scope and which was not tested. **The rule
   is deliberate and documented, and the owner has now seen the menu with
   the switch on** (= `wenshu.cover.auto.enabled` = 1 in the owner's own
   preferences). **Open, and it is the owner's call**: if the owner wants a
   card menu that can always make a cover, that is a rule change in
   `CardCoverMenu`, and it is a new card. Raised by the reviewer
   (`t_c32629b5`, comment 1875) as a non-blocking finding, and recorded
   here so it is not lost.
2. **`PreviewPaneGrids.swift`** carries four helpers
   (`coverVideoURL(forReference:)`, `coverVideoURL(forBookDoc:)`,
   `coverImageURL(forReference:)`, `coverImageURL(forBookDoc:)`) with
   **zero callers** in `Sources` or `Tests`. Pre-existing (= not this
   diff), but they are a second, signal-blind door to the very files this
   change invalidates, and they live in the file this change touches.
   Verified still at zero callers on the merged tree. **Owner: a dead-code
   sweep, not this scope.**
3. **The provider's video quota was exhausted** in the window the owner
   tested in (= `quotaExhausted` on `minimax-cn`), so the regeneration the
   owner describes could not land. **Not a defect in this scope**, and not
   a card either: it is the provider's allowance, and the owner's standing
   instruction is that covers are generated later.

## 11. This record's own rounds

- **Round 1**: this document. Every number in it was read from the tree or
  from the board's own rows; the two "before" numbers in §7's table were
  read from the library **before** the owner's action and the "after" ones
  **after** it, and the pair is what §7 publishes. §8's audit number was
  **corrected before this record was written** (= the first answer said 26
  requirements were lost, and the re-derivation says zero), because a
  record that publishes a wrong number is the same defect class as the
  review findings this scope was reopened for. ⇒ The registry row for this
  file quotes this file's line count, and that count is written **after**
  the prose is final and **in the same commit** (= a row that carries a
  stale count reads as a defect, and two commits leave the tree red in
  between).
