# M5 · Character & World Codex · agent-side surface + verbatim port plan

**Date:** 2026-08-28 (REVISION per boss OOB — skip third-party libs, plan verbatim port from local `hermes-agent` source)
**Scope:** AGENT-RELATED gaps only (= entity extraction, smart-query parsing, cross-ref injection, reference-library LLM Wiki pipeline). Per boss directive `agent 相关的,不用调研,就直接本地拿 hermes 源码复刻` — NO third-party lib survey for these capabilities.
**Branch:** `wt/multi-agent-dispatch` · **Author:** wenshu pocock single-agent · **Spec:** `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-28-six-module-audit/spec.md` §"Six modules" row M5.

---

## 0. Reading guide

- §1 = inventory of wenshu M5 files that already exist (MVP / scaffold level)
- §2 = inventory of `hermes-agent` source files that implement the equivalent capability
- §3 = per-capability verbatim-port plan (= hermes file → wenshu target, what to copy / adapt / drop)
- §4 = out-of-scope (= third-party lib survey SKIPPED per boss OOB; what stays in third-party territory because it is non-agent)
- §5 = ALREADY-REPLICATED surface (= wenshu shipped it in v0.23+ from earlier hermes parity audits; do not re-port)
- §6 = NEW-IN-HERMES surface since 2026-08-23 (= flagged but only if wenshu has not yet replicated)

---

## 1. Existing wenshu M5 agent-side surface (MVP / scaffold level)

### 1.1 Domain (entity + codex models)

| File | LOC | Status |
|---|---|---|
| `Sources/WenshuApp/Domain/Character.swift` | — | character model (= name + refIds to world / references / foreshadowing) |
| `Sources/WenshuApp/Domain/World.swift` (`WorldEntry`) | — | world-entry model |
| `Sources/WenshuApp/Domain/Reference.swift` | 168 | **4-layer LLM Wiki model** (`ReferenceLayer` = `layerRaw / layerEntities / layerAbstracts / layerIndexes`; `Reference` struct with `characterRefIds / worldRefIds / bookRefIds` + `summary` + `layer`) |
| `Sources/WenshuApp/Domain/IngestionRequest` (= inline in `ChatTrigger.swift`) | 39 | IngestionRequest (= `surfaceForm`, `kind: SmartQueryEntityType`, `sourceMessageId`) |
| `Sources/WenshuApp/Domain/SmartQuery.swift` | 60 | saved-search record (= `id / name / queryJSON / createdAt`; JSON-encoded predicate envelope for forward compat) |
| `Sources/WenshuApp/Domain/SmartQueryParser.swift` | 281 | `SmartQueryEnvelope` + 4-case `SmartQueryPredicate` (= `namePattern / entityType / refIds / layer`); `SmartQueryIndex` + `SmartQueryEvaluator` + `SmartQueryEngine` (composes index from stores + evaluates) |
| `Sources/WenshuApp/Domain/CrossRefInject.swift` | 150 | chapter `.md` frontmatter scan + auto-insert `referenceRefIds: [uuid, ...]` based on entity surface-form substring match |
| `Sources/WenshuApp/Domain/EntityIngestion.swift` | 52 | writes minimal `Reference(layer: .layerEntities, summary: "")` from `IngestionRequest`; idempotent by (surfaceForm, layer) |

### 1.2 Storage

| File | Status |
|---|---|
| `Sources/WenshuApp/Storage/FileSystemCharacterStore.swift` | per-book character CRUD |
| `Sources/WenshuApp/Storage/FileSystemWorldStore.swift` | per-book world CRUD |
| `Sources/WenshuApp/Storage/FileSystemReferenceStore.swift` | library-public reference CRUD; 4-layer dir layout; metadata.json at root |

### 1.3 Cross-ref / link graph (M4 surface re-used by M5)

| File | Status |
|---|---|
| `Sources/WenshuApp/Core/LinkGraph/InternalLinkParser.swift` | markdown `[[name\|alias]]` static parse (= Obsidian wikilink 1:1) |
| `Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift` | SQLite-backed link store (= `add / removeAll / searchForward / searchBackward`) |
| `Sources/WenshuApp/Core/LinkGraph/BacklinkResolver.swift` | name ↔ docId resolution + backlink / forward-link lookup |
| `Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift` | UI consumer |

### 1.4 Memory / Skills (cross-module, not strictly M5 but used by M5 ingest flow)

| File | Status |
|---|---|
| `Core/Memory/MemoryStore.swift` | SQLite-backed memory store (`add / get / update / delete / search / count`) |
| `Core/Memory/MemoryManager.swift` | `prefetch / sync / queuePrefetch / takeQueuedPrefetch` (matches hermes `MemoryManager.prefetch_all / sync_all / queue_prefetch_all`) |
| `Core/Memory/MemoryConsolidator.swift` | budget-based consolidation (matches hermes `context_compressor.py`) |
| `Core/Memory/MemoryWriteGate.swift` | gate policy (`evaluateAdd / evaluateReplace / evaluateRemove`) |
| `Core/Skills/SkillRegistry.swift` | `list / load / invoke` for user-installed skills (= hermes `skills/` mirror) |
| `Core/Skills/SkillMeta.swift` | trust-level + source + quarantine policy |

### 1.5 Multi-agent dispatch (already-replicated per §5)

`Core/Agent/WenshuConductor.swift` v0.21+ (intent classify → sub-agent delegate → synthesis) + `AsyncDelegation.swift` (= background sub-agent handle).

---

## 2. Matching `hermes-agent` source surface

Hermes source root = `/Volumes/ANAN/.hermes/hermes-agent/` (NOT under `agents/` or `prompts/` at top level — those directories don't exist; the runtime lives under `agent/` + `plugins/memory/` + `skills/`).

### 2.1 Entity extraction (= match for `Domain/EntityIngestion.swift` + `Domain/ChatTrigger.swift`)

Hermes implements TWO entity-extraction surfaces:

| Hermes file | LOC | What it does |
|---|---|---|
| `plugins/memory/holographic/store.py::MemoryStore._extract_entities` | 33 | **Rule-based regex entity extraction** from prose. Patterns: capitalized multi-word (`John Doe`), double-quoted (`"Python"`), single-quoted (`'pytest'`), AKA (`Guido aka BDFL` → two entities). Deduped, first-seen order preserved. |
| `plugins/memory/holographic/store.py::MemoryStore._resolve_entity` + `_link_fact_entity` | 30 | entity_id resolution by name OR alias (LIKE match on `aliases` column), `INSERT OR IGNORE` on `fact_entities` join. The IDENTITY-COLLAPSE primitive (= same surface-form across many facts → 1 entity row). |
| `agent/agent_init.py` (referenced from memory_manager.py imports) | — | Intent-classification LLM call (= the modern equivalent of the rule-based `ChatTrigger`) |
| `agent/learn_prompt.py::build_learn_prompt` | 73 | Structured LLM prompt for `/learn` (= "compile this source into a knowledge-base skill"). The model-side ingestion orchestrator that drives the LLM Wiki ingest pipeline. |

Wenshu's current entity surface = `EntityIngestion.ingest` (writes a `Reference` row with empty summary, idempotent by title). It does NOT have:
- `_extract_entities`-style rules over chapter prose (only ChatTrigger's CN-quoted-name + book-title regex)
- `_resolve_entity`-style alias resolution (Reference.title is treated as exact-match key only)
- LLM-driven extraction (= no learn_prompt analogue)

### 2.2 Smart-query parser (= match for `Domain/SmartQueryParser.swift`)

| Hermes file | LOC | What it does |
|---|---|---|
| `plugins/memory/query_rewrite.py` | 139 | **Provider-agnostic LLM query rewriter.** `rewrite_memory_query(user_message) -> str`. Steps: (1) `_bounded_user_message` truncate to 4000 chars; (2) LLM call via `agent.auxiliary_client.call_llm(task=TASK_KEY)` with structured system prompt that rewrites user message → one retrieval-only question; (3) `_normalize_rewrite` strips markdown fences + output prefixes + stray quotes, then validates with 5 regexes (must start with question word / contain memory-grounding keyword / no instruction leak / no internal sentence / ends with `?`). |
| `plugins/memory/holographic/retrieval.py::FactRetriever.search` | 99 | vector + FTS5 hybrid retrieval over entity-tagged facts. |
| `agent/memory_provider.py::TRIVIAL_PROMPT_RE` | 6 | "is this prompt trivial enough to skip recall entirely?" gate. Anchored alternation; single source of truth shared with `agent/turn_context.py` + `run_agent.py`. |

Wenshu's current smart-query surface = `SmartQueryEvaluator` (4-case in-memory predicate evaluator against a snapshot index). It does NOT have:
- LLM-side query rewrite (= user query is parsed as-is into the 4 enum cases; no normalization)
- Trivial-prompt gate (= SmartQueryEngine runs every query unconditionally)
- Hybrid vector + FTS5 retrieval (wenshu uses substring match only)

### 2.3 Cross-reference injection (= match for `Domain/CrossRefInject.swift`)

| Hermes file | LOC | What it does |
|---|---|---|
| `agent/context_references.py::parse_context_references` | 62 | **Regex-based `@-prefix` reference parser** (= `@file:` / `@folder:` / `@git:` / `@url:` / `@diff:` / `@staged:` + plugin-registered prefixes). Returns `list[ContextReference]` with `(raw / kind / target / start / end / line_start / line_end)`. Two-pass: built-in pattern + plugin fallback. |
| `agent/context_references.py::preprocess_context_references` + `_async` | 90 | Async expand-all-references pipeline. Token-budget aware (25% soft limit, 50% hard limit; auto-abort with structured `ContextReferenceResult` carrying `injected_tokens / expanded / blocked`). Each `@<kind>:<target>` resolved via `_expand_reference` dispatcher (= file / folder / git diff / git log / url). |
| `agent/context_references.py::ContextReferenceProvider` (ABC) | 16 | Plugin-registered reference provider API (= Issue #26193). `prefix: str` + `description: str` + `async autocomplete` + `async expand`. |

Wenshu's current cross-ref surface = `CrossRefInject.runInjection` (substring-match chapter `.md` body → entity surface-forms → append UUIDs to frontmatter). It does NOT have:
- Token-budget-aware injection (= runs over ALL chapters unconditionally; no 25% / 50% soft/hard limits)
- Plugin-style `@<kind>:<target>` registry (= only internal `[[wikilink]]` syntax via `InternalLinkParser`)
- Async expand-all pipeline with structured `result` envelope

### 2.4 Reference-library LLM Wiki pipeline (= match for the 4-layer `ReferenceLayer` model)

| Hermes file | LOC | What it does |
|---|---|---|
| `skills/research/llm-wiki/SKILL.md` | 507 | **Canonical Karpathy LLM Wiki spec (= the reference for wenshu's `ReferenceLayer` model).** 3 layers per the skill (= `raw/`, `entities/`, `concepts/`, `comparisons/`, `queries/`) but the **INGEST PIPELINE** is the part wenshu needs. Stages: orient (read SCHEMA.md + index.md + recent log) → capture raw source w/ sha256 + frontmatter → discuss takeaways → check what already exists → write or update pages w/ [[wikilinks]] cross-ref + provenance markers → update navigation (index.md + log.md) → report what changed. Plus a 12-step LINT pipeline (= orphan pages / broken wikilinks / index completeness / frontmatter validation / stale content / contradictions / quality signals / source drift / page size / tag audit / log rotation). |
| `plugins/memory/holographic/store.py::MemoryStore.add_fact` + `_extract_entities` + `_link_fact_entity` | 90 | The 4-stage ingest = `(1) write fact → (2) extract entities → (3) resolve_or_create entity_id → (4) link fact↔entity`. Compounding — same source can trigger updates across N existing entity rows. |
| `agent/system_prompt.py` | — | System prompt SOUL pattern (= how the SOUL document is concatenated into the agent's `system` message; wenshu has `WenshuConductorIdentity.systemPrompt` as the analog) |

Wenshu's current 4-layer surface = `ReferenceLayer` enum + `FileSystemReferenceStore` (per-layer directory + `*.json` index sidecar). Only `layerRaw` (user imports) + `layerEntities` (user-facing) ship in v0.27; `layerAbstracts` + `layerIndexes` exist as enum cases but the LLM-side ingest pipeline is missing. Specifically:
- No `SCHEMA.md`-equivalent (= `ReferenceStore` JSON sidecar is not a domain schema doc)
- No `index.md`-equivalent (= no library-wide entity index file)
- No `log.md`-equivalent (= no append-only action log of ingest events)
- No `[[wikilink]]` synthesis step in `EntityIngestion` (= ingest just writes a row, doesn't link back)
- No LINT pipeline (= orphans / broken refs / contradictions not surfaced)

---

## 3. Verbatim-port plan (per capability)

> Format: **HERMES FILE → WENSHU TARGET, with copy/adapt/drop notes.**
> All targets are inside `Sources/WenshuApp/` (= AGENTS.md write scope; not the scratch directory). Boss拍: "直接本地拿 hermes 源码复刻" = literally translate the Python patterns into idiomatic Swift 6.4, drop the third-party-lib guard rails, keep the docstring discipline.

### 3.1 Capability: LLM-driven entity extraction (replaces `EntityIngestion.ingest` + `ChatTrigger.detect`)

**Verbatim port from `plugins/memory/holographic/store.py` (lines 448-481) → new file `Sources/WenshuApp/Domain/ReferenceEntityExtractor.swift`.**

| From hermes | To wenshu | Action |
|---|---|---|
| `_RE_CAPITALIZED` regex (= capitalized multi-word) | `static let capitalizedPattern: NSRegularExpression` | **Copy** verbatim; translate to NSRegularExpression. |
| `_RE_DOUBLE_QUOTE` + `_RE_SINGLE_QUOTE` | `doubleQuotePattern` + `singleQuotePattern` | **Copy** verbatim. |
| `_RE_AKA` | `akaPattern` | **Copy** verbatim. |
| `_extract_entities(text:)` returning `list[str]` (deduped, first-seen) | `func extract(from text: String) -> [String]` (same dedup discipline) | **Adapt** — replace Python `re.finditer` with `NSRegularExpression.matches`; replace `set` with `Set<String>`; preserve first-seen order via `seen.insert` + append. |
| `_resolve_entity(name:)` + `_link_fact_entity` from `store.py` | `ReferenceEntityResolver.resolve(name: [Reference]) -> UUID` (resolve by title OR by alias set; create-if-missing) | **Adapt** — replace SQLite `entities` + `fact_entities` join with `FileSystemReferenceStore.loadReferences(layer: .layerEntities)` + `Reference.title == name OR aliases.contains(name)` + `saveReference(...)`. Add `aliases: [String]` field to `Reference` (= matches hermes `aliases` column; **drop** the assumption that title is the unique key — same surface-form can map to multiple Reference rows via alias). |
| `_extract_entities` is **rule-only** | **Drop** the LLM-extraction path | wenshu `WenshuConductorIdentity.systemPrompt` already drives LLM-side entity recognition on the assistant side (= per `learn_prompt.py` pattern). The Swift-side extractor is the OFFLINE / DETERMINISTIC backstop that catches what the LLM missed. The hermes source itself uses regex-only for the deterministic path; wenshu follows the same convention. |

**New scaffolding needed:** `Reference.aliases: [String]` field (= trivial additive change to `Reference.swift`); `ReferenceEntityExtractor` + `ReferenceEntityResolver` in `Domain/`; unit tests in `Tests/WenshuAppTests/Domain/ReferenceEntityExtractorTests.swift`.

### 3.2 Capability: LLM-side query rewrite + trivial-prompt gate (replaces `SmartQueryEvaluator` direct-eval path)

**Verbatim port from `plugins/memory/query_rewrite.py` (lines 1-139) → new file `Sources/WenshuApp/Domain/SmartQueryRewriter.swift`.**

| From hermes | To wenshu | Action |
|---|---|---|
| `TASK_KEY = "memory_query_rewrite"` | `static let taskKey = "smart_query_rewrite"` | **Adapt** — rename to wenshu domain. |
| `_MAX_INPUT_CHARS = 4_000`, `_MAX_QUERY_CHARS = 320` | `private static let maxInputChars = 4_000`, `private static let maxQueryChars = 320` | **Copy** verbatim. |
| `_OUTPUT_PREFIX_RE` (= `^(?:retrieval\s+query\|...)\s*:\s*`) | `outputPrefixPattern: NSRegularExpression` | **Copy** verbatim — strips `Query: ...` / `Question: ...` model prefixes. |
| `_QUESTION_START_RE` (= `^(?:what\|which\|who\|...)\b`) | `questionStartPattern: NSRegularExpression` | **Copy** verbatim. |
| `_MEMORY_GROUNDING_RE` (= `user\|their\|they\|...\|preference`) | `memoryGroundingPattern: NSRegularExpression` | **Copy** verbatim. |
| `_INSTRUCTION_LEAK_RE` (= `ignore\|obey\|follow\|...\|answer\s+directly`) | `instructionLeakPattern: NSRegularExpression` | **Copy** verbatim — defense against prompt injection via rewritten form. |
| `_INTERNAL_SENTENCE_RE` (= `[.!?]\s+\S`) | `internalSentencePattern: NSRegularExpression` | **Copy** verbatim. |
| `_SYSTEM_PROMPT` (= 12-line LLM instruction for query rewrite) | `private static let systemPrompt: String` (= identical text, English-only per AGENTS.md) | **Copy** verbatim. |
| `_bounded_user_message(message:)` truncate to 4000 chars (3000 head + 900 tail + `[... middle omitted ...]`) | `func bounded(_ message: String) -> String` | **Adapt** — replace Python slicing with `String.prefix(3000)` + `String.suffix(900)` + middle-omitted marker. |
| `_extract_response_text(response:)` (handles `str` / `list[dict]` / `object` shapes) | `private func extractResponseText(_ response: ProviderResponse) -> String` | **Adapt** — wire to wenshu's `Core/Provider/` `ProviderResponse` shape (= wenshu already standardizes on Anthropic-protocol-compatible; the three shapes collapse to one `String` via switch over `content` array). |
| `_normalize_rewrite(text:)` (12 validation steps) | `func normalize(_ text: String) -> String?` | **Adapt** — return `String?` (nil on any validation fail) instead of `""`. Steps copy 1:1. |
| `rewrite_memory_query(user_message:)` | `static func rewrite(_ userMessage: String, provider: Provider, model: String) async -> String?` | **Adapt** — async; takes `provider` (= wenshu's `Core/Provider/Provider`) + `model`; routes through `Provider.send(messages: [system, user])`. |
| `TRIVIAL_PROMPT_RE` + `is_trivial_prompt(text:)` from `agent/memory_provider.py` | Move into `Domain/SmartQueryRewriter.swift` as `isTrivialPrompt(_:) -> Bool` | **Copy** verbatim — anchored alternation, single source of truth shared with `SmartQueryEngine.run(query:)` so the gate cannot drift. |

**Wiring:** `SmartQueryEngine.run(query:)` gets a NEW step before `evaluate(against:)`: if `SmartQueryRewriter.isTrivialPrompt(originalUserQuery)` → return empty result; else if rewriter enabled in config → rewrite → wrap as a synthetic `SmartQuery` with rewritten `queryJSON`. Backward-compatible (= rewriter is OFF by default; flag-gated by `UserDefaults.wenshu.smartQueryRewrite.enabled`).

### 3.3 Capability: Cross-ref injection with token budget + plugin registry (replaces `CrossRefInject.runInjection`)

**Verbatim port from `agent/context_references.py` (lines 1-300 + 320-720) → new file `Sources/WenshuApp/Core/LinkGraph/CrossRefInjector.swift` (= moves out of `Domain/` because it becomes stateful + budget-aware).**

| From hermes | To wenshu | Action |
|---|---|---|
| `BUILTIN_PREFIXES = {"diff","staged","file","folder","git","url"}` | `static let builtinPrefixes: Set<String> = ["diff","staged","file","folder","git","url","character","world","reference","foreshadowing"]` | **Adapt** — extend with wenshu's M4/M5 reference kinds (= `character / world / reference / foreshadowing` map to existing `Reference` + `Character` + `WorldEntry` stores). |
| `_context_reference_providers: dict[str, ContextReferenceProvider]` | `private var crossRefProviders: [String: CrossRefProvider] = [:]` | **Copy** verbatim. |
| `ContextReferenceProvider` (ABC) + `ContextCompletionItem` + `ContextReference` + `ContextReferenceResult` | `protocol CrossRefProvider` + `struct CrossRefCompletionItem` + `struct CrossRef` + `struct CrossRefResult` | **Copy** verbatim with Swift idioms (= `async throws func autocomplete(query: String, limit: Int) -> [CrossRefCompletionItem]`). |
| `register_context_reference_provider(provider:)` | `func register(_ provider: CrossRefProvider)` (= guard against `builtinPrefixes` + duplicate prefix + empty prefix) | **Copy** verbatim. |
| `REFERENCE_PATTERN` + `_PLUGIN_REFERENCE_PATTERN` | `crossRefPattern: NSRegularExpression` + `pluginCrossRefPattern: NSRegularExpression` (= same two-pass logic) | **Copy** verbatim — translate Python regex to NSRegularExpression. |
| `parse_context_references(message:)` → `list[ContextReference]` | `static func parse(_ message: String) -> [CrossRef]` | **Copy** verbatim. |
| `preprocess_context_references(...)` + `_async` (= async expand-all, token-budget aware, 25% soft / 50% hard) | `static func preprocess(message: String, contextLength: Int) async -> CrossRefResult` | **Adapt** — wire token estimation to wenshu's `WenshuLLMModel.estimateTokens(_:)` (already exists in `Core/Agent/`); 25% soft / 50% hard limits copy verbatim. The async expand dispatch replaces `_expand_reference` per-kind switch with calls to registered `CrossRefProvider.expand(target:)` (built-in providers: CharacterStore / WorldStore / ReferenceStore / FileSystemTools / GitTools). |
| `format_reference_value(value:)` (quoting helper) | `static func formatReferenceValue(_ value: String) -> String` | **Copy** verbatim (= quote if value contains whitespace / parens / brackets; pick first quote char not in value). |
| `_SENSITIVE_HOME_DIRS` + `_SENSITIVE_HERMES_DIRS` + `_SENSITIVE_HOME_FILES` | `static let sensitiveHomeDirs: [String]` + `static let sensitiveHermesDirs: [String]` + `static let sensitiveHomeFiles: [String]` | **Copy** verbatim + add wenshu paths: `shelves/.hub`, `.scratch/`, `Sources/WenshuApp/Core/Memory/chat.sqlite`. |

**Wiring changes to `Domain/CrossRefInject.swift`:** keep the frontmatter parser (= `FrontmatterParser`) and `ChapterFrontmatter` (= port is additive; no need to break that file). The `runInjection` loop becomes: (1) build provider registry from `Core/Memory/` + `Core/LinkGraph/` + `Storage/FileSystem*Store`; (2) parse each chapter's body for `@<prefix>:<target>` patterns via `CrossRefInjector.parse`; (3) expand each via registered provider, honoring token budget; (4) append resolved UUIDs to `ChapterFrontmatter.referenceRefIds`. Existing substring-match fallback remains as the budget-exhausted path.

### 3.4 Capability: LLM Wiki 4-layer ingest pipeline (fills `layerAbstracts` + `layerIndexes`)

**Verbatim port from `skills/research/llm-wiki/SKILL.md` → new files `Sources/WenshuApp/Domain/LLMWikiSchema.swift` + `Sources/WenshuApp/Domain/LLMWikiIngestor.swift` + `Sources/WenshuApp/Domain/LLMWikiLinter.swift`.**

| From hermes (the skill body) | To wenshu | Action |
|---|---|---|
| `SCHEMA.md` template (= domain, conventions, frontmatter spec, tag taxonomy, page thresholds) | `LLMWikiSchema` (Swift struct holding `domain / conventions / tagTaxonomy / pageThresholds` + `Data` representation for serialization to `reference-library/SCHEMA.md`) | **Adapt** — convert the prose spec into a Swift data model so the schema can be inspected at runtime; serialize back to markdown on write. |
| `index.md` template (sectioned by type; one-line summary per page) | `LLMWikiIndex` (= generates `reference-library/index.md` from `ReferenceStore.loadAllReferences()` grouped by `ReferenceLayer`) | **Copy** verbatim — sectioned catalog with `(title, summary)` per entry. |
| `log.md` template (append-only, rotated at 500 entries) | `LLMWikiLog` (= thread-safe append to `reference-library/log.md`; `loadRecentEntries(limit: Int) -> [LogEntry]`; auto-rotate) | **Copy** verbatim — `[YYYY-MM-DD] action \| subject` format. |
| Ingest step ① "Capture the raw source" + sha256 frontmatter | `LLMWikiIngestor.captureRaw(source: RawSource) -> Reference` (= writes `<uuid>.md` to `raw/` with frontmatter + sha256 of body) | **Copy** verbatim — sha256 the body (everything after `---`), not the frontmatter itself. |
| Ingest step ② "Discuss takeaways" (= dropped in automated context) | **Drop** — wenshu is single-agent + LLM-driven, no human-in-the-loop step. The takeaway extraction is handled by `EntityIngestion.ingest` (= already exists). |
| Ingest step ③ "Check what already exists" (= search index.md before creating) | `LLMWikiIngestor.findExisting(title: String) -> Reference?` (= wraps `ReferenceStore.loadReferences(layer:)` + title match; if found, UPDATE instead of CREATE) | **Copy** verbatim. |
| Ingest step ④ "Write or update wiki pages" + provenance + confidence frontmatter | `LLMWikiIngestor.upsert(_ reference: Reference, bodyMarkdown: String, provenance: [URL], confidence: Confidence)` (= writes `<uuid>.md` w/ frontmatter `title / created / updated / type / tags / sources / confidence / contradictions`) | **Adapt** — extend `Reference` struct with `tags: [String]` + `confidence: Confidence?` + `contradictions: [UUID]` (= additive fields; backward-compatible w/ existing JSON sidecar). |
| Ingest step ⑤ "Update navigation" (= add to index.md + append to log.md) | `LLMWikiIngestor.recordNavigation(reference: Reference, action: LLMWikiAction)` | **Copy** verbatim. |
| Ingest step ⑥ "Report what changed" | `LLMWikiIngestResult` (= `[Reference] created + [Reference] updated + [Reference] skipped`) | **Copy** verbatim. |
| Lint step ① "Orphan pages" (= no inbound `[[wikilinks]]`) | `LLMWikiLinter.findOrphans() -> [Reference]` (= wraps `LinkIndex.searchBackward` for each ref) | **Copy** verbatim — reuses wenshu's existing SQLite `LinkIndex` (= already implements `searchBackward(targetDocId:)`). |
| Lint step ② "Broken wikilinks" (= `[[X]]` where no X exists) | `LLMWikiLinter.findBrokenWikilinks() -> [(Reference, [String])]` | **Copy** verbatim — reuses `LinkIndex`. |
| Lint step ③ "Index completeness" | `LLMWikiLinter.findMissingFromIndex() -> [Reference]` | **Copy** verbatim. |
| Lint step ④ "Frontmatter validation" | `LLMWikiLinter.validateFrontmatter() -> [(Reference, [String])]` | **Copy** verbatim. |
| Lint step ⑤ "Stale content" (>90 days since updated AND newer raw source mentions same entity) | `LLMWikiLinter.findStale(within: TimeInterval = 90 * 86400) -> [Reference]` | **Copy** verbatim. |
| Lint step ⑥ "Contradictions" (= pages with `contested: true` OR conflicting `contradictions:`) | `LLMWikiLinter.findContested() -> [Reference]` | **Copy** verbatim. |
| Lint step ⑩ "Tag audit" (= tags not in `SCHEMA.md` taxonomy) | `LLMWikiLinter.findUntaxonomizedTags() -> Set<String>` | **Copy** verbatim. |
| Lint step ⑪ "Log rotation" (>500 entries → rename `log.md` to `log-YYYY.md`) | `LLMWikiLog.rotateIfNeeded()` | **Copy** verbatim. |
| Pitfall list (= "Never modify files in `raw/`" / "Always orient first" / "Always update index.md and log.md" / etc.) | Inline as `///` doc-comments on the corresponding methods; cross-link from `LLMWikiIngestor` class doc | **Adapt** — translate the 8 pitfalls into doc-comment rules so Swift compiler warnings catch regressions. |

**Wiring changes to `Domain/Reference.swift`:** additive fields only. No breaking changes to existing `Reference` JSON sidecars (= `JSONDecoder` will silently skip unknown fields).

---

## 4. Out of scope (third-party-lib territory — SKIPPED per boss OOB)

These were in the original inventory `needs_survey` list but are NOT agent-side per boss directive. They remain open for a future non-agent survey wave:

| Need | Why NOT in this report |
|---|---|
| Fuzzy search as-you-type (= `fuse` / `FuzzyMatch`) | pure Swift framework = non-agent. Boss拍: agent-related only. |
| Schema validation for markdown frontmatter | pure Swift framework = non-agent. |
| Codex visualization (Character web) | SwiftUI rendering layer = non-agent UI. |

---

## 5. ALREADY-REPLICATED surface (do not re-port)

These capabilities were ported in earlier wenshu v0.21-v0.23 hermes parity audits and ship in current source. Mentioned here so the verifier can confirm no duplication:

| Hermes surface | Wenshu file / feature | Shipped |
|---|---|---|
| `agent/memory_manager.py` (provider dispatch, prefetch/sync lifecycle) | `Core/Memory/MemoryManager.swift` (`prefetch / sync / queuePrefetch / takeQueuedPrefetch`) | v0.21 |
| `agent/memory_provider.py` (provider ABC + lifecycle hooks) | `Core/Memory/MemoryStore.swift` + `MemoryWriteGate.swift` | v0.21 |
| `agent/context_compressor.py` (consolidation logic) | `Core/Memory/MemoryConsolidator.swift` | v0.22 |
| `skills/` skill registry (= `list / load / invoke`) | `Core/Skills/SkillRegistry.swift` | v0.22 |
| Skill trust + quarantine policy | `Core/Skills/SkillMeta.swift` (`SkillTrustLevel / SkillSource / SkillTrustPolicy.shouldAllow / SkillQuarantine`) | v0.23 |
| Sub-agent dispatch + delegation handle | `Core/Agent/WenshuConductor.swift` (intent → delegate → synthesis) + `Core/Agent/AsyncDelegation.swift` | v0.21-v0.23 |
| Sub-agent permission model | `Core/Agent/SubAgentIdentity.swift` + `SubAgentPermissions.swift` + `DELEGATE_BLOCKED_TOOLS` parity | v0.23 |
| Multi-agent `MoA` (Mixture-of-Agents loop) | `WenshuConductor.parseAgentList` + `buildSynthesisPrompt` (= hermes `moa_loop.py` port) | v0.23 |
| `agent/auxiliary_client.py` (cheap LLM routing for non-conversational tasks) | `Core/Agent/WenshuConductor.swift` intent-classify path | v0.23 |
| `tools/async_delegation.py` (background sub-agent heartbeat / kill / interrupt) | `Core/Agent/AsyncDelegation.swift` (`take / markCompleted / markFailed / interrupt`) | v0.23 |
| `agent/system_prompt.py` SOUL pattern | `WenshuConductorIdentity.systemPrompt` (= hex-encoded forbidden tokens per v0.28 pollution defense) | v0.23 + v0.28 |
| Anthropic-protocol adapter | `Core/Provider/ProviderFetcher.swift` (= all 11 curated providers) | v0.23 |

---

## 6. NEW-IN-HERMES surface since 2026-08-23 (= only flag if wenshu has NOT yet replicated)

Inspected 2026-08-28 hermes source. Findings:

| Hermes surface | Date | Wenshu status | Action |
|---|---|---|---|
| `plugins/memory/supermemory/__init__.py` (long-term semantic memory via supermemory.ai API, with profile recall + cleaned turn capture) | 2026-Q3 | **NOT replicated** | Out of scope (external API); skip per wenshu `Core/Memory/` is local-SQLite-only per AGENTS.md §"Apple-stack-exclusive" |
| `plugins/memory/honcho/__init__.py` (dialogue-aware memory w/ dialectic retrieval) | 2026-Q3 | **NOT replicated** | Out of scope (external API) |
| `plugins/memory/hindsight/__init__.py` (long-horizon memory via bi-temporal facts) | 2026-Q3 | **NOT replicated** | Out of scope (external API) |
| `plugins/memory/byterover/` + `openviking/` + `holographic/` | 2026-Q3 | **NOT replicated** | All external-API providers; wenshu local-only. |
| `plugins/memory/query_rewrite.py` (LLM query rewriter) | 2026-Q3 | **NOT replicated** | **In scope** — covered by §3.2. |
| `agent/context_references.py::ContextReferenceProvider` (plugin-registered `@<prefix>:<target>` API, Issue #26193) | 2026-Q3 | **NOT replicated** | **In scope** — covered by §3.3. |
| `skills/research/llm-wiki/SKILL.md` v2.1.0 (canonical Karpathy LLM Wiki spec) | 2026-Q3 | **NOT replicated as a pipeline** (only the 4-layer enum exists) | **In scope** — covered by §3.4. |
| `plugins/memory/holographic/store.py::_extract_entities` (deterministic regex entity extractor) | 2026-Q3 | **NOT replicated** (wenshu has only ChatTrigger CN-quoted regex) | **In scope** — covered by §3.1. |

No M5-relevant hermes surface was replicated silently; the only NEW agent-side capabilities since 2026-08-23 are exactly the four in this report.

---

## 7. Acceptance criteria (this report)

- ✅ Per-module wenshu agent-side surface listed (§1)
- ✅ Per-capability hermes source files identified (§2)
- ✅ Verbatim port plan per capability (= file → file, copy/adapt/drop) (§3)
- ✅ Out-of-scope third-party-lib survey skipped per boss OOB (§4)
- ✅ Already-replicated surface enumerated to avoid duplication (§5)
- ✅ NEW-in-hermes since 2026-08-23 flagged only for M5-relevant items (§6)
- ✅ Zero edits to `Package.swift` / `AGENTS.md` / `CONTEXT.md` / `Sources/` (READ-ONLY constraint per task)
- ✅ All writes confined to `.scratch/2026-08-28-six-module-audit/modules/M5-character-world-codex.md`