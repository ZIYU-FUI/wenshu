# 009: Port memory subsystem (wenshu-side, filesystem JSON per §11 baseline)

**What to build:** Port hermes memory subsystem (`agent/memory_manager.py` 1,086 LOC + `agent/memory_provider.py` ~400 LOC) into wenshu's filesystem-JSON storage layer. Per §11 baseline, wenshu memory uses filesystem JSON (NOT SQLite) inside the per-book `world/` + `characters/` folders. Memory retrieval runs cross-book via the library-public `reference-library/` (= §11 baseline). After this ticket, wenshu's LLM calls can use memory for context enrichment.

**Blocked by:** 001 (LLMConnector protocol + agent loop must exist so memory can be retrieved inside the loop)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/memory_manager.py` | 1,086 | Full port = memory storage + retrieval interface (storage backend differs: wenshu = filesystem JSON; hermes = SQLite) |
| `agent/memory_provider.py` | ~400 | Full port = memory backend interface |

Plus NEW wenshu-side authoring of:
- `Sources/WenshuApp/Core/Agent/Memory/MemoryStore.swift` (= filesystem JSON backend; wenshu §11 baseline)

## UI-affordance mapping (per spec §6.4)

This ticket's translated products and their UI landing:

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| Memory subsystem (engine) | (underwater) | 🟦 | retrieval runs inside ConversationLoop |
| Memory retrieval result display | DynamicZone right-bottom | 🟨 + 🟥 | user sees what memory was retrieved for current turn |
| Memory configuration | Settings弹窗 new "Memory" view | 🟥 | user configures memory scope + retention |

**3-question check** (per spec §6.4):

1. **Who triggers it?** Memory retrieval triggers automatically inside `ConversationLoop.runTurn()` before each LLM call (= 🟦 engine). User opens Settings → Memory to configure (= 🟥).
2. **What signal does the user see?** In DynamicZone right-bottom (= existing `DynamicZoneView.swift` + `ZoneContentView.swift`), a new "Memory" tab shows retrieved memory entries for the current turn with their source file paths. In Settings → Memory, user sees scope config (per-book vs library-public) + retention settings.
3. **UI affordances added**: DynamicZone new tab "Memory" with retrieval list (= 🟥); Settings弹窗 new "Memory" view (= 🟥).

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Memory/MemoryManager.swift` ports `memory_manager.py` 1:1 (interface shape; storage backend differs)
- [ ] `Sources/WenshuApp/Core/Agent/Memory/MemoryProvider.swift` ports `memory_provider.py` 1:1 (interface; wenshu = filesystem JSON, hermes = SQLite)
- [ ] `Sources/WenshuApp/Core/Agent/Memory/MemoryStore.swift` authored (wenshu-side; per §11 baseline = filesystem JSON under `.ws/shelves/<shelf>/books/<book>/world/` + `characters/` + `reference-library/`)
- [ ] Memory retrieval integrates with ConversationLoop.swift (= retrieved memory injected into context as system-prompt dynamic tier)
- [ ] Cross-book memory: reference-library access works (per §11 baseline)
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] Z contract test: golden files for memory retrieval entry/exit
- [ ] Manual e2e: open book A, ask LLM "what does character X look like" — answer draws from `.ws/shelves/<shelf>/books/<book-A>/characters/<X>.md` (= per-book private memory)

## Iron rules applied

- [ ] Direct port with `// SWIFT-PORT:` markers (interface only; backend = wenshu filesystem JSON, NOT SQLite)
- [ ] §11 baseline: wenshu memory = filesystem JSON. Do NOT introduce SQLite for memory storage.
- [ ] Cross-book privacy: reference-library is library-public but per-book memory is per-book private. Honor §11 baseline.

## Estimated LOC

~1,500 Swift LOC.

## Commit format

`feat(wenshu): v0.35 -- memory subsystem (filesystem JSON backend) (= ticket 009 of 11)`