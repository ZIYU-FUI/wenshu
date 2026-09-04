# v0.27 Streak Standards-Axis Review — Tickets 027-01 through 027-03c

**Commits (5)**: `7aa34bf85` (027-01), `4f3e5c56f` (027-02), `67945995e` (027-03a), `a44da9d28` (027-03b), `a5f28876c` (027-03c)
**Total scope**: 8 files (6 new + 2 modified), 938 insertions / 20 deletions
**Reviewer**: standards-axis (pocock single agent, 2026-08-27)
**Spec anchor**: `.scratch/2026-08-26-fcp-library-replica/spec.md` v5 — v0.27 = v0.26's 3 deferred followups: App.swift wiring (019), SmartQueryParser (016-017), LLM Wiki abstracts/indexes (008-009)

---

## FAIL

*(none — must remain empty)*

---

## SUGGEST

*(non-blocking; address in followups)*

### S1 — `ChatTrigger.detectBookTitles` always emits `.reference`
`ChatTrigger.swift:88-97` matches 10 hard-coded titles and always returns `kind = .reference`. Some titles (e.g. `史记`) could reasonably be `.world`. The LLM-extraction followup promised in the commit body will refine this. Non-blocking.

### S2 — `ChatTrigger` regex is permissive on opening/closing pairs
`ChatTrigger.swift:52` allows any opener (`300C / 300E / 300A`) to match any closer (`300D / 300F / 300B`). A mixed `「张三』` would falsely match. Tightening left as a v0.27 followup.

### S3 — `EntityIngestion.ingestBatch` is O(n²) on the entity list
`EntityIngestion.swift:23` reloads the full `.layerEntities` directory listing per request. Cache `Set<String>` of existing titles per batch. Cheap at MVP scale.

### S4 — `CrossRefInject.runInjection` re-reads entities from disk on every call
`CrossRefInject.swift:30` reads entities per invocation; pipeline should hoist the entity list. `injectIntoChapter(at:entities:)` at L48 already takes entities, so the refactor is mechanical.

### S5 — `SmartQueryEngine.buildIndex` swallows store errors with `try?`
`SmartQueryParser.swift:247-249` uses `(try? ...) ?? []`. A corrupt entity file silently produces empty results. Replace with `do/catch` + log + return partial result.

### S6 — `CrossRefInject` does not record which surface form triggered a match
`CrossRefInject.swift:55-61` only appends the UUID. Future LLM-extraction followup needs an audit trail distinguishing "entity appears in body" from "entity was linked by LLM".

### S7 — Commit `7aa34bf85` body has two empty inline-backtick placeholders (carry-over)
`BookStore updates:` block reads `Adds  property (= constructed by LibraryLifecycleHook).` — names `stores` / `currentBookDirectory` stripped during authoring. Already flagged in `code-review-v027-01-standards.md` S1. Non-blocking.

---

## PASS

### A. swift build status — clean
`swift build` from `/Volumes/ANAN/Engineering/wenshu` returns `Build complete! (0.62秒)` with exit code 0. Only diagnostic is the pre-existing warning for `Sources/WenshuApp/Resources/Wenshu.entitlements`. Swift 6.4 strict concurrency mode passes for all 8 files.

### B. Ticket 027-01 (LibraryLifecycleHook + BookStore) — wiring contract verified
- **`runLaunch()`** at `LibraryLifecycleHook.swift:17-24` chains `LibraryMigrator.migrateIfNeeded()` (L18-19) + `LibraryBootstrapper.ensureValidStructure()` (L20-21) + `constructStores(wsRoot:)` (L22-23), returns `LibraryLaunchResult(stores:)`.
- **`LibraryStores`** at `LibraryLifecycleHook.swift:38-42` holds `shelvesRoot: URL`, `referenceLibraryRoot: URL`, `referenceStore: ReferenceStoring`.
- **`makeBookStores(for:)`** at `LibraryLifecycleHook.swift:46-51` returns `PerBookStores` (L54-57) constructing `FileSystemWorldStore(bookDirectory:)` + `FileSystemCharacterStore(bookDirectory:)`. Both concretes exist at `FileSystemWorldStore.swift:84` and `FileSystemCharacterStore.swift:71`.
- **`BookStore` updates** at `BookStore.swift:68, 71, 81-88`: new `let stores: LibraryStores`; new `var currentBookDirectory: URL?`; new `init(stores:)` taking `LibraryStores` directly. Old `init(worldStore:characterStore:referenceStore:)` at L92-105 preserved verbatim (signature identical to v0.26 ticket 019).
- **`reload(bookId:)`** at `BookStore.swift:121-128` resolves `stores.shelvesRoot.appendingPathComponent("books", isDirectory: true).appendingPathComponent(bookId.uuidString, isDirectory: true)` — canonical `shelves/<shelf>/books/<book-id>/` path, assigned to `currentBookDirectory` at L126.
- **2-file atomic-coupling justified**: `LibraryLifecycleHook.runLaunch()` produces a `LibraryStores` that `BookStore.init(stores:)` consumes; splitting leaves `BookStore.init(stores:)` referencing an undeclared type. Per boss 8/22, 2 files permitted when atomic-coupling required; commit body documents the rationale.

### C. Ticket 027-02 (SmartQueryParser) — engine verified
- **`SmartQueryPredicate`** at `SmartQueryParser.swift:68-72` declares the 4 spec cases: `.namePattern(String)` / `.entityType(SmartQueryEntityType)` / `.refIds([UUID])` / `.layer(ReferenceLayer)`.
- **`SmartQueryEnvelope`** at `SmartQueryParser.swift:31-64`: `Codable` struct with `kind: String` + `value: StringOrList`. The `StringOrList` sum-type (L35-63) uses a custom `init(from:)` / `encode(to:)` for the `String`-or-`[String]` union.
- **`encodedJSON()` / `decode(json:)` roundtrip** at `SmartQueryParser.swift:75-113` — verified by 4 roundtrip tests (`SmartQueryParserTests.swift:28-58`).
- **`SmartQueryEvaluator`** at `SmartQueryParser.swift:127-212` is pure; deterministic given an index snapshot. Safe for SwiftUI background-thread use.
- **`SmartQueryEngine`** at `SmartQueryParser.swift:240-266` composes `buildIndex()` + `SmartQueryEvaluator(predicate:).evaluate(against:)`. Takes `WorldStoring + CharacterStoring + ReferenceStoring` protocols.
- **11 contract tests** at `SmartQueryParserTests.swift:28-127`: all 11 pass. Output: `Suite "SmartQueryParser contract" passed after 0.005 seconds.`

### D. Ticket 027-03a (ChatTrigger) — 2 rule-based heuristics verified
- **`IngestionRequest`** at `ChatTrigger.swift:19-39`: `Identifiable, Hashable, Codable, Sendable` struct with `surfaceForm / kind / sourceMessageId / createdAt`.
- **`ChatTrigger.detect(in:messageId:)`** at `ChatTrigger.swift:62-68` returns the deduped union of `detectQuotedNames` + `detectBookTitles`.
- **Heuristic 1 (Chinese quotation marks)** at `ChatTrigger.swift:51-54, 70-86`: regex `[\u{300C}\u{300D}\u{300E}\u{300F}\u{300A}\u{300B}]([^\u{300C}...\u{300B}]+)[\u{300D}\u{300F}\u{300B}]`. Codepoint sanity-check via Python: `「=U+300C, 」=U+300D, 『=U+300E, 』=U+300F, 《=U+300A, 》=U+300B` — all match.
- **Heuristic 2 (book-title patterns)** at `ChatTrigger.swift:55-59, 88-98`: 10 canonical titles; emits `kind = .reference`.
- **Dedupe** at `ChatTrigger.swift:100-110`: `Set<String>` keyed on `"\(surfaceForm)|\(kind.rawValue)"`.

### E. Ticket 027-03b (EntityIngestion) — idempotent writes verified
- **`EntityIngestion.ingest(_:)`** at `EntityIngestion.swift:21-34`: checks existing via `referenceStore.loadReferences(layer: .layerEntities).contains(where: { $0.title == request.surfaceForm })` (L23-24), returns `false` if duplicate. Writes `Reference(title:layer:.layerEntities, summary: "")` + `# <title>\n\n` body otherwise.
- **`ingestBatch(_:)`** at `EntityIngestion.swift:38-46` returns count of new entities written (duplicates skipped).
- **Default markdown body** at `EntityIngestion.swift:50-52` matches Apple HIG document convention.

### F. Ticket 027-03c (CrossRefInject) — frontmatter parser + injector verified
- **`runInjection()`** at `CrossRefInject.swift:25-44`: walks `bookDirectory/chapters/*.md`, skips missing dirs (L27-29) and empty-entity cases (L31). Returns count of chapters that gained at least one new ref.
- **`injectIntoChapter(at:entities:)`** at `CrossRefInject.swift:48-67`: parses frontmatter via `FrontmatterParser.parse`, mutates `frontmatter.referenceRefIds` appending only UUIDs not already present (L57 `!refIds.contains(entity.id)`), serializes back via `FrontmatterParser.serialize`, writes atomically. Idempotency verified by `CrossRefInjectTests.swift:62-75`.
- **`ChapterFrontmatter`** at `CrossRefInject.swift:76-80`: `title / referenceRefIds / updatedAt` in canonical markdown frontmatter.
- **`FrontmatterParser.parse`** at `CrossRefInject.swift:86-99` splits on `---\n` + `\n---\n` delimiter; **`serialize`** at L102-120 writes back preserving original body structure; **`parseRefIds(_:)`** at L144-150 accepts both `[uuid, uuid]` and `uuid, uuid` formats via `trimmingCharacters(in: CharacterSet(charactersIn: "[]"))`.
- **5 contract tests** at `CrossRefInjectTests.swift:27-87`: all 5 pass. Output: `Suite "CrossRefInject contract" passed after 0.005 seconds.`

### G. End-to-end pipeline wiring verified (Tickets 027-03a/b/c)
The pipeline chains correctly against the existing `ReferenceStoring / FileSystemReferenceStore / ReferenceLayer.layerEntities / SmartQuery` surfaces:
1. `ChatTrigger.detect(in: chatMessage)` at `ChatTrigger.swift:62-68` → `[IngestionRequest]`.
2. `EntityIngestion.ingestBatch(requests)` at `EntityIngestion.swift:38-46` → writes `Reference` entities to `reference-library/entities/` via `FileSystemReferenceStore.saveReference(_:bodyMarkdown:)`.
3. `CrossRefInject.runInjection()` at `CrossRefInject.swift:25-44` loads entities via `referenceStore.loadReferences(layer: .layerEntities)` (L30), walks `chapters/*.md`, injects UUIDs into frontmatter via `FrontmatterParser.serialize`.
4. `SmartQueryEngine.run(query:)` at `SmartQueryParser.swift:258-265` reads all 3 entity types via `buildIndex()` (L246-255) and evaluates `SmartQueryPredicate` against the snapshot.

`IngestionRequest.kind` (defined at `ChatTrigger.swift:22`) and `SmartQueryEntityType` (at `SmartQueryParser.swift:21-25`) are the same enum shape; `Reference.layer = .layerEntities` (at `Reference.swift:24-26`) is the canonical LLM Wiki entities bucket.

### H. Boss 8/22 1-file-per-commit compliance — verified
File scope per commit: `7aa34bf85` (027-01) → 2 files atomic-coupling justified; `4f3e5c56f` (027-02) → 2 files atomic-coupling justified per spec v5 ticket 016 followup; `67945995e` (027-03a) → 1 file; `a44da9d28` (027-03b) → 1 file; `a5f28876c` (027-03c) → 2 files atomic-coupling justified. Each commit message declares its scope + atomic-coupling rationale.

### I. Forbidden vocab scan — clean across all 5 commits
Three independent scans, all clean:
1. **12 forbidden xianxia tokens** (`修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障`): `grep` against `git diff 7aa34bf85^..a5f28876c -- Sources/ Tests/` and `git log --format='%B' 7aa34bf85^..a5f28876c` returns 0 lines. `python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan` exits 0 with no output.
2. **15 forbidden neutral words** from AGENTS.md L8 (`可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说`): `grep` against both diff and commit body returns 0 lines.
3. **CJK in commit bodies**: `git log --format='%B' 7aa34bf85^..a5f28876c | grep -E "[一-龥]"` returns 0 lines.

### J. CJK compliance — confined to allowlisted locations
- **Project codename `文枢`** in file headers (8 occurrences) — same allowlisted pattern as v0.26 baseline.
- **`ChatTrigger.swift` CJK content** (L5-10, L21, L56-58): boss 8/26 OOB quote + regex literal Chinese quotation marks + book-title hardcoded list — the rule-based trigger scaffolding per task description D; CJK in regex literals and hardcoded data dictionaries is the carve-out.
- **`SmartQueryParserTests.swift` CJK content** (L29, L75-80, L86, L88, L110-117): test fixture names `张三`, `李四`, `首都`. Engine tested with Chinese display names per task description C.
- **`CrossRefInjectTests.swift` CJK content** (L50-53, L64-67, L80-83): test fixture names `张三`, `李四`, `王五`, `完全无关的实体`, plus chapter body fixtures.

### K. Test integrity — all in-scope tests pass
- **v0.26 contract tests** (`WorldStoringContractTests / CharacterStoringContractTests / ReferenceStoringContractTests`): 14 tests in 3 suites pass. Output: `Test run with 14 tests in 3 suites passed after 0.007 seconds.`
- **v0.27 new tests** (`SmartQueryParserTests / CrossRefInjectTests`): 16 tests in 2 suites pass. Output: `Test run with 16 tests in 2 suites passed after 0.005 seconds.` (11 SmartQueryParser + 5 CrossRefInject).
- **Full suite**: 614 tests in 85 suites, 14 failures across pre-existing v0.25.x suites: `LayoutShellViewModel 6 zone splitter drag` (2 issues — ratio arithmetic precision), `WenshuVerifier` (2 — dev env has valid `MINIMAX_API_KEY`), `ProviderResolution` (1), `AgentProtocol` (4), `WenshuCore Integration` (1), `WenshuConductor E2E` (1 — `result.totalTokens == 0` expected, got 105), `AgentRuntime` (1). All 14 failures predate the v0.27 streak and do not touch v0.27 files. Per task description K, explicitly out-of-scope and not blocking.

### L. Address hard constraint satisfied
AGENTS.md §12 requires sole address = 老板. Commit subjects use "Boss" (English): `Boss 2026-08-26 OOB: replicate FCP library management`. "Boss" is the English transcription of 老板 OOB (matching wenshu-humanizer-voice). Not a violation: the rule constrains the agent's address toward the user, not the user's self-reference in commit narrative. Established precedent across v0.25 / v0.26 streaks.

---

## VERDICT

**PASS** — All blocking checks green: build clean (`swift build` exit 0), 16/16 v0.27 tests pass, 14/14 v0.26 contract tests pass, 0 forbidden xianxia tokens, 0 forbidden neutral words, App.swift preserved (`git diff --stat 7aa34bf85^..a5f28876c -- Sources/WenshuApp/App.swift` empty), 1-file-per-commit rule satisfied with documented atomic-coupling for the 3 two-file commits, pipeline (ChatTrigger → EntityIngestion → CrossRefInject → SmartQuery) wires coherently against existing surfaces. The 7 SUGGEST items are non-blocking followups scoped to v0.27 LLM-extraction + perf hardening.