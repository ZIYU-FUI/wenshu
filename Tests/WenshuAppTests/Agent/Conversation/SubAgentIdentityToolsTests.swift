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
//    2. writer's tools include "book_chapter"
//    3. analyst's tools include "book_outline" and "book_entity"
//    4. archivist / auditor have empty tool lists
//       (= their domains reach storage directly)
//    5. Every non-empty tool name resolves to a registered
//       ToolRegistry handler (= the runner's getHandler call
//       must succeed; = the LLM tool dispatch path must work)
//

import Testing
import WenshuAgent
import WenshuData
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

    @Test("writer tool list includes book_chapter")
    func writerTools() {
        let tools = SubAgentIdentity.tools(name: .writer)
        #expect(tools.contains("book_chapter"),
                "writer must have book_chapter (= the per-book chapter tool; = a create writes a draft)")
    }

    @Test("analyst tool list reaches the per-book structure tools")
    func analystTools() {
        let tools = SubAgentIdentity.tools(name: .analyst)
        #expect(tools.contains("book_outline"),
                "analyst must have book_outline (= the per-book outline surface)")
        #expect(tools.contains("book_entity"),
                "analyst must have book_entity (= the per-book entity surface)")
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

    /// Every tool a role names must resolve to a registered handler.
    ///
    /// The registry this reads is seeded from the PRODUCTION catalogue,
    /// not from a list the test writes itself. A self-seeded stub makes
    /// the test agree with whatever the test believes: the row that
    /// named a tool deleted from production stayed green here for
    /// months, because the stub list carried the dead name.
    @Test("every non-empty tool name resolves to a registered handler")
    func everyNonEmptyToolListResolves() async {
        // An isolated registry seeded from the production catalogue
        // (= the same set the app's own bootstrap registers).
        let registry = ToolRegistry()
        for name in ToolCatalogue.names {
            await registry.registerTool(
                name: name,
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: name,
                    description: "catalogue-backed stub for \(name)"
                ),
                handler: PassThroughToolStub(),
                description: "test",
                emoji: "🧪"
            )
        }

        // Every role that names a tool must have every named tool
        // resolve (= the runner's `getHandler(name:)` call must succeed).
        for name in SubAgentIdentity.Name.allCases {
            for tool in SubAgentIdentity.tools(name: name) {
                let handler = await registry.getHandler(name: tool)
                #expect(handler != nil,
                        "\(name.rawValue) tool '\(tool)' must resolve to a registered ToolRegistry handler; got nil")
            }
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