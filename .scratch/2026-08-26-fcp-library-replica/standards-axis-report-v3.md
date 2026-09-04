# Standards-Axis Code-Review Report v3 (post-SUG remediation)

- **Spec under review**: `.scratch/2026-08-26-fcp-library-replica/spec.md` (revised v3, 329 lines, ~28 KB; v2 was 306 lines, +23 lines = the 5 SUG remediations).
- **Prior reports**: v1 FAIL, v2 PASS (`standards-axis-report-v2.md`).
- **Reviewer axis**: STANDARDS only — English-only + forbidden vocab + Apple HIG + Boss 8/22 + existing wenshu conventions + .ws layout conflict.
- **Method**: line-by-line re-grep; every CJK line re-categorised against the 3-category carve-out at L17-22; full forbidden-vocab re-scan; v3-specific assertion check (SUG-1 to SUG-5).

---

## v3 change verification

### SUG-1 — Spec axis v2 SUGGEST-4 (Bookshelf → Shelf rename gap) → PASS

New ticket 024b lands at L279-299 as a PLANNING-only ticket with three explicit options: (a) 12 atomic commits, (b) 1 mega-commit, (c) no rename. Recommendation = (c) no rename, with three numbered reasons (L294-297). The ticket body carries the boss-decision gate at L280 ("Boss must pick one of three options before this ticket lands. Per boss 8/22, this ticket CANNOT start without explicit boss拍板"). Scope is anchored to a verified 12-file, 104-reference callsite list (L283-289) — the file inventory is concrete, not hand-waved.

Atomic-coupling consistency check for options a/b/c: option (a) is explicitly framed as 12 sub-tickets violating boss 8/22 "in spirit" (L295); option (b) is explicitly framed as requiring boss拍 because it violates "in letter" (L292); option (c) preserves the 1-file-per-commit rule with a CONTEXT.md terminology-drift note (L299). All three options are internally consistent with the boss 8/22 protocol as written. The re-sequence dependency shift ("024b lands BEFORE 024 if boss picks a/b" at L298) is the only sequencing risk; ticket 024b is marked PLANNING with a hard boss-decision gate, so the spec itself does not break 1-file-per-commit. PASS.

### SUG-2 — Standards axis v2 SUG-1 (stale line-number anchors) → PASS

L19 now lists nine precise CJK line citations: L74, L87, L89, L92, L93, L174, L199, L200, L206. Verified each one with `awk 'NR==L && /[一-鿿]/'`: all nine lines actually carry CJK on the exact lines cited. The v2 imprecision (which listed L67/L70/L82/L86/L192/L296 as context anchors, only L199 being CJK) is corrected; the carve-out at L17-22 is now reviewer-unambiguous. PASS.

### SUG-3 — Standards axis v2 SUG-3 (ticket 022 books/ empty case) → PASS

Ticket 022 now carries an explicit "Note on `books/`" bullet at L252: "PRESERVE whether empty or non-empty. An empty `books/` (= boss's real `/Users/anbaiqiang/Documents/anbaiqiang.ws/books/` per `ls -la`) means the user has not created books yet; the directory is a structural placeholder, not a deletion target. Migrator never deletes `books/` regardless of emptiness." Cites the real workspace path; cites the verification command; locks in the behavior. The boss's actual `ls -la` of `/Users/anbaiqiang/Documents/anbaiqiang.ws/` was confirmed in the v2 review and remains accurate (no churn since). PASS.

### SUG-4 — Spec axis v2 SUGGEST-2 (ticket 014 missing boss 8/22 citation) → PASS

Ticket 014 header at L197 now reads: "Ticket 014 — Library Properties panel (= 1 file, per boss 8/22 protocol)". Cites the boss protocol directly. The body at L199 also retains the Boss 8/25 'UI 全中文' carve-out citation for the Chinese button labels. PASS.

### SUG-5 — Spec axis v2 SUGGEST-3 (§11 amendment precondition unmissable) → PASS

L15 now opens with ⚠️ RE-SEQUENCE HARD REQUIREMENT ⚠️ markers, carries the explicit "Implementation MUST land ticket 024 BEFORE ticket 001" directive, and adds the CI enforcement note ("CI may enforce this by refusing to merge tickets 001-023 against the unamended §11 baseline"). The ⚠️ glyph (U+26A0) is a Unicode symbol, NOT a Chinese character — the English-only rule at AGENTS.md §11 is preserved. AGENTS.md §11 line 16 still reads "Stack = Swift / SwiftUI + CoreData + single-process coroutine + self-built lightweight AI kernel." (re-verified via `sed -n '16p' AGENTS.md`), so the contradiction the §11 NOTE describes remains real and the amendment precondition is correctly characterised. PASS.

---

## Regression check

- **12 forbidden xianxia terms** (修真/渡劫/筑基/返虚/结丹/金丹/元婴/飞升/天劫/雷劫/心魔/魔障): zero hits via `grep -nE`. Clean.
- **14 forbidden neutral words** (lever/leverage/seamless/robust/scalable/cutting-edge/state-of-the-art/paradigm-shift/synergy/holistic/paradigm/ecosystem): zero hits via `grep -nE`. Clean.
- **CJK line count and categorisation**: 26 lines contain CJK (full `grep -n '[一-鿿]'` enumerated). Every line maps to one of the 3 carve-out categories: Boss OOB quotations (L6/8/9/18/200/280/292/296/297/303/329), UI label references (L19/29-34/73/74/77/87/89/92/93/174/199/206/326), FCP mapping table + cross-reference model + glossary entries (L20). Zero out-of-category hits.
- **Apple HIG compliance** unchanged: NSOpenPanel (L40, L92), FileManager.moveItem (L92), UserDefaults.wenshu.libraryPath (L40, L81, L84, L92, L93, L204, L206), SwiftUI environment injection (L234), Bundle(url:) for Info.plist read (L227), Settings menu + modal sheet pattern (L87-93, L199), Apple HIG bundle pattern with Info.plist at .ws root (L41, L67). All v2 PASS HIG signals preserved.
- **Existing wenshu conventions match** unchanged: FileSystemLibraryStore.swift precedent (L67, L160), LibraryStoring injection pattern (L234), LibraryRootView.swift:296-309 Info.plist writer (L41, L67), WenshuWorkspaceMigrator.swift:39 three-layer pattern (verified in v2). 老板 (boss-address, AGENTS.md §12) still 0 occurrences in spec body; boss is consistently addressed as "Boss" / "boss" in 34 lines — matches v2 PASS convention.
- **Boss 8/22 protocol** unchanged: 1-file-per-commit default preserved for tickets 001-022 and 025; atomic-coupling justifications retained for 023 (L262-267) and 024 (L271-277); 024b is explicitly PLANNING with a boss-decision gate, not silently adding a multi-file commit. No new protocol violation.

No new CJK violations, no new forbidden vocab, no HIG regressions, no convention drift.

---

## VERDICT

**VERDICT: PASS.**

All 5 SUG remediations (SUG-1 through SUG-5) land correctly. v2 PASS is preserved: 3-category CJK carve-out still holds for every CJK line; zero forbidden vocab hits; Apple HIG compliance unchanged; Boss 8/22 protocol intact; existing wenshu conventions still matched; .ws layout conflict resolution from v2 (Info.plist kept, chat.sqlite preserved, books/ preserved with new explicit empty-case note at L252, chapters/ + shelves/ dropped only-if-empty) all carried forward.

The §11 amendment re-sequence precondition is now unmissable (SUG-5) and traceable to AGENTS.md §11 line 16. The Bookshelf → Shelf rename is quarantined to a PLANNING ticket with a hard boss-decision gate (SUG-1), not silently smuggled into the 1-file-per-commit flow. The CJK carve-out line citations (SUG-2) are now reviewer-unambiguous — every cited line was verified to actually carry CJK. The empty-books/ case (SUG-3) and ticket 014 boss-protocol citation (SUG-4) are anchored to the boss's real workspace and the boss 8/22 standing rule respectively.

The spec body is internally consistent, references real on-disk files, and is ready to enter the implementation phase — conditional on the boss 8/22 §11 re-sequence (024 before 001) and the boss拍 on ticket 024b option (a/b/c). Both gating items are surfaced explicitly in the spec itself (L15 and L280 respectively), not buried.

Standards-axis v3 PASS. Spec axis review remains a separate pass.

---

*Standards-axis report v3 · 2026-08-26 · reviewer scope = English-only + forbidden vocab + Apple HIG + Boss 8/22 protocol + existing wenshu conventions + .ws layout conflict. Spec axis deferred to a separate review pass.*
