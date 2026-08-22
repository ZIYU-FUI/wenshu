//
//  WenshuWorkspaceTests.swift · Wenshu · v0.23 ticket 014.001
//
//  Boss 2026-08-23 拍: '我想先落地, 类似 FCP 的库文件'.
//  Tests for WenshuWorkspace actor (single-file workspace).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("WenshuWorkspace (FCP-style single-file .ws)")
struct WenshuWorkspaceTests {

    private func tmpPath(_ tag: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory() + "wenshu-ws-\(tag)-\(UUID().uuidString).ws")
    }

    @Test("open: creates new .ws file + bootstrap schema")
    func testOpenCreatesFile() async throws {
        let path = tmpPath("create")
        let ws = WenshuWorkspace(path: path)
        try await ws.open()
        #expect(FileManager.default.fileExists(atPath: path.path))
        try await ws.close()
        try? FileManager.default.removeItem(at: path)
    }

    @Test("open: idempotent (re-open same file is OK)")
    func testOpenIdempotent() async throws {
        let path = tmpPath("idempotent")
        let ws1 = WenshuWorkspace(path: path)
        try await ws1.open()
        try await ws1.close()
        let ws2 = WenshuWorkspace(path: path)
        try await ws2.open()
        try await ws2.close()
        try? FileManager.default.removeItem(at: path)
    }

    @Test("currentManifestVersion: 1 on fresh DB")
    func testManifestVersion() async throws {
        let path = tmpPath("manifest-version")
        let ws = WenshuWorkspace(path: path)
        try await ws.open()
        let version = await ws.currentManifestVersion()
        #expect(version == WenshuWorkspace.currentSchemaVersion)
        #expect(version == 1)
        try await ws.close()
        try? FileManager.default.removeItem(at: path)
    }

    @Test("workspaceUUID: set on bootstrap, stable across opens")
    func testWorkspaceUUID() async throws {
        let path = tmpPath("uuid")
        let ws1 = WenshuWorkspace(path: path)
        try await ws1.open()
        let uuid1 = await ws1.workspaceUUID()
        #expect(uuid1 != nil)
        try await ws1.close()
        let ws2 = WenshuWorkspace(path: path)
        try await ws2.open()
        let uuid2 = await ws2.workspaceUUID()
        #expect(uuid1 == uuid2)
        try await ws2.close()
        try? FileManager.default.removeItem(at: path)
    }

    @Test("exec: basic CRUD on chat_messages")
    func testChatMessagesCRUD() async throws {
        let path = tmpPath("chat-crud")
        let ws = WenshuWorkspace(path: path)
        try await ws.open()
        try await ws.exec("""
        INSERT INTO chat_messages (id, session_id, source, content, timestamp)
        VALUES ('m1', 'default', 'user', 'hello', 1000.0);
        """)
        let count = await ws.queryCount("SELECT COUNT(*) FROM chat_messages;")
        #expect(count == 1)
        try await ws.close()
        try? FileManager.default.removeItem(at: path)
    }

    @Test("all 13 tables exist after bootstrap")
    func testAllTablesExist() async throws {
        let path = tmpPath("all-tables")
        let ws = WenshuWorkspace(path: path)
        try await ws.open()
        let expected = [
            "ws_manifest", "chat_messages", "chat_summaries",
            "kanban_tasks", "sub_agent_runs", "memory_entries",
            "skills", "provider_keys", "preferences",
            "books", "bookmarks", "outline_entries", "attachments"
        ]
        for table in expected {
            #expect(await ws.tableExists(table), "table \(table) missing after bootstrap")
        }
        try await ws.close()
        try? FileManager.default.removeItem(at: path)
    }

    @Test("all 6 indexes created after bootstrap")
    func testAllIndexesExist() async throws {
        let path = tmpPath("all-indexes")
        let ws = WenshuWorkspace(path: path)
        try await ws.open()
        let expected = [
            "idx_chat_messages_session", "idx_kanban_tasks_status",
            "idx_sub_agent_runs_session", "idx_memory_entries_user",
            "idx_books_shelf", "idx_outline_entries_book"
        ]
        for index in expected {
            let sql = "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='\(index)';"
            let count = await ws.queryCount(sql) ?? 0
            #expect(count == 1, "index \(index) missing")
        }
        try await ws.close()
        try? FileManager.default.removeItem(at: path)
    }

    @Test("backup: copies file to destination atomically with data preserved")
    func testBackup() async throws {
        let src = tmpPath("backup-src")
        let dst = tmpPath("backup-dst")
        let ws = WenshuWorkspace(path: src)
        try await ws.open()
        try await ws.exec("INSERT INTO chat_messages (id, session_id, source, content, timestamp) VALUES ('m1', 'default', 'user', 'hi', 1000.0);")
        try await ws.backup(to: dst)
        #expect(FileManager.default.fileExists(atPath: dst.path))
        // Verify data preserved
        let ws2 = WenshuWorkspace(path: dst)
        try await ws2.open()
        let count = await ws2.queryCount("SELECT COUNT(*) FROM chat_messages;")
        #expect(count == 1)
        try await ws2.close()
        try await ws.close()
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: dst)
    }

    @Test("integrityCheck: returns true for healthy workspace")
    func testIntegrityCheckHealthy() async throws {
        let path = tmpPath("integrity")
        let ws = WenshuWorkspace(path: path)
        try await ws.open()
        let ok = await ws.integrityCheck()
        #expect(ok == true)
        try await ws.close()
        try? FileManager.default.removeItem(at: path)
    }
}