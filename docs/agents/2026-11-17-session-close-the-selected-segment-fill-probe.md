# The segmented control's selected segment: the fill is measured in a key window

The repo's own probe now measures what fills the SELECTED segment of a
segmented control in a KEY window, and the reading says the SYSTEM
ACCENT (= the theme colour), = not a material. = This session closed the
measurement blind spot that the previous session's probe could not see.

## WHAT WAS MEASURED, AND WHERE THE PREVIOUS PROBE LOOKED

`Tools/wenshu-devtool/probes/segmented_control_material.swift` (= the
probe the previous session landed) reads the native segmented control's
own material on an UNSELECTED cell, = in a window that is never the key
window. = ⇒ That measurement is sound for the question it asks, = and it
is TRUE: = the unselected cell lets the host layer behind it read
through. = ⇒ But it cannot answer the question the app's users see, = and
the two questions have DIFFERENT answers.

The new probe, = `Tools/wenshu-devtool/probes/segmented_control_selected_fill.swift`,
= reads the SELECTED segment of a control that carries the app's
production parameters (= role `.valueSelection`, = size `.small`, =
style `.roundRect`, = border shape `.capsule`, = segment distribution
`.fillEqually`), = over a saturated host layer, = in a window that IS the
key window.

| Reading | darkAqua | aqua |
| --- | --- | --- |
| the SELECTED segment's strip, in a key window | `(6,118,242)` | `(0,111,234)` |
| its distance to the system accent | 14.9 | 23.7 |
| its distance to the host layer's green | 166.1 | 159.9 |
| the SAME strip, in a NON-key window | `(48,163,108)` | `(0,115,61)` |
| an UNSELECTED segment of the SAME key window | `(20,151,89)` | `(0,132,70)` |
| the SAME strip under an opaque accent | `(0,114,249)` | `(0,114,249)` |

⇒ ⇒ ⇒ ⇒ ⇒ THE SELECTED SEGMENT IS THEME-COLOURED: = it reads the
system accent, = and not the host layer showing through. = ⇒ The accent
belongs to the SELECTION: = an unselected segment of the same key window
reads the host layer through, = and so does the selected segment of a
non-key window. = ⇒ And the key state is what does it: = the two arms
differ in the window's key state and in nothing else, = so the
difference between them is what the key state does.

The claim is scoped to THAT control and THAT state. = A differently
configured control, = or another macOS appearance, = is not covered by
these numbers. = This does NOT replace the previous session's numbers:
= that probe measured a different subject (= an unselected cell, = in a
non-key window), = and that subject still reads what it read.

## THE COMMITS (all on `main`, = all mine)

| Commit | What it carries |
| --- | --- |
| `e2e7dafcc` | the probe itself |
| `e44e34efe` | the index row, = the recorded output, = the README invocation line, = and the NFI row |
| `fb8eeea67` | the first review's F1 and F2 fixes |
| `6c499ab1d` | the first review's F3 fix (= the recorded block carries all four arms) |
| `321197105` | the row names the probe's commit after the rebase |

## THE TWO REVIEW ROUNDS, AND WHAT EACH FOUND

Round 1, = card `t_7299fd6b` (= `CHANGES REQUESTED`, = 21 minutes): = the
probe's exit contract was false for three of the five readings it
prints, = the two arms differed in window class and not only in key
state, = the recorded block carried two of the four arms, = and the
card's own body put the sha where `review_gate.py` never reads it.

Round 2, = card `t_9dacb1ff` (= `APPROVED`, = 9 minutes): = the four
gates green on the tip, = F1 proved with six mutations (four of them
the card names, = and two more the reviewer ran), = F2 proved both
structurally (= both arms are `NSPanel`s) and decisively (= flipping
ONLY the key state moves the reading), = F3 proved byte for byte against
the probe's own stdout at the commit the row names, = and the file at
600 lines (= the NFI gate bites at 601).

## THE GATES, RE-RUN ON THE MERGED MAIN

| Gate | Result |
| --- | --- |
| `test_probe_index.py` | 5 passed, 0 failed |
| `nfi-loc-check.py --base 8ea2727be` | every rewritten file's row carries its own count (= 1 row checked) |
| `ci_change_gate.py --base 8ea2727be --check pollution` | no forbidden vocabulary |
| `ci_change_gate.py --base 8ea2727be --check formatting` | no unformatted line |
| the probe, on the merged main | exit 0, = `source_commit: 321197105`, = four arms with `panel_is_key: true` and `probe_took_foreground: false` |

## THE TWO THINGS THIS SESSION DID NOT DO

= = = The production drawing is NOT changed. = = = The parallel branch
`wt/safari-tab-close-2026-11-17` writes the production control file, =
and this session's commits do not write it, = so the two do not collide.
= ⇒ The production fix (= making the selected segment material) is the
NEXT card, = and it reads these numbers instead of re-measuring.

= = = The previous session's closeout document is NOT narrowed here. = =
= It is a landed document, = and a doc-only correction after a landing
takes its own card. = ⇒ Its claim stands as it was written (= about the
cell it measured), = and this document names the boundary between the two
subjects instead.

## WHAT A READER CAN NOW DO

A card that must make the selected segment material reads the numbers
above (= or the probe's own output), = and it knows which subject it is
looking at: = the selected segment in a key window reads the accent, =
and the unselected cell reads the host layer through. = Both are Apple's
own drawing, = and the app's own control draws both.
