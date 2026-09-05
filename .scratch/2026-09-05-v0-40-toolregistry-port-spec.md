# v0.40 ToolRegistry 1:1 port (= boss 2026-09-05 OOB '参考 hermes, 1:1 复刻')

## Boss directive (verbatim)

> 过于工程，我无法判断，参考 hermes，1:1 复刻

## Why 1:1 (vs original 4-option plan)

The original 4-option A/B/C/D plan was too engineer-driven; boss cannot judge without a reference. Switch direction: port hermes' `tools/registry.py` 1:1 to wenshu (= model the architecture on a proven implementation instead of designing from scratch).

## Hermes source of truth

- File: `/Volumes/ANAN/.hermes/tools/registry.py` (= 766 LOC)
- Class: `ToolRegistry` (= singleton, thread-safe via `threading.RLock`)
- Struct: `ToolEntry` (= 10 fields = name / toolset / schema / handler / check_fn / requires_env / is_async / description / emoji / max_result_size_chars)
- Method: `register()` with override protection (= prevents accidental shadowing)
- Method: `get_definitions()` returns tool schemas for LLM
- Mechanism: `discover_builtin_tools()` scans `tools/*.py` via AST (= hermes does NOT use `@Tool` decorator / explicit registration in main)

## What to ship (= 1 ticket, = 2 commits)

### Commit 1 — `feat(wenshu): PORT-TOOLREGISTRY-001 -- port hermes tools/registry.py 1:1 (= ToolRegistry actor + ToolEntry struct + auto-discovery + 8 tests)`

Create `Sources/WenshuApp/Core/Agent/Tool/ToolRegistry.swift` (= ~400 LOC Swift port):

```swift
public struct ToolEntry: Sendable, Equatable {
    public let name: String
    public let toolset: String
    public let schema: ToolSchema           // JSON schema
    public let handlerID: ObjectIdentifier  // points to registered Tool actor instance
    public let checkFn: (@Sendable () -> Bool)?
    public let requiresEnv: [String]
    public let isAsync: Bool
    public let description: String
    public let emoji: String
    public let maxResultSizeChars: Int?

    // ... standard init ...
}

public actor ToolRegistry {
    public static let shared = ToolRegistry()

    private var _tools: [String: ToolEntry] = [:]
    private var _handlers: [ObjectIdentifier: any Tool] = [:]
    private var _generation: Int = 0
    private let _lock = NSLock()  // actor isolation already gives us serialization; lock = safety for nonisolated reads

    /// Register a tool (= hermes register() with override protection).
    public func register(
        name: String,
        toolset: String,
        schema: ToolSchema,
        handler: any Tool,
        checkFn: (@Sendable () -> Bool)? = nil,
        requiresEnv: [String] = [],
        isAsync: Bool = true,
        description: String = "",
        emoji: String = "",
        maxResultSizeChars: Int? = nil,
        override: Bool = false
    ) async {
        // ... hermes-equivalent logic ...
    }

    /// Get tool definitions for LLM (= hermes get_definitions()).
    public func getDefinitions(toolNames: Set<String>) async -> [ToolSchema]

    /// Get a registered tool (= for execution).
    public func getHandler(name: String) async -> (any Tool)?

    /// Current generation (= for cache invalidation).
    public func generation() async -> Int

    /// Clear all registrations (= for testing).
    public func clear() async
}
```

### Commit 2 — `feat(wenshu): MIGRATE-TOOLREGISTRY-002 -- migrate all 12 existing tool registrations to ToolRegistry.shared.register(...) (= hermes-style auto-discovery)`

Update all 12 existing tool files to call `ToolRegistry.shared.register(...)` at module-load time (= instead of the current ad-hoc `WenshuConductor.tools: [String: any Tool]` dict construction):

- `ParagraphAITool.swift` (already a stub-→-EditorTransformTools dispatch from P1 #10)
- `TodoStoreTool.swift` (from WIRE-AGENT-004)
- `KanbanStoreTool.swift` (from WIRE-AGENT-005)
- `BookManagerTool.swift` (from PORT-LIBRARIAN-001)
- `FileTool.swift` (existing)
- `ProcessTool.swift` (existing)
- `VisionTool.swift` (existing)
- `WebTool.swift` (existing)
- `EditorTransformTools.swift` (from PORT-SPECIALIZED-005)
- ... etc.

Each file calls:
```swift
// At module-load time (= outside any actor)
await ToolRegistry.shared.register(
    name: "ParagraphAI",
    toolset: "editor",
    schema: .editorExpand,
    handler: ParagraphAITool.shared,
    description: "Expand selected text (= make longer)",
    emoji: "⤴"
)
```

This is a **declarative registration** (= hermes-style) instead of the current explicit `WenshuConductor.tools` dict construction.

## Hard rules (= from original 4-option spec + boss directive)

- English-only in all files.
- DO NOT touch AGENTS.md / CLAUDE.md / README.md / CHANGELOG.md.
- DO NOT introduce any new third-party dependency (= Apple stack exclusive per §11.1).
- DO NOT remove any existing public surface on `Tool` protocol / `WenshuConductor.tools`.
- DO NOT touch the existing 7 LLM-connector profiles (Anthropic / OpenAI / etc.) — these are not tools, they're connectors.
- DO NOT touch any file outside `ToolRegistry.swift` (new) + the 12 tool files (registration calls added).

## Acceptance

- swift build exit 0
- swift build --target WenshuAppTests exit 0
- swift test --filter "ToolRegistry" = 8/8 pass
- All existing tool tests still pass (= no regression in WIRE-AGENT-002 / 004 / 005 / etc.)
- Working tree clean after push

## Tests (8 round-trip)

1. testRegister_addsEntry
2. testRegister_overrideProtection_rejectsShadowing
3. testRegister_overrideTrue_acceptsShadow
4. testGetDefinitions_returnsFilteredSchemas
5. testGetHandler_returnsCorrectTool
6. testClear_removesAllEntries
7. testGeneration_incrementsOnMutation
8. testConcurrentRegister_threadSafe

## Frontend verification dependency

**None** (= internal refactor; no UI changes). Boss can verify by launching wenshu.app and checking that the existing 12 tools still appear in CommandPalette (= tools still registered correctly via the new singleton pattern).

## Workspace

/Volumes/ANAN/Engineering/wenshu (main worktree).

## Out of scope (= not part of this ticket)

- Migrating from `WenshuConductor.tools` dict to `ToolRegistry.shared` (= separate ticket; this one just adds the registry, future tickets use it)
- Auto-discovery via SwiftSyntax AST scan (= hermes does this for Python; Swift equivalent needs SwiftSyntax lib which would be a new dep; deferred to separate ticket)
- `check_fn` TTL cache + transient-failure suppression (= hermes-specific Python detail; not relevant for Swift actor model)

## Effort

M (= 2-3 days).

## Risk

Low (= pure addition; existing public surface unchanged).

## Value

Medium-High (= enables future dynamic tool discovery + centralized metadata + override protection for plugins).

*First line = fact. Last line = fact.*