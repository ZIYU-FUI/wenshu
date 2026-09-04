refactor(wenshu): v0.34 -- B-22 auto-save on dirty→clean transitions (Apple HIG pattern)

Boss 2026-09-02 feedback on B-21 (= 'auto-save = 自己写的吗, 如果停手 3 秒保存了一次, 然后继续停留, 还会保存吗? 如果每三秒就这么保存一次, 那不是很浪费内存'): the B-21 implementation fired on every keystroke (= cancel + restart Task on each char) which wastes memory creating a fresh Task per char.

This commit replaces B-21's per-keystroke debounce with the Apple HIG
standard auto-save pattern (= matches macOS TextEdit / Pages / Xcode):

  - dirty = true  (= user started editing after a clean state):
    start ONE 3-second Task. The Task fires writeDraftToDisk, then
    sets originalBody = draft (= triggers dirty → false below).
  - dirty = false (= Cmd+S saved, or auto-save Task fired, or user
    discarded changes): cancel the pending Task (= no more writes).

Wiring:
  - .onChange(of: draft) no longer triggers auto-save. It only updates
    the word count (= pure Foundation = microseconds).
  - .onChange(of: isDirty) NEW. Triggers handleDirtyTransition(Bool).
  - EditorEditContent onAutoSaveTrigger callback REMOVED; onDirtyChange
    callback ADDED (= decoupled from Task internals).
  - handleDirtyTransition(Bool) replaces triggerAutoSave().
    - isDirty == true: start Task if autoSaveTask == nil (= at most
      ONE active Task at any time; = no churn regardless of typing
      speed). When Task fires: writeDraftToDisk + originalBody = draft
      (= triggers the false branch below via SwiftUI re-render).
    - isDirty == false: cancel any pending Task (= the document is
      already saved).
  - saveDraft() (= Cmd+S) and the discard button both call
    handleDirtyTransition(false) (= the post-save / post-discard
    state = dirty = false = no more writes).

Result: at most 1 active Task at any time, regardless of typing
speed. Saves exactly once per dirty→clean cycle. No memory churn.
boss Q-A: '如果停手 3 秒保存了一次, 然后继续停留, 还会保存吗?' =
answer is NO (= no more triggers until the user types again).

Apple HIG rationale:
  - Auto-save on dirty→clean = matches TextEdit / Pages / Xcode.
  - Swift 5.5+ Task structured concurrency = automatic cancellation
    (= Apple recommended pattern for debounce + persistence).
  - .onChange(of: isDirty) = right Apple HIG primitive (= state
    transition subscription = single source of truth for save
    intent; = no per-keystroke callback overhead).

Iron rules applied:
- Rule 11: @State autoSaveTask = persistent debounce state.
- Rule 6: no magic numbers (= 3 seconds = explicit comment = boss spec).
- wenshu-apple-api-first: Apple HIG Task + String.write + .onChange =
  Foundation + SwiftUI standard = no third-party debounce lib.
- Boss 9/2 'git grep BEFORE patch' rule: applied (= searched for all
  onAutoSaveTrigger callers before removal = 1 in WorkspaceView).
- AGENTS.md hard rule: English-only commit body; 0 forbidden vocab.

Verified: swift build exit 0 (24.14s).
