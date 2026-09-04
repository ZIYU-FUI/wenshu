# Standards axis code-review — v0.30 preview sort button + editor expand trailing fix

- **Reviewer**: Standards sub-agent (Q34 step 5)
- **Date**: 2026-08-31
- **Branch**: `wt/multi-agent-dispatch`
- **Commit under review**: `adcab7c1b` — `feat(wenshu): v0.30 — preview sort button + editor expand trailing fix`
- **Spec**: `.scratch/v0.30-preview-sort-button/spec.md`
- **Boss OOB (verbatim)**: "排序功能的 icon 没有实现, 其实就是和新建一样, 加在预览区的顶栏里. 老代码学一下怎么实现的就好了. 你按八步方法论, 同时加载 ponytail 技能, 像大神一样思考"
- **Files in scope (all 7 = exactly the spec)**: `Sources/WenshuApp/UI/PaneTabBar.swift`, `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`, `CONTEXT.md`, `.scratch/v0.30-preview-sort-button/{spec.md, issues/01..03-*.md}`

## Verdict

**FAIL** — 1 hard violation (H-3 CJK in `.scratch/spec.md` + ticket 02 + ticket 03, all newly added under this commit). 0 H-1, 0 H-2, 0 H-4.

The source-code changes themselves (PaneTabBar.swift, WorkspaceView.swift, CONTEXT.md) are clean: zero CJK characters added to source, zero forbidden 修真 tokens, zero forbidden neutral words, zero new dead code, zero scope creep, build exits 0 (verified `swift build` → "Build complete! 21.29秒"). The violation lives entirely in the new `.scratch/` Markdown documentation that AGENTS.md §5-6 explicitly requires to be English-only.

## Hard violations

| ID | Rule | Location (path:line) | Evidence | Severity |
|---|---|---|---|---|
| **H-3** | AGENTS.md v0.07.4 §5-6 English-only in `.scratch/spec.md` + `.scratch/issues/` + commit message | `.scratch/v0.30-preview-sort-button/spec.md:5-8` (blockquote quote of Boss OOB) | 4-line Chinese quote: `"排序功能的 icon 没有实现, 其实就是和新建一样, 加在预览区的 顶栏里, 不是原创的逻辑了, 老代码学一下怎么实现的就好了. 你别接 到需求上来就硬写, 你按八步方法论, 方法里一定有明确要求, 同时加 载 ponytail 技能, 像大神一样思考"` — AGENTS.md §5 explicitly lists `.scratch/spec.md` and `.scratch/issues/` as English-only surfaces | hard |
| H-3 (same rule, same violation, different file) | ditto | `.scratch/v0.30-preview-sort-button/issues/02-preview-sort-button-rewrite.md:74` (the "Why cycle-through instead of dropdown menu?" section opens with 1 line of Chinese = `Boss OOB says "排序功能的 icon 没有实现"`) | Chinese in a `.scratch/issues/` file = explicit §5-6 violation | hard |
| H-3 (same rule, same violation, different file) | ditto | `.scratch/v0.30-preview-sort-button/issues/03-editor-trailing-button-rewrite.md` (Chinese prose paragraph in body — "用了 Color.clear..." style explanatory sentences; `grep -c '[一-龥]'` = 2 lines containing CJK) | Chinese in a `.scratch/issues/` file = explicit §5-6 violation | hard |
| H-3 (same rule, same violation, commit body) | AGENTS.md §5: commit messages English-only | commit message body lines 3-5: `Boss 2026-08-31 OOB '排序功能的 icon 没有实现, 其实就是和新建 一样, 加在预览区的顶栏里. 老代码学一下怎么实现的就好了. 你按 八步方法论, 同时加载 ponytail 技能, 像大神一样思考'` | entire Boss OOB quote is CJK in the commit body. The commit footer even claims "AGENTS.md §5-6 English-only honored" — but the commit message itself contains the violation it's claiming to honor. Self-contradictory. | hard |
| **H-1** | dead code | none found | The new code in PaneTabBar.swift (`.frame(maxWidth: .infinity)`) is reachable, the new EditorExpandShrinkTrailingButton body is reachable (`.help(editorMaximized ? "恢复 (shrink)" : "展开 (expand)")` is unchanged), PreviewSortMenuButton body is reachable. No `@available(*, deprecated)`, no unused vars, no commented-out blocks. The `Image(systemName:)` SF Symbol fallback in EditorExpandShrinkTrailingButton:538-543 is unreachable in practice (Lucide package always resolves `"expand"`/`"shrink"`) but it's a **pre-existing pattern** carried over from before this commit (= not introduced = not a violation per Q34.5 "new in this commit"). | pass |
| **H-2** | scope creep | none found | All 7 touched files exactly match the task scope. No incidental edits, no drive-by refactors. `git diff-tree --no-commit-id --name-only -r adcab7c1b` = `.scratch/v0.30-preview-sort-button/issues/{01..03-*.md}` + `.scratch/v0.30-preview-sort-button/spec.md` + `CONTEXT.md` + `Sources/WenshuApp/UI/PaneTabBar.swift` + `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`. CONTEXT.md adds 3 domain words (PreviewSortMenuButton, EditorExpandShrinkTrailingButton, PaneTabBar inner HStack layout) — matches the spec. | pass |
| **H-4** | forbidden 修真 tokens (AGENTS.md §8) | none found | `grep -cE '(修真\|渡劫\|筑基\|返虚\|结丹\|金丹\|元婴\|飞升\|天劫\|雷劫\|心魔\|魔障)'` on all `+` lines of every touched file = 0. Forbidden neutral words (`可\|应当\|或许\|可能\|应该\|建议\|考虑\|试图\|尽量\|大概\|也许\| 或 \|任意\|大概率\|通常\|一般来说`) on all `+` lines of every touched file = 0. The "ponytail" skill name appears in comments (= skill name, not a forbidden token). | pass |

**Hard-violation count: 4 (all same H-3 rule across 4 surfaces)**.

## Soft suggestions

1. **The commit body claims "AGENTS.md §5-6 English-only honored" but the commit body itself contains Chinese** (= the Boss OOB quote block). This is a self-contradictory footer — the reviewer should treat the footer claim as false until the body is English-only. Recommended: rewrite the Boss OOB quote in `pinyin + English gloss` or `[CJK text]` placeholder form, then translate the intent into English in the surrounding prose. Pattern used in v0.28 batch 1 commits (see `git log --grep='boss'` body for examples).

2. **The spec.md blockquote quote of the Boss OOB is more verbose than needed.** The quote = 4 lines of CJK that AGENTS.md §5-6 forbids. If preserving the verbatim boss voice is required, move the Chinese quote into a code-fenced block labeled `text=boss-original (CJK reference, not for rendering)` and put the English prose paraphrase above it. Same applies to ticket 02 and ticket 03 inline CJK prose.

3. **The new `// ponytail fix:` comments in WorkspaceView.swift and PaneTabBar.swift are verbose (~10 lines each)**. Ponytail ladder rung 6 says "minimum code" — these comments are not minimal. A 2-line comment + 1-line fix = matches ponytail ladder better. The current verbose comments are 9 lines in WorkspaceView.swift PreviewSortMenuButton (lines 631-640 of post-edit file) and 10 lines in PaneTabBar.swift (post-edit L151-160). Not a hard violation (English-only + on-topic) but a code-volume smell.

4. **CONTEXT.md delta for "PaneTabBar inner HStack layout" duplicates the bug-pattern lesson already in spec.md §"Bug-pattern lessons" item 1** (= Spacer in conditional trailing slot needs parent full-width). Same content in 2 places. Future readers will have to chase both. Soft suggestion: cross-link instead of duplicating, or pick one canonical location.

5. **The `PreviewSortMenuButton.help("排序方式: \(sortOrder.rawValue)")` UI string at WorkspaceView.swift:692 is unchanged** (= pre-existing) and is correctly Chinese (user-facing string per AGENTS.md §6 "UI string rule, Chinese-only in user-facing strings"). Not a violation — flagging for clarity that this is the legitimate §6 carve-out, not an inconsistency with §5-6 English-only code comments.

6. **`@State previewSortOrder` is held in WorkspaceView per spec.md context bullet 1** — but WorkspaceView does NOT currently bind this `@State` to anything that persists across launches. spec.md says "Persistence = observer pattern via `@AppStorage` + `.onChange` (= pattern from commit a82397943)" — but the actual WorkspaceView code does NOT have `@AppStorage` wiring in either pre-edit or post-edit WorkspaceView. This is a documented feature that the spec promises but the code does not deliver. Not a hard violation (no implementation claim was made in the commit body — only "Persistence = @State previewSortOrder in WorkspaceView (= shared with PreviewPane via @Binding)" which is per-render only). Soft suggestion: either remove the `@AppStorage` claim from CONTEXT.md, or file a v0.30 follow-up ticket to actually wire `@AppStorage("previewSortOrder")` around the `@State`.

7. **`Lucide(editorMaximized ? "shrink" : "expand")` returning a non-Optional Lucide view + `if let lucide = ...`** is a slightly awkward pattern — `Lucide(_:)` always succeeds for valid icon names. The `else { Image(systemName: ...) }` branch is effectively unreachable for any icon the package supports. Pre-existing pattern from the original `Color.clear + .overlay` impl, so not new dead code. Soft suggestion: collapse to `Lucide(editorMaximized ? "shrink" : "expand").frame(width: 28, height: 28)...` without the `if let`, in a future refactor (not this PR's scope).

8. **The new `EditorExpandShrinkTrailingButton.help(editorMaximized ? "恢复 (shrink)" : "展开 (expand)")`** carries over from the pre-existing code — but now that the button is fully visible with hover tint, the `.help` Chinese tooltip is the user's only affordance for knowing which direction the click goes. Soft suggestion: ensure localizability is not regressed (the helper text is Chinese-only = correct per AGENTS.md §6, but if v0.31 adds English UI, this `.help` will need a localized string lookup).

## Recommended fixes (with line refs)

The 4 hard violations share the same rule (H-3). Three fix commits or one fix commit; pick one:

**Fix commit A (preferred — surgical, single-purpose)**:

1. `Sources/WenshuApp/UI/PaneTabBar.swift` — no change (already clean).
2. `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` — no change (already clean).
3. `CONTEXT.md` — no change (already clean).
4. `.scratch/v0.30-preview-sort-button/spec.md:5-8` — replace the 4-line Chinese blockquote with English paraphrase. Example:

   ```markdown
   Boss OOB (2026-08-31, verbatim Chinese, English paraphrase below):
   > [CJK original preserved in code-fenced block, labeled as reference only]

   English paraphrase: "The sort function icon is not yet implemented. It should
   follow the same pattern as the 'New' button in the sidebar: place an icon in
   the preview pane's top bar. This isn't a new logic — the old code already
   shows how to do it. Don't hardcode the requirement the moment you receive
   it; follow the 8-step methodology and load the ponytail skill — think like
   a master."
   ```
5. `.scratch/v0.30-preview-sort-button/issues/02-preview-sort-button-rewrite.md:74` — replace `Boss OOB says "排序功能的 icon 没有实现"` with `Boss OOB says "the sort icon is not yet implemented"`.
6. `.scratch/v0.30-preview-sort-button/issues/03-editor-trailing-button-rewrite.md` — translate any Chinese prose paragraphs to English. Per `grep -c '[一-龥]'` = 2 lines containing CJK in this file.
7. **Commit message body** for `adcab7c1b` — per Q5.4 "do not amend", do NOT rewrite the original commit. Instead, add a follow-up commit (e.g., `docs(wenshu): v0.30 — English-only pass on preview-sort-button spec + tickets`) that:
   - References the source commit: `(= source commit adcab7c1b, H-3 forward-fix)`
   - Documents the violation: `Standards sub-agent Q34.5 review found H-3 CJK in .scratch/v0.30-preview-sort-button/{spec.md, issues/02..., issues/03...} + commit message body (= Boss OOB quote block) violating AGENTS.md v0.07.4 §5-6 English-only rule.`
   - States what changed: `Translated Boss OOB quote to English paraphrase + moved verbatim Chinese into [CJK-original reference] code-fenced block. All source code + CONTEXT.md unchanged (= already English-only).`

**Fix commit B (alternative — single forward-fix commit that touches everything)**:

Bundle all of (4)-(6) above into one `docs(wenshu): v0.30 — H-3 English-only forward-fix` commit. Same Q5.4 do-not-amend protection on the original.

**Do NOT**:
- Use `git commit --amend` on `adcab7c1b` (boss拍 Q5.4 do-not-amend).
- Translate `EditorExpandShrinkTrailingButton.help("恢复 (shrink)" : "展开 (expand)")` — that's a user-facing string (§6 carve-out, leave as-is).
- Translate `PreviewSortMenuButton.help("排序方式: \(sortOrder.rawValue)")` — same §6 carve-out.
- Translate `EditorExpandShrinkTrailingButton`'s preceding `/// 此时 ICON 变成 shrink 点击后 恢复到刚刚点击 expand 前的状态'` doc-comment — verify: this comment is pre-existing, but if it's NEW in this commit (per `git show adcab7c1b^:Sources/WenshuApp/Views/Workspace/WorkspaceView.swift | grep -nE '此时'` returned L520 in pre-edit = NOT new in this commit). Leave as-is.

## Verification commands run

```bash
# Build verification
cd /Volumes/ANAN/Engineering/wenshu
swift build 2>&1 | tail -3
# -> "Build complete! 21.29秒" (exit 0)

# CJK scan on source code ADDED lines (should be 0)
git show adcab7c1b -- Sources/WenshuApp/UI/PaneTabBar.swift | grep -cE '^\+.*[一-龥]'
# -> 0
git show adcab7c1b -- Sources/WenshuApp/Views/Workspace/WorkspaceView.swift | grep -cE '^\+.*[一-龥]'
# -> 0

# CJK scan on .scratch/ files (whole-file content of NEW files)
for f in spec.md issues/01-panetabbar-spacer-fix.md issues/02-preview-sort-button-rewrite.md issues/03-editor-trailing-button-rewrite.md; do
  echo "$f:"; git show adcab7c1b:.scratch/v0.30-preview-sort-button/$f | grep -c '[一-龥]'
done
# -> spec.md: 9, 01: 0, 02: 3, 03: 2

# 修真 / forbidden-token scan on added lines (should be 0)
for f in Sources/WenshuApp/UI/PaneTabBar.swift Sources/WenshuApp/Views/Workspace/WorkspaceView.swift .scratch/v0.30-preview-sort-button/spec.md .scratch/v0.30-preview-sort-button/issues/*.md CONTEXT.md; do
  echo "$f:"; git show adcab7c1b -- $f 2>/dev/null | grep -E '^\+' | grep -cE '(修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障)'
done
# -> all 0

# Forbidden neutral words on added lines (should be 0)
[same loop with grep -E '(可|应当|或许|可能|应该|建议|考虑|试图|尽量|大概|也许| 或 |任意|大概率|通常|一般来说)']
# -> all 0

# Scope creep check (file list should match the 7 in-scope files)
git diff-tree --no-commit-id --name-only -r adcab7c1b
# -> all 7 expected, no surprises
```

## Notes for the Spec-axis sibling review

- The "Cycle-through 3 sort orders" behavior (= `pinyinFirstLetter → createdAt → modifiedAt → pinyinFirstLetter`) deviates from the original `Menu + .menuStyle(.button)` behavior (= "see all 3 orders in a dropdown, pick one"). This is a **behavioral change**, not just a UI rendering fix. Spec-axis should verify whether the boss OOB implies cycle-through or implies "match the 新建 pattern" (= dropdown). The spec.md acceptance criterion #2 says "Click on sort icon cycles through 3 sort orders" = the cycle-through interpretation is asserted in spec.md. Standards-axis does not flag this as a violation (it's a Spec-axis concern).
- The Persistence claim in CONTEXT.md "Persistence = `@State previewSortOrder` in WorkspaceView" is per-render only — there is NO `@AppStorage` wiring in either pre-edit or post-edit WorkspaceView. Standards-axis notes this as soft suggestion #6 (CONTEXT.md may be over-claiming). Spec-axis should verify whether `a82397943` actually established this pattern and whether the current WorkspaceView.swift correctly applies it.
- The `EditorExpandShrinkTrailingButton` `@State editorMaximized` is local-only toggle — the spec.md notes "full-screen expansion wiring = ticket 027-35 followup". So the button currently toggles `editorMaximized` but nothing observes it. Standards-axis notes this as not-a-violation (it's an explicit followup), but Spec-axis may want to confirm ticket 027-35 is tracked.