//
//  AgentProtocolTests.swift · Wenshu · v0.18 ticket 03 (A2A protocol)
//
// test A2A: message/send + task/get + task/list + JSON encode/decode.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AgentProtocol (A2A 协议)")
struct AgentProtocolTests {
    private static func makeProtocol() -> AgentProtocol {
        // v0.21 ticket 03 + code-review S3: handle verifier throw (echo), test fallback error path
        // test agent WenshuVerifier (key → ping fail → error path, yes echo)
        // v1.52 stale-test-cleanup: inject an empty InMemoryKeychainStore
        // (= hermetic; = test expects no LLM key → verifier .missingAPIKey
        // → task.status = .failed). The previous default behavior read
        // the real keychain (= dev env may have sk-test, = verifier
        // succeeds, = test fails because no error path was exercised).
        AgentProtocol(agentCard: AgentCard(
            name: "test-agent",
            description: "测试 agent",
            skills: ["search", "memory"],
            endpoint: "in-process://test-agent"
        ), verifier: WenshuVerifier())
    }

    /// Set up the test with an empty InMemoryKeychain backend so that
    /// WenshuVerifier.resolveCredentials() throws .missingAPIKey.
    /// Returns the backend (callers can use it inside `defer` to restore).
    private static func withEmptyKeychain<R>(_ body: () async throws -> R) async rethrows -> R {
        let empty = InMemoryKeychainStore()
        return try await ProviderKeychain.withBackendForTesting(empty, perform: body)
    }

    @Test("message/send 创建 task 并返回 status")
    func testMessageSend() async throws {
        try await Self.withEmptyKeychain {
            let protocol_ = Self.makeProtocol()
            let taskId = UUID()
            let request = A2ARequest(method: .messageSend, params: .messageSend(
                taskId: taskId,
                message: AgentMessage(role: .user, content: "hello agent"),
                fromAgent: "user"
            ))
            let response = await protocol_.handle(request)
            // v0.21 ticket 03 + code-review S3: handle echo fallback, LLM → error != nil
            // test agent WenshuVerifier key → LLM fail → error yes LLM failed
            #expect(response.error != nil)
            if response.error == nil {
                Issue.record("expected LLM failure (no API key), got success")
            }
        }
    }

    @Test("task/get 拿 task 详情")
    func testTaskGet() async throws {
        try await Self.withEmptyKeychain {
            let protocol_ = Self.makeProtocol()
            let taskId = UUID()
            let sendRequest = A2ARequest(method: .messageSend, params: .messageSend(
                taskId: taskId,
                message: AgentMessage(role: .user, content: "test"),
                fromAgent: "user"
            ))
            _ = await protocol_.handle(sendRequest)
            let getRequest = A2ARequest(method: .taskGet, params: .taskGet(taskId: taskId))
            let response = await protocol_.handle(getRequest)
            #expect(response.error == nil)
            guard case .task(let task) = response.result else {
                Issue.record("expected task")
                return
            }
            #expect(task.id == taskId)
            // v0.21 ticket 03 + code-review S3: handle (LLM fail) → task.status = .failed, agent reply message
            #expect(task.status == .failed)
            #expect(task.messages.count == 1)  // user message, agent echo
        }
    }

    @Test("task/get 没找到返回 taskNotFound error")
    func testTaskGetNotFound() async throws {
        try await Self.withEmptyKeychain {
            let protocol_ = Self.makeProtocol()
            let request = A2ARequest(method: .taskGet, params: .taskGet(taskId: UUID()))
            let response = await protocol_.handle(request)
            guard case .taskNotFound = response.error else {
                Issue.record("expected taskNotFound")
                return
            }
            #expect(true)
        }
    }

    @Test("task/list 返回该 agent 所有 task")
    func testTaskList() async throws {
        try await Self.withEmptyKeychain {
            let protocol_ = Self.makeProtocol()
            let taskId1 = UUID()
            let taskId2 = UUID()
            // v0.21 ticket 03 + code-review S3: handle task save (status = .failed)
            _ = await protocol_.handle(A2ARequest(method: .messageSend, params: .messageSend(
                taskId: taskId1, message: AgentMessage(role: .user, content: "1"), fromAgent: "user")))
            _ = await protocol_.handle(A2ARequest(method: .messageSend, params: .messageSend(
                taskId: taskId2, message: AgentMessage(role: .user, content: "2"), fromAgent: "user")))
            let response = await protocol_.handle(A2ARequest(method: .taskList, params: .taskList(agentName: nil)))
            guard case .taskList(let tasks) = response.result else {
                Issue.record("expected taskList")
                return
            }
            // task save (status = .failed LLM fail, task record)
            #expect(tasks.count == 2)
        }
    }

    @Test("JSON encode + decode round-trip")
    func testJSONRoundTrip() async throws {
        let protocol_ = Self.makeProtocol()
        let taskId = UUID()
        let original = A2ARequest(method: .messageSend, params: .messageSend(
            taskId: taskId,
            message: AgentMessage(role: .user, content: "JSON test"),
            fromAgent: "alice"
        ))
        let encoded = try await protocol_.encode(original)
        let decoded = try await protocol_.decode(encoded)
        #expect(decoded.method == .messageSend)
        guard case .messageSend(let dTaskId, let dMessage, let dFromAgent) = decoded.params else {
            Issue.record("expected messageSend")
            return
        }
        #expect(dTaskId == taskId)
        #expect(dMessage.content == "JSON test")
        #expect(dFromAgent == "alice")
    }

    @Test("invalid params 返回 invalidParams error")
    func testInvalidParams() async throws {
        let protocol_ = Self.makeProtocol()
        // mismatch: .messageSend method + .taskGet params
        let request = A2ARequest(method: .messageSend, params: .taskGet(taskId: UUID()))
        let response = await protocol_.handle(request)
        guard case .invalidParams = response.error else {
            Issue.record("expected invalidParams")
            return
        }
        #expect(true)
    }
}