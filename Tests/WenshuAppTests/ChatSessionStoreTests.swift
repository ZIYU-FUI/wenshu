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

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-chat-\(tag)-\(UUID().uuidString).sqlite"
    }
}