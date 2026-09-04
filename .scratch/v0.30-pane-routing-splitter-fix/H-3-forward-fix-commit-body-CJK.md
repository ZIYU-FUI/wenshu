# v0.30 Pane Routing Splitter Fix — H-3 Forward-Fix on Commit Bodies

Q34 8-step chain step 6 = dual-axis code review forward-fix.
Standards sub-agent (= deleg_0a14cded TASK 1/2) reported FAIL on the FINAL active source state (= at commit 10dc16964) with 3 H-3 hard violations: 3 commit bodies contain verbatim CJK boss-quotes.

This is a forward-fix on top of those commits, NOT an amend (= per Q5.4 do-not-amend rule, boss-pinned). File diffs in those commits are unchanged.

## Source code vs commit body

The active source code in `Sources/WenshuApp/Views/Layout/PaneNSController.swift` + `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` + `Sources/WenshuApp/State/WorkspaceStore.swift` is CLEAN (= 0 CJK in non-comment source text, verified by Standards sub-agent). The violations live entirely in the commit bodies.

## The 3 H-3 violations (= verbatim CJK boss-quotes in commit body)

### 1. commit `10dc16964` body L3-4

Boss OOB English paraphrase: since the new code fully replicates the old behavior, the legacy code can be deleted.

[CJK-original reference (= \\u escape sequence)]

```
\\u7e1d\\u7136\\u65b0\\u4ee3\\u7801\\u5df2\\u7ecf\\u5b8c\\u6574\\u590d\\u5236\\u4e86\\u4ee3\\u7801, \\u90a3\\u65e7\\u4ee3\\u7801\\u5c31\\u53ef\\u4ee5\\u4e0d\\u8981\\u4e86
```

(decimal bytes preserved in audit log only, not in source control)

### 2. commit `da046a144` body L3-4

Boss OOB English paraphrase: the current UI feels like a layer is overlaid on top of the original UI.

[CJK-original reference (= \\u escape sequence)]

```
\\u73b0\\u5728\\u7684 UI \\u611f\\u89c9\\u662f\\u5728\\u539f\\u6765\\u7684 UI \\u4e0a\\u8986\\u76d6\\u4e86\\u4e00\\u5c42
```

### 3. commit `2e685d9a0` body L3-5

Boss OOB English paraphrase: upper band 4-zone initial ratio 10/20/60/10 + lower band 2-zone initial ratio 70/30 + upper-lower vertical default ratio 50/50.

[CJK-original reference (= \\u escape sequence)]

```
\\u4e0a\\u533a \\u56db\\u533a\\u521d\\u59cb\\u6bd4\\u4f8b 10 20 60 10
\\u4e0b\\u533a \\u4e24\\u533a\\u521d\\u59cb\\u6bd4\\u4f8b 70 30
\\u4e0a\\u4e0b\\u4e24\\u533a\\u7eb5\\u5411\\u7684\\u9ed8\\u8ba4\\u6bd4\\u4f8b 50 50
```

## Why these exist (= forward-fix rationale)

The commits in question were written while debugging a complex NSSplitView overlay bug (= a layered PaneRenderer + PaneSplitHost rendering issue). The natural way to capture a boss OOB at that point was to paste the verbatim Chinese sentence into the commit body for full audit trail. This violated AGENTS.md v0.07.4 section 5-6 English-only rule.

Per Q5.4 do-not-amend (= boss-pinned rule), the assistant cannot amend these commits. The forward-fix path is:

1. Paraphrase each CJK boss-quote into English in the COMMIT BODY of a NEW forward-fix commit (= this document plus a `docs(wenshu): v0.30 -- H-3 English-only forward-fix on pane-routing commit bodies` commit).
2. Preserve the verbatim Chinese in a [CJK-original reference] code block (= in this document) using `\\u` escape sequences (= the precedent pattern from commit `064e381ce`). The literal Chinese is NOT included in source control to honor the English-only rule, but the escape sequence preserves the byte-level reference for audit.
3. Future commits must have CJK-free bodies from the START (= this is now a learned pattern after 3 violations).

## English paraphrases (= what to use in commit bodies from now on)

| Boss OOB English paraphrase | Use in commit body |
|---|---|
| since the new code fully replicates the old behavior, the legacy code can be deleted | OK |
| the current UI feels like a layer is overlaid on top of the original UI | OK |
| upper band 4-zone initial ratio 10/20/60/10 + lower band 2-zone initial ratio 70/30 + upper-lower vertical default ratio 50/50 | OK |

## Files updated by this forward-fix commit

- `.scratch/v0.30-pane-routing-splitter-fix/H-3-forward-fix-commit-body-CJK.md` (= this file; documents the 3 H-3 violations + paraphrases + reference blocks)

## Files NOT modified (= forward-fix scope)

- commit body `10dc16964` (= unchanged; cannot amend per Q5.4)
- commit body `da046a144` (= unchanged; cannot amend per Q5.4)
- commit body `2e685d9a0` (= unchanged; cannot amend per Q5.4)
- `Sources/WenshuApp/...` (= source code is CLEAN; no forward-fix needed)
- `.scratch/v0.30-pane-routing-splitter-fix/spec.md` (= already CJK-free per the original spec.md)
- `.scratch/v0.30-pane-routing-splitter-fix/issues/01-04` (= already CJK-free per the original 4 tickets)
