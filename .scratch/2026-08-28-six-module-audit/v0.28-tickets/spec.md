# Wenshu v0.28 third-party-integration + M5/M6 hermes-port — ticket spec

> Boss 2026-08-28 OOB拍 (after six-module audit):
> 1. Grape::ForceSimulation — **A** (accept WARN)
> 2. EPUBKit — **ADOPT**, boss确认 EPUB import trigger feeds M5 LLM Wiki pipeline (= entity extraction + 文风 fingerprint indexing into reference-library abstracts + indexes layers)
> 3. HighlighterSwift — **ADOPT** (accept thin margin)
> 4. M5/M6 hermes-port — split into 4-5 v0.28 tickets (not one mega-commit)

## Scope

This batch covers **all 11 library adoptions + 4 hermes-port workstreams** = 15 distinct v0.28+ commits landing across the next 4-5 sprint cycles. Each ticket = 1 atomic commit (per Q124 + Q108).

## Adoptions (= Package.swift + docs commit per library)

| # | Ticket | Lib | Pin | Trigger |
|---|---|---|---|---|
| 01 | v0.28-3p-01 — adopt `pointfreeco/swift-snapshot-testing` | snapshot-testing | 1.19.4 | TestTarget only; lands with v0.28 ticket 028-011 (drag-lost regression suite) |
| 02 | v0.28-3p-02 — adopt `smittytone/HighlighterSwift` | HighlighterSwift | 3.1.0 | UI enhancement; lands with M2 chapter-preview ticket (= code-fence syntax highlight) |
| 03 | v0.28-3p-03 — adopt `witekbobrowski/EPUBKit` + `EPUBImportService` adapter | EPUBKit | 0.5.0 | M3 EPUB import ticket; trigger feeds M5-3 LLM Wiki pipeline |
| 04 | v0.28-3p-04 — adopt `davecom/SwiftGraph` | SwiftGraph | 4.0.0 | M4 foreshadowing graph algorithms (BFS / Dijkstra / Prim) |
| 05 | v0.28-3p-05 — adopt `li3zhen1/Grape::ForceSimulation` (CONDITIONAL WARN) | ForceSimulation | 1.1.0 | M4 force-directed layout; boss拍 A = WARN accepted, adapter wraps |
| 06 | v0.28-3p-06 — adopt `apple/swift-log` | swift-log | 1.5.4 | M6 observability; lands with first wenshu CLI / daemon ticket |
| 07 | v0.28-3p-07 — adopt `orchetect/MenuBarExtraAccess` | MenuBarExtraAccess | 1.3.0 | M6 menu bar toggle when v0.28+ menu shape lands |
| 08 | v0.28-3p-08 — bump `sindresorhus/Defaults` 8.2.0 → 9.0.8 | Defaults | 9.0.8 | v0.28 chat history migration ticket (= first consumer of complex Codable UserDefaults) |
| 09 | v0.28-3p-09 — bump `sindresorhus/KeyboardShortcuts` 1.10.0 → 2.2.0 | KeyboardShortcuts | 2.2.0 | v0.28 Settings pane Keyboard tab |
| 10 | v0.28-3p-10 — bump `realm/SwiftLint` → 0.62.1 | SwiftLint | 0.62.1 | Brewfile update + wenshu-devtool pre-commit hook integration |
| 11 | v0.28-3p-11 — bump `nicklockwood/SwiftFormat` → 0.62.1 | SwiftFormat | 0.62.1 | Brewfile update + wenshu-devtool pre-commit hook integration |

11 adopt-list tickets = 11 atomic commits.

## M5 hermes-port (per `.scratch/2026-08-28-six-module-audit/modules/M5-character-world-codex.md`)

| # | Ticket | From hermes | To wenshu | Est LOC |
|---|---|---|---|---|
| 12 | v0.28-m5-01 — entity extraction verbatim port | `plugins/memory/holographic/store.py::_extract_entities` (L448-481) | `Domain/ReferenceEntityExtractor.swift` | ~300 |
| 13 | v0.28-m5-02 — smart-query rewriter + trivial-prompt gate | `plugins/memory/query_rewrite.py` (139 LOC) | `Domain/SmartQueryRewriter.swift` | ~250 |
| 14 | v0.28-m5-03 — cross-ref injection with token budget + plugin registry | `agent/context_references.py::ContextReferenceProvider` | `Domain/CrossRefInject_v2.swift` | ~400 |
| 15 | v0.28-m5-04 — LLM Wiki 4-layer ingest pipeline (= Karpathy pattern, feeds EPUBKit imports) | `skills/research/llm-wiki/SKILL.md` v2.1.0 | `Domain/{LLMWikiSchema,LLMWikiIngestor,LLMWikiLinter}.swift` | ~550 |

## M6 hermes-port (per `.scratch/2026-08-28-six-module-audit/modules/M6-settings-library.md`)

| # | Ticket | From hermes | To wenshu | Est LOC |
|---|---|---|---|---|
| 16 | v0.28-m6-01 — Provider profile + models_dev adapter | `providers/base.py` + `agent/models_dev.py` + `agent/model_metadata.py` | `Core/Provider/{ProviderProfile,ModelsDev,ModelMetadata}.swift` | ~800 |
| 17 | v0.28-m6-02 — Agent identity + system prompt builder | `agent/prompt_builder.py` + `agent/system_prompt.py` + `agent/onboarding.py` | `Core/Agent/WenshuSystemPromptBuilder.swift` + extend `WenshuAgentIdentity` | ~1300 |
| 18 | v0.28-m6-03 — MemoryManager REPLACES existing | `agent/memory_manager.py` (1393 LOC) | new `Core/Memory/MemoryManager.swift` REPLACES existing | ~700 |
| 19 | v0.28-m6-04 — Skills hub (provenance + guard + linter + ledger) | `tools/skills_hub.py` + `tools/skill_provenance.py` + `tools/skills_guard.py` + `tools/skill_linter.py` + `tools/skill_ledger.py` | `Core/Skills/{SkillSource,HubStateDir,SkillFrontmatterParser,SkillProvenance,SkillGuard,SkillLinter,SkillLedger,SkillManager}.swift` | ~1300 |
| 20 | v0.28-m6-05 — Cron scheduler + lifecycle guard | `cron/jobs.py` + `cron/scheduler.py` + `cron/executions.py` + `cron/incidents.py` + `cron/monitor.py` + `cron/lifecycle_guard.py` | `Core/Cron/{CronjobStore,CronScheduler,CronScheduleCalculator,CronExecution,CronIncident,CronMonitor,CronLifecycleGuard}.swift` | ~900 |

## Total = 20 tickets (across 4-5 sprint cycles)

| Category | Count | Total est. LOC |
|---|---|---|
| Adoptions | 11 | ~minor (mostly Package.swift rows + AGENTS.md §11.1 entries + trigger docs) |
| M5 hermes-port | 4 | ~1,500 |
| M6 hermes-port | 5 | ~5,000 |

## Dependency graph

```
[T-12 entity-extract]          ──┐
[T-13 smart-query-rewriter]    ──┼─→ [T-15 llm-wiki-pipeline]
[T-14 cross-ref-inject]        ──┘             │
                                              ↓
[T-03 EPUBKit + adapter] ─────────────────→ feeds T-15
                                              │
                                              ↓
[T-19 Skills hub] ──→ [T-20 Cron scheduler] (uses SkillRegistry)
[T-18 MemoryManager REPLACES] ──→ [T-17 Agent identity] (system prompt mentions memory provider)
[T-16 Provider profile] ──→ [T-17 Agent identity] (system prompt lists provider profiles)
```

**Independent tracks** (parallelizable):
- M5-12/13/14/15 (one chain, self-contained)
- M6-16 (Provider, lowest-level)
- M6-17 (Agent identity, depends on M6-16)
- M6-18 (MemoryManager, independent)
- M6-19 (Skills hub, independent)
- M6-20 (Cron scheduler, depends on Skills hub for SkillRegistry reference)

Adoptions 01-11 are all independent (each = 1 Package.swift row + 1 doc commit).

## Acceptance criteria

- 20 atomic commits land before v0.28 ship, each pass Q34 po main flow 8-step checklist
- Each adoption commit: Package.swift row + AGENTS.md §11.1 entry + `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/NN-*.md` ticket = 1 commit per Q124
- Each hermes-port ticket: spec → verbatim-port file → `swift build` exit 0 → dual-axis code-review (Standards + Spec per Q125) → CONTEXT.md domain word (if new concept) per Q34 step 7
- Cross-pollination: T-15 (LLM Wiki) MUST accept EPUBKit imports as one trigger, with the `EPUBImportService` adapter from T-03 wired into T-15's ingest entry point

## Out of scope

- v0.28 free-layout ticket 028-001+ (separate spec at `.scratch/2026-08-28-v0-28-free-layout/`)
- Per-feature UX tickets (= consume the adoption, ship in 029+ or 028 feature wave)
- Bonsplit (rejected per ADR-0008 path C)