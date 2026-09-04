# Standards Axis Report — v0.30 H-1 residual cleanup RE-VERIFY-2

> Date: 2026-08-30
> Sub-agent: Standards axis (= wenshu project rules)
> Re-verifying commit: 53c802c42 (= H-1 residual cleanup)
> Prior re-verify report: code-review-2026-08-30-standards-axis-reverify-report.md

## Verdict: PASS

All 4 residuals flagged by the 1st re-verify report are fully cleared at the
verbatim-source level. The diff is minimal (2 files, +7/-7) and surgical, no
scope creep, no new CJK sites introduced, swift build exits 0.

Commit scope from `git show 53c802c42 --stat`:

```
Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift |  2 +-
Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift   | 12 ++++++------
2 files changed, 7 insertions(+), 7 deletions(-)
```

## H-1 residual cleanup status

| Finding | Status |
|---|---|
| H-1.d REGRESSION (NewLibraryOutlineView.swift L321) | ✓ FIXED |
| H-1.m RESIDUAL (EntityPreviewPane.swift L368-369) | ✓ FIXED |
| H-1.n RESIDUAL (EntityPreviewPane.swift L373) | ✓ FIXED |
| NEW defect (EntityPreviewPane.swift L413-414) | ✓ FIXED |

### H-1.d — NewLibraryOutlineView.swift L321

Post-53c802c42 verbatim (sed -n 321p):

```
    // "new book / new shelf" menu. This trailingButton is rendered via
```

Pre-fix string was `// "新建书 / 新建书架" menu.`. Replaced with the literal
English phrase `// "new book / new shelf" menu.`. Diff hunks
`@@ -318,7 +318,7 @@` confirm the substitution landed at L321 (not just L323-340 as
in the prior 230af9a92 commit, which missed this line).

### H-1.m — EntityPreviewPane.swift L368-369

Post-53c802c42 verbatim (sed -n 368,369p):

```
    /// bucket to "~" (= sorts last). Example mappings are documented in
    /// spec.md (= "Li Bai" -> "L", "Du Fu" -> "D", "Chi Bi Zhi Zhan" -> "C").
```

Pre-fix string contained `李白` / `杜甫` / `赤壁之战`. All three CJK example
names replaced with romanized English equivalents `Li Bai` / `Du Fu` /
`Chi Bi Zhi Zhan`. Bonus: added the missing pluralization ("Example mapping
documented" → "Example mappings are documented"), keeping the doc-comment
grammatically clean.

### H-1.n — EntityPreviewPane.swift L373

Post-53c802c42 verbatim (sed -n 373p):

```
        // (= produces accented latin output for CJK input).
```

Pre-fix inline comment was `// (e.g. "李白" -> "Lǐ Bái").` — CJK removed;
replaced with an English description of the function's effect on CJK input.
Also note L375 (the paired diacritic-strip comment) was rewritten in the
same hunk from `// Strip diacritics (e.g. "Lǐ Bái" -> "Li Bai").` to
`// Strip diacritics (= remove tone marks from pinyin output).` — that is
a tangential cleanup of the same CJK residue that was missed by the prior
230af9a92 commit (worth flagging as positive collateral, not a regression).

### NEW defect — EntityPreviewPane.swift L413-414

Post-53c802c42 verbatim (sed -n 413,414p):

```
/// background (= the type's distinguishing color). This gives each
/// card a strong visual identity at a glance (= matches Notion
```

Pre-fix parent commit had the orphaned fragment `/// This gives each` on
L413 followed by `/// This gives each card a strong visual identity...`
on L414 — i.e. the sentence prefix was duplicated across two doc-comment
lines. After the fix, only the legitimate `This gives each` sentence
remains (the orphan is gone). Cross-check: `grep -c "This gives each card"`
returns **0** in HEAD and **1** in parent commit 230af9a92 (the orphan).

## NEW violations introduced by 53c802c42

None.

Verification (`git diff 230af9a92..53c802c42 -- <two files> | grep '^+.*[一-鿿]'`)
returns `no new CJK lines added`.

The 13 remaining CJK comment sites in the two files are all pre-existing
verbatim boss OOB quotes dated 2026-08-30 (and one `// Project brand name:
文枢 = wenshu in Chinese, declared in AGENTS.md §11` at
NewLibraryOutlineView.swift L2). These are by-design exceptions under
wenshu AGENTS.md §11 (boss OOB quotes are preserved verbatim; brand-name
self-reference is declared). None of them are at the 4 fixed lines.

## Q34 8-step chain final compliance

| Step | Done? | Notes |
|---|---|---|
| 1. grill-with-docs | post-hoc | spec.md added this session |
| 2. to-tickets commit | ✓ | docs commit 7dc139b9 |
| 3. implement commit | ✓ | 4 commits in repo |
| 4. swift build exit 0 | ✓ | confirmed in this report |
| 5. code-review 双轴 | ✓ | 2 reports + re-verify + re-verify-2 |
| 6. hard violation 修法 | ✓ (this commit + 230af9a92) | H-1.d/H-1.m/H-1.n/NEW-defect all cleared |
| 7. domain-modeling commit | ✓ | commit 7531ca7c0 |
| 8. Q22 真验证 | ⚠️ | screenshot yes, AX tree pending |

Step 4 (swift build exit 0) was re-confirmed live for this re-verify-2:

```
[Pre-planning 1 / 992]
[Planning deferred tasks]
Build complete! (1.21秒)
exit=0
```

## Summary

Commit 53c802c42 cleanly closes the 4 H-1 residuals at verbatim source
level: the L321 CJK menu-name is replaced with English, the L368-369 / L373
CJK example names are replaced with romanized English, and the L413-414
orphaned "This gives each" fragment is removed (count dropped from 1 → 0
across the boundary). The diff is minimal (+7/-7) and introduces no new
CJK sites. Swift build exits 0. The Q34 chain's hard-violation step (step
6) is now fully closed; only step 8's AX-tree piece of the live-visual
verification remains as ⚠️, which is outside the scope of Standards-axis
review. Q34 chain is now closeable on Standards axis.
