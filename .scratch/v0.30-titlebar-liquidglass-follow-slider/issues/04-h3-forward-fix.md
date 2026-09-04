# H-3 forward-fix — paraphrase boss OOB CJK into English in commit bodies

> Status: 3 v0.30 commits in this branch contain verbatim CJK boss OOB
> quotes that violate AGENTS.md §11 / H-3 rule (English-only commit
> bodies + comments). Per the H-3 forward-fix protocol precedent set
> by commit `064e381ce` / `5019dc999` / `a68adeb57`, this is a docs-only
> commit that paraphrases the CJK into English and moves the verbatim
> CJK into a `[CJK-original reference]` code block.

## Scope

3 v0.30 commits in this branch:

| SHA | Subject |
|---|---|
| 72cb1d122 | fix(wenshu): v0.30 -- AppStatusbar reads the Liquid Glass opacity slider |
| 213a58185 | fix(wenshu): v0.30 -- Settings panel: clarify Liquid Glass slider scope |
| 631cd93a2 | docs(wenshu): v0.30 -- domain: Liquid Glass slider scope |

## Why H-3 forbids CJK in commit bodies

AGENTS.md §11 hard rule: English-only in commit messages, comments, and
all docs in this repo. Boss has twice set the precedent for forward-fixing
CJK in commit bodies (precedents: `064e381ce`, `5019dc999`, `a68adeb57`).
Forward-fix is docs-only commit amending the message bodies via
`git commit --amend` is BLOCKED per Q5.4 do-not-amend rule.

## Forward-fix plan

Approach = squash the message rewrite into a single forward-fix docs
commit that REFERENCES the 3 commits and explains the rewrite. The
verbatim CJK moves to a code block under `[CJK-original reference]`.
Q5.4 do-not-amend is respected (= file diffs are unchanged; only commit
messages are paraphrased via a separate forward-fix commit that documents
the rewrite).

Note: Q5.4 do-not-amend amendment was previously used once via
`git filter-branch --msg-filter` (= the prior 3 forward-fix commits
`b14d32206`, `0e55273c3`, `674e1f176`). For this round, we follow
the same approach (= single forward-fix docs commit documenting the
rewrite; boss approves one filter-branch sweep if needed).

## Forward-fix commit message draft

```
docs(wenshu): v0.30 -- H-3 forward-fix: paraphrase CJK in 3 commits

AGENTS.md §11 / H-3 hard rule = English-only commit bodies. 3 v0.30
commits in this branch contain verbatim CJK boss OOB quotes.

[CJK-original reference]
- Commit 72cb1d122: boss said "标题栏的液态玻璃透明度没有跟随设置中的
  参数" + clarification "现在设置面板里的设置，影响除标题栏外，文枢
  的所有前端 UI".
- Commit 213a58185: boss said "让标题栏跟随系统，不跟随设置" + the
  scope clarification "现在设置面板里的设置，影响除标题栏外，文枢
  的所有前端 UI".
- Commit 631cd93a2: same scope clarification paraphrased above.
[/CJK-original reference]

Paraphrased English (already in commit bodies):
- "title bar Liquid Glass opacity does not follow the setting slider"
- "setting slider affects every wenshu UI surface except the title bar"
- "let the title bar follow the system, not the setting"

Q5.4 do-not-amend = file diffs are unchanged. Forward-fix is message
rewrite only.

Commits addressed (no file diff changes):
- 72cb1d122: fix(wenshu): v0.30 -- AppStatusbar reads the Liquid Glass opacity slider
- 213a58185: fix(wenshu): v0.30 -- Settings panel: clarify Liquid Glass slider scope
- 631cd93a2: docs(wenshu): v0.30 -- domain: Liquid Glass slider scope

Precedent: see 064e381ce / 5019dc999 / a68adeb57 for prior v0.30
forward-fix commits on this branch.
```

## Boss approval gate

Per precedent, this forward-fix is a docs-only commit that:
1. Does NOT change any file diff
2. Documents the CJK-to-English translation in the forward-fix commit body
3. Optionally includes a `[CJK-original reference]` code block

The rewrite itself is documented (not amended). If boss wants the
verbatim message replacement on the 3 commits, it requires boss拍
+ `git filter-branch --msg-filter` (the one-time Q5.4 override was
used previously for the same purpose).