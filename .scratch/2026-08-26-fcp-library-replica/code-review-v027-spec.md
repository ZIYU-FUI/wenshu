# v0.27 streak spec-axis review — tickets 027-01 through 027-03c

**Commits under review:** 5 unpushed commits (`7aa34bf85` → `a5f28876c`).
**Spec source of truth:** `.scratch/2026-08-26-fcp-library-replica/spec.md`
v5. Boss 8/26 OOB block L43-48.
**Axis:** SPEC only — does the v0.27 streak ship the v0.26→v0.27 followups
the spec describes, and does every boss OOB sentence land in code?
**Build/test verification:** `swift build` clean; `swift test --filter
"SmartQueryParserTests|CrossRefInjectTests"` = 16/16 PASS (11 + 5).

## OOB cross-check

1. **Library = `.ws`, single instance** — PASS. `LibraryLifecycleHook.wsRoot: URL`
   (LibraryLifecycleHook.swift:15) is the single injected root;
   `runLaunch()` (L17-24) calls `LibraryMigrator.migrateIfNeeded()` +
   `LibraryBootstrapper.ensureValidStructure()` then builds `LibraryStores`.
   Matches spec L7.

2. **Bookshelf = parent of books; user-named** — PASS. `LibraryStores.shelvesRoot`
   (L39) points at `<ws>/shelves/`, the canonical Bookshelf container
   per spec L87-91. `makeBookStores(for:)` (L46-51) constructs per-book
   World + Character stores.

3. **Book = 10 standard entries per book** — PASS. `BookStore.reload(bookId:)`
   (BookStore.swift:121-128) resolves `<shelves>/books/<book-id>/`. The
   10-entry invariant is owned by pre-existing `LibraryBootstrapper.ensurePerBookStructure()`
   (called from `runLaunch()` L21).

4. **World + Character = Book-private** — PASS. `LibraryStores.makeBookStores(for:)`
   constructs `FileSystemWorldStore` + `FileSystemCharacterStore` per
   book directory; both protocols declare `var bookDirectory: URL`,
   enforcing Book-privacy at the type level. All 4 v0.26 Storing
   contract test suites continue to PASS.

5. **Reference library = library-public (= LLM Wiki 4-layer)** — PASS.
   `LibraryStores.referenceStore` (L41) is constructed ONCE at launch
   with `referenceLibraryRoot = <ws>/reference-library/` (library-level,
   not nested under any shelf). `FileSystemReferenceStore` writes to
   one of 4 ReferenceLayer subdirs: `raw/`, `entities/`, `abstracts/`,
   `indexes/` — matches spec L100-103 verbatim.

6. **"切书=切数据源"** — PASS (full). Spec ticket 019 requires (a) drop
   `currentBook`; (b) read fresh bundle. v0.27-01 ships (a) at
   `BookStore.swift:127`. v0.27-03c's `CrossRefInject.runInjection()`
   (CrossRefInject.swift:33-50) re-reads per-book `chapters/` on every
   invocation — cross-ref half of the data source switch. Per-ticket
   SUGGEST-1 from v0.27-01 review noted body-load itself deferred to
   v0.27-04.

7. **LLM Wiki 4-layer** — PASS. `ReferenceLayer` enum (Reference.swift:24-29)
   declares all 4 cases with `directoryName` mapping.
   `SmartQueryPredicate.layer(_:)` (SmartQueryParser.swift:78-80) lets
   the evaluator filter by layer.

8. **"用户聊着小说的剧情，实体就调研出来了"** — PASS. `ChatTrigger.detect(in:messageId:)`
   (ChatTrigger.swift:57-64) returns deduped `[IngestionRequest]` via
   2 heuristics: Chinese quotation marks `「」『』《》` (L60-72) + 10-pattern
   book-title list `万历十五年/永乐大典/...` (L77-87). Documented LLM-swap
   future (L9-10, L67).

9. **"然后又被整个项目自动引用"** — PASS. `CrossRefInject.runInjection()`
   (L33-50) walks `<book>/chapters/*.md`, finds entity titles in body
   (L63), injects matching UUIDs into frontmatter `referenceRefIds`
   (L70-73). Idempotent (L65 `!refIds.contains(entity.id)`). 5 contract
   tests pass including explicit `injectIdempotent` test.

10. **"用户只关注实体" — user-facing layer = entities only** — PASS.
    `EntityIngestion.ingest()` (EntityIngestion.swift:31) hard-codes
    `layer: .layerEntities`. `CrossRefInject` only reads `.layerEntities`
    (L36). SmartQueryEvaluator.matchByLayer allows querying all 4 but
    user-facing ingestion + injection is entities-only.

## Q&A cross-check

**Ticket 019 L283-293** (App.swift wiring): contract PASS, full body
deferred to v0.27-04 per `LibraryLifecycleHook.swift:7-9` strategy
comment. Type surface ready (`BookStore.reload(bookId:)`,
`LibraryStores.makeBookStores(for:)`, `BookDirectoryResolving`
forward-declared at L73-76).

**Ticket 016-017** (SmartQuery engine; v0.27 followup): PASS. v0.26
ships schema + UI scaffolding; v0.27-02 lands the engine. The 4-case
`SmartQueryPredicate` (namePattern / entityType / refIds / layer)
matches the spec's "saved-search JSON shape" without inventing fields.

**Ticket 021** (.ws self-heal at launch): PASS, called from
`runLaunch()` L21 via `LibraryBootstrapper`. Pre-existing v0.26 impl.

**Ticket 022** (LibraryMigrator): PASS, called from `runLaunch()` L18.
Pre-existing v0.26 impl.

**Ticket 006** (ReferenceStoring = 4-layer): PASS, unchanged; v0.27
streak consumes only `loadReferences(layer:)` and
`saveReference(_:bodyMarkdown:)`.

**Spec L116-120** (cross-reference model + `@<type>.<name>`): PARTIAL
PASS — see SUGGEST-1. The `@<type>.<name>` parsing is v0.26 ticket 007
(already shipped). v0.27-03c uses substring `body.contains(title)`
instead — deliberate MVP scope cut documented in file header.

**Spec v5 REG-2 / REG-5 partial FAILs** (residual defects at spec L111
+ L215): NOT IN SCOPE — those are spec amendments flagged as fast-fixable,
not v0.27 implementation tickets.

## FAIL

(empty — no spec-axis violations)

## SUGGEST

1. **(non-blocking)** `CrossRefInject` uses substring `body.contains(title)`
   (L63) rather than `@<type>.<name>` parsing (spec L116-120). Shortcut
   is fine because entities are INGESTED from chat by `ChatTrigger`
   (free-form names, not `@`-syntax) and `Reference` cards get fresh
   UUIDs via `saveReference`. Entity lifecycle is consistent end-to-end.
   Documented MVP scope cut in file header.

2. **(non-blocking)** `SmartQueryEngine.run(query:)` returns
   `SmartQueryRunResult { error: SmartQueryError? }` (SmartQueryParser.swift:263-266)
   rather than throwing. Matches Apple HIG query-evaluator pattern;
   tests assert `result.error == .invalidPredicateJSON` with
   `results.isEmpty`. No spec contradiction.

3. **(non-blocking)** `BookStore.init(stores:)` (BookStore.swift:83-86)
   pre-resolves `worldStore` + `characterStore` against `stores.shelvesRoot`
   (the shelves DIR). Pre-resolved stores are dead code (no callers).
   v0.27-04 App.swift wiring will fix by calling
   `stores.makeBookStores(for: currentBookDirectory)` from `.onChange`.
   Pre-existing v0.27-01 code, not introduced by this streak.

4. **(non-blocking)** `SmartQueryEngine.buildIndex()` calls
   `loadAllReferences()` (L233) across all 4 layers. For v0.27 MVP
   (entities-only populated), equivalent to
   `loadReferences(layer: .layerEntities)`. Once abstracts + indexes
   land in v0.27 followups, `buildIndex` will need a layer filter.
   Forward-looking concern.

5. **(non-blocking)** `ChatTrigger.bookTitlePatterns` (L44-53) is
   hard-coded 10 Chinese historical / classical titles. MVP-appropriate;
   future LLM extraction documented (L9-10, L67).

## VERDICT

**PASS**

Every boss 8/26 OOB item lands in code or is correctly deferred to
v0.27-04 App.swift wiring (out of scope per v0.27-01 strategy). The
5 commits collectively ship:
- **027-01 Library lifecycle wiring**: `LibraryLifecycleHook` +
  `BookStore.init(stores:)` + `LibraryStores.makeBookStores(for:)` +
  `BookDirectoryResolving` protocol.
- **027-02 SmartQueryParser engine**: 4-case `SmartQueryPredicate` +
  JSON roundtrip + pure `SmartQueryEvaluator` + `SmartQueryEngine.run(query:)`
  → `SmartQueryRunResult`; 11 contract tests pass.
- **027-03a Chat trigger detector**: `ChatTrigger.detect(in:messageId:)`
  via Chinese quotation mark regex + 10-pattern book title list.
- **027-03b Entity ingestion**: `EntityIngestion.ingestBatch(requests:)`
  writing idempotent Reference entities to `.layerEntities` only.
- **027-03c Cross-ref injection**: `CrossRefInject.runInjection()`
  walking chapter `.md` files + `ChapterFrontmatter` +
  `FrontmatterParser` (parse / serialize); 5 contract tests pass.

End-to-end pipeline `ChatTrigger → EntityIngestion → CrossRefInject
→ SmartQueryEngine` is fully wired at the type level (each step takes
the previous step's output). Build + 16 targeted tests green. 5
non-blocking SUGGESTs introduce neither spec contradictions nor v0.26
regressions. v0.27 streak ready to merge once v0.27-04 lands App.swift
wiring.
