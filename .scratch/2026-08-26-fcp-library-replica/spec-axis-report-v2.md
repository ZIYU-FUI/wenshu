# Spec-Axis Code Review v2 — FCP Library Replica spec (post-FAIL remediation)

**Spec under review:** `.scratch/2026-08-26-fcp-library-replica/spec.md` (306 lines, 2026-08-26 21:06)
**Ground truth:** Boss 2026-08-26 OOB (11 items) + Boss decision record (13 Q&A items)
**Prior review:** `spec-axis-report.md` (v1) — issued 2 blocking FAILs (FAIL-A line 76, FAIL-B line 166)
**Review date:** 2026-08-26 | **Axis:** SPEC only (Standards axis is separate per ticket 025)

---

## First-pass FAIL remediation verification

### FAIL-A (v1 line 76, "导出整库为 zip" button) — **PASS**

- **Panel content (spec L86-94)** now lists exactly 5 items: path display + Reveal in Finder (L89), disk usage (L90), schema version (L91), Move Warehouse (L92), Reset Library (L93). No zip button.
- **Explicit anti-zip note at L94**: `Note: there is NO zip export button. Boss vetoed per OOB item 8 and Q13; user moves the .ws directory via Finder if they want it elsewhere.` Pins intent in-place.
- **Out-of-scope veto (L295)**: `- Library export to zip (= boss vetoed: user moves via Finder)` — still present, now consistent with the body.
- **Whole-spec grep** (`zip|Zip|ZIP|导出整库|导出.*zip|export.*zip`) returns 3 hits (L94, L293=move-mention false-positive, L295) — every remaining mention is anti-zip prose. No "Export" UI, no `*.zip` path, no `导出整库` button text anywhere.
- **OOB #8 + Q13 + spec body + Out-of-scope** now agree: direct Finder migration, no zip.

Verdict: self-contradiction gone. The explicit NOTE is a stronger fix than just deleting the bullet — it makes future drift unlikely.

### FAIL-B (v1 line 166, "WanshuApp" → "WenshuApp" typo) — **PASS**

- **`grep -nE 'Sources/(WenshuApp|WanshuApp)' spec.md issues/README.md`** returns 22 lines in spec.md + 0 in issues/README.md. Every one is `Sources/WenshuApp/...` with the 'e'. Zero `WanshuApp` occurrences anywhere.
- **Cross-checked against real source tree** (per `CONTEXT.md` and `CLAUDE.md`, all existing wenshu code lives under `Sources/WenshuApp/`). The 22 spec paths are now consistent.
- **Renumbering side-effect**: Ticket 009's path moved from v1 L166 to v2 L183 (the panel ref-note section was restructured). L183 reads `Sources/WenshuApp/Views/Library/WorldEntryEditorSheet.swift` — correct.

Verdict: compile-breaking typo fully eradicated.

---

## Cross-check of all 11 OOB items

| # | OOB item | Verdict | Citation |
|---|---|---|---|
| 1 | Library holds books + world + character + reference | PASS | L29 mapping row (Library → Shelf); L18-26 enumerates all four |
| 2 | Book holds chapters + private world + private characters | PASS | L30-33, L36-46 layout puts `chapters/`, `world/`, `characters/` inside `<book-uuid>/` |
| 3 | World + Character private per Book | PASS | L32-33 (per-book dir); Tickets 004-005 scoped by bookId; Tickets 008-011 are per-Book views |
| 4 | Reference shared across all books | PASS | L34, L57-60 puts `shared/references/` at shelf root; Ticket 012 "shelf-shared, top-level" (L191); Ticket 006 (L167) has no bookId |
| 5 | Single-shelf model, onboarding one-time | PASS | L79-84 + Ticket 015 (L202-206) skip-if-already-locked logic |
| 6 | Library Properties panel = FCP-style | PASS | L86-94 full panel (5 fields) + Ticket 014 (L197-200) |
| 7 | Replicate FCP library management | PASS | L26-36 mapping table mirrors Library → Event → Project + Keyword + Smart Collections |
| 8 | Migration via Finder, no zip export | **PASS (was v1 FAIL-A)** | L94 anti-zip note + L295 out-of-scope + zero zip UI |
| 9 | .ws layout = Info.plist + library.sqlite + books/ + shared/ + cache/ | PASS | L39-63 layout diagram shows all 5 layers |
| 10 | @ syntax, load-time parse, Document.refIds | PASS | L72-77 + Ticket 007 (L170-174) adds `charRefIds`/`worldRefIds`/`refIds` + parser in `loadDocument` |
| 11 | Chapter stays as .md files (NOT a domain entity) | PASS | L31 + L294 out-of-scope + no chapter-ticket in 001-025 |

All 11 PASS. No v1 FAILs regressed.

---

## Cross-check of all 13 Q&A decisions

| Q | Decision | Verdict | Citation |
|---|---|---|---|
| Q1 scope | all 4 entities | PASS | L29-34 + L292 OOS confirms multi-shelf rejection |
| Q2 ownership | 角色+世界观 Book-private / 资料库 shelf-shared | PASS | L32-34; Tickets 004-005 bookId-scoped vs Ticket 006 shelf-scoped |
| Q3 Chapter | a = stay as .md | PASS | L31 + L294 |
| Q4 D1 form | .ws bundle shipped | PASS | L29 ("already shipped in v0.24 ticket 015.005") + L40 |
| Q5 D1.1 layout | three-layer FCP mirror (a) | PASS | L38 section header "FINAL — boss 2026-08-26 decision, three-layer FCP mirror" |
| Q6 D2 format | JSON sidecar + .md | PASS | L43-46, L54-56, L58-60 |
| Q7 D3 shelf dir | UUID unchanged | PASS | L36, L40-46, L57-60 — every entity subdir uses `<uuid>` |
| Q8 D4 character | JSON sidecar + .md | PASS | L51-53 + Ticket 002 (L120-139) Codable |
| Q9 D5 association | @ + Document.refIds | PASS | L72-77 + Ticket 007 (L170-174) |
| Q10 D6 shelf dir | UUID unchanged | PASS | Same as Q7 |
| Q11 D7 panel | full panel (c) | PASS | L86-94 (5 fields) + Ticket 014 (L197-200) |
| Q12 D8 startup | single-shelf, one-time onboarding | PASS | L79-84 + Ticket 015 (L202-206) |
| Q13 move | direct Finder, no zip | **PASS (was conditional on FAIL-A)** | L94 anti-zip note + L92 Move uses FileManager + L295 OOS |

All 13 PASS. Q1 panel + Q13 zip (both conditional in v1) are now unconditional PASS because FAIL-A held.

---

## Remaining FAIL

None. v1 issued 2 blocking FAILs; both fully remediated with evidence above. No new FAILs introduced (L94 anti-zip note and L183 path fix are net additions / net fixes, not regressions).

---

## New SUGGEST (non-blocking improvements)

**SUGGEST-1 — Promote "no zip button" into the panel description itself.** L94's anti-zip note sits below the bullet list. Consider folding it into L88-89 as a parenthetical so it lives next to the UI it constrains. **Non-blocking** — L94 is already self-documenting.

**SUGGEST-2 — Cite boss 8/22 protocol in Ticket 014.** Tickets 001-013 and 015-025 cite "boss 8/22 protocol" in their headers (e.g. L96, L98, L119, L141, L202). Ticket 014 (L197-200) does not — minor consistency gap. **Non-blocking.**

**SUGGEST-3 — Make the §11 amendment precondition unmissable.** Spec L15 flags that ticket 024 must land before ticket 001 to amend the "Stack = CoreData" §11 line. The re-sequencing is documented (Ticket 024, L268-276) but a one-line addition like "Re-sequence: 024 MUST land before 001" would prevent out-of-order execution. **Non-blocking.**

**SUGGEST-4 (carry-forward from v1 SUGGEST-1) — Shelf vs Bookshelf rename gap.** Spec uses "Shelf" canonically (L29, L79); Ticket 024 (L270) acknowledges the `Bookshelf → Shelf` rename. But the existing wenshu codebase still ships `Sources/WenshuApp/Domain/Bookshelf.swift` and the spec includes no dedicated rename commit. Recommend a new ticket 000 (or 024b) before 001 to do the rename + update all `Bookshelf` call-sites, so tickets 001-006 don't trip on the inconsistency. **Non-blocking**, but the single largest residual spec-vs-code gap.

---

## VERDICT

**PASS.** Both v1 blocking FAILs are fully remediated:

1. **FAIL-A** (zip contradiction): gone. OOB #8, Q13, panel section (L86-94 with anti-zip note on L94), and Out-of-scope (L295) now all agree. Whole-spec grep: zero residual zip-button text.
2. **FAIL-B** (WanshuApp typo): gone. All 22 ticket file paths use `WenshuApp`; cross-checked against real source tree.

All 11 OOB items + all 13 Q&A decisions PASS. Internal coherence preserved (dependency chain Domain 001-003 → Storage 004-006 → Document 007 → Views 008-013 → Library Properties 014 → Onboarding 015 → SmartQuery 016-017 → LibraryInfo 018 → App wiring 019 → Cache + Bootstrap 020-021 → Migrator 022 → Tests 023 → Docs 024 → Review 025 is sound). No scope creep beyond v1's noted defensive additions (smart query UI, migration shim, cache dir).

**Recommendation:** Spec approved for implementation. Standards-axis review (ticket 025, separate file `standards-axis-report.md`) is orthogonal and runs independently. The 4 SUGGESTs are quality-of-life improvements, not blockers.
