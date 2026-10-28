# 2026-10-28 Chat Transcript Bottom Anchoring — Closure

Status: merged to main (= commit `4da695e6d42b`), pushed to `origin` and
`old-origin`.
Worktree: `project/t_dc8f59da-t2-the-chat-transcript-loses-the-last-li`
(= cleaned up post-merge).
Tests: `swift test --filter ChatTranscriptScrollTests` = 3/3 pass (= the
card's gate), deterministic across 3/3 runs.
Build: clean (= `swift build` exits 0).
Review: approved by `wenshu-review` (= round 2, execution lens; = the
independent verdict is on the card `t_dc8f59da`).

## Boss intent (= the only spec that matters)

> A point that can be improved: when the window's width changes, the
> chat's conversation does not keep showing the last line of the output
> text (= it scrolls back to the earliest message). This can be handled.

One requirement: the chat transcript keeps showing the LAST line of the
output when the window's width changes.

## Symptom

A resize of the chat column re-wrapped the message bubbles (= the content
grew taller) and the transcript fell back to earlier messages: the last
line of the output went below the viewport, and the user had to scroll
down again after every resize.

## Root cause

A GAP between two edges, not a missing scroll rule.

The transcript padded its content on all sides, so the content's bottom
edge sat BELOW the last message's bottom edge. The chat's own "keep
showing the last line" rule scrolls the last MESSAGE to the bottom
(`proxy.scrollTo(last.id, anchor: .bottom)`), which therefore landed that
gap short of the maximum offset (= 8 pt, = `DesignTokens.spacingStandard`).

A transcript that is short of the maximum offset is not anchored:
`defaultScrollAnchor(.bottom)` holds the bottom only while the offset
IS the maximum. So the next re-wrap (= a narrower column, the bubbles
re-wrapping, the content growing) grew the content beneath a transcript
that no longer followed it, and the last line fell below the viewport.

Measured on the real `ChatView` (= the app's own view in a hosted window,
read through AppKit's scroll geometry):

| | content's height | offset | the bottom |
| --- | --- | --- | --- |
| before the fix | 1639 -> 2119 | 1583 | 1695 (= 112 pt short) |
| after the fix | 1631 -> 2791 | 2375 | 2375 (= exact) |

The independent reviewer's own AppKit probe agrees: with the fix the
settled offset equals the scroll view's TRUE maximum (= short = 0 at rest
and after the resize); without it, short = 8 at rest and 216 after the
resize.

## Fix

The transcript's bottom padding moves out of the content and into the
content margin below it (= the strip the input bar occupies), so:

* the content's bottom edge MEETS the last message's bottom edge, so
  the chat's own scroll lands ON the maximum offset, where the bottom
  anchor holds, and
* the space is not lost: the gap between the last message and the input
  bar is unchanged (= 92 pt before and after, = measured by the reviewer
  on both trees).

No scroll rule changed: `scrollTo(last.id, .bottom)`,
`scrollTo(newLatestID, .top)` and `defaultScrollAnchor(.bottom)` are
byte-identical to the merge base.

## Why NOT a third scroll rule (= the road not taken)

A third rule that watches the content's height and re-asserts the bottom
anchor was built and measured first, and it does not work. The transcript
is a lazy stack, so its content height is only known for the
materialized rows, and the height swings (= measured: 2503 -> 1799 ->
2516 -> 1687 -> 2487 -> 1703) as the rows materialize and unmaterialize.
Every re-assert scrolls to the last materialized row, which changes what
is materialized, which changes the height again: the rule fought the lazy
stack and left the offset short (= 1583 of a bottom of 1695, = the same
as without the rule). Removing the gap fixes the anchoring itself, which
was the one thing that was wrong.

## Tests

`Tests/WenshuAppTests/Chat/ChatTranscriptScrollTests.swift` drives the
REAL `ChatView` (= the app's own view, not a mock of it) in an
`NSHostingView` in a window, with a `ChatViewModel` whose
`providersConfigured` returns true and whose `repository` returns a fixed
list of long messages (= no keychain, no SwiftData, no network), and
asserts:

1. the transcript reaches its last line after the history loads,
2. a stepped width change (= the eleven widths a window drag passes
   through) leaves it showing its last line, and
3. the offset follows the content's height (= the anchoring invariant).

The baseline is measured, not assumed: with `ChatView.swift` reverted to
the merge base, the suite is RED (= 2 of 3 fail; = the reviewer measured
the same on its own).

## Open items

1. **AGENTS.md 7.7 (= the boss's in-person look at the running build).**
   The measured gap between the last message and the input bar is
   byte-for-byte unchanged (= 92 pt), and the transcript's anchoring is
   proved by the offset landing exactly on the scroll view's true
   maximum, so the visual delta is nil. The chat's CONTENT still cannot
   be seen on this machine without a provider key in the keychain (= the
   chat renders its empty state without one), = the one thing the boss
   cannot eyeball here.
2. A reader who scrolled up to read history is still pulled to the
   bottom when the content's height changes (= `defaultScrollAnchor(.bottom)`'s
   own behaviour, = it was already so before this change, = the
   transcript's content rule does the same on every new message). This
   card did not change it.
