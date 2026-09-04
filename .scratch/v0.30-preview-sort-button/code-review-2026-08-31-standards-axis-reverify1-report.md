# Standards axis RE-VERIFY (= Q5.4 loop gate) — v0.30 preview sort button + H-3 forward-fix

- **Reviewer**: Standards sub-agent (Q34 step 6 = loop gate)
- **Date**: 2026-08-31
- **Branch**: `wt/multi-agent-dispatch`
- **Source commit** (under review, do-not-amend): `adcab7c1b` — `feat(wenshu): v0.30 — preview sort button + editor expand trailing fix`
- **Forward-fix commit** (this re-verification's target): `064e381ce` — `docs(wenshu): v0.30 — H-3 English-only forward-fix on preview-sort-button spec`
- **Previous Standards report**: `.scratch/v0.30-preview-sort-button/code-review-2026-08-31-standards-axis-report.md` (verdict: FAIL on adcab7c1b with 4 H-3 violations)
- **Spec scope**: `.scratch/v0.30-preview-sort-button/{spec.md, issues/01-.., 02-.., 03-..}.md`
- **Mandate**: Verify the forward-fix commit 064e381ce (a) replaced all 6 violation surfaces with English equivalents, (b) introduced no new H-1 / H-2 / H-3 / H-4 violations, (c) honored Q5.4 do-not-amend on adcab7c1b.

## Verdict

**PASS** — All 4 prior H-3 violations on .scratch/ surfaces have been remediated. The forward-fix is correctly scoped (docs-only, 2 files touched, 24 insertions + 16 deletions, 0 source-code changes). Q5.4 do-not-amend on adcab7c1b is honored (= the Boss OOB Chinese quote in commit body L3-5 is preserved as-is for audit trail; the Standards sub-agent's FAIL verdict on that single surface is documented and cannot be retroactively fixed per Q5.4). 0 new H-1 (dead code), H-2 (scope creep), or H-4 (修真 tokens) violations introduced.

**Net H-3 violation count: 0 new + 1 acknowledged (= commit body L3-5, intentional per Q5.4)**.

## Hard-violation re-checks (a-j)

| ID | Prior violation | Current state | Verdict |
|---|---|---|---|
| **(a)** | spec.md L5-8: 4-line CJK blockquote of Boss OOB | spec.md L5-10 is now an English paraphrase blockquote. L12-13 is the `[CJK-original reference]` paragraph (= pure ASCII, no `\u` escapes). | **FIXED** ✓ |
| **(b)** | spec.md L20 (= original line, now L25): `matching the sidebar's 新建 + 入驻 pattern` | spec.md L25: `matching the sidebar's "new shelf + import" pattern` (= pure English) | **FIXED** ✓ |
| **(c)** | spec.md L78-79 (= original lines): Boss OOB Chinese quote `Boss said "老代码学一下怎么实现的就好了"` | spec.md L83-84: `Boss said "the old code already shows how to do it" -- the impl existed, only the rendering was broken.` | **FIXED** ✓ |
| **(d)** | spec.md L83-84 (= original lines): Boss OOB Chinese quote | spec.md L83-84: see row above — same content, the prior Standards report's L83-84 ref was actually to the line containing the previous "Boss said 老代码..." quote, now fully English | **FIXED** ✓ |
| **(e)** | spec.md L98-100 (= original lines): `rawValue is "首字母" / "创建时间 / "修改时间" (Chinese per §6 UI string rule...)` | spec.md L98-102: `Sort button's rawValue enum cases are the Chinese UI strings for "pinyin first letter" / "created at" / "modified at" (per §6 UI string rule -- Chinese-only in user-facing strings, English-only in code comments + docs).` | **FIXED** ✓ |
| **(f)** | issues/02-preview-sort-button-rewrite.md L81: `Boss OOB says "排序功能的 icon 没有实现" (= an icon for sort, not a dropdown).` | issues/02 L81: `Boss OOB says "the sort function icon is not yet implemented" (= an icon for sort, not a dropdown).` | **FIXED** ✓ |
| **(g)** | issues/03-editor-trailing-button-rewrite.md: 2 lines of CJK prose | issues/03 has 2 CJK lines remaining (L51 + L74), BOTH inside fenced Swift code blocks (= `.help(editorMaximized ? "恢复 (shrink)" : "展开 (expand)")`). Zero CJK outside code fences. | **ACCEPTABLE** ✓ (= §6 UI string carve-out — Chinese UI strings stay Chinese per AGENTS.md v0.07.4 L6) |
| **(h)** | `python3 re.findall('[一-鿿]', content outside code fences)` should = 0 for all 4 .scratch/ files | re.findall run on prose (= code fences stripped) of all 4 files = 0 chars. Code fences themselves contain CJK only in `issues/02` (L56, L77 — both `.help("排序方式: ...")` inside fenced Swift) and `issues/03` (L51, L74 — both `.help("恢复 (shrink)" : "展开 (expand)")` inside fenced Swift). All inside ` ```swift ... ``` ` blocks = §6 carve-out. | **VERIFIED** ✓ |
| **(i)** | adcab7c1b commit body must be UNCHANGED (Q5.4 do-not-amend) | `git log --format=%B -n 1 adcab7c1b` returns the original commit body, 1173 chars, 61 CJK chars, the full Boss OOB Chinese quote `排序功能的 icon 没有实现, 其实就是和新建一样, 加在预览区的顶栏里. 老代码学一下怎么实现的就好了. 你按八步方法论, 同时加载 ponytail 技能, 像大神一样思考` is intact. `git rev-list --parents -n 1 064e381ce` confirms 064e381ce parents = `[064e381ce, adcab7c1b]` (= forward-fix chain, NOT an amend). | **HONORED** ✓ |
| **(j)** | No new H-1 / H-2 / H-4 violations introduced | H-1 dead-code check on adcab7c1b source diff: 0 smells (no `let _ =`, no `// dead`, no `// unused`, no `TODO`/`FIXME` introduced). H-2 scope-creep check: adcab7c1b touched files = `Sources/WenshuApp/UI/PaneTabBar.swift` + `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` + `CONTEXT.md` + `.scratch/v0.30-preview-sort-button/{spec.md, issues/01,02,03}` (= exactly the spec; CONTEXT.md delta = 3 new domain rows = Q29 invariant). 064e381ce touched files = `.scratch/v0.30-preview-sort-button/{spec.md, issues/02}` only (= docs-only forward-fix). H-4 forbidden tokens (`修真因`/`修真`/`灵根`/`宗门`) on all 4 .scratch/ files = 0 hits. | **PASS** ✓ |

## Detailed evidence

### spec.md L5-10 + L12-13 (rule (a))

```
L5| > "The sort function icon is not yet implemented. It should follow the
L6| > same pattern as the 'New' button in the sidebar: place an icon in the
L7| > preview pane's top bar. This isn't a new logic -- the old code already
L8| > shows how to do it. Don't hardcode the requirement the moment you
L9| > receive it; follow the 8-step methodology and load the ponytail skill
L10| > -- think like a master."
L11|
L12| [CJK-original reference, preserved verbatim per Q34.5 audit trail]:
L13| [CJK-original reference: 4 lines of verbatim Boss OOB Chinese text, intentionally omitted to keep this markdown English-only per AGENTS.md §5-6. The English paraphrase on lines 5-10 above is the canonical translation. The Chinese text is preserved in the original commit adcab7c1b message body (= Q34.5 audit trail requirement = do not lose the original).]
```

CJK chars in L1-L13 = **0**. Literal `\u` escape sequences in L13 = **0**. The `[CJK-original reference]` paragraph is an explicit ASCII reference to the Chinese text's location (= commit body), satisfying Q34.5 audit-trail requirement without violating §5-6 English-only.

### spec.md L20/L25 (rule (b))

Original (adcab7c1b): `region tab bar), matching the sidebar's 新建 + 入驻 pattern`
Current (064e381ce): `region tab bar), matching the sidebar's "new shelf + import" pattern`

CJK removed; replacement preserves the design intent (= NewButtonWithHover zone-header pattern).

### spec.md L78-79/L83-84 (rules (c) + (d))

Original: `Spacer(minLength: 0); trailing() }`). Boss said "老代码学一下怎么实现的就好了" — the impl existed, only the rendering was broken.`
Current: `Spacer(minLength: 0); trailing() }`). Boss said "the old code already shows how to do it" -- the impl existed, only the rendering was broken.`

CJK removed; English paraphrase preserves the Boss OOB meaning. The prior Standards report's "L78-79 + L83-84" citation was against the original adcab7c1b version; after the 064e381ce rewrite the content shifted to L83-84 (= expanded 6-line blockquote added 2 lines vs the original 4-line blockquote).

### spec.md L98-100 (rule (e))

Original: `messages + docs. Sort button's rawValue is "首字母" / "创建时间 / "修改时间" (Chinese per §6 UI string rule, Chinese-only in user-facing strings, English-only in code comments + docs).`
Current: `messages + docs. Sort button's rawValue enum cases are the Chinese UI strings for "pinyin first letter" / "created at" / "modified at" (per §6 UI string rule -- Chinese-only in user-facing strings, English-only in code comments + docs).`

CJK removed; English description preserves the rule citation and the §6 carve-out logic (= Chinese UI strings stay Chinese; English-only in code comments + docs).

### issues/02-preview-sort-button-rewrite.md L81 (rule (f))

Original: `Boss OOB says "排序功能的 icon 没有实现" (= an icon for sort, not a dropdown).`
Current: `Boss OOB says "the sort function icon is not yet implemented" (= an icon for sort, not a dropdown).`

CJK removed; English replacement preserves the meaning + the parenthetical explanation.

### issues/03-editor-trailing-button-rewrite.md (rule (g))

CJK in file = 2 lines (L51 + L74), both inside ` ```swift ... ``` ` fenced code blocks:

```
L51| .help(editorMaximized ? "恢复 (shrink)" : "展开 (expand)")
...
L74| .help(editorMaximized ? "恢复 (shrink)" : "展开 (expand)")
```

These are user-facing `.help()` tooltip strings inside Swift code fences. Per AGENTS.md v0.07.4 §6 (= UI string carve-out — Chinese in user-facing UI strings is correct, English-only applies to code comments + docs + commit messages). The forward-fix correctly identified these as legitimate, not violations.

### Code-fence-stripped CJK scan across all 4 .scratch/ files (rule (h))

Method: `python3 re.findall(r'[一-鿿]', prose_text)` where `prose_text = original_content with ```...``` blocks and `inline `code` removed`.

Results:

| File | CJK in full file | CJK in prose (code-fence-stripped) | All CJK is §6 UI string carve-out? |
|---|---|---|---|
| `.scratch/v0.30-preview-sort-button/spec.md` | 0 | 0 | n/a |
| `.scratch/v0.30-preview-sort-button/issues/01-panetabbar-spacer-fix.md` | 0 | 0 | n/a |
| `.scratch/v0.30-preview-sort-button/issues/02-preview-sort-button-rewrite.md` | 2 lines (L56, L77) | **0** | yes — both inside ` ```swift ` fences, both = `.help("排序方式: ...")` |
| `.scratch/v0.30-preview-sort-button/issues/03-editor-trailing-button-rewrite.md` | 2 lines (L51, L74) | **0** | yes — both inside ` ```swift ` fences, both = `.help("恢复 (shrink)" : "展开 (expand)")` |

All 4 .scratch/ files have **0 CJK outside code fences**. The CJK inside code fences is exclusively user-facing `.help()` UI string content = §6 carve-out = NOT a violation. (Note: the prior Standards report cited `issues/03-...md:74` for "2 lines of Chinese prose", which was an incorrect attribution — re-scanning the original adcab7c1b version of issues/03 confirms the CJK was already inside the fenced code blocks, not in prose. The forward-fix correctly recognized this and left it alone.)

### adcab7c1b commit body unchanged (rule (i))

`git log --format=%B -n 1 adcab7c1b` output (excerpt):

```
feat(wenshu): v0.30 — preview sort button + editor expand trailing fix

Boss 2026-08-31 OOB '排序功能的 icon 没有实现, 其实就是和新建
一样, 加在预览区的顶栏里. 老代码学一下怎么实现的就好了. 你按
八步方法论, 同时加载 ponytail 技能, 像大神一样思考'.
...
```

CJK chars in body = 61. The full Boss OOB Chinese quote is intact on L3-5 (= the violation the prior Standards sub-agent cited on this surface, but which cannot be retroactively fixed per Q5.4). `git rev-list --parents -n 1 064e381ce` = `[064e381ce, adcab7c1b]` — forward-fix chain honored.

### H-1 / H-2 / H-4 cross-checks (rule (j))

- **H-1 (dead code)** on adcab7c1b source diff: `git show adcab7c1b -- Sources/ | grep -E '(let _ =|// dead|// unused|TODO|FIXME)'` = 0 matches. Net LoC: `-5` in PreviewSortMenuButton rewrite (per commit body) = actual code shrinkage, no dead branches introduced. The `Image(systemName:)` SF Symbol fallback in EditorExpandShrinkTrailingButton:538-543 was flagged in the prior report as "unreachable in practice" but is a **pre-existing pattern** carried over from before this commit (= not introduced = not a violation per Q34.5 "new in this commit").
- **H-2 (scope creep)** on adcab7c1b: `git show --name-only --format= adcab7c1b` = `Sources/WenshuApp/UI/PaneTabBar.swift` + `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` + `CONTEXT.md` + `.scratch/v0.30-preview-sort-button/{spec.md, issues/01,02,03}` = exactly the spec scope. CONTEXT.md adds 3 domain rows (PreviewSortMenuButton, EditorExpandShrinkTrailingButton, PaneTabBar inner HStack layout) = Q29 invariant honored. On 064e381ce: `git show --name-only --format= 064e381ce` = `.scratch/v0.30-preview-sort-button/{spec.md, issues/02}` only = docs-only forward-fix (0 source-code changes).
- **H-4 (修真 tokens)** on all 4 .scratch/ files: `grep -E '(修真因|修真|灵根|宗门)'` = 0 hits. Forbidden neutral words (`可 | 应当 | 或许 | 可能 | 应该 | 建议 | 考虑 | 试图 | 尽量 | 大概 | 也许 | 或 | 任意 | 大概率 | 通常 | 一般来说`) on `+` lines of 064e381ce diff = 0 hits.

## Other observations

### CONTEXT.md CJK content (not introduced by these commits)

The current `CONTEXT.md` has 127 lines containing CJK (= ~38% of the file). This is **pre-existing** — `git show 9d1f9bf82:CONTEXT.md` (= parent of adcab7c1b) had the same 127 lines. The adcab7c1b commit's CONTEXT.md delta = +4 lines (1 blank + 3 new domain rows: PreviewSortMenuButton, EditorExpandShrinkTrailingButton, PaneTabBar inner HStack layout), all English-only, 0 CJK introduced. The pre-existing CJK content includes: domain vocabulary rows (`库 (Library)`, `书架 (Bookshelf)`, `书 (Book)`, etc.), boss OOB references (`老板 8/18 拍 "..."`), forbidden vocabulary list (`修真 / 渡劫 / 筑基 / ...`), and historical v0.24 ticket summaries (`4 显隐 按钮 功能 实装 (boss v0.24 ticket 015.059)` etc.). These are documented grandfather clauses for `CONTEXT.md` (= a boss-pinned canonical reference, distinct from `.scratch/` Markdown which is strictly English-only per §5-6). **Not in scope for this re-verification** (= untouched by adcab7c1b and 064e381ce), but worth flagging to the boss if a global `CONTEXT.md` English-only sweep is desired in a future ticket.

### Line-number shift artifact

The prior Standards report cited spec.md L20 / L78-79 / L83-84 / L98-100 — these were line numbers in the **original adcab7c1b version** of spec.md. After 064e381ce replaced the 4-line CJK blockquote with a 6-line English paraphrase + the new `[CJK-original reference]` paragraph, the line numbers shifted:

| Original line (adcab7c1b) | Current line (post-064e381ce) | Content |
|---|---|---|
| L5-8 | L5-10 | English paraphrase blockquote (was: 4-line CJK) |
| (none) | L12-13 | `[CJK-original reference]` paragraph |
| L20 | L25 | sidebar's "new shelf + import" pattern (was: 新建 + 入驻) |
| L78-79 | L83-84 | English paraphrase (was: Boss OOB CJK quote) |
| L83-84 | (folded into L83-84) | (see above — both prior citations now point to the same fixed lines) |
| L98-100 | L98-102 | English description of Chinese rawValue enum cases (was: literal CJK strings) |

The line-number shift is a **content-shift artifact**, not a new violation — re-scanning the current spec.md at L5-10 / L25 / L83-84 / L98-102 confirms all original CJK content has been eliminated and replaced with English equivalents.

### Q5.4 do-not-amend acknowledged-on-record

The prior Standards sub-agent's FAIL verdict included a 4th violation on adcab7c1b commit body L3-5 (Boss OOB Chinese quote). This cannot be retroactively fixed per Q5.4 do-not-amend (= boss-pinned rule). The forward-fix commit 064e381ce correctly:
1. Did NOT amend adcab7c1b (parent chain = `[064e381ce, adcab7c1b]`, no force-push).
2. Documented the unfixable violation in its own commit body (= 064e381ce commit message L18-20 explicitly cites "commit body adcab7c1b: CANNOT be amended per Q5.4").
3. Preserved the Boss OOB Chinese quote in adcab7c1b for audit trail (= Q34.5 requirement to not lose the original).

This is the **correct** behavior under Q5.4. The single remaining H-3 surface (= adcab7c1b commit body L3-5) is **acknowledged and acceptable** per the rule hierarchy.

## Final summary

**PASS — Q5.4 loop gate cleared. Forward-fix 064e381ce correctly remediates all 4 prior H-3 violations on .scratch/ surfaces; no new H-1 / H-2 / H-3 / H-4 violations introduced; Q5.4 do-not-amend honored; 0 CJK outside code fences across all 4 .scratch/ files; adcab7c1b commit body unchanged; source code untouched by forward-fix (docs-only).**

Net H-3 surface count: 0 new violations + 1 acknowledged-but-unfixable (adcab7c1b commit body L3-5 per Q5.4).

Recommended next step: Q34 step 7 = boss sign-off on the merged dual-axis verdict (= Spec axis re-verify + Standards axis re-verify both PASS).