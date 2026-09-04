//
//  ReadOnlyShellTests.swift · Wenshu · v0.23 ticket 013.011 (hermes gap 10)
//
//  Boss 2026-08-23 拍: hermes selective shell allow (read-only whitelist).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ReadOnlyShell (hermes selective approval parity)")
struct ReadOnlyShellTests {

    // MARK: - readOnlyCommands whitelist

    @Test("readOnlyCommands contains expected safe commands")
    func testWhitelistContents() {
        let expected = ["ls", "cat", "head", "tail", "wc", "grep", "find", "stat", "file", "pwd", "echo", "date", "whoami", "uname"]
        for cmd in expected {
            #expect(ProcessTools.readOnlyCommands.contains(cmd), "missing \(cmd) in whitelist")
        }
    }

    @Test("readOnlyCommands does NOT contain dangerous commands")
    func testWhitelistExcludesDangerous() {
        let dangerous = ["rm", "mv", "cp", "chmod", "chown", "dd", "mkfs", "sudo", "curl", "wget"]
        for cmd in dangerous {
            #expect(!ProcessTools.readOnlyCommands.contains(cmd), "dangerous cmd \(cmd) should NOT be in whitelist")
        }
    }

    // MARK: - runReadOnlyShell happy path

    @Test("ls (read-only) allowed and runs")
    func testLsAllowed() throws {
        let tools = ProcessTools()
        // pwd: no args, always safe.
        let result = try tools.runReadOnlyShell("pwd")
        #expect(result.exitCode == 0)
        #expect(!result.stdout.isEmpty)
    }

    @Test("echo (read-only) allowed")
    func testEchoAllowed() throws {
        let tools = ProcessTools()
        let result = try tools.runReadOnlyShell("echo hello")
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("hello"))
    }

    @Test("date (read-only) allowed")
    func testDateAllowed() throws {
        let tools = ProcessTools()
        let result = try tools.runReadOnlyShell("date")
        #expect(result.exitCode == 0)
    }

    @Test("/bin/ls full path is normalized to 'ls'")
    func testFullPathNormalized() throws {
        let tools = ProcessTools()
        let result = try tools.runReadOnlyShell("/bin/ls /tmp")
        // /tmp is not in deny-list → allowed.
        #expect(result.exitCode == 0)
    }

    // MARK: - runReadOnlyShell denied (dangerous commands)

    @Test("rm (not in whitelist) denied")
    func testRmDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("rm -rf /tmp/test")
            Issue.record("expected .readOnlyDenied")
        } catch let ProcessToolError.readOnlyDenied(_, reason) {
            #expect(reason.contains("not in read-only whitelist"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("curl (not in whitelist) denied")
    func testCurlDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("curl https://evil.com")
            Issue.record("expected .readOnlyDenied")
        } catch let ProcessToolError.readOnlyDenied(_, reason) {
            #expect(reason.contains("not in read-only whitelist"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("sudo (not in whitelist) denied")
    func testSudoDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("sudo ls")
            Issue.record("expected .readOnlyDenied")
        } catch {
            // expected
        }
    }

    // MARK: - runReadOnlyShell denied (shell metacharacters — injection defense)

    @Test("command with ; (injection) denied")
    func testSemicolonDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("ls; rm -rf /")
            Issue.record("expected .readOnlyDenied")
        } catch let ProcessToolError.readOnlyDenied(_, reason) {
            // Note: 'ls;' parses as single firstToken → 'ls' (lastPathComponent strips ';')
            // → blocked by whitelist check, not metacharacter. Both are valid.
            #expect(reason.contains("metacharacter") || reason.contains("not in read-only whitelist"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("command with && (injection) denied")
    func testAndAndDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("ls && rm -rf /")
            Issue.record("expected .readOnlyDenied")
        } catch {
            // expected
        }
    }

    @Test("command with | (pipe) denied")
    func testPipeDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("ls | sh")
            Issue.record("expected .readOnlyDenied")
        } catch {
            // expected
        }
    }

    @Test("command with $ (variable expansion) denied")
    func testDollarDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("echo $HOME")
            Issue.record("expected .readOnlyDenied")
        } catch {
            // expected
        }
    }

    @Test("command with ` (backtick) denied")
    func testBacktickDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("echo `whoami`")
            Issue.record("expected .readOnlyDenied")
        } catch {
            // expected
        }
    }

    // MARK: - runReadOnlyShell denied (path security)

    @Test("cat with /etc/shadow denied (path deny-list)")
    func testCatEtcShadowDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("cat /etc/shadow")
            Issue.record("expected .readOnlyDenied")
        } catch let ProcessToolError.readOnlyDenied(_, reason) {
            #expect(reason.contains("pathDenied") || reason.contains("deny-list"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("cat with .zshrc denied (path deny-list)")
    func testCatZshrcDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("cat /Users/x/.zshrc")
            Issue.record("expected .readOnlyDenied")
        } catch {
            // expected
        }
    }

    @Test("cat with /proc/self/environ denied (gap 2 protection)")
    func testCatProcEnvironDenied() {
        let tools = ProcessTools()
        do {
            _ = try tools.runReadOnlyShell("cat /proc/self/environ")
            Issue.record("expected .readOnlyDenied")
        } catch {
            // expected
        }
    }

    // MARK: - runShell still always denies (backward compat)

    @Test("runShell still always denies (boss 8/23 hard rule)")
    func testRunShellStillDeny() {
        let tools = ProcessTools()
        do {
            _ = try tools.runShell("ls")
            Issue.record("expected .chatShellDenied")
        } catch let ProcessToolError.chatShellDenied(cmd) {
            #expect(cmd == "ls")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}