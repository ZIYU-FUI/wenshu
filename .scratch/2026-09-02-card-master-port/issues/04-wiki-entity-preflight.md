# Issue 04 — WikiEntityPreflight

## What (= scope)

A `WikiEntityPreflight` validation layer that runs BEFORE a LLM Wiki entity is written to disk. Validates: id uniqueness, field non-empty, reference MD body exists + is non-empty, entity classifier consistency.

Reference Card-master `preflight.ts` + `UserscriptInstallError` (= diagnostic array → fail-fast or pass-through).

## Why (= rationale)

Wenshu currently writes LLM Wiki entities directly to disk (= no preflight). If LLM output is empty / duplicate id / broken classification, the bad entity stays in the library.

Boss拍 'all 11 items' includes this engineering mechanism (= no LLM-side validation = corrupt library state).

## Apple-API-first check

- Custom code: `WikiEntityPreflight.validate(_ entity: WikiEntity) -> [PreflightIssue]` returning diagnostics.
- Apple HIG candidate: Swift `Codable` validation (`try container.decode(...)` + custom `init(from:)`).
- Apple coverage: partial (= Codable handles type validation; semantic validation (= id uniqueness, classifier consistency) is custom).
- LOC delta: ~200.
- Risk: low.

## Files touched

- `Sources/WenshuApp/Domain/WikiEntityPreflight.swift` (NEW): validation layer.
- `Sources/WenshuApp/Storage/FileSystemReferenceStore.swift`: invoke `WikiEntityPreflight.validate` before write; throw on errors.
- `Sources/WenshuApp/UI/References/WikiEntityPreflightErrorView.swift` (NEW): user-facing error display when validation fails.

## Acceptance criteria

- [ ] `WikiEntityPreflight.validate` returns 0 issues for a valid entity.
- [ ] Returns specific issue codes for: empty title, empty summary, duplicate id (= via FileSystemReferenceStore scan), broken classification.
- [ ] `FileSystemReferenceStore.upsert` blocks write on critical issue (= severity = error).
- [ ] Test file: `WikiEntityPreflight.test.swift` covers all paths.

## Dependencies

None.

## References

- Source: Card-master `src/userscript/application/preflight.ts`
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 4

First line: fact. Last line: fact.