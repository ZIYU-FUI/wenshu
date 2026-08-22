//
//  AgentRuntimeTests.swift · Wenshu · v0.18 ticket 04 (多 agent runtime)
//
//  单元测试 AgentRuntime: register / unregister / list / resolve / delegateTask / broadcast.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AgentRuntime (多 agent runtime)")
struct AgentRuntimeTests {
    private static func makeAgent(name: String) -> AgentRegistration {
        AgentRegistration(
            name: name,
            card: AgentCard(
                name: name,
                description: "测试 agent \(name)",
                skills: ["test"],
                endpoint: "in-process://\(name)"
            ),
            // v0.21 ticket 03 + code-review S3: 测 verifier 也传 (没 key → LLM fail 路径, 但不是 echo)
            process: AgentProtocol(agentCard: AgentCard(
                name: name,
                description: "测试 agent \(name)",
                skills: ["test"],
                endpoint: "in-process://\(name)"
            ), verifier: WenshuVerifier())
        )
    }

    @Test("register + list")
    func testRegisterList() async {
        let runtime = AgentRuntime()
        await runtime.register(Self.makeAgent(name: "alpha"))
        await runtime.register(Self.makeAgent(name: "beta"))
        let names = await runtime.list()
        #expect(names == ["alpha", "beta"])
    }

    @Test("register 后 main 默认指向第一个")
    func testMainDefault() async {
        let runtime = AgentRuntime()
        await runtime.register(Self.makeAgent(name: "first"))
        await runtime.register(Self.makeAgent(name: "second"))
        let main = await runtime.main()
        #expect(main?.name == "first")
    }

    @Test("resolve 按 name")
    func testResolve() async {
        let runtime = AgentRuntime()
        await runtime.register(Self.makeAgent(name: "alpha"))
        let resolved = await runtime.resolve(name: "alpha")
        #expect(resolved?.name == "alpha")
        let missing = await runtime.resolve(name: "missing")
        #expect(missing == nil)
    }

    @Test("unregister 删 1 个")
    func testUnregister() async {
        let runtime = AgentRuntime()
        await runtime.register(Self.makeAgent(name: "alpha"))
        await runtime.register(Self.makeAgent(name: "beta"))
        await runtime.unregister(name: "alpha")
        let names = await runtime.list()
        #expect(names == ["beta"])
    }

    @Test("delegateTask 派任务 + 拿 task 详情 (dev env 没 LLM key → 期望 delegateFailed)")
    func testDelegateTask() async throws {
        let runtime = AgentRuntime()
        await runtime.register(Self.makeAgent(name: "worker"))
        // v0.21 ticket 03 + code-review S3: handle LLM 失败 → AgentProtocol 返回 error → AgentRuntime 抛 .delegateFailed
        // dev env 缺 MINIMAX_CN_API_KEY, LLM 必 fail, 所以期望抛错 (这是真值, 不是测试 bug)
        await #expect(throws: AgentRuntimeError.self) {
            _ = try await runtime.delegateTask(to: "worker", content: "do something")
        }
    }

    @Test("delegateTask agent 不存在抛错")
    func testDelegateTaskNotFound() async {
        let runtime = AgentRuntime()
        await #expect(throws: AgentRuntimeError.self) {
            _ = try await runtime.delegateTask(to: "missing", content: "test")
        }
    }

    @Test("broadcast 给所有 agent")
    func testBroadcast() async {
        let runtime = AgentRuntime()
        await runtime.register(Self.makeAgent(name: "alpha"))
        await runtime.register(Self.makeAgent(name: "beta"))
        let results = await runtime.broadcast(content: "broadcast test")
        #expect(results.count == 2)
        #expect(results["alpha"] != nil)
        #expect(results["beta"] != nil)
    }
}