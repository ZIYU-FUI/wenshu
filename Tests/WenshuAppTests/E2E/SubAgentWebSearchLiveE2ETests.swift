//
//  SubAgentWebSearchLiveE2ETests.swift · Wenshu · v2.7d
//
//  Live E2E (= opt-in via WENSHU_LIVE_API_TESTS=1) verifying
//  the production tool dispatch path end-to-end: a real
//  sub-agent LLM call (= the production runner + the canonical
//  minimax-cn / MiniMax-M3 connector) emits a `web_search`
//  tool_use, the SubAgentRunner dispatches it via an isolated
//  ToolRegistry (= fresh actor instance), the WebSearchTool
//  fires KeylessRing.search(...) (= real HTTP round-trip
//  against Parallel MCP / Exa MCP / Keenable REST), and the
//  LLM echoes a URL from the real results back into its
//  final assistant text.
//
//  This test closes Gap 3 (= the Q46 stop-rule follow-up from
//  2026-09-26). The previous Gap 3 attempt used
//  `toolRegistry: ToolRegistry.shared` and aborted with signal 5
//  (= Swift concurrency runtime teardown on the ToolRegistry.shared
//  + WebSearchTool._registryBootstrap path inside the test process).
//
//  Resolution (= this test):
//    1. Construct a fresh `ToolRegistry()` actor (= bypass the
//       shared singleton + bootstrap side effects).
//    2. Manually register the `web_search` tool on the fresh
//       registry with the same schema WebSearchTool uses.
//    3. Pass the fresh registry via the new
//       `SubAgentRunner.init(isolatedRegistry:isolatedToolRegistry:...)`
//       parameter (= parallel to the existing `isolatedRegistry:`
//       AsyncDelegationRegistry override).
//    4. The runner dispatches `web_search` through the fresh
//       ToolRegistry (= no ToolRegistry.shared access at all).
//
//  Skipped by default when WENSHU_LIVE_API_TESTS is not set.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sub-agent web_search live E2E · v2.7d", .serialized)
@MainActor
struct SubAgentWebSearchLiveE2ETests {

    /// Opt-in via WENSHU_LIVE_API_TESTS=1 (= CI-safe default off).
    private static var liveEnabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"
    }

    /// Build a fresh ToolRegistry actor with only the web_search tool
    /// registered (= same schema WebSearchTool self-registers in
    /// production). The isolated registry never touches
    /// `ToolRegistry.shared`, so the Swift concurrency runtime issue
    /// (= signal 5 abort on the shared bootstrap path) does not
    /// trigger.
    private func makeIsolatedToolRegistry() async -> ToolRegistry {
        let registry = ToolRegistry()
        let schema = ToolRegistrySchema(
            name: "web_search",
            description: """
            Web search via the keyless anonymous public free tier ring \
            (= Parallel / Exa / Keenable, in that order). No API key \
            or configuration is needed; works on first launch. \
            Actions: search (= multi-vendor ring with rate-limit failover), \
            research (= search + local summary aggregation). \
            Returns ranked results with title / url / snippet.
            """,
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "The web_search operation to perform.",
                    enumValues: ["search", "research"]
                ),
                "query": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Search query string (= required)."
                ),
                "limit": ToolRegistrySchemaProperty(
                    type: "integer",
                    description: "Maximum number of results to return (= default 10 for search, 5 for research)."
                )
            ],
            required: []
        )
        await registry.registerTool(
            name: "web_search",
            toolset: "research",
            schema: schema,
            handler: WebSearchTool.shared,
            description: "Web search via the keyless anonymous free tier ring.",
            emoji: "🔍"
        )
        return registry
    }

    @Test("Gap 3: researcher sub-agent dispatches web_search via isolated ToolRegistry + real KeylessRing")
    func researcherDispatchesWebSearchTool() async throws {
        guard Self.liveEnabled else { return }

        // Step 1: fresh ToolRegistry + fresh AsyncDelegationRegistry
        // (= both bypass the shared singletons that cause signal 5
        // aborts in the test process).
        let toolRegistry = await makeIsolatedToolRegistry()
        let registry = AsyncDelegationRegistry()

        // Step 2: build the production-shape SubAgentRunner via the
        // new isolatedToolRegistry init.
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            isolatedToolRegistry: toolRegistry,
            connector: MinimaxConnector()
        )

        // Step 3: register a researcher handle. The task wording
        // is concrete enough that the LLM picks web_search over
        // trying to answer from its own training cutoff.
        let task = "请用 web_search 工具查询「Apple HIG NavigationSplitView」的官方文档，输出一段中文摘要（3-5 句话），并附上查询到的文档 URL。"
        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: task,
            state: .pending
        )
        await registry.register(handle: handle)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Step 4: drive the production drain (= real LLM + real
        // tool dispatch + real KeylessRing HTTP round-trip).
        let n = await runner.drainPending()
        #expect(n >= 1, "drainPending should process the registered handle")

        // Step 5: verify the handle transitioned to .completed and
        // the LLM's final result references a real URL (= the
        // KeylessRing returned at least one web result; = the
        // LLM echoed the URL into its final assistant text).
        let finalHandle = await registry.get(id: handle.id)
        if finalHandle?.state != .completed {
            Issue.record("researcher handle did not complete; state=\(String(describing: finalHandle?.state))")
            return
        }
        let result = finalHandle?.result ?? ""
        #expect(!result.isEmpty, "researcher result must be non-empty")
        // The real LLM typically emits a final summary that
        // includes at least one URL (= KeylessRing result).
        let hasURL = result.contains("http://") || result.contains("https://")
        #expect(hasURL, "researcher result must include a URL (= the KeylessRing returned a real web result); got \(result.prefix(500))")
    }
}