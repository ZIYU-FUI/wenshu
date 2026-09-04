# H-3 forward-fix — verbatim CJK to `[CJK-original reference]` code block (Q5.4 clean)

> Boss 2026-09-01 OOB 'H-3 拍 A' + clarification '不违反 Q5.4 有办法修吗'.
> Choose docs-commit-only path (= no `git filter-branch`, no amend)
> so Q5.4 do-not-amend stays honored. Q5.4's prior one-time override
> was used in commit `0e55273c3` (= single carve-out, not reusable).

## Scope (= 1 docs commit)

This commit only adds a docs note + `[CJK-original reference]` block
in the v0.30-titlebar-liquidglass-follow-slider scratch spec folder.
**No commit bodies are rewritten.** **No `filter-branch`.** **No
amend.**

## CJK-original reference (= verbatim boss OOB quotes, preserved as required by H-3)

The 3 commits in this branch contain verbatim CJK boss OOB quotes.
They are preserved here (= the H-3 protocol requires the verbatim
quote to be retained as a `[CJK-original reference]`, not deleted).
The commits themselves remain in git history (= the verbatim CJK in
commit bodies is grandfathered per the prior Q5.4 carve-out pattern;
the new forward-fix policy applies to NEW commits from this point
forward).

```
[CJK-original reference]

Commit 72cb1d122 (fix(wenshu): v0.30 -- AppStatusbar reads the Liquid
Glass opacity slider) verbatim boss OOB quote:

  "标题栏的液态玻璃透明度没有跟随设置中的参数"
  +
  clarification:
  "现在设置面板里的设置，影响除标题栏外，文枢的所有前端 UI"

Commit 213a58185 (fix(wenshu): v0.30 -- Settings panel: clarify
Liquid Glass slider scope) verbatim boss OOB quote:

  "让标题栏跟随系统，不跟随设置"
  +
  the same scope clarification (per commit 72cb1d122).

Commit 631cd93a2 (docs(wenshu): v0.30 -- domain: Liquid Glass slider
scope) verbatim boss OOB quote:

  Same scope clarification as commit 213a58185.

[/CJK-original reference]
```

## Paraphrased English (= already in commit bodies)

The commit bodies themselves contain the paraphrased English equivalent
of the CJK quotes. The paraphrases are NOT the verbatim quotes; they
are independent prose written in English (= no boss OOB verbatim
text in English; the boss spoke in CJK and the agent paraphrased).

For reference, the paraphrased content is:

- "the Liquid Glass opacity in the title bar does not follow the
  setting slider"
- "the setting slider affects every wenshu UI surface except the
  title bar"
- "let the title bar follow the system, not the setting"

## Why this is the right fix (boss拍 A clarification)

Boss's "拍 A" was clarified to "do not violate Q5.4". Q5.4 do-not-amend
has 2 paths that don't violate it:

1. **Docs commit path** (this commit): add a `[CJK-original reference]`
   to the v0.30 scratch spec, retain the verbatim CJK in commit
   history but document it as "grandfathered carve-out". Future
   commits must have CJK-free bodies from the start (= this is the
   primary mechanism).
2. **`filter-branch` path**: rewrites commit history. Violates Q5.4
   and requires explicit boss override. Used ONCE for this branch
   per `0e55273c3`'s prior carve-out; not reusable.

Boss chose path 1. This commit implements it.

## Q5.4 status after this fix

- **Forward-fix applied**: via docs commit (no history rewrite).
- **Q5.4 status**: HONORED (= no amend, no filter-branch).
- **H-3 status**: PASS for this commit body (English-only). PASS for
  commits `b21aabeeb` / `5ac5bdf60` / `4cd5fe1d8` / `56559b66c` (English-only).
  Grandfathered per prior carve-out: `72cb1d122` / `213a58185` /
  `631cd93a2` (verbatim CJK retained in commit history + documented
  here).

## Commits referenced (= no file diff changes to any of these)

- 72cb1d122: fix(wenshu): v0.30 -- AppStatusbar reads the Liquid Glass opacity slider
- 213a58185: fix(wenshu): v0.30 -- Settings panel: clarify Liquid Glass slider scope
- 631cd93a2: docs(wenshu): v0.30 -- domain: Liquid Glass slider scope

## Precedent

This commit follows the precedent set by `064e381ce` (= the H-3
forward-fix on v0.30-preview-sort-button spec) for the docs-commit
path. Differs from `0e55273c3` (= single filter-branch carve-out,
already used; not reusable).

## File touched (this commit)

- .scratch/v0.30-titlebar-liquidglass-follow-slider/issues/06-h3-forward-fix-docs-commit.md (new)