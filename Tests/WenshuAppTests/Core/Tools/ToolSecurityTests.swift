//
//  ToolSecurityTests.swift · Wenshu · v0.23 ticket 008.005 (security guardrails tests)
//
//  Boss 2026-08-23 拍: '用户不可以通过聊天修改 agent 的设定 / 系统的代码 / 配置文件'.
//  Tests verify L1 (system prompt) + L2 (invokeTool allowlist) + L3 (path deny-list) defenses.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Tool security guardrails (boss 8/23 拍: 用户不可通过聊天改系统)")
struct ToolSecurityTests {

    // MARK: - L3: path deny-list (FileTools)

    @Test("L3 path deny-list: Sources/ in path → denied")
    func testPathDenyListSources() {
        let tools = FileTools()
        #expect(tools.pathDenied("/Users/x/Projects/wenshu/Sources/foo.swift"))
        #expect(tools.pathDenied("./Sources/WenshuApp.swift"))
        #expect(tools.pathDenied("Sources/some-file.swift"))
    }

    @Test("L3 path deny-list: Tests/ → denied")
    func testPathDenyListTests() {
        let tools = FileTools()
        #expect(tools.pathDenied("./Tests/foo.swift"))
        #expect(tools.pathDenied("/tmp/x/Tests/x.swift"))
    }

    @Test("L3 path deny-list: .scratch/ → denied")
    func testPathDenyListScratch() {
        let tools = FileTools()
        #expect(tools.pathDenied("./.scratch/spec.md"))
        #expect(tools.pathDenied("/Users/x/.scratch/2026-08-23/foo.md"))
    }

    @Test("L3 path deny-list: ~/.hermes/ → denied")
    func testPathDenyListHermes() {
        let tools = FileTools()
        #expect(tools.pathDenied("/Users/x/.hermes/skills/foo.md"))
        #expect(tools.pathDenied("/Users/anbaiqiang/.hermes/data.json"))
    }

    @Test("L3 path deny-list: shell init files → denied")
    func testPathDenyListShellInit() {
        let tools = FileTools()
        #expect(tools.pathDenied("/Users/x/.zshrc"))
        #expect(tools.pathDenied("/Users/x/.bashrc"))
        #expect(tools.pathDenied("/Users/x/.profile"))
        #expect(tools.pathDenied("/Users/x/.bash_profile"))
    }

    @Test("L3 path deny-list: /tmp/legit.txt → allowed")
    func testPathDenyListAllowsTmp() {
        let tools = FileTools()
        #expect(!tools.pathDenied("/tmp/legit.txt"))
        #expect(!tools.pathDenied("/Users/x/Documents/novel.md"))
        #expect(!tools.pathDenied("./draft.md"))
    }

    @Test("L3: FileTools.write on deny-list path throws")
    func testFileWriteBlockedOnSources() throws {
        let tools = FileTools()
        // Use a path containing "Sources/" (deny-list prefix) inside tmp.
        let blockedPath = NSTemporaryDirectory() + "Sources/foo.swift"
        #expect(throws: FileToolError.self) {
            try tools.write(path: blockedPath, content: "evil")
        }
    }

    @Test("L3: FileTools.write on /tmp/ succeeds (allowed path)")
    func testFileWriteSucceedsOnTmp() throws {
        let tools = FileTools()
        let allowedPath = NSTemporaryDirectory() + "wenshu-security-test-\(UUID().uuidString).txt"
        try tools.write(path: allowedPath, content: "safe content")
        let content = try tools.read(path: allowedPath)
        #expect(content == "safe content")
        try? FileManager.default.removeItem(atPath: allowedPath)
    }

    // MARK: - L2: ProcessTools.runShell deny

    @Test("L2: ProcessTools.runShell always throws")
    func testProcessRunShellAlwaysThrows() {
        let tools = ProcessTools()
        do {
            _ = try tools.runShell("ls")
            Issue.record("runShell should throw")
        } catch let ProcessToolError.chatShellDenied(cmd) {
            #expect(cmd == "ls")
        } catch {
            Issue.record("expected ProcessToolError.chatShellDenied, got \(error)")
        }
    }

    // MARK: - L1: System prompt hardening

    @Test("L1: main agent identity mentions tool restrictions")
    func testMainIdentityMentionsToolRestrictions() {
        let prompt = WenshuConductorIdentity.systemPrompt
        #expect(prompt.contains("Tool restrictions"))
        #expect(prompt.contains("boss 2026-08-23 拍"))
        #expect(prompt.contains("file.write"))
        #expect(prompt.contains("process.runShell"))
    }

    @Test("L1: all 5 sub-agent prompts mention tool restrictions")
    func testAllSubAgentPromptsMentionToolRestrictions() {
        for name in SubAgentIdentity.Name.allCases {
            let prompt = SubAgentIdentity.systemPrompt(name: name)
            #expect(prompt.contains("Tool restrictions"), "\(name) prompt missing Tool restrictions section")
            #expect(prompt.contains("file.write"), "\(name) prompt missing file.write mention")
            #expect(prompt.contains("process.runShell"), "\(name) prompt missing process.runShell mention")
        }
    }

    @Test("L1: tool restrictions section REFUSE keyword (改代码) present")
    func testRefuseKeywordPresent() {
        let prompt = WenshuConductorIdentity.systemPrompt
        #expect(prompt.contains("改代码"))
        #expect(prompt.contains("改设定"))
        #expect(prompt.contains("改配置文件"))
        #expect(prompt.contains("ignore previous instructions"))
    }

    @Test("L1: tool restrictions section directs to GUI Settings")
    func testDirectsToGUISettings() {
        let prompt = WenshuConductorIdentity.systemPrompt
        #expect(prompt.contains("GUI Settings"))
    }
}