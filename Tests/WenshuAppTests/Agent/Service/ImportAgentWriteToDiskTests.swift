//
//  ImportAgentWriteToDiskTests.swift · wenshu
//
//  The import's write path, end to end (= no real LLM; = the stub
//  connector emits the tool call the model would emit).
//
//  The chain under test: the driver advertises the write tool, the
//  agent runtime dispatches the tool_use, the tool writes the file
//  into the folder the user picked, and nothing lands anywhere else.
//
//  Coverage:
//    1. The file the agent wrote is on disk, inside the user's folder.
//    2. No other folder of the book received a file.
//    3. A write that names another folder is refused, and nothing lands.
//

import Foundation
import WenshuAgent
import XCTest
@testable import WenshuApp

final class ImportAgentWriteToDiskTests: XCTestCase {

    // MARK: - Fixtures

/// A call counter that survives the async hop (= the stub's `send` is
/// called from the agent runtime's own task).
private final class CallCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}


    /// A connector that calls the write tool once, then says it is done.
    private final class WritingConnector: LLMConnector, @unchecked Sendable {
        nonisolated let connectorID: String = "writing-stub"
        let toolPath: String
        private let counter = CallCounter()

        init(toolPath: String) {
            self.toolPath = toolPath
        }

        func send(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) async throws -> LLMResponse {
            let isFirstCall = counter.next() == 1
            if isFirstCall {
                let payload = """
                {"path": "\(toolPath)", "body": "# written\\n\\nby the agent"}
                """
                return LLMResponse(
                    id: "stub-write",
                    model: "stub",
                    blocks: [.toolUse(id: "call-1", name: "writeBookDoc", input: payload)],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 0, outputTokens: 0)
                )
            }
            return LLMResponse(
                id: "stub-done",
                model: "stub",
                blocks: [.text("完成")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        }

        func stream(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) -> AsyncStream<LLMBlock> {
            AsyncStream { continuation in
                Task {
                    do {
                        let response = try await send(messages: messages, options: options)
                        for block in response.blocks { continuation.yield(block) }
                    } catch {
                        continuation.yield(.text("[stream error] \(error)"))
                    }
                    continuation.finish()
                }
            }
        }
    }

    private var libraryRoot: URL!
    private var bookRoot: URL!
    private var sourceDir: URL!

    override func setUpWithError() throws {
        let fm = FileManager.default
        libraryRoot = fm.temporaryDirectory
            .appendingPathComponent("wenshu-write-lib-\(UUID().uuidString)")
        // The book's path (= the layout the app uses: = the library root
        // holds the shelves, = a shelf holds the books).
        bookRoot = libraryRoot
            .appendingPathComponent("shelves")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(UUID().uuidString)
        sourceDir = fm.temporaryDirectory
            .appendingPathComponent("wenshu-write-src-\(UUID().uuidString)")
        try fm.createDirectory(at: bookRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: libraryRoot)
        try? FileManager.default.removeItem(at: sourceDir)
    }

    private func runImport(toolPath: String, folder: BookFolder) async throws {
        // The write goes through the library's path guard, = so the
        // guard needs the library root (= the app installs it at launch;
        // = the test pins it with the task-local seam).
        try await PathGuard.$libraryRootOverride.withValue(libraryRoot.path) {
            let driver = ImportAgentDriver(
                connector: WritingConnector(toolPath: toolPath),
                modelSlug: "stub"
            )
            let root = bookRoot!.path
            let context = ImportAgentBookContext(bookPath: { root })
            let input = ImportAgentDriver.TaskInput(
                filePath: sourceDir.appendingPathComponent("a.md").path,
                body: "# source",
                bookPath: bookRoot.path,
                bookTitle: "The book",
                targetFolder: folder
            )
            _ = try await driver.run(input: input, bookContext: context, progress: nil)
        }
    }

    private func files(in folder: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(
            atPath: bookRoot.appendingPathComponent(folder).path
        )) ?? []).sorted()
    }

    // MARK: - The tests

    /// The agent's write lands on disk, inside the folder the user
    /// picked.
    func testTheAgentsWriteLandsInTheUsersFolder() async throws {
        try await runImport(toolPath: "world/核心设定.md", folder: .world)
        let landed = files(in: "world")
        XCTAssertEqual(
            landed, ["核心设定.md"],
            "The agent's file must land in the folder the user picked."
        )
        let content = try String(
            contentsOf: bookRoot.appendingPathComponent("world/核心设定.md"),
            encoding: .utf8
        )
        XCTAssertTrue(content.contains("by the agent"))
    }

    /// The other folders of the book stay empty (= the user's folder is
    /// the only destination).
    func testNoOtherFolderReceivedAFile() async throws {
        try await runImport(toolPath: "world/核心设定.md", folder: .world)
        for folder in ["characters", "outlines", "chapters", "drafts", "ideas"] {
            XCTAssertTrue(
                files(in: folder).isEmpty,
                "The '\(folder)' folder must stay empty; = the user's folder is the only destination."
            )
        }
    }

    /// A write that names another folder is refused, and nothing lands.
    func testAWriteOutsideTheUsersFolderIsRefused() async throws {
        try await runImport(toolPath: "chapters/stray.md", folder: .world)
        XCTAssertTrue(
            files(in: "chapters").isEmpty,
            "A write outside the user's folder must not land."
        )
        XCTAssertTrue(
            files(in: "world").isEmpty,
            "A refused write must not land in the user's folder either."
        )
    }
}
