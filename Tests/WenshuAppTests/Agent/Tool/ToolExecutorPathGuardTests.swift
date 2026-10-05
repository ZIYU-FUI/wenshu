//
//  ToolExecutorPathGuardTests.swift · Wenshu · wt/path-guard-v2-2026-09-25
//
//  Integration coverage: confirms ToolExecutor.executeSequential
//  rejects tool_use blocks whose input dict has a path-bearing key
//  (= path / file / cwd / from / to / rootDir) that resolves outside
//  the .ws library root. Replaces the v1 ToolExecutorSandboxTests
//  (= now that the rename + move is complete, the integration test
//  reads "PathGuard" instead of "WenshuSandbox").
//
//  ActiveLibrary.overrideForTesting is a `@TaskLocal` (= Apple
//  HIG canonical pattern for test seams). Tests wrap their body
//  in `ActiveLibrary.$overrideForTesting.withValue(...) { ... }`
//  via the `withLibraryRoot` helper (= per-task scope; = no
//  cross-suite pollution; = no init() reset needed).
//

import Testing
import Foundation
@testable import WenshuApp

@MainActor
@Suite("ToolExecutor ↔ PathGuard integration (wt/path-guard-v2-2026-09-25)", .serialized)
struct ToolExecutorPathGuardTests {

    private let libraryRoot = "/Users/anbaiqiang/libraries/test.ws"

    /// Run `body` with `ActiveLibrary.overrideForTesting` bound to
    /// `libraryRoot` for the duration of the closure (= Apple HIG
    /// canonical TaskLocal pattern; = no cross-suite pollution).
    private func withLibraryRoot<R>(_ body: () async throws -> R) async rethrows -> R {
        try await ActiveLibrary.$overrideForTesting.withValue(libraryRoot, operation: body)
    }

    /// Echo-style tool returning the input verbatim with a "RAN:"
    /// prefix so tests can detect "tool body ran" vs "skipped by
    /// PathGuard".
    private struct EchoPathTool: Tool {
        func execute(input: String) async throws -> String {
            return "RAN:\(input)"
        }
    }

    @Test("executeSequential allows a tool_use block whose path key resolves inside the library")
    func testAllowsInsideLibrary() async throws {
        try await withLibraryRoot {
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

            #expect(messages.count == 2)
            if case .toolResult(_, let output) = messages[1].blocks[0] {
                #expect(output.hasPrefix("RAN:"))
            } else {
                Issue.record("expected toolResult block in messages[1]")
            }
        }
    }

    @Test("executeSequential rejects a tool_use block whose path key resolves outside the library")
    func testRejectsOutsideLibrary() async throws {
        try await withLibraryRoot {
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

            let allBlocks = messages.flatMap { $0.blocks }
            let anyRan = allBlocks.contains { block in
                if case .toolResult(_, let output) = block, output.hasPrefix("RAN:") { return true }
                return false
            }
            #expect(anyRan == false, "tool body must not run when PathGuard rejects the path")
        }
    }

    @Test("executeSequential allows a tool_use block with no path-bearing keys")
    func testAllowsEmptyInput() async throws {
        try await withLibraryRoot {
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
    }

    @Test("executeSequential processes the first tool_use (valid) and aborts on the second (outside)")
    func testMixedValidAndInvalid() async throws {
        try await withLibraryRoot {
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

            #expect(messages.count == 2)
            if case .toolResult(_, let firstOutput) = messages[1].blocks[0] {
                #expect(firstOutput.hasPrefix("RAN:"))
            } else {
                Issue.record("expected first toolResult to be the RAN: echo of the inside path")
            }
        }
    }

    @Test("executeSequential errorDescription for pathGuardViolation does NOT leak absolute path")
    func testErrorDescriptionHidesAbsolutePath() async throws {
        try await withLibraryRoot {
            let executor = ToolExecutor()
            let tools: [String: any Tool] = ["ReadFileLike": EchoPathTool()]

            let assistantMessage = LLMMessage(
                role: .assistant,
                blocks: [.toolUse(
                    id: "t1",
                    name: "ReadFileLike",
                    input: "{\"path\":\"/etc/passwd\"}"
                )]
            )
            var messages: [LLMMessage] = [assistantMessage]

            do {
                try await executor.executeSequential(
                    assistantMessage: assistantMessage,
                    messages: &messages,
                    taskId: "task-1",
                    tools: tools
                )
                Issue.record("expected throw")
            } catch let error as ToolExecutorError {
                let description = error.errorDescription ?? ""
                #expect(!description.contains("/etc/passwd"))
                #expect(description.contains("passwd"))
            }
        }
    }
}
