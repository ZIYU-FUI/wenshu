# 13: B-13 fix EditorPlaceholder wiring (= dead-code bug fix)

## Boss OOB context

Boss 2026-09-02 macOS visual verification (foreground-mode cua capture confirmed):
editor zone has NO top toolbar (= mode toggle / save / expand / close all
missing). Root cause = ticket 04-10 patch landed on EditorPlaceholder struct
(L605), but WorkspaceView kept instantiating the OLD EditorContentPlaceholder
(L523) which was never patched. Boss 9/2 'git grep BEFORE patch' rule
violation surfaced via visual verification.

## What to build

Replace `EditorContentPlaceholder()` with `EditorPlaceholder()` at L279
(ZoneContentView .editor case in v0.28 followup preset) and L487 (same
in v0.25.1 builtinDefault preset). 1-line change per call site.

## Blocked by

None (= bug discovered during macOS visual verification of ticket 01-11 + B-12).

## Status

ready-for-agent (= implemented; needs visual re-verify to confirm toolbar renders)

## Acceptance criteria

- [x] WorkspaceView L279 + L487 instantiate EditorPlaceholder (= ticket 04-10 patched struct)
- [x] EditorContentPlaceholder stays defined (= backward compat; future ticket to delete if unused)
- [x] swift build exit 0
- [ ] macOS foreground-mode cua capture confirms editor zone top toolbar renders (mode toggle + save + expand + close)
- [ ] visual-verify report refreshed after fix

## Iron rules applied

- Rule 11 (State persistence) / Rule 7 (system Button): unchanged
- Boss 9/2 'git grep BEFORE patch' rule: applied retroactively to surface dead-code bug

## Double-axis review

- [ ] Standards axis: English-only body, 0 forbidden vocab
- [ ] Spec axis: ticket 04-10 acceptance criteria (= toolbar visible) now testable after fix
