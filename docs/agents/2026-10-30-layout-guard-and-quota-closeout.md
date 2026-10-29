# Layout guard and quota naming: the session closeout

## What landed

Four cards, all on `main`, all with an independent approving verdict from
the profile that did not implement them:

- `87ba16e2ef` = the merge of the reviewed resize-guard fix
  (`f4f9cddab6`, `8ac726eea1`, `124e84b8db`): the divider is positioned
  once per settle instead of once per frame, and the resize latch is
  released when a resize ends on the share.
- `9e0297f8c6` = a spent Token Plan allowance is not a transient 429.
- `a02fac4142` = the Cover classifier reads the provider's code out of the
  body when the caller has none.
- `6dfa19522d8e` = this session's records.

## What the fixes changed, in the user's terms

- Double-clicking the title bar to zoom, or dragging the window wider, no
  longer kills the app (AppKit's runaway-layout guard).
- In the top-bottom arrangement the chat pane keeps its height and a
  divider drag upwards survives, so the chat is no longer squeezed to its
  minimum and the drag is no longer eaten. That symptom and the crash were
  one defect: the split was written to on every frame of a resize.
- A refusal that means "the plan's allowance is spent" is reported as a
  quota failure on the chat path and is no longer retried by the agent
  path, on either side of the package boundary.

## The gates, on the merged tree

`swift build` exits 0, and the suites that own the touched files:
`EditorChatNSControllerTests` 46, `CoverProviderFailureTests` 22,
`ConversationLoopRunTurnTests` 13, `ChatTranscriptScrollTests` 3,
`AppStateCloseTabTests` 13, `LabelSegmentedControlSelectionTests` 7 = 104
tests, 0 failures.

## Where this is (the durable fact)

Every commit above, and this record, are ancestors of `refs/heads/main` on
BOTH remotes, checked with `git merge-base --is-ancestor` after reading
each remote back with `git ls-remote`. The tips are not quoted: they move
as other lanes land.

## The open item, on purpose

**The launch-time crash was not measured, and the boss closed that line.**
What the attempt did establish is worth keeping: the app HANGS at launch,
1598 of 1598 samples blocked in `open()` inside
`contentsOfDirectoryAtURL`, called from `loadShelves()` during
`applicationWillFinishLaunching`. That hang is why the launch arm read
`windows=0 alive=True` on every trial, = the arm never reached the layout
that trips AppKit's runaway-layout guard, so its zero crashes proved
nothing. Two things follow: the startup path's blocking read is a defect
in its own right, and an arm that reports zero windows must sample the
process before anyone blames its seeding. Both are written into the
triage skill.

## What the cards' history says about the process

- 17 runs across four cards, and 6 of them died on the provider's quota
  wall. Each of those cost about a minute, so the wall is the common
  killer and not the expensive one: the lever is the card's length, not
  the cap.
- The landing card spent one extra review round because the card body
  asked the closure record to quote the remotes' tips, and a tip is stale
  within minutes. The rule now in the shared skill: a closure record
  states ancestry, and byte-identity only over the files it names.
- A card that replaces a deleted card carries the dead card's uncommitted
  work as CODE, never as a path: the deleted card's worktree is pruned
  with the card.
