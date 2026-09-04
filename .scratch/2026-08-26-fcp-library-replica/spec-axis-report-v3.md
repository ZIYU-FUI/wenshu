# Spec-Axis Code Review v3 — FCP Library Replica spec (post-SUG remediation)

**Spec under review:** `.scratch/2026-08-26-fcp-library-replica/spec.md` (329 lines, 2026-08-26 21:32)
**Ground truth:** Boss 2026-08-26 OOB (11 items) + Boss decision record (13 Q&A items) + Boss 8/22 (1-file protocol) + Boss 8/25 (re-sequence 024 before 001)
**Prior review:** `spec-axis-report-v2.md` — issued VERDICT PASS + 4 SUGGESTs (SUG-1..4); standards v2 also raised a carry-forward naming SUG (SUG-4 naming variant). v3 remediates 5 SUGs.
**Review date:** 2026-08-26 | **Axis:** SPEC only

---

## v3 change verification

### SUG-1 — New Ticket 024b with three options (a/b/c) + recommended (c) — **PASS**

- **Placement**: spec L279-299, between Ticket 024 (L268-276) and Ticket 025 (L300-303). Order matches the dependency chain (024b is a pre-implementation cleanup; 024 finalizes §11 wording; 025 is review).
- **Three options enumerated** at L290-293: (a) 12 atomic commits, (b) 1 mega-commit with explicit boss拍板 justification, (c) no rename + CONTEXT.md terminology-drift note.
- **Recommendation (c)** at L294-297: cites Boss 8/22 protocol, documents the documentation-only gap, calls the rename "reversible later".
- **Boss-decision dependency** explicitly declared at L280 and L298-299. Cannot start without explicit boss拍板.
- **No new entity introduced**: 024b is about renaming the existing `Bookshelf` type (verified at L281, L283-289). The three options all act on the same existing type; option (c) skips the ticket entirely.
- **OOB ground truth check**: Boss 2026-08-26 OOB item 5 = "Single-shelf model" — uses "Shelf" (= 书架) as the user-facing product name. No OOB item specifies the Swift type name. Q&A decisions do not constrain the type name. **No OOB/Q&A contradiction.**
- **Dependency coherence**: L298-299 correctly states that options (a)/(b) shift the re-sequence so 024b lands BEFORE 024; option (c) skips 024b. Both branches preserve §11 amendment integrity.

Verdict: PASS. Ticket 024b is a meta-planning ticket about renaming an existing entity, not a new domain entity. Fully consistent with OOB items 1, 2, 5 and all 13 Q&A decisions.

### SUG-2 — L19 now lists precise CJK line citations — **PASS**

- **L19** enumerates exactly 9 CJK line numbers: L74 (= "@角色.张三"), L87 (= "库属性"), L89 (= "在 Finder 中显示"), L92 (= "移动仓库"), L93 (= "重置库"), L174 (= "角色 / 世界观 / 资料库"), L199 (= "移动仓库 / 重置库"), L200 (= "用户体验最完整"), L206 (= "重置库"). All 9 are valid CJK-bearing lines in the spec body and each maps to a UI label that the Swift source will contain per Boss 8/25 'UI 全中文' carve-out.
- **Category-bound**: L19 frames each mention as category 2 (UI label references, parenthetical English explanation). Standards-axis v2 (L16-22 of `standards-axis-report-v2.md`) already PASSed these lines as category 2.
- **OOB ground truth check**: OOB item 10 = "@ syntax + Document.refIds" — CJK form `@角色.张三` is the user-facing syntax, consistent. OOB item 6 = "Library Properties panel" — Chinese label "库属性" is consistent with Boss 8/25 'UI 全中文'. No contradiction.

Verdict: PASS. The citation list is exhaustive and line-accurate. No new CJK outside the §11 carve-out categories.

### SUG-3 — Ticket 022 migration path adds "Note on books/" bullet — **PASS**

- **L252** reads verbatim: "**Note on `books/`**: PRESERVE whether empty or non-empty. An empty `books/` (= boss's real `/Users/anbaiqiang/Documents/anbaiqiang.ws/books/` per `ls -la`) means the user has not created books yet; the directory is a structural placeholder, not a deletion target. Migrator never deletes `books/` regardless of emptiness."
- **Defensive correctness**: this prevents a future migrator author from "cleaning up" an empty `books/` directory and silently dropping the user's structural skeleton. The real `anbaiqiang.ws/books/` on disk is currently empty (per boss's `ls -la` reference); without this note, ticket 022's author might misinterpret emptiness as safe-to-delete.
- **OOB ground truth check**: OOB item 8 = "Migration via Finder, no zip export" + Q13 = direct Finder move. The migrator's job is to handle existing user data, including empty placeholders. PRESERVE-on-empty is consistent with "do not drop user data" intent.
- **Internal coherence with Ticket 021** (L242-244): bootstrapper is also "never deletes user data" (L245). L252's "Migrator never deletes `books/`" aligns with that principle.

Verdict: PASS. Defensive bullet correctly placed in the migration-path list and grounded in observable real state.

### SUG-4 — Ticket 014 header adds "(= 1 file, per boss 8/22 protocol)" — **PASS**

- **L197** reads verbatim: "### Ticket 014 — Library Properties panel (= 1 file, per boss 8/22 protocol)".
- **Consistency check**: every other ticket header in the spec carries the same suffix pattern (L98, L119, L141, L157, L162, L166, L170, L176, L182, L185, L188, L191, L194, L202, L208, L213, L216, L231, L236, L240, L247, L270, L301). L197 now matches.
- **OOB ground truth check**: Boss 8/22 protocol is the standing rule for commit granularity; L197 just cites it for traceability.

Verdict: PASS. Header style is now consistent across all 24 tickets.

### SUG-5 — L15 §11 NOTE upgraded to "⚠️ RE-SEQUENCE HARD REQUIREMENT ⚠️" — **PASS**

- **L15** reads verbatim: "**⚠️ RE-SEQUENCE HARD REQUIREMENT ⚠️**: §11 baseline line 16 currently declares 'Stack = ... CoreData ...'. This spec's 'NOT CoreData' claim contradicts §11 until ticket 024 lands the §11 amendment. Implementation MUST land ticket 024 BEFORE ticket 001 (re-sequence dependency). If ticket 024 is not yet merged, the spec body L13 must be read as forward-looking. CI may enforce this by refusing to merge tickets 001-023 against the unamended §11 baseline."
- **Consistency with Boss 8/25 protocol**: The re-sequence rule (024 before 001) was established in the v2 review (SUGGEST-3 in `spec-axis-report-v2.md` L86) and in the standards-axis v2 review. Boss 8/25 explicitly approved this ordering. The hard-requirement framing in v3 is a stronger visual signal than v2's "Implementation MUST land ticket 024 BEFORE ticket 001".
- **CI enforcement note** (last sentence of L15): forward-looking. No contradiction; documents intent for future CI hook.
- **OOB ground truth check**: OOB item 7 = "Replicate FCP library management"; boss 8/22 = 1-file protocol; boss 8/25 = re-sequence rule. None of these OOB items contradict L15's HARD REQUIREMENT framing.

Verdict: PASS. Warning level raised appropriately. Re-sequence rule is pinned with rationale and enforcement hook.

---

## Regression check

**No regressions detected.** Each of the 5 v3 changes is a net addition or net clarification:

- **SUG-1** adds a new ticket (L279-299) without modifying any existing ticket. All prior ticket descriptions (001-024, 025) remain byte-identical to v2.
- **SUG-2** extends the existing L19 CJK category list (was a generic "Chinese form of cross-reference syntax; concrete lines with CJK: L74 [=..." in v2; now lists 9 specific lines). The framing is tighter, not contradictory.
- **SUG-3** adds a new bullet to the existing migration-path list at L252; the surrounding PRESERVE/DROP/CREATE/WRITE structure (L249-255) is unchanged.
- **SUG-4** adds a parenthetical to L197 only; ticket body (L198-200) is unchanged.
- **SUG-5** upgrades L15's NOTE tone but does not change the underlying re-sequence rule (which v2 L86 had already established as SUGGEST-3).

**v2 verdict preservation**: v2's PASS on all 11 OOB items + all 13 Q&A decisions holds. v2's FAIL-A (anti-zip) and FAIL-B (WanshuApp typo) remain remediated — no reintroduction of either.

**issues/README.md updated**: Ticket 024b row added at line 37, and the implementation-order footer at line 40 reads "023 → 024b (if boss picks a/b) → 024 → 025". This matches the spec's L298-299 conditional and preserves the dependency chain.

---

## VERDICT

**PASS.** All 5 SUG remediations verified, no regressions on v2 PASS, and the spec is ready to enter the implementation phase. The conditional 024b branch (boss picks a/b vs c) is correctly threaded through both the spec (L298-299) and `issues/README.md` (line 40). The ⚠️ HARD REQUIREMENT framing on L15 pins the re-sequence dependency in a way the boss and CI can both rely on.

**Recommendation:** Spec approved. Begin implementation with ticket 024 first (unblocks §11 amendment), then 001 → 002 → 003 in canonical order, holding ticket 024b open until boss picks option a / b / c.