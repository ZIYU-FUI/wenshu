# CP1 Spec-Axis Review v2 — v0.26 FCP Library Replica (post FAIL-fix verification)

**Reviewer**: spec-axis subagent · **Date**: 2026-08-26
**Scope**: verify that the 3 Standards-side FAILs (F1 build break + F2 commit-msg typo + F3 trailing newline) fixed by `ca0d6ad26` + `ec44feab7` did NOT regress spec-axis compliance. Prior spec review `code-review-cp1-spec.md` PASSED on all OOB (11/11) + Q&A (13/13) + schema/spec axes.
**Spec under test**: `.scratch/2026-08-26-fcp-library-replica/spec.md` (v5, dual-axis PASS).

---

## FAIL

(none)

## SUGGEST

(none)

## PASS

### A. `ReferenceLayer` case naming preserves LLM Wiki 4-layer semantics

The rename `raw/entities/abstracts/indexes` → `layerRaw/layerEntities/layerAbstracts/layerIndexes` (commit `ca0d6ad26`) is a **pure identifier change** in the Swift type system. The `directoryName` getter maps each renamed case back to the spec-required string:

- `layerRaw.directoryName == "raw"` — `Reference.swift` L34 ✓
- `layerEntities.directoryName == "entities"` — `Reference.swift` L35 ✓
- `layerAbstracts.directoryName == "abstracts"` — `Reference.swift` L36 ✓
- `layerIndexes.directoryName == "indexes"` — `Reference.swift` L37 ✓

Spec v5 L76 mandates `.ws/reference-library/{raw/, entities/, abstracts/, indexes/}` and L100-103 enumerate the same 4 layer subdirectories. The storage layer `FileSystemReferenceStore.swift` L125-127 derives the layer path via `referenceLibraryRoot.appendingPathComponent(layer.directoryName, isDirectory: true)` — works identically before and after the rename because the mapping is driven by the getter, not by the case identifier.

`isUserFacing` flag unchanged (correct for v0.26): `layerRaw` + `layerEntities` → `true`; `layerAbstracts` + `layerIndexes` → `false` (`Reference.swift` L54-59). Matches spec L394 ("abstracts + indexes layers are HIDDEN in v0.26") and OOB-5 ("Library-public; user CANNOT delete or rename").

Storage layer `loadReferences(layer:)` L159 + `writeIndex(_:for:)` L275 + `layerDirectory(_:)` L125 all switch on `ReferenceLayer` via the typed parameter — no string literals, no risk of typos. Build clean (`swift build` = "Build complete! 0.25 sec" at tip).

### B. Ticket 003 storage path spec contract still satisfied

Spec L98-103 / L185-186 mandate `<.ws>/reference-library/<layer>/<uuid>.md`. On-disk path: `Reference.onDiskPath(under:)` L149-153 returns `referenceLibraryRoot.appendingPathComponent(layer.directoryName).appendingPathComponent(filename)` where `filename = "\(id.uuidString).md"` (L143-145). For each of the 4 layers this resolves to `<.ws>/reference-library/{raw|entities|abstracts|indexes}/<uuid>.md` — exactly matches the spec contract. `reference-library/` is NOT under `shelves/` (parameter `referenceLibraryRoot` is passed in by the caller from the library bootstrapper, not derived from any shelf path) — matches spec L113 independence requirement.

### C. `d83d3df8f` commit-scope typo `wensch` is message-only, not content

`git show ec44feab7 --stat` returns zero files touched. The F2 fix is a documentation-only commit (empty tree diff). Verified via `git show ec44feab7 --name-only`: no file changes. The original `d83d3df8f` commit's `feat(wensch):` scope typo is preserved in history (documented as intentional per the followup commit body — amendment would orphan 7 dependent commits per the fix commit's reasoning). AGENTS.md + CONTEXT.md content in `d83d3df8f` correctly spells "wenshu" everywhere — confirmed by the prior spec review (OOB 1-11 + Q&A 1-13). No content typo. No spec regression.

### D. No spec content changed by followup commits

`git log --all --oneline -- spec.md` (spec tracked via `.scratch/...`) shows no commits since the original spec v5 writing. `git status spec.md` reports "Untracked files" — the spec was never committed to git (scratch artifact), so neither followup commit could have touched it even by accident. Diff between spec L76/L98-103/L113/L314 (subdirectory names `raw/entities/abstracts/indexes`) and the new `ReferenceLayer.directoryName` getter outputs is zero — semantic equivalence preserved. Spec remains v5 PASS per `spec-axis-report-v5.md`.

## VERDICT

**PASS** — Both FAIL-fix commits (`ca0d6ad26`, `ec44feab7`) preserve full spec-axis compliance:

- A (layer naming): pure Swift identifier change; `directoryName` getter output unchanged; spec L76/L98-103/L100-103/L394 still satisfied
- B (storage path): `onDiskPath` returns spec contract path for all 4 layers; library-public independence preserved
- C (`wensch` typo): commit-message-only artifact; no content typo; AGENTS.md + CONTEXT.md unchanged
- D (spec content): untouched; spec remains v5

No new spec-axis defects introduced. All 11 OOB + 13 Q&A + schema/spec axes from prior review `code-review-cp1-spec.md` remain PASS. CP1 is spec-PASS and ready to merge once both the spec-axis (this report) and Standards-axis (`code-review-cp1-standards.md` after F1-F3 fixes = PASS) sign off.