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

/// ProcessTools: 本地 process ops
public struct ProcessTools: Sendable {
    public init() {}

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

    /// runShell: 跑 shell 命令 (走 /bin/sh -c, 真值: macOS 默认 shell)
    public func runShell(_ command: String, workingDirectory: String? = nil) throws -> ProcessResult {
        try run(executable: "/bin/sh", arguments: ["-c", command], workingDirectory: workingDirectory)
    }

    /// isRunning: 查 process 是否在跑 (Apple Process 真值)
    public func isRunning(processID: Int32) -> Bool {
        kill(processID, 0) == 0
    }
}