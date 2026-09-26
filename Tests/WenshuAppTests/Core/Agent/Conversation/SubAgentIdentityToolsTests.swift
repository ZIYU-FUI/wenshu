//
//  SubAgentIdentityToolsTests.swift · Wenshu · v2.7d tool mapping
//
//  Unit tests for `SubAgentIdentity.tools(name:)`.
//
//  v2.7d constraint (= boss 2026-09-26 "团队链路真跑 LLM"):
//    Every tool name returned by `SubAgentIdentity.tools(_:)` MUST
//    match a real wenshu tool registered in `ToolRegistry.shared`.
//    The previous v0.23 implementation returned hermes port slugs
//    (= "search", "web", "linkgraph") that do not match any
//    wenshu-registered tool (= the runner's tool-schema lookups
//    returned empty schemas; = the LLM saw no tools).
//
//  Test scope:
//    1. researcher's tools include "web_search" and "reference_library"
//    2. writer's tools include "paragraph_ai"
//    3. analyst / archivist / auditor have empty tool lists
//       (= per §11 baseline "no placeholder/stub text")
//    4. Every non-empty tool name resolves to a registered
//       ToolRegistry handler (= the runner's getHandler call
//       must succeed; = the LLM tool dispatch path must work)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SubAgentIdentity.tools · v2.7d wenshu tool mapping", .serialized)
struct SubAgentIdentityToolsTests {

    // MARK: - Per-agent tool-list expectations

    @Test("researcher tool list includes web_search and reference_library")
    func researcherTools() {
        let tools = SubAgentIdentity.tools(name: .researcher)
        #expect(tools.contains("web_search"),
                "researcher must have web_search (covers external web + reference library lookup)")
        #expect(tools.contains("reference_library"),
                "researcher must have reference_library (writes grounded summaries per v2.6 facet model)")
    }

    @Test("writer tool list includes paragraph_ai")
    func writerTools() {
        let tools = SubAgentIdentity.tools(name: .writer)
        #expect(tools.contains("paragraph_ai"),
                "writer must have paragraph_ai (the only writing tool in wenshu today)")
    }

    @Test("analyst tool list is empty (= no outline/bases/graph tools exist)")
    func analystTools() {
        let tools = SubAgentIdentity.tools(name: .analyst)
        #expect(tools.isEmpty,
                "analyst must have empty tool list per §11 baseline 'no placeholder/stub text'; got \(tools)")
    }

    @Test("archivist tool list is empty (= bookmark/backup tools do not exist)")
    func archivistTools() {
        let tools = SubAgentIdentity.tools(name: .archivist)
        #expect(tools.isEmpty,
                "archivist must have empty tool list (= bookmark/backup tools do not exist; = archivist writes go through WSBookmarkRepository.shared + filesystem directly); got \(tools)")
    }

    @Test("auditor tool list is empty (= memory removed from tool surface in v2.4)")
    func auditorTools() {
        let tools = SubAgentIdentity.tools(name: .auditor)
        #expect(tools.isEmpty,
                "auditor must have empty tool list (= memory removed in v2.4; = auditor reads WSMemoryProvider.shared directly); got \(tools)")
    }

    // MARK: - ToolRegistry resolution check (= the runner's runtime contract)

    /// Verifies that every non-empty tool list resolves to a registered
    /// ToolRegistry handler (= the runner's `getHandler(name:)` call
    /// must succeed for every name). Uses an isolated ToolRegistry
    /// (= fresh instance per test) seeded with the names that are
    /// expected to be registered in production.
    @Test("every non-empty tool name resolves to a registered handler")
    func everyToolResolvesToAHandler() async throws {
        // Build an isolated registry seeded with the names we expect
        // (= the ones SubAgentIdentity.tools returns for researcher
        // and writer). Touching `ToolRegistry.shared` would couple
        // the test to the production bootstrap order (= flaky).
        let registry = ToolRegistry()
        for name in [
            "web_search",       // WebSearchTool
            "reference_library", // ReferenceLibraryTool (Core/Agent/Librarian/)
            "paragraph_ai",     // ParagraphAITool
        ] {
            await registry.registerTool(
                name: name,
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: name,
                    description: "test stub for \(name)"
                ),
                handler: PassThroughToolStub(),
                description: "test",
                emoji: "🧪"
            )
        }

        // Researcher: every tool name must resolve.
        for name in SubAgentIdentity.tools(name: .researcher) {
            let handler = await registry.getHandler(name: name)
            #expect(handler != nil,
                    "researcher tool '\(name)' must resolve to a registered ToolRegistry handler; got nil")
        }

        // Writer: every tool name must resolve.
        for name in SubAgentIdentity.tools(name: .writer) {
            let handler = await registry.getHandler(name: name)
            #expect(handler != nil,
                    "writer tool '\(name)' must resolve to a registered ToolRegistry handler; got nil")
        }

        // Analyst / archivist / auditor: empty tool lists need no
        // resolution (= the runner's `if let registry` branch in
        // runRealSubAgent skips the schema lookup when the list
        // is empty).
        for agent in [SubAgentIdentity.Name.analyst,
                      .archivist,
                      .auditor] {
            #expect(SubAgentIdentity.tools(name: agent).isEmpty,
                    "\(agent.rawValue) tool list must be empty (= no LLM tool dispatch)")
        }
    }
}

// MARK: - Stub tool (= registers without invoking)

/// Minimal `Tool` stub (= the registry needs a handler to satisfy
/// `getHandler`; = the test never actually invokes it).
private struct PassThroughToolStub: Tool {
    func execute(input: String) async throws -> String {
        "{\"ok\":true}"
    }
}