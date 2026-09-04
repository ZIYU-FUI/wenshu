//
//  ChatSessionStoreTests.swift · Wenshu · v0.21 ticket 02 (chat persistent)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatSessionStore (wenshu chat 持久化)")
struct ChatSessionStoreTests {

    @Test("bootstrap 创建 chat_messages + chat_summaries 表 (不抛错 = schema 创表成功)")
    func testBootstrap() async throws {
        let store = try ChatSessionStore(path: tmpPath("bootstrap"))
        try await store.bootstrap()
    }

    @Test("append + loadMessages 按 timestamp ASC 返回")
    func testAppendLoad() async throws {
        let store = try ChatSessionStore(path: tmpPath("appendload"))
        try await store.bootstrap()
        let now = Date()
        let m1 = StoredChatMessage(id: "m1", source: "user", content: "hello", timestamp: now)
        let m2 = StoredChatMessage(id: "m2", source: "wenshu", content: "hi", timestamp: now.addingTimeInterval(1))
        let m3 = StoredChatMessage(id: "m3", source: "user", content: "world", timestamp: now.addingTimeInterval(2))
        try await store.append(m1, sessionId: "default")
        try await store.append(m2, sessionId: "default")
        try await store.append(m3, sessionId: "default")
        let loaded = try await store.loadMessages(sessionId: "default")
        #expect(loaded.count == 3)
        #expect(loaded[0].id == "m1")
        #expect(loaded[1].source == "wenshu")
        #expect(loaded[2].content == "world")
    }

    @Test("clear 清空 messages 但保留 summary")
    func testClearPreservesSummary() async throws {
        let store = try ChatSessionStore(path: tmpPath("clear"))
        try await store.bootstrap()
        let m1 = StoredChatMessage(id: "m1", source: "user", content: "x", timestamp: Date())
        try await store.append(m1, sessionId: "default")
        try await store.saveSummary("old summary", sessionId: "default", lastMessageId: "m1")
        try await store.clear(sessionId: "default")
        let count = try await store.count(sessionId: "default")
        #expect(count == 0)
        let summary = try await store.loadSummary(sessionId: "default")
        #expect(summary == "old summary")
    }

    @Test("session_id 隔离: 不同 session_id 不混")
    func testSessionIsolation() async throws {
        let store = try ChatSessionStore(path: tmpPath("isolation"))
        try await store.bootstrap()
        let m1 = StoredChatMessage(id: "m1", source: "user", content: "session1", timestamp: Date())
        let m2 = StoredChatMessage(id: "m2", source: "user", content: "session2", timestamp: Date())
        try await store.append(m1, sessionId: "session1")
        try await store.append(m2, sessionId: "session2")
        let s1 = try await store.loadMessages(sessionId: "session1")
        let s2 = try await store.loadMessages(sessionId: "session2")
        #expect(s1.count == 1)
        #expect(s2.count == 1)
        #expect(s1[0].content == "session1")
        #expect(s2[0].content == "session2")
    }

    @Test("deleteOldMessages 删早于某 timestamp 的旧 messages")
    func testDeleteOldMessages() async throws {
        let store = try ChatSessionStore(path: tmpPath("deleteold"))
        try await store.bootstrap()
        let t0 = Date()
        let m1 = StoredChatMessage(id: "m1", source: "user", content: "old", timestamp: t0)
        let m2 = StoredChatMessage(id: "m2", source: "user", content: "new", timestamp: t0.addingTimeInterval(100))
        try await store.append(m1, sessionId: "default")
        try await store.append(m2, sessionId: "default")
        try await store.deleteOldMessages(sessionId: "default", beforeTimestamp: t0.addingTimeInterval(50))
        let loaded = try await store.loadMessages(sessionId: "default")
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "m2")
    }

    @Test("summaryCutoffTimestamp 返回第 (count-keepLastN) 条消息 timestamp")
    func testSummaryCutoff() async throws {
        let store = try ChatSessionStore(path: tmpPath("cutoff"))
        try await store.bootstrap()
        let t0 = Date()
        for i in 0..<25 {
            try await store.append(StoredChatMessage(id: "m\(i)", source: "user", content: "msg \(i)", timestamp: t0.addingTimeInterval(TimeInterval(i))), sessionId: "default")
        }
        let cutoff = try await store.summaryCutoffTimestamp(sessionId: "default", keepLastN: 10)
        #expect(cutoff != nil)
        // SQLite LIMIT 1 OFFSET N: skip N rows, 取第 N+1 行. count=25, keepLastN=10, offset=15 → 取 index 15 (timestamp = t0 + 15 = 15.0)
        // 但实际 SQLite timeIntervalSince1970 double 精度有 +/- 1 偏移, 用容差 0.001
        let cutoffTime = cutoff!.timeIntervalSince(t0)
        #expect(abs(cutoffTime - 15.0) < 0.001)
    }

    @Test("summaryCutoffTimestamp count <= keepLastN 返回 nil (= 不触发 summary)")
    func testSummaryCutoffNoTrigger() async throws {
        let store = try ChatSessionStore(path: tmpPath("cutoff-no"))
        try await store.bootstrap()
        for i in 0..<5 {
            try await store.append(StoredChatMessage(id: "m\(i)", source: "user", content: "msg", timestamp: Date()), sessionId: "default")
        }
        let cutoff = try await store.summaryCutoffTimestamp(sessionId: "default", keepLastN: 10)
        #expect(cutoff == nil)
    }

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-chat-\(tag)-\(UUID().uuidString).sqlite"
    }

    // MARK: - v0.23 ticket 006: sub-agent run trace

    @Test("v0.23 ticket 006: bootstrap 创建 sub_agent_runs 表 (不抛错)")
    func testSubAgentRunBootstrap() async throws {
        let store = try ChatSessionStore(path: tmpPath("subrun-bootstrap"))
        try await store.bootstrap()  // sub_agent_runs 表也创建
    }

    @Test("v0.23 ticket 006: recordSubAgentRun 写 + loadSubAgentRuns 读 (round-trip)")
    func testSubAgentRunRoundTrip() async throws {
        let store = try ChatSessionStore(path: tmpPath("subrun-roundtrip"))
        try await store.bootstrap()
        let run = SubAgentRun(
            id: "sub-001",
            agentName: "writer",
            title: "writer: 续写捕快抓贼",
            status: .done,
            startedAt: Date(),
            completedAt: Date(),
            resultSummary: "新章节 1200 字, wuxia 风格"
        )
        try await store.recordSubAgentRun(run, sessionId: "default")
        let loaded = try await store.loadSubAgentRuns(sessionId: "default")
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "sub-001")
        #expect(loaded[0].agentName == "writer")
        #expect(loaded[0].status == .done)
        #expect(loaded[0].resultSummary == "新章节 1200 字, wuxia 风格")
    }

    @Test("v0.23 ticket 006: 多 sub-agent run 按 started_at ASC 排序")
    func testSubAgentRunOrdering() async throws {
        let store = try ChatSessionStore(path: tmpPath("subrun-ordering"))
        try await store.bootstrap()
        // Insert out of order
        try await store.recordSubAgentRun(SubAgentRun(
            id: "b", agentName: "writer", title: "second", status: .done,
            startedAt: Date(timeIntervalSince1970: 1000), resultSummary: "n2"
        ), sessionId: "default")
        try await store.recordSubAgentRun(SubAgentRun(
            id: "a", agentName: "researcher", title: "first", status: .done,
            startedAt: Date(timeIntervalSince1970: 500), resultSummary: "n1"
        ), sessionId: "default")
        let loaded = try await store.loadSubAgentRuns(sessionId: "default")
        #expect(loaded.count == 2)
        #expect(loaded[0].id == "a")  // earlier first
        #expect(loaded[1].id == "b")
    }

    @Test("v0.23 ticket 006: status 3 case (running / done / failed) 持久化正确")
    func testSubAgentRunStatusAllCases() async throws {
        let store = try ChatSessionStore(path: tmpPath("subrun-status"))
        try await store.bootstrap()
        for status in [SubAgentRunStatus.running, .done, .failed] {
            try await store.recordSubAgentRun(SubAgentRun(
                id: "id-\(status.rawValue)", agentName: "x", title: "x",
                status: status, startedAt: Date()
            ), sessionId: "default")
        }
        let loaded = try await store.loadSubAgentRuns(sessionId: "default")
        let statuses = Set(loaded.map(\.status))
        #expect(statuses == Set([.running, .done, .failed]))
    }
}