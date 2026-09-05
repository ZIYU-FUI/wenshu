//
//  ProcessTools.swift · Wenshu · v0.18 ticket 08 (hermes replica)
//
//  本地 process tools (复刻 hermes terminal / process tool 真值).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现" + "不符合文枢定位的可以复刻".
//
//  wenshu 定位 = SwiftUI 桌面写作 app. ProcessTools 写作用 (跑脚本 / 查文档).
//  Apple HIG 真值: Foundation Process 真值.
//

import Foundation

/// Process 结果真值
public struct ProcessResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// ProcessToolError: errors thrown by ProcessTools (v0.23 ticket 008: chat-triggered shell deny).
public enum ProcessToolError: Error, LocalizedError {
    case chatShellDenied(command: String)
    case readOnlyDenied(command: String, reason: String)  // v0.23 ticket 013.011

    public var errorDescription: String? {
        switch self {
        case .chatShellDenied(let cmd):
            return "shell access blocked (boss 8/23 拍: 用户不可通过聊天改系统): \(cmd)"
        case .readOnlyDenied(let cmd, let reason):
            return "read-only shell denied (v0.23 ticket 013.011): \(cmd) — \(reason)"
        }
    }
}

/// ProcessTools: 本地 process ops
public struct ProcessTools: Tool, Sendable {
    public init() {}

    /// Tool-protocol adapter (= MIGRATE-TOOLREGISTRY-002): shell
    /// execution via the existing ProcessTools surface. Mirrors
    /// `WenshuConductor.invokeTool(name: "process", ...)` which
    /// is deny-all (= chat-triggered shell blocked per boss 8/23
    /// rule: 用户不可通过聊天改系统).
    public func execute(input: String) async throws -> String {
        // Deny-all for chat-triggered shell (= matches the legacy
        // `WenshuConductor.invokeTool("process")` behavior). Read-only
        // commands flow through the dedicated `runReadOnlyShell` path
        // (= separately registered as `process_readonly` if needed
        // in a future ticket; for now it stays off the registry).
        _ = input
        throw ProcessToolError.chatShellDenied(command: "process tool blocked from chat")
    }

    /// runShell: v0.23 ticket 008.002: blocked from chat path by default (boss 8/23 拍).
    /// Use wenshu-devtool CLI for legitimate shell access.
    /// v0.23 ticket 013.011: read-only commands are now allowed via `runReadOnlyShell`.
    public func runShell(_ command: String, workingDirectory: String? = nil) throws -> ProcessResult {
        throw ProcessToolError.chatShellDenied(command: command)
    }

    /// v0.23 ticket 013.011 (hermes gap 10): run read-only shell commands.
    /// Mirrors hermes `set_approval_callback` pattern: dangerous commands
    /// require approval, but safe read-only commands (ls, wc, cat, etc.) are
    /// allowed without approval.
    /// - Whitelist: command must start with one of `readOnlyCommands`.
    /// - Reject: anything that contains dangerous chars (;, &&, |, >, <, `, $).
    /// - Reject: path arguments that match FileTools.pathDenied (security).
    public func runReadOnlyShell(_ command: String, workingDirectory: String? = nil) throws -> ProcessResult {
        // Strip leading/trailing whitespace.
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        // Check command starts with a whitelisted prefix.
        let firstToken = trimmed.split(separator: " ").first.map(String.init) ?? ""
        let baseCmd = (firstToken as NSString).lastPathComponent  // handle "/bin/ls" → "ls"
        guard Self.readOnlyCommands.contains(baseCmd) else {
            throw ProcessToolError.readOnlyDenied(command: command, reason: "command '\(baseCmd)' not in read-only whitelist. allowed: \(Self.readOnlyCommands.sorted().joined(separator: ", "))")
        }
        // Reject shell metacharacters that could be used for command injection.
        // NOTE: use Swift.Character explicitly because WenshuApp.Character (this
        // project's Character enum = ticket 002) shadows the standard library
        // Character type in this scope.
        let dangerousChars: Set<Swift.Character> = [";", "&", "|", ">", "<", "`", "$", "(", ")", "{", "}", "*", "?", "[", "]", "!", "~", "#"]
        for char in trimmed {
            if dangerousChars.contains(char) {
                throw ProcessToolError.readOnlyDenied(command: command, reason: "shell metacharacter '\(char)' not allowed in read-only mode (defense against command injection)")
            }
        }
        // Check file path arguments against FileTools.pathDenied (security).
        let args = trimmed.split(separator: " ").map(String.init).dropFirst()
        for arg in args {
            if arg.hasPrefix("/") || arg.hasPrefix(".") || arg.hasPrefix("~") {
                let tools = FileTools()
                if tools.pathDenied(arg) {
                    throw ProcessToolError.readOnlyDenied(command: command, reason: "arg '\(arg)' is in FileTools.pathDenied deny-list")
                }
            }
        }
        // Run with /bin/sh -c (hermes pattern: shell parses args, but we already validated)
        return try run(executable: "/bin/sh", arguments: ["-c", trimmed], workingDirectory: workingDirectory)
    }

    /// v0.23 ticket 013.011: read-only command whitelist.
    /// Mirrors hermes read-only shell command safety pattern.
    public static let readOnlyCommands: Set<String> = [
        "ls",      // list directory
        "cat",     // read file
        "head",    // read file head
        "tail",    // read file tail
        "wc",      // word count
        "grep",    // text search
        "find",    // find files
        "stat",    // file metadata
        "file",    // file type
        "pwd",     // print working directory
        "echo",    // print text (no shell expansion if no $ allowed)
        "date",    // current date
        "whoami",  // current user
        "uname",   // system info
    ]

    /// run: 跑 1 个命令 + 拿 stdout/stderr/exit code (Apple Process 真值)
    public func run(executable: String, arguments: [String] = [], workingDirectory: String? = nil) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let cwd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    /// runShell: 已弃用 — v0.23 ticket 008: chat-triggered shell blocked (boss 8/23 拍).
    /// Use wenshu-devtool CLI for legitimate shell access.
    /// (stub below replaced by the deny-only runShell earlier in this file.)

    /// isRunning: 查 process 是否在跑 (Apple Process 真值)
    public func isRunning(processID: Int32) -> Bool {
        kill(processID, 0) == 0
    }
}

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension ProcessTools {
    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1). Fires once at first
    /// type access; the underlying `Task` schedules the async
    /// `register(...)` call off the init thread.
    ///
    /// Registered as a stub schema because chat-triggered shell is
    /// deny-all per boss 8/23 (= the `execute(input:)` adapter always
    /// throws `ProcessToolError.chatShellDenied`). The schema is here
    /// so the LLM knows the tool name exists and that it is
    /// permanently blocked from chat; use wenshu-devtool CLI for
    /// legitimate shell access.
    public static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.register(
                name: "process",
                toolset: "data",
                schema: ToolRegistrySchema(
                    name: "process",
                    description: "Local shell process execution (= deny-all from chat per boss 8/23 rule: 用户不可通过聊天改系统. Use wenshu-devtool CLI for legitimate shell access.).",
                    inputSchema: [
                        "command": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Shell command to execute. Will always be rejected (= use wenshu-devtool CLI instead)."
                        )
                    ],
                    required: ["command"]
                ),
                handler: ProcessTools(),
                description: "Local shell process execution (= deny-all from chat).",
                emoji: "⛔"
            )
        }
    }()
}
