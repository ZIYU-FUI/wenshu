//
//  FileToolsAgentTests.swift · Wenshu · v0.35 ticket 001 sub-step 6
//
//  Unit tests for ReadFileTool + WriteFileTool (= 2 stub tools for
//  TB-B tracer-bullet, per hermes-core-translation spec §3.4).
//
//  These are thin async wrappers over existing wenshu FileTools
//  (= AGENTS.md §11.3 wenshu-side wins pattern: do not re-implement
//  file I/O, reuse FileTools.pathDenied + read + write verbatim).
//
//  Test surface:
//  1. ReadFileTool reads existing file via FileTools delegate (= round-trip)
//  2. WriteFileTool writes new file via FileTools delegate (= round-trip)
//  3. ReadFileTool rejects sandbox-denied path (= uses FileTools.pathDenied)
//  4. WriteFileTool rejects sandbox-denied path
//  5. Both tools integrate with ToolExecutor (= end-to-end dispatch)
//
//  Uses /tmp (= POSIX-portable temp dir, not sandbox-denied per
//  FileTools.pathDenied implementation).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("FileTools (agent-side, = ticket 001 sub-step 6)")
struct FileToolsAgentTests {

    // MARK: - Test 1: Read round-trip

    @Test("ReadFileTool reads existing file via FileTools delegate")
    func testReadRoundTrip() async throws {
        // Setup: write a file directly via FileTools (= not via WriteFileTool,
        // to isolate the test)
        let tmpPath = "/tmp/wenshu-readfiletool-test-\\(UUID().uuidString).md"
        try FileTools().write(path: tmpPath, content: "hello wenshu")

        defer {
            try? FileManager.default.removeItem(atPath: tmpPath)
        }

        // Execute ReadFileTool
        let tool = ReadFileTool()
        let result = try await tool.execute(input: "{\"path\":\"\\(tmpPath)\"}")
        #expect(result == "hello wenshu")
    }

    // MARK: - Test 2: Write round-trip

    @Test("WriteFileTool writes file via FileTools delegate")
    func testWriteRoundTrip() async throws {
        let tmpPath = "/tmp/wenshu-writefiletool-test-\\(UUID().uuidString).md"
        let input = "{\"path\":\"\\(tmpPath)\",\"content\":\"wrote via WriteFileTool\"}"

        defer {
            try? FileManager.default.removeItem(atPath: tmpPath)
        }

        let tool = WriteFileTool()
        _ = try await tool.execute(input: input)

        // Verify file exists with correct content (= read back via FileTools)
        let written = try FileTools().read(path: tmpPath)
        #expect(written == "wrote via WriteFileTool")
    }

    // MARK: - Test 3: Read sandbox denial

    @Test("ReadFileTool rejects sandbox-denied path")
    func testReadSandboxDenial() async throws {
        let tool = ReadFileTool()
        // /etc/shadow is the canonical sandbox-denied path
        await #expect(throws: ToolExecutorError.self) {
            _ = try await tool.execute(input: "{\"path\":\"/etc/shadow\"}")
        }
    }

    // MARK: - Test 4: Write sandbox denial

    @Test("WriteFileTool rejects sandbox-denied path")
    func testWriteSandboxDenial() async throws {
        let tool = WriteFileTool()
        await #expect(throws: ToolExecutorError.self) {
            _ = try await tool.execute(input: "{\"path\":\"/etc/shadow\",\"content\":\"x\"}")
        }
    }

    // MARK: - Test 5: Integration with ToolExecutor

    @Test("ReadFileTool integrates with ToolExecutor (end-to-end dispatch)")
    func testToolExecutorIntegration() async throws {
        let tmpPath = "/tmp/wenshu-exec-test-\\(UUID().uuidString).md"
        try FileTools().write(path: tmpPath, content: "executor dispatched this")

        defer {
            try? FileManager.default.removeItem(atPath: tmpPath)
        }

        let executor = ToolExecutor()
        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "ReadFile", input: "{\"path\":\"\\(tmpPath)\"}")]
        )
        var messages: [LLMMessage] = [assistantMessage]

        try await executor.executeSequential(
            assistantMessage: assistantMessage,
            messages: &messages,
            taskId: "task-1",
            tools: ["ReadFile": ReadFileTool()]
        )

        // Verify: 1 assistant + 1 tool message with the file content
        #expect(messages.count == 2)
        #expect(messages[1].role == .tool)
        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output == "executor dispatched this")
        } else {
            Issue.record("expected toolResult block")
        }
    }
}