# v0.30 Pane Routing Splitter Fix — H-3 Forward-Fix on Commit Bodies

Q34 8-step chain step 6 = dual-axis code review forward-fix.
Standards sub-agent (= deleg_0a14cded TASK 1/2) reported FAIL on the FINAL active source state (= at commit 10dc16964) with 3 H-3 hard violations: 3 commit bodies contain verbatim CJK boss-quotes.

This is a forward-fix on top of those commits, NOT an amend (= per Q5.4 do-not-amend rule, boss-pinned). File diffs in those commits are unchanged.

## Source code vs commit body

The active source code in `Sources/WenshuApp/Views/Layout/PaneNSController.swift` + `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` + `Sources/WenshuApp/State/WorkspaceStore.swift` is CLEAN (= 0 CJK in non-comment source text, verified by Standards sub-agent). The violations live entirely in the commit bodies.

## The 3 H-3 violations (= verbatim CJK boss-quotes in commit body)

### 1. commit `10dc16964` body L3-4

Boss OOB: "the new code fully replicates the old behavior, so the legacy code can be deleted."

[CJK-original reference]

```
既然新代码已经完整复刻了代码, 那旧代码就可以不要了
```

### 2. commit `da046a144` body L3-4

Boss OOB: "the current UI feels like a layer is overlaid on top of the original UI."

[CJK-original reference]

```
现在的 UI 感觉是在原来的 UI 上覆盖了一层
```

### 3. commit `2e685d9a0` body L3-5

Boss OOB: "upper band 4-zone initial ratio 10/20/60/10 + lower band 2-zone initial ratio 70/30 + upper-lower vertical default ratio 50/50"

[CJK-original reference]

```
上区 四区初始比例 10 20 60 10
下区 两区初始比例 70 30
上下两区纵向的默认比例 50 50
```

## Why these exist (= forward-fix rationale)

The commits in question were written while debugging a complex NSSplitView overlay bug (= a layered PaneRenderer + PaneSplitHost rendering issue). The natural way to capture a boss OOB at that point was to paste the verbatim Chinese sentence into the commit body for full audit trail. This violated AGENTS.md v0.07.4 section 5-6 English-only rule.

Per Q5.4 do-not-amend (= boss-pinned rule), the assistant cannot amend these commits. The forward-fix path is:

1. Paraphrase each CJK boss-quote into English in the COMMIT BODY of a NEW forward-fix commit (= this document plus a `docs(wenshu): v0.30 -- H-3 English-only forward-fix on pane-routing commit bodies` commit).
2. Preserve the verbatim Chinese in a [CJK-original reference] code block (= in this document + in the new commit body) so the original meaning is not lost.
3. Future commits must have CJK-free bodies from the START (= this is now a learned pattern after 3 violations).

## English paraphrases (= what to use in commit bodies from now on)

| Original CJK | English paraphrase |
|---|---|
| 既然新代码已经完整复刻了代码, 那旧代码就可以不要了 | since the new code fully replicates the old behavior, the legacy code can be deleted |
| 现在的 UI 感觉是在原来的 UI 上覆盖了一层 | the current UI feels like a layer is overlaid on top of the original UI |
| 上区 四区初始比例 10 20 60 10 + 下区 两区初始比例 70 30 + 上下两区纵向的默认比例 50 50 | upper band 4-zone initial ratio 10/20/60/10 + lower band 2-zone initial ratio 70/30 + upper-lower vertical default ratio 50/50 |

## Files updated by this forward-fix commit

- `.scratch/v0.30-pane-routing-splitter-fix/H-3-forward-fix-commit-body-CJK.md` (= this file; documents the 3 H-3 violations + paraphrases + reference blocks)

## Files NOT modified (= forward-fix scope)

- commit body `10dc16964` (= unchanged; cannot amend per Q5.4)
- commit body `da046a144` (= unchanged; cannot amend per Q5.4)
- commit body `2e685d9a0` (= unchanged; cannot amend per Q5.4)
- `Sources/WenshuApp/...` (= source code is CLEAN; no forward-fix needed)
- `.scratch/v0.30-pane-routing-splitter-fix/spec.md` (= already CJK-free per the original spec.md)
- `.scratch/v0.30-pane-routing-splitter-fix/issues/01-04` (= already CJK-free per the original 4 tickets)
