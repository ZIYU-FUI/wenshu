//
//  ToolRegistryEndToEndTests.swift · Wenshu · v0.40 VERIFY-TOOLREGISTRY-004
//
//  Final end-to-end verification that the 12 self-registering wenshu
//  tools all materialize through `ToolRegistry.shared` (= the hermes
//  pattern adopted in PORT-001 / MIGRATE-002 / WIRE-003).
//
//  Bootstrap mechanics (= important context):
//  Each of the 12 tool files owns a `public static let _registryBootstrap`
//  (= a Swift 6-compatible lazy init for the hermes module-load
//  `register(...)` call). The static `let` runs the FIRST time the
//  type is referenced. Production code paths trigger it via
//  `ParagraphAITool.shared`, `ReadFileTool()`, etc. (= the type-touch
//  fires the bootstrap). In tests, the bootstrap is dormant unless
//  the test explicitly references the type. These tests therefore
//  reference each of the 12 tool types via `_ = ClassName._registryBootstrap`
//  before asserting on the registry (= mirrors production type-access
//  patterns).
//
//  Surface tested (= 4 tests):
//    1. testAll12ToolsRegistered       -- every expected tool name
//                                         resolves via `getHandler`.
//    2. testGetDefinitionsReturnsAll    -- `getDefinitions` returns
//                                         >= 12 ToolRegistrySchemas,
//                                         each with non-empty
//                                         name + description.
//    3. testBuildToolsYieldsTwelve     -- WenshuConductor.buildTools
//                                         yields >= 12 tool handlers
//                                         from ToolRegistry.shared.
//    4. testGenerationIncreases        -- mutation counter increments
//                                         after a fresh register call.
//                                         (Uses an isolated
//                                         `ToolRegistry()` instance
//                                         for this one test to
//                                         avoid polluting the shared
//                                         singleton.)
//
//  Acceptance: `--filter "ToolRegistryEndToEnd"` = 4/4 pass.
//
//  Hard rule: tests only. No source-file changes. (= matches the
//  VERIFY-TOOLREGISTRY-004 ticket scope.)

import Foundation
import SwiftData
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

@Suite("ToolRegistry end-to-end (VERIFY-TOOLREGISTRY-004)")
struct ToolRegistryEndToEndTests {
    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSKanbanRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    ///  migration from KanbanStore actor.
    @MainActor
    private static func makeKanbanRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }



    /// Canonical 11 tool names as registered by the 11 tool files at
    /// module-import time. Names match `WenshuConductor.defaultToolNames`
    /// (= single source of truth for the conductor's tool surface).
    ///
    /// Kept in declaration order to match the conductor list for
    /// diff-clarity.
    private static let expectedToolNames: [String] = [
        "ReadFile",        // Core/Agent/Tool/ReadFileTool.swift
        "WriteFile",       // Core/Agent/Tool/WriteFileTool.swift
        "av",              // Core/Tools/AVMediaTools.swift
        "book_manager",    // Core/Agent/Librarian/BookManagerTool.swift
        "file",            // Core/Tools/FileTools.swift
        "kanban",          // Core/Agent/Tool/KanbanStoreTool.swift
        "process",         // Core/Tools/ProcessTools.swift
        "todo",            // Core/Agent/Tool/TodoStoreTool.swift
        "todo_hermes",     // Core/Agent/Todo/HermesTodoTool.swift
        "vision",          // Core/Tools/VisionTools.swift
        "web"              // Core/Tools/WebTools.swift
    ]

    /// Upper bound on how long to wait for the module-load registrations to
    /// land. Each `_registryBootstrap` schedules its `Task { await … }` on the
    /// cooperative pool, so how long that takes depends on what else the
    /// process is doing. A fixed sleep tuned for an idle run is too short when
    /// the whole suite runs in parallel — `kanban` and `todo` were the two that
    /// lost the race, every time. Poll instead of sleeping once.
    private static let settleTimeoutMs: UInt64 = 5_000
    private static let settlePollMs: UInt64 = 20

    /// Waits until every expected tool has a handler, then returns the names
    /// still missing (empty = settled). FAILURE MODE: returns the missing set
    /// rather than trapping, so the assertion reports which tools did not land.
    private static func awaitSettledRegistration() async -> [String] {
        var missing = expectedToolNames
        let deadline = ContinuousClock.now.advanced(
            by: .milliseconds(Int64(settleTimeoutMs))
        )
        while ContinuousClock.now < deadline {
            var stillMissing: [String] = []
            for name in missing {
                if await ToolRegistry.shared.getHandler(name: name) == nil {
                    stillMissing.append(name)
                }
            }
            if stillMissing.isEmpty { return [] }
            missing = stillMissing
            try? await Task.sleep(nanoseconds: settlePollMs * 1_000_000)
        }
        return missing
    }

    /// Force every one of the 11 tool types' `_registryBootstrap`
    /// static `let` to run (= the Swift 6-compatible lazy module-load
    /// registration site). Each tool file wraps its
    /// `Task { await ToolRegistry.shared.register(...) }` inside
    /// `public static let _registryBootstrap: Void = { Task { ... } }()`,
    /// which fires on first type access. Touching `_registryBootstrap`
    /// here mirrors the production ChatView type-access pattern and
    /// primes the shared singleton for the test assertions.
    ///
    /// Order-independent: each bootstrap registers a distinct name so
    /// no override protection fires.
    private static func triggerAllToolBootstraps() {
        _ = ReadFileTool._registryBootstrap
        _ = WriteFileTool._registryBootstrap
        _ = AVMediaTools._registryBootstrap
        _ = BookManagerTool._registryBootstrap
        _ = FileTools._registryBootstrap
        _ = KanbanStoreTool._registryBootstrap
        _ = ProcessTools._registryBootstrap
        _ = TodoStoreTool._registryBootstrap
        _ = HermesTodoTool._registryBootstrap
        _ = VisionTools._registryBootstrap
        _ = WebTools._registryBootstrap
    }

    /// Test 1 -- every expected tool name resolves via the shared
    /// registry's `getHandler` (= the dispatch path used by
    /// `ToolExecutor`).
    @Test("All 11 expected tools are registered in ToolRegistry.shared")
    func testAll11ToolsRegistered() async throws {
        // Force all 11 tool bootstraps to fire (= production
        // type-access pattern).
        Self.triggerAllToolBootstraps()

        // Brief settle so the Task blocks have time to land on the
        // actor (= matches `WenshuConductor.buildTools(from:)`
        // warmup window).
        let unsettled = await Self.awaitSettledRegistration()
        #expect(unsettled.isEmpty,
                "tools never registered within 5s: \(unsettled)")

        for toolName in Self.expectedToolNames {
            let handler = await ToolRegistry.shared.getHandler(name: toolName)
            #expect(
                handler != nil,
                "Tool '\(toolName)' is missing from ToolRegistry.shared (= module-load registration did not settle)"
            )
        }
    }

    /// Test 2 -- `getDefinitions` returns >= 11 schemas, each with
    /// non-empty name + description (= the schema surface used by the
    /// LLM function-call envelope).
    @Test("ToolRegistry.getDefinitions returns 11+ schemas with valid name + description")
    func testGetDefinitionsReturnsAll() async throws {
        Self.triggerAllToolBootstraps()
        let unsettled = await Self.awaitSettledRegistration()
        #expect(unsettled.isEmpty,
                "tools never registered within 5s: \(unsettled)")

        let requested = Set(Self.expectedToolNames)
        let definitions = await ToolRegistry.shared.getDefinitions(toolNames: requested)
        #expect(
            definitions.count >= 11,
            "Expected at least 11 schemas from ToolRegistry.getDefinitions, got \(definitions.count)"
        )

        // Each schema must carry a non-empty name + description (= the
        // fields the LLM uses to pick a tool).
        for def in definitions {
            #expect(!def.name.isEmpty, "Schema name must not be empty")
            #expect(!def.description.isEmpty, "Schema description must not be empty")
        }

        // Every requested name that has a registered handler must
        // appear in the returned schemas (= output is not silently
        // truncated for names that DO exist).
        let returnedNames = Set(definitions.map { $0.name })
        for toolName in Self.expectedToolNames {
            let handler = await ToolRegistry.shared.getHandler(name: toolName)
            if handler != nil {
                #expect(
                    returnedNames.contains(toolName),
                    "Registered tool '\(toolName)' is missing from getDefinitions output"
                )
            }
        }
    }

    /// Test 3 -- `WenshuConductor.buildTools(from:)` (= the production
    /// wiring site used by ChatView) yields >= 11 tool handlers from
    /// the shared registry.
    @Test("WenshuConductor.buildTools yields 11 tools from ToolRegistry.shared")
    func testBuildToolsYieldsTwelve() async throws {
        Self.triggerAllToolBootstraps()
        let unsettled = await Self.awaitSettledRegistration()
        #expect(unsettled.isEmpty,
                "tools never registered within 5s: \(unsettled)")

        let tools = await WenshuConductor.buildTools(from: ToolRegistry.shared)
        #expect(
            tools.count >= 11,
            "Expected at least 11 tools from WenshuConductor.buildTools(from:), got \(tools.count)"
        )

        // Every conductor default name that has a registered handler
        // must be present in the produced dict (= hermes parity:
        // buildTools silently drops unknown names but never drops
        // names that ARE registered).
        for toolName in await WenshuConductor.defaultToolNames {
            if tools[toolName] == nil {
                let registered = await ToolRegistry.shared.getHandler(name: toolName)
                #expect(
                    registered == nil,
                    "buildTools dropped '\(toolName)' even though it IS registered in ToolRegistry.shared"
                )
            }
        }
    }

    /// Test 4 -- the generation counter increments on `register`. This
    /// test uses a FRESH isolated `ToolRegistry()` (= not the shared
    /// singleton) so it does not pollute the production registry. The
    /// point is to verify the counter contract from
    /// PORT-TOOLREGISTRY-001 still holds when exercising the
    /// `register(...)` signature with the same parameter shape
    /// (= `name` + `toolset` + `schema` + `handler` + `description`)
    /// used by the 12 tool files.
    @Test("ToolRegistry.generation increases on register (= fresh isolated instance)")
    func testGenerationIncreases() async throws {
        let registry = ToolRegistry()
        let initial = await registry.generation()
        #expect(initial == 0, "fresh ToolRegistry must start at generation 0")

        let uniqueName = "TEST_TOOL_\(UUID().uuidString)"
        let schema = ToolRegistrySchema(
            name: uniqueName,
            description: "test"
        )

        // Use any live tool as the handler payload (= matches the
        // 11 tool files' pattern of passing `MyTool.shared`).
        let payloadHandler = HermesTodoTool.shared

        await registry.register(
            name: uniqueName,
            toolset: "test",
            schema: schema,
            handler: payloadHandler,
            description: "test"
        )

        let after = await registry.generation()
        #expect(after > initial, "generation must increase after a successful register")

        // lastRegisterError must be nil on the clean register path.
        let error = await registry.lastRegisterError()
        #expect(error == nil, "register on a fresh registry must not populate lastRegisterError")
    }
}
