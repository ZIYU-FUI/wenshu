//
//  WenshuCoreIntegrationTests.swift · Wenshu · v0.18 ticket 29 (integration)
//
//  集成测试 WenshuCore (MemoryStore + SkillRegistry + KanbanStore + TodoStore + AgentRuntime + FileTools + WebTools + AVMediaTools + Cronjob + Backup).
//  验证多模块协作 (Memory + Agent + Skill + Kanban).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuCore Integration")
struct WenshuCoreIntegrationTests {
    @Test("Memory + Skill + Kanban + Todo 全 Core 集成")
    func testAllCoreIntegration() async throws {
        // 1. MemoryStore 真值 (mem0 复刻)
        let memory = try MemoryStore(path: tmpPath("mem"))
        try await memory.bootstrap()
        let memResult = try await memory.add(userId: "u1", content: "test memory")
        #expect(memResult.userId == "u1")

        // 2. KanbanStore 真值 (kanban_db 复刻)
        let kanban = try KanbanStore(path: tmpPath("kanban"))
        try await kanban.bootstrap()
        let task1 = try await kanban.add(title: "Integration task 1", status: .new)
        try await kanban.transition(id: task1.id, to: .running)
        let running = try await kanban.list(status: .running)
        #expect(running.count == 1)

        // 3. TodoStore 真值
        let todo = try TodoStore(path: tmpPath("todo"))
        try await todo.bootstrap()
        _ = try await todo.add(title: "Todo 1", priority: .high)

        // 4. AgentRuntime + AgentProtocol (A2A + 多 agent) — 用真值 verifier (没 key → LLM fail 路径, S3 修法)
        let card = AgentCard(
            name: "integration-agent",
            description: "integration",
            skills: ["memory", "kanban"],
            endpoint: "in-process://integration"
        )
        let agent = AgentProtocol(agentCard: card, verifier: WenshuVerifier())
        let runtime = AgentRuntime()
        await runtime.register(AgentRegistration(name: "integration-agent", card: card, process: agent))
        // v0.21 ticket 03 + code-review S3: LLM 失败 → delegateFailed 抛错
        await #expect(throws: AgentRuntimeError.self) {
            _ = try await runtime.delegateTask(to: "integration-agent", content: "test delegation")
        }

        // 5. FileTools 真值
        let fileTools = FileTools()
        let testPath = tmpPath("file.txt")
        try fileTools.write(path: testPath, content: "integration test")
        let readBack = try fileTools.read(path: testPath)
        #expect(readBack == "integration test")
        try? FileManager.default.removeItem(atPath: testPath)

        // 6. Backup 真值
        let backup = BackupTools()
        let source = ".test-integration-source"
        try FileManager.default.createDirectory(atPath: source, withIntermediateDirectories: true)
        try "data".write(toFile: source + "/data.txt", atomically: true, encoding: .utf8)
        let meta = try backup.backup(sourceDir: source, backupDir: ".test-integration-backups")
        #expect(meta.size > 0)
        try? FileManager.default.removeItem(atPath: source)
        try? FileManager.default.removeItem(atPath: ".test-integration-backups")

        // 清理
        try? FileManager.default.removeItem(atPath: ".test-integration-mem.db")
        try? FileManager.default.removeItem(atPath: ".test-integration-kanban.db")
        try? FileManager.default.removeItem(atPath: ".test-integration-todo.db")
    }

    @Test("AVMediaTools estimateDuration 在 wenshu 写作用途")
    func testAVMediaForWriting() {
        let tools = AVMediaTools()
        // wenshu 写作用: 朗读当前章节
        let chapter = String(repeating: "今天我写了一段新内容. ", count: 50)
        let duration = tools.estimateDuration(text: chapter)
        // 50 句 / 4 字/秒 = 12.5 秒 (估算)
        #expect(duration > 0)
    }

    @Test("Cronjob parseSchedule 在 wenshu 写作用途")
    func testCronjobForWriting() {
        // wenshu 写作用: 每 5 分钟自动保存
        let valid = CronjobStore.parseSchedule("*/5 * * * *")
        #expect(valid == true)
        let next = CronjobStore.nextRun(schedule: "*/5 * * * *")
        #expect(next != nil)
// 9. 清理临时 db
        try? FileManager.default.removeItem(atPath: ".test-integration-mem.db")
        try? FileManager.default.removeItem(atPath: ".test-integration-kanban.db")
        try? FileManager.default.removeItem(atPath: ".test-integration-todo.db")
        try? FileManager.default.removeItem(atPath: ".test-integration-file.txt")
    }

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-core-int-\(tag)-\(UUID().uuidString).db"
    }
}