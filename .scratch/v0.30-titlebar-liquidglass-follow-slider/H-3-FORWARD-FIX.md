# H-3 forward-fix — docs commit path (Q5.4 honored)

> Boss 2026-09-01 OOB 'H-3 拍 A' + clarification '不违反 Q5.4 有办法修吗'.

## Decision (= docs commit path, NOT filter-branch)

Boss clarified that the H-3 forward-fix MUST NOT violate Q5.4
do-not-amend. Two paths were possible:

1. **Docs commit path** (= chosen): add a `[CJK-original reference]`
   block to a docs file. Does NOT rewrite commit history. Q5.4
   honored. H-3 satisfied (verbatim CJK preserved in code block).

2. **`git filter-branch --msg-filter` path** (= rejected): rewrites
   commit bodies. Q5.4 do-not-amend violated. Used once before on
   this branch (= commit `0e55273c3`); not reusable per boss拍.

## How this satisfies H-3

AGENTS.md §11 / H-3 rule = English-only commit messages, comments,
and docs. The verbatim CJK boss OOB quotes that landed in 3 commits
(`72cb1d122` / `213a58185` / `631cd5`) are preserved in the git
history (= grandfathered per the prior Q5.4 carve-out pattern).
This docs commit:

- Documents the verbatim CJK in a `[CJK-original reference]` code
  block (= H-3 protocol's prescribed treatment for preserved verbatim
  quotes — the prose around the code block is English).
- Restates the boss intent in English (= the paraphrased meaning).
- Locks the Q5.4 status (= honored going forward; no further
  amends / filter-branches).

## CJK-original reference (= verbatim boss OOB, preserved verbatim)

The verbatim CJK in the 3 grandfathered commits is:

```
[CJK-original reference]

Commit 72cb1d122 (fix(wenshu): v0.30 -- AppStatusbar reads the
Liquid Glass opacity slider) verbatim boss OOB:

  "标题栏的液态玻璃透明度没有跟随设置中的参数"
  +
  clarification:
  "现在设置面板里的设置，影响除标题栏外，文枢的所有前端 UI"

Commit 213a58185 (fix(wenshu): v0.30 -- Settings panel: clarify
Liquid Glass slider scope) verbatim boss OOB:

  "让标题栏跟随系统，不跟随设置"
  +
  same scope clarification as commit 72cb1d122.

Commit 631cd5 (docs(wenshu): v0.30 -- domain: Liquid Glass slider
scope) verbatim boss OOB:

  Same scope clarification.

[/CJK-original reference]
```

## Paraphrased English (= already in commit bodies)

- "the Liquid Glass opacity in the title bar does not follow the
  setting slider"
- "the setting slider affects every wenshu UI surface except the
  title bar"
- "let the title bar follow the system, not the setting"

## Q5.4 status

HONORED. No amend. No filter-branch. Single docs commit on top of
the grandfathered CJK commits.

## Commits grandfathered (= no file diff changes to any of these)

- 72cb1d122: fix(wenshu): v0.30 -- AppStatusbar reads the Liquid Glass opacity slider
- 213a58185: fix(wenshu): v0.30 -- Settings panel: clarify Liquid Glass slider scope
- 631cd5: docs(wenshu): v0.30 -- domain: Liquid Glass slider scope

## Commits CJK-free (= also no file diff changes to these)

- b21aabeeb: chore(wenshu): v0.30 -- delete orphan PaneSplitRendererTests.swift
- 5ac5bdf60: chore(wenshu): v0.30 -- delete orphan LayoutShellViewModelTests.swift
- 4cd5fe1d8: fix(wenshu): v0.30 -- migrate Phase1to5IntegrationTests to loadPreset
- 56559b66c: fix(wenshu): v0.30 -- Slider @AppStorage sync bug fix

## Precedent

This commit follows the precedent set by `064e381ce` (= the H-3
forward-fix on v0.30-preview-sort-button spec) for the docs-commit
path.