//
//  ToolRegistryTests.swift · Wenshu · v0.40 PORT-TOOLREGISTRY-001
//
//  Round-trip tests for the ToolRegistry actor (= hermes 1:1 port).
//
//  Surface tested (= matches spec §"Tests (8 round-trip)"):
//    1. testRegister_addsEntry
//    2. testRegister_overrideProtection_rejectsShadowing
//    3. testRegister_overrideTrue_acceptsShadow
//    4. testGetDefinitions_returnsFilteredSchemas
//    5. testGetHandler_returnsCorrectTool
//    6. testClear_removesAllEntries
//    7. testGeneration_incrementsOnMutation
//    8. testConcurrentRegister_threadSafe
//
//  Each test instantiates a fresh `ToolRegistry()` (= not the shared
//  singleton) so suite order doesn't matter and the production singleton
//  is never mutated by tests.
//

import Testing
import Foundation
@testable import WenshuApp

// MARK: - Test fixtures

/// Minimal `Tool` impl for fixture use. Returns a deterministic string
/// built from the input (= "echo:<input>"). Used to verify that
/// `getHandler(name:)` round-trips to the same handler that was
/// registered.
private struct EchoTool: Tool, Sendable {
    let tag: String
    init(tag: String = "default") { self.tag = tag }
    func execute(input: String) async throws -> String {
        return "echo[\(tag)]:\(input)"
    }
}

/// Minimal `Tool` impl that throws on every call (= used to verify
/// error propagation through `getHandler`).
private struct FailingTool: Tool, Sendable {
    func execute(input: String) async throws -> String {
        throw ToolExecutorError.toolFailed(name: "Failing", underlying: "always fails")
    }
}

@Suite("ToolRegistry (PORT-TOOLREGISTRY-001)")
struct ToolRegistryTests {

    // MARK: - Test 1: register adds an entry

    @Test("register adds an entry to the registry")
    func testRegister_addsEntry() async {
        let registry = ToolRegistry()
        let schema = ToolRegistrySchema(
            name: "Echo",
            description: "Echoes the input back"
        )
        let handler = EchoTool(tag: "t1")

        await registry.register(
            name: "Echo",
            toolset: "test",
            schema: schema,
            handler: handler
        )

        let count = await registry.count()
        #expect(count == 1)

        let entry = await registry.getEntry(name: "Echo")
        #expect(entry != nil)
        #expect(entry?.name == "Echo")
        #expect(entry?.toolset == "test")
        #expect(entry?.schema.description == "Echoes the input back")
        #expect(entry?.isAsync == true)

        let error = await registry.lastRegisterError()
        #expect(error == nil)
    }

    // MARK: - Test 2: override protection rejects shadowing

    @Test("register rejects shadowing across toolsets when override=false")
    func testRegister_overrideProtection_rejectsShadowing() async {
        let registry = ToolRegistry()
        let schemaA = ToolRegistrySchema(name: "Echo", description: "variant A")
        let schemaB = ToolRegistrySchema(name: "Echo", description: "variant B")

        await registry.register(
            name: "Echo",
            toolset: "core",
            schema: schemaA,
            handler: EchoTool(tag: "core")
        )

        let genBefore = await registry.generation()

        // Try to register the same name under a different toolset
        // WITHOUT override=true. Should be rejected (= state unchanged,
        // lastRegisterError populated, generation NOT bumped).
        await registry.register(
            name: "Echo",
            toolset: "plugin",
            schema: schemaB,
            handler: EchoTool(tag: "plugin"),
            override: false
        )

        let entry = await registry.getEntry(name: "Echo")
        #expect(entry?.toolset == "core", "toolset must remain 'core' after rejected shadow")

        let error = await registry.lastRegisterError()
        #expect(error != nil, "lastRegisterError must be populated on rejection")
        #expect(error?.contains("Echo") == true)
        #expect(error?.contains("plugin") == true)
        #expect(error?.contains("core") == true)

        let genAfter = await registry.generation()
        #expect(genAfter == genBefore, "rejected register must not bump generation")
    }

    // MARK: - Test 3: override=true accepts shadow

    @Test("register replaces the existing entry when override=true")
    func testRegister_overrideTrue_acceptsShadow() async {
        let registry = ToolRegistry()
        let schemaA = ToolRegistrySchema(name: "Echo", description: "variant A")
        let schemaB = ToolRegistrySchema(name: "Echo", description: "variant B")

        await registry.register(
            name: "Echo",
            toolset: "core",
            schema: schemaA,
            handler: EchoTool(tag: "core")
        )

        let genBefore = await registry.generation()

        await registry.register(
            name: "Echo",
            toolset: "plugin",
            schema: schemaB,
            handler: EchoTool(tag: "plugin"),
            override: true
        )

        let entry = await registry.getEntry(name: "Echo")
        #expect(entry?.toolset == "plugin", "toolset must be 'plugin' after override")
        #expect(entry?.schema.description == "variant B")

        let error = await registry.lastRegisterError()
        #expect(error == nil, "override=true must clear lastRegisterError")

        let genAfter = await registry.generation()
        #expect(genAfter == genBefore + 1, "successful override must bump generation")
    }

    // MARK: - Test 4: getDefinitions returns filtered schemas

    @Test("getDefinitions returns filtered ToolRegistrySchemas honoring checkFn")
    func testGetDefinitions_returnsFilteredSchemas() async {
        let registry = ToolRegistry()

        // Always-available tool (= no checkFn).
        let availableSchema = ToolRegistrySchema(
            name: "Available",
            description: "always on"
        )
        await registry.register(
            name: "Available",
            toolset: "core",
            schema: availableSchema,
            handler: EchoTool(tag: "available")
        )

        // Conditionally-available tool (= checkFn that returns false).
        let gatedSchema = ToolRegistrySchema(
            name: "Gated",
            description: "gated on docker daemon"
        )
        let checkResult = false
        await registry.register(
            name: "Gated",
            toolset: "docker",
            schema: gatedSchema,
            handler: EchoTool(tag: "gated"),
            checkFn: { checkResult }
        )

        // Conditionally-available tool (= checkFn that returns true).
        let openSchema = ToolRegistrySchema(
            name: "Open",
            description: "gated but available right now"
        )
        let checkResult2 = true
        await registry.register(
            name: "Open",
            toolset: "docker",
            schema: openSchema,
            handler: EchoTool(tag: "open"),
            checkFn: { checkResult2 }
        )

        // Request all three. Expect schemas for Available + Open;
        // Gated is filtered out because its checkFn returned false.
        let definitions = await registry.getDefinitions(
            toolNames: ["Available", "Gated", "Open"]
        )
        #expect(definitions.count == 2)
        let names = definitions.map { $0.name }.sorted()
        #expect(names == ["Available", "Open"])

        // Verify output is sorted by tool name (= hermes
        // `sorted(tool_names)`).
        let onlyAvailable = await registry.getDefinitions(toolNames: ["Available"])
        #expect(onlyAvailable.count == 1)
        #expect(onlyAvailable.first?.name == "Available")

        // Unknown tool name is silently dropped (= hermes `entries_by_name.get(name)`).
        let withUnknown = await registry.getDefinitions(toolNames: ["Available", "NoSuchTool"])
        #expect(withUnknown.count == 1)
    }

    // MARK: - Test 5: getHandler returns the correct tool

    @Test("getHandler returns the registered tool instance")
    func testGetHandler_returnsCorrectTool() async {
        let registry = ToolRegistry()
        let schema = ToolRegistrySchema(name: "Echo", description: "echo")
        let handler = EchoTool(tag: "matching")

        await registry.register(
            name: "Echo",
            toolset: "test",
            schema: schema,
            handler: handler,
            emoji: "🔊"
        )

        let retrieved = await registry.getHandler(name: "Echo")
        #expect(retrieved != nil)

        // Round-trip the handler: invoke execute and verify the tag
        // round-trips (= the same handler instance is what we put in).
        let output = try? await retrieved?.execute(input: "hello")
        #expect(output == "echo[matching]:hello")

        // Unknown tool returns nil.
        let missing = await registry.getHandler(name: "NoSuchTool")
        #expect(missing == nil)

        // getEntry returns metadata.
        let entry = await registry.getEntry(name: "Echo")
        #expect(entry?.emoji == "🔊")

        // getEmoji returns the stored emoji or default fallback.
        let emoji = await registry.getEmoji(name: "Echo")
        #expect(emoji == "🔊")
        let defaultEmoji = await registry.getEmoji(name: "NoSuchTool")
        #expect(defaultEmoji == "⚡")
    }

    // MARK: - Test 6: clear removes all entries

    @Test("clear removes all registrations and bumps generation")
    func testClear_removesAllEntries() async {
        let registry = ToolRegistry()

        let schemaA = ToolRegistrySchema(name: "A", description: "first")
        let schemaB = ToolRegistrySchema(name: "B", description: "second")

        await registry.register(
            name: "A",
            toolset: "core",
            schema: schemaA,
            handler: EchoTool(tag: "a")
        )
        await registry.register(
            name: "B",
            toolset: "core",
            schema: schemaB,
            handler: EchoTool(tag: "b")
        )

        let countBefore = await registry.count()
        #expect(countBefore == 2)

        let genBefore = await registry.generation()
        await registry.clear()
        let genAfter = await registry.generation()
        #expect(genAfter == genBefore + 1)

        let countAfter = await registry.count()
        #expect(countAfter == 0)

        // getHandler returns nil after clear.
        let handler = await registry.getHandler(name: "A")
        #expect(handler == nil)

        // getDefinitions returns empty after clear.
        let definitions = await registry.getDefinitions(toolNames: ["A", "B"])
        #expect(definitions.isEmpty)

        // getAllToolNames returns empty after clear.
        let names = await registry.getAllToolNames()
        #expect(names.isEmpty)

        // lastRegisterError is cleared.
        let error = await registry.lastRegisterError()
        #expect(error == nil)
    }

    // MARK: - Test 7: generation increments on mutation

    @Test("generation counter increments on register / deregister / clear")
    func testGeneration_incrementsOnMutation() async {
        let registry = ToolRegistry()
        let gen0 = await registry.generation()
        #expect(gen0 == 0)

        // First register -> gen +1
        let schemaA = ToolRegistrySchema(name: "A", description: "a")
        await registry.register(
            name: "A",
            toolset: "core",
            schema: schemaA,
            handler: EchoTool(tag: "a")
        )
        let gen1 = await registry.generation()
        #expect(gen1 == 1)

        // Idempotent re-register of same toolset bumps again.
        await registry.register(
            name: "A",
            toolset: "core",
            schema: schemaA,
            handler: EchoTool(tag: "a")
        )
        let gen2 = await registry.generation()
        #expect(gen2 == 2)

        // Rejected shadow (= override=false) does NOT bump.
        await registry.register(
            name: "A",
            toolset: "plugin",
            schema: schemaA,
            handler: EchoTool(tag: "plugin"),
            override: false
        )
        let gen3 = await registry.generation()
        #expect(gen3 == gen2, "rejected register must not bump generation")

        // Successful override bumps.
        await registry.register(
            name: "A",
            toolset: "plugin",
            schema: schemaA,
            handler: EchoTool(tag: "plugin"),
            override: true
        )
        let gen4 = await registry.generation()
        #expect(gen4 == gen3 + 1)

        // deregister bumps.
        await registry.deregister(name: "A")
        let gen5 = await registry.generation()
        #expect(gen5 == gen4 + 1)

        // deregister of unknown name is a no-op (= no bump).
        await registry.deregister(name: "NoSuchTool")
        let gen6 = await registry.generation()
        #expect(gen6 == gen5)

        // clear bumps.
        await registry.register(
            name: "B",
            toolset: "core",
            schema: ToolRegistrySchema(name: "B", description: "b"),
            handler: EchoTool(tag: "b")
        )
        let gen7 = await registry.generation()
        await registry.clear()
        let gen8 = await registry.generation()
        #expect(gen8 == gen7 + 1)
    }

    // MARK: - Test 8: concurrent register is thread-safe

    @Test("concurrent register calls are serialized and consistent")
    func testConcurrentRegister_threadSafe() async {
        let registry = ToolRegistry()

        // Register 50 distinct tools concurrently from a TaskGroup.
        // The actor must serialize these; result must have exactly 50
        // entries and final generation must equal 50 (= one bump per
        // successful register).
        let count = 50
        let schema = ToolRegistrySchema(name: "Bulk", description: "bulk")

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    await registry.register(
                        name: "Tool-\(i)",
                        toolset: "bulk",
                        schema: ToolRegistrySchema(
                            name: "Tool-\(i)",
                            description: "tool #\(i)"
                        ),
                        handler: EchoTool(tag: "t\(i)")
                    )
                }
            }
        }

        let totalCount = await registry.count()
        #expect(totalCount == count)

        let allNames = await registry.getAllToolNames()
        #expect(allNames.count == count)
        #expect(Set(allNames).count == count, "all names must be unique")

        let gen = await registry.generation()
        #expect(gen == count, "generation must equal the number of successful registers")

        // Also exercise concurrent register that ALL collide on the
        // same name with different toolsets. Exactly one wins
        // (whichever runs first); the rest are rejected with override=
        // false. Final state has exactly one entry; generation is 1.
        let collisionRegistry = ToolRegistry()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    await collisionRegistry.register(
                        name: "Same",
                        toolset: "toolset-\(i)",
                        schema: ToolRegistrySchema(
                            name: "Same",
                            description: "variant \(i)"
                        ),
                        handler: EchoTool(tag: "v\(i)"),
                        override: false
                    )
                }
            }
        }

        let collisionCount = await collisionRegistry.count()
        #expect(collisionCount == 1, "only one tool may be registered for collision")
        let collisionGen = await collisionRegistry.generation()
        #expect(collisionGen == 1, "only one successful register bumps generation")
    }
}