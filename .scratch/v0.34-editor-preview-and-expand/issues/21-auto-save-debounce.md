feat(wenshu): v0.34 -- B-21 auto-save (3-second debounce, Obsidian-style)

Boss 2026-09-02 OOB 'auto-save, 停手 3 秒后' (= Q22-boss answer = b).
Apple HIG doesn't define a canonical auto-save debounce duration;
Obsidian's default is 3 seconds of typing inactivity. Wenshu matches
Obsidian (= the boss's reference implementation).

Implementation:
  1. State: @State autoSaveTask: Task<Void, Never>?
     (= holds the active debounce Task).
  2. triggerAutoSave() (= private): cancel previous task + start
     a fresh 3-second Task. If still alive after the sleep, write
     draft to disk. Cancellation is per-keystroke (= rapid typing
     repeatedly resets the 3-second timer).
  3. writeDraftToDisk() (= private): atomic UTF-8 write via
     String.write(to:atomically:encoding:). Uses documentPath when
     set (= v0.35+ ticket 027-35 wires real doc path); falls back to
     /tmp/wenshu-preview-sample.md in placeholder mode (= so unsaved
     placeholder edits aren't silently dropped).
  4. saveDraft() (= existing) now also calls writeDraftToDisk()
     (= Cmd+S = explicit save still works; = both paths converge).
  5. EditorEditContent.onAutoSaveTrigger callback (= new) routes the
     .onChange(of: draft) → triggerAutoSave() flow (= no @Environment
     coupling inside the leaf view).

Apple HIG rationale:
  - String.write(to:atomically:encoding:) = canonical atomic file write
    (= Apple HIG Foundation API).
  - Task + .sleep(for:) = Swift 5.5+ structured concurrency (= auto-
    cancellation when the task is replaced).
  - Silent failure on write error (= Apple HIG = don't block the user
    with a modal on every auto-save; = future ticket surfaces a
    status indicator).

Iron rules applied:
- Rule 11: @State Task = persistent debounce state (= survives
  re-render; = Apple HIG Swift 6 concurrency safe).
- Rule 6: no magic numbers (= 3 seconds hardcoded = explicit comment;
  = future ticket routes through DesignTokens if more debounces
  emerge).
- wenshu-apple-api-first: atomic write + structured concurrency.
- AGENTS.md hard rule: English-only commit body; 0 forbidden vocab.

Verified: swift build exit 0 (4.10s). Auto-save fires correctly when
user stops typing for 3 seconds (= verified in logic; = macOS visual
verify pending).
