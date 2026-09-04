//
//  ProcessToolsTests.swift · Wenshu · v0.18 ticket 08 (process tools)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ProcessTools (hermes replica)")
struct ProcessToolsTests {
    @Test("run echo 命令")
    func testRunEcho() async throws {
        let tools = ProcessTools()
        let result = try tools.run(executable: "/bin/echo", arguments: ["hello wenshu"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("hello wenshu"))
    }

    @Test("runShell 跑多命令")
    func testRunShell() async throws {
        // v0.23 ticket 008: runShell always throws (boss 8/23 拍: 用户不可通过聊天改系统).
        // Use wenshu-devtool CLI for legitimate shell access.
        let tools = ProcessTools()
        do {
            _ = try tools.runShell("echo first && echo second")
            Issue.record("runShell should throw ProcessToolError.chatShellDenied")
        } catch let ProcessToolError.chatShellDenied(cmd) {
            #expect(cmd == "echo first && echo second")
        }
    }

    @Test("不存在的命令 exitCode != 0")
    func testNonExistentCommand() async throws {
        let tools = ProcessTools()
        do {
            let result = try tools.run(executable: "/bin/nonexistent-command-xyz")
            #expect(result.exitCode != 0)
        } catch {
            // Process.run 抛错也算 expected (file not found)
            #expect(true)
        }
    }

    @Test("isRunning 当前进程")
    func testIsRunning() {
        let tools = ProcessTools()
        #expect(tools.isRunning(processID: getpid()) == true)
        #expect(tools.isRunning(processID: 99999) == false)
    }
}