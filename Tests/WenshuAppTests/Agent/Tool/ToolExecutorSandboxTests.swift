//
//  ToolExecutorSandboxTests.swift · Wenshu · wt/sandbox-tighten-2026-09-25
//
//  Integration coverage: confirms that ToolExecutor.executeSequential
//  rejects any tool_use block whose input dictionary carries a
//  path-bearing key (path / file / cwd / from / to) that resolves
//  outside the .ws library root.
//
//  Each test sets wenshu.libraryPath in setUp and tears it down in
//  tearDown so test isolation is preserved.
//
//  Cases:
//    1. Path inside the library = the tool runs normally
//    2. Path outside the library = throws ToolExecutorError.sandboxViolation,
//       the offending tool is NOT invoked
//    3. Empty input dict (= no path keys) = the tool runs normally
//        (= sandbox only checks path-bearing keys)
//    4. Two sequential tool_use blocks: one valid, one outside = the
//        second throws while the first succeeds (= executor keeps
//        going on first, aborts on second per the spec's throw-to-abort
//        pre-dispatch semantics)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ToolExecutor ↔ WenshuSandbox integration (wt/sandbox-tighten-2026-09-25)")
struct ToolExecutorSandboxTests {

    private let libraryRoot = "/Users/anbaiqiang/libraries/test.ws"

    init() {
        // Clean before each test (= no leakage from prior runs / real onboarding).
        UserDefaultsStore.shared.remove(.libraryPath)
    }

    private func setLibraryRoot() {
        UserDefaultsStore.shared.setString(libraryRoot, forKey: .libraryPath)
    }

    /// Echo-style tool that returns the input dictionary verbatim so
    /// tests can assert whether the tool body ran (= input round-trips
    /// to output).
    private struct EchoPathTool: Tool {
        func execute(input: String) async throws -> String {
            // Tag the output so a test can detect "tool ran" vs "tool
            // was skipped by the sandbox".
            return "RAN:\(input)"
        }
    }

    @Test("executeSequential allows a tool_use block whose path key resolves inside the library")
    func testAllowsInsideLibrary() async throws {
        setLibraryRoot()
        let executor = ToolExecutor()
        let insidePath = "\(libraryRoot)/chapter.md"
        let tools: [String: any Tool] = ["ReadFileLike": EchoPathTool()]

        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(
                id: "t1",
                name: "ReadFileLike",
                input: "{\"path\":\"\(insidePath)\"}"
            )]
        )
        var messages: [LLMMessage] = [assistantMessage]

        try await executor.executeSequential(
            assistantMessage: assistantMessage,
            messages: &messages,
            taskId: "task-1",
            tools: tools
        )

        // 1 tool_result message appended; the "RAN:" prefix proves the
        // tool was actually invoked (= sandbox passed it through).
        #expect(messages.count == 2)
        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output.hasPrefix("RAN:"))
        } else {
            Issue.record("expected toolResult block in messages[1]")
        }
    }

    @Test("executeSequential rejects a tool_use block whose path key resolves outside the library")
    func testRejectsOutsideLibrary() async throws {
        setLibraryRoot()
        let executor = ToolExecutor()
        let outsidePath = "/etc/passwd"
        let tools: [String: any Tool] = ["ReadFileLike": EchoPathTool()]

        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(
                id: "t1",
                name: "ReadFileLike",
                input: "{\"path\":\"\(outsidePath)\"}"
            )]
        )
        var messages: [LLMMessage] = [assistantMessage]

        await #expect(throws: ToolExecutorError.self) {
            try await executor.executeSequential(
                assistantMessage: assistantMessage,
                messages: &messages,
                taskId: "task-1",
                tools: tools
            )
        }

        // The echo tool body did NOT run (= no "RAN:" prefix in
        // any result; = the sandbox aborted the call before
        // dispatch).
        let allBlocks = messages.flatMap { $0.blocks }
        let anyRan = allBlocks.contains { block in
            if case .toolResult(_, let output) = block, output.hasPrefix("RAN:") { return true }
            return false
        }
        #expect(anyRan == false, "tool body must not run when the sandbox rejects the path")
    }

    @Test("executeSequential allows a tool_use block with no path-bearing keys")
    func testAllowsEmptyInput() async throws {
        setLibraryRoot()
        let executor = ToolExecutor()
        let tools: [String: any Tool] = ["SearchLike": EchoPathTool()]

        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(
                id: "t1",
                name: "SearchLike",
                input: "{\"query\":\"literal text\"}"
            )]
        )
        var messages: [LLMMessage] = [assistantMessage]

        try await executor.executeSequential(
            assistantMessage: assistantMessage,
            messages: &messages,
            taskId: "task-1",
            tools: tools
        )

        #expect(messages.count == 2)
        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output.hasPrefix("RAN:"))
        } else {
            Issue.record("expected toolResult block in messages[1]")
        }
    }

    @Test("executeSequential processes the first tool_use (valid) and aborts on the second (outside)")
    func testMixedValidAndInvalid() async throws {
        setLibraryRoot()
        let executor = ToolExecutor()
        let tools: [String: any Tool] = ["Mixed": EchoPathTool()]

        let insidePath = "\(libraryRoot)/valid.txt"
        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [
                .toolUse(id: "t1", name: "Mixed", input: "{\"path\":\"\(insidePath)\"}"),
                .toolUse(id: "t2", name: "Mixed", input: "{\"path\":\"/etc/passwd\"}")
            ]
        )
        var messages: [LLMMessage] = [assistantMessage]

        await #expect(throws: ToolExecutorError.self) {
            try await executor.executeSequential(
                assistantMessage: assistantMessage,
                messages: &messages,
                taskId: "task-1",
                tools: tools
            )
        }

        // First block ran (= "RAN:" tool result present); second
        // never ran (= no second tool result message appended).
        // The throw aborts BEFORE the executor appends the toolResult
        // for the second block, so messages.count stays at 2 (= initial
        // + first successful tool_result).
        #expect(messages.count == 2)
        if case .toolResult(_, let firstOutput) = messages[1].blocks[0] {
            #expect(firstOutput.hasPrefix("RAN:"))
        } else {
            Issue.record("expected first toolResult to be the RAN: echo of the inside path")
        }
    }
}