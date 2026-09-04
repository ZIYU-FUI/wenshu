# Standards-Axis Code Review v5 — FCP Library Replica spec

**Spec under review:** `.scratch/2026-08-26-fcp-library-replica/spec.md` (412 lines, unchanged length from v4)
**Ground truth:** AGENTS.md §11 English-only + 12-forbidden-vocab + 14-forbidden-neutral-words; boss 2026-08-26 OOB; boss 8/22 1-file-per-commit; boss 8/25 dual-axis; Apple HIG.
**Prior:** v1 FAIL, v2/v3/v4-Standards PASS; v4-Spec FAIL (REG-1..REG-5)
**Axis:** STANDARDS only — confirm v5 fixes don't regress on v3 + v4-Standards PASS.

---

## v5 change verification

### REG-1 — entry-count arithmetic — **PASS**
L9: `8 standard folders + 2 data files (= 10 entries; see §Book structure below)`. L16 heading: `(8 standard folders + 2 data files = 10 entries)`. L304 + L316: `all 8 standard folders + 2 data files exist`. L68 + L93 consistent. 8+2=10 math now resolves cleanly.

### REG-2 — `shelves/` deletion ambiguity — **PASS**
L303 NOTE: `do NOT touch shelves/ at .ws root here — see ticket 022 for that cleanup.` L313 mirrors in Ticket 022 DROP list: `shelves/ at .ws root ... was an empty placeholder dir; v0.26 introduces a real shelves/ (= canonical book container) which the migrator creates below.` v4 L111 vs L303 contradiction resolved.

### REG-3 — stale `shared/` paths — **PASS**
L263 Ticket 016 storage: `.ws/reference-library/indexes/saved-searches/<query-uuid>.json` (matches L77). L411 verification step 7: `create a reference in reference-library/raw/` (matches L98-103). Zero residual `shared/` paths in normative sections.

### REG-4 — stale filename — **PASS**
L235 + L392 both `ReferenceLibraryOutlineView.swift`. Matches Ticket 012 and `issues/README.md` L24. No residual `ReferenceOutlineView.swift`.

### REG-5 — stale CJK citations + "Shelf-shared" — **PASS (one straggler observation)**
L46 OOB rewritten to `Library-level cross-cutting; ... sibling to user-created shelves/`. L119 corrected to `reference (Library-shared, via ReferenceLibrary entities)`. L55-59 rewritten as `grep -nE '[一-龥]' spec.md` live-verification recipe rather than brittle v3 line numbers; the only remaining specific anchors are Boss-OOB quotations and UI-label categories, all verified CJK-bearing at current line numbers (sed-checked L117/L120/L130/L132/L135/L136/L217/L238/L243/L251/L252/L258/L312/L334/L357/L364/L368/L384/L385/L409/L412).

**Stragglers**: L215 still reads `(= references to shelf-shared Reference entities)` — REG-5 fixed L119 but missed this sibling parenthetical. Internal documentation drift only; the substantive Library-level Reference semantics are established at L10/L46/L76/L119. Not blocking.

---

## Regression check

- **⚠️ RE-SEQUENCE HARD REQUIREMENT** (L52): intact. `Implementation MUST land ticket 024 BEFORE ticket 001`.
- **AGENTS.md §11 English-only**: zero matches for 12 forbidden xianxia tokens (`修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障`) and zero matches for 14 forbidden neutral words (grep-verified).
- **Boss 8/22 1-file-per-commit**: every ticket row carries `= 1 file` scope; atomic-coupling justifications present for 023/024/025/026; 024b PLANNING with three options awaiting boss拍 (L340-360).
- **Apple HIG**: NSOpenPanel onboarding (L7, L83, L135), Info.plist as Apple HIG bundle pattern (L84, L108, L281), `@Observable` + `@Environment(BookStore.self)` Apple standard (L285, L291), Finder reveal (L132, L137), FileManager.moveItem (L135), Bundle Info.plist read (L279). Consistent with macOS HIG.
- **Dual-axis review**: L412 mandates both axes PASS; this = standards axis; spec-axis v4 FAIL remediated and confirmed separately.
- **Criterion D (CJK carve-out correctness)**: L55-59 delegates to live `grep -nE '[一-龥]' spec.md`; passes against current file.
- **Criterion E (entry-count arithmetic)**: L9 + L16 + L68 + L93 + L304 + L316 all agree `8 standard folders + 2 data files (= 10 entries)`.

---

## VERDICT

**PASS — spec is ready for implementation.** All 5 v4→v5 remediations land without introducing new CJK violations, forbidden vocabulary, neutral-word bloat, Apple-HIG regressions, or 1-file-per-commit anomalies. The single L215 straggler is internal parenthetical drift, not a Standards violation, and does not block PASS.
