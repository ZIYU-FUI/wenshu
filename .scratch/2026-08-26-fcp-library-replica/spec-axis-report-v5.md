# Spec-Axis Code Review v5 — FCP Library Replica spec (post v4 FAIL remediation)

**Spec under review:** `.scratch/2026-08-26-fcp-library-replica/spec.md` (412 lines, v5)
**Prior reports:** v4 FAIL (`spec-axis-report-v4.md`)
**Axis:** SPEC only — confirmation pass that v5 does NOT regress on v3 PASS and each v4 FAIL is fixed.

---

## v5 change verification

### REG-1 (entry-count arithmetic 8+2=10) — **PASS**

All four call sites now read correctly: L9 `carries 8 standard folders + 2 data files (= 10 entries; see §Book structure below)`; L16 `## Book structure (8 standard folders + 2 data files = 10 entries)`; L304 (ticket 021) `verify all 8 standard folders + 2 data files exist; create missing ones`; L316 (ticket 022) `create the 8 standard folders + 2 JSON data files IF they do not exist`. Tickets 021/022 implementers will now create 10 entries per book, not 12.

### REG-2 (shelves/ root-orphan cleanup) — **PARTIAL FAIL**

L303 (ticket 021) is fixed: it removes only `chapters/` + `books/` and explicitly says `do NOT touch shelves/ at .ws root here — see ticket 022 for that cleanup`. L313 (ticket 022) correctly drops the empty `shelves/` orphan with a clarifying note.

**Residual defect**: L111 (Layout decisions block) still reads `The empty chapters/ + shelves/ directories at .ws root ... are removed by LibraryBootstrapper on first launch`. This contradicts L303 and L87/L112/L301 (which make `shelves/` the canonical container). The v4 remediation patched L303 but missed L111. An implementer reading L111 + L303 sees contradictory instructions. **Textual fix**: L111 must read `chapters/ + books/`.

### REG-3 (shared/smart/ → reference-library/indexes/saved-searches/) — **PASS**

All three stale paths are gone: L77 (FCP mapping) `.ws/reference-library/indexes/saved-searches/*.json`; L263 (ticket 016) `.ws/reference-library/indexes/saved-searches/<query-uuid>.json`; L411 (verification step 7) `create a reference in reference-library/raw/ → verify it appears in the ReferenceLibrary entities/ layer`. `grep -n 'shared/' spec.md` returns no hits; the namespace is fully retired.

### REG-4 (ReferenceOutlineView.swift → ReferenceLibraryOutlineView.swift) — **PASS**

L235 (ticket 012) `ReferenceLibraryOutlineView.swift (new)`. L392 (Files to modify) `ReferenceLibraryOutlineView.swift`. `issues/README.md` L24 `ReferenceLibraryOutlineView.swift` — matches. No `ReferenceOutlineView.swift` token remains.

### REG-5 ("Shelf-shared" → "Library-shared" + CJK cite list) — **PARTIAL FAIL**

L46 OOB restatement is fixed: `Reference library (= "资料库") is shared across all books in the library (= Library-level cross-cutting; ...)`. L119 is fixed: `reference (Library-shared, via ReferenceLibrary entities)`. L33 markdown typo is gone. The CJK cite list at L55-57 was regenerated; live `grep -nE '[一-龥]' spec.md` confirms each cited line carries an exempted CJK reference.

**Residual defect**: L215 (ticket 007) still reads `Add var charRefIds: [UUID], var worldRefIds: [UUID], var refIds: [UUID] (= references to shelf-shared Reference entities)`. The `shelf-shared` wording contradicts L119's `Library-shared`. The REG-5 fix touched L119 and L46 but missed L215. **Textual fix**: change `shelf-shared` to `library-shared` at L215.

---

## F (no new design contradictions)

OOB 1-11 satisfied (L7, L8, L9, L10, L98-103, L122-127, L129-137, L83-104, L116-120, L69, L100-103). Q&A Q1-Q13 satisfied. F (切书=切数据源): L288-292 BookStore @Observable + selectedBookId + reload. G (ReferenceLibrary root-level): L236 satisfied, L10/L113 independence preserved. H (012/013/022/026 scope): no scope bleed. I (implementation order): `issues/README.md` L44-63 unchanged, honors `024 → 024b → 001-022+026 → 023 → 025` re-sequence. No new design contradictions introduced. Both residual defects (L111, L215) are pure wording drift, not design changes.

---

## VERDICT

**FAIL (regression against v4 FAIL remediation, but fast-fixable).** v5 cleanly remediates 3 of 5 v4 FAILs (REG-1, REG-3, REG-4) and partially remediates 2 (REG-2, REG-5). Both partial remediations leave a single stale token each — L111 (`shelves/` → `books/`) and L215 (`shelf-shared` → `library-shared`) — that an implementer following the spec literally would catch as contradictory against the rest of the document. No v3 PASS criterion has regressed; no new design contradiction introduced; the implementation order in `issues/README.md` remains consistent with all v5 changes.

**Required fixes before PASS (textual, 2 lines):**
1. L111: replace `chapters/ + shelves/ directories at .ws root` with `chapters/ + books/ directories at .ws root`.
2. L215: replace `references to shelf-shared Reference entities` with `references to library-shared Reference entities`.

After these 2 single-token edits the spec is ready for implementation — no v6 needed.
