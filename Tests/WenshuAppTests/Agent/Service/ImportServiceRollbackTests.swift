//
//  ImportServiceRollbackTests.swift · wenshu
//
//  The cancel rollback (= boss's 2026-10-09 directive: "取消退出时，所有已经导入
//  的内容回退清掉 ... 不留痕" = cancel = nothing lands on disk).
//
//  In the reorganize mode the agent is the only writer (= the orchestrator
//  writes nothing; = see `ImportServiceMainFileWriter`). The agent writes
//  through `WriteBookDocTool`, so the orchestrator's own trail of written
//  files is empty. The rollback therefore diffs the book's tree: the tree
//  before the run, and the tree after it.
//
//  Coverage:
//    1. The file the agent wrote is gone after a rollback.
//    2. The file the book held before the run is still there.
//    3. The directory the run created is gone (= no trace).
//

import Foundation
import XCTest
@testable import WenshuApp

@MainActor
final class ImportServiceRollbackTests: XCTestCase {

    // MARK: - Fixtures

    /// A router that writes into the book the way the agent does (= the
    /// write lands on disk, = the orchestrator's own trail stays empty).
    actor AgentLikeRouter: ImportRouter {
        let bookRoot: URL
        let fileName: String

        init(bookRoot: URL, fileName: String) {
            self.bookRoot = bookRoot
            self.fileName = fileName
        }

        func route(
            _ input: ImportFileInput,
            destination: ImportDestination,
            progress: (@Sendable (String) async -> Void)? = nil
        ) async throws -> ImportRoutingResult {
            let folder = bookRoot.appendingPathComponent("world")
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true
            )
            try "# written by the agent".write(
                to: folder.appendingPathComponent(fileName),
                atomically: true,
                encoding: .utf8
            )
            return ImportRoutingResult(
                destination: .bookFolder(.world),
                title: "t", summary: "s",
                tags: ["stub"], entityType: "other",
                category: nil, confidence: 1.0,
                rewrittenBody: nil,
                extraFiles: []
            )
        }

        func isContentSame(
            sourceBody: String,
            existingBody: String,
            sourceTitle: String
        ) async throws -> ContentSameResult {
            ContentSameResult(
                isContentSame: false,
                confidence: 0.0,
                reasoning: "Stub router; always different."
            )
        }
    }

    private func makeFixture() throws -> (
        source: URL,
        wsRoot: URL,
        shelfId: UUID,
        bookId: UUID,
        bookRoot: URL,
        preExisting: URL
    ) {
        let fm = FileManager.default
        let source = fm.temporaryDirectory
            .appendingPathComponent("wenshu-rollback-src-\(UUID().uuidString)")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try "source body".write(
            to: source.appendingPathComponent("a.md"),
            atomically: true,
            encoding: .utf8
        )
        let wsRoot = fm.temporaryDirectory
            .appendingPathComponent("wenshu-rollback-ws-\(UUID().uuidString)")
        let shelfId = UUID()
        let bookId = UUID()
        let bookRoot = wsRoot
            .appendingPathComponent("shelves")
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
        let world = bookRoot.appendingPathComponent("world")
        try fm.createDirectory(at: world, withIntermediateDirectories: true)
        // A document the book held before the run.
        let preExisting = world.appendingPathComponent("既有文档.md")
        try "# already here".write(
            to: preExisting, atomically: true, encoding: .utf8
        )
        try fm.createDirectory(
            at: wsRoot.appendingPathComponent("reference-library/entities"),
            withIntermediateDirectories: true
        )
        return (source, wsRoot, shelfId, bookId, bookRoot, preExisting)
    }

    private func makeTarget(
        wsRoot: URL,
        shelfId: UUID,
        bookId: UUID
    ) -> ImportTarget {
        ImportTarget(
            destination: .book,
            wsRoot: wsRoot,
            bookId: bookId,
            shelfId: shelfId,
            referenceStore: FileSystemReferenceStore(
                referenceLibraryRoot: wsRoot.appendingPathComponent("reference-library")
            ),
            rewriteMode: .reorganize,
            bookFolder: .world
        )
    }

    // MARK: - The tests

    /// Cancel removes the file the agent wrote, keeps the file the book
    /// held before the run, and takes the directory the run created.
    func testTheRollbackRemovesWhatTheAgentWrote() async throws {
        let fx = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fx.source)
            try? FileManager.default.removeItem(at: fx.wsRoot)
        }
        let target = makeTarget(
            wsRoot: fx.wsRoot, shelfId: fx.shelfId, bookId: fx.bookId
        )
        let service = ImportService()
        _ = await service.importFiles(
            in: fx.source,
            into: target,
            router: AgentLikeRouter(bookRoot: fx.bookRoot, fileName: "agent.md")
        )
        // The agent's file is on disk now.
        let agentFile = fx.bookRoot
            .appendingPathComponent("world")
            .appendingPathComponent("agent.md")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: agentFile.path),
            "The agent's file must be on disk before the rollback."
        )
        // The user cancels.
        await service.cancel()
        await service.rollback()
        // The agent's file is gone.
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: agentFile.path),
            "Cancel must remove what the agent wrote; = nothing lands on disk."
        )
        // The file the book held before the run is still there.
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fx.preExisting.path),
            "The rollback must not touch a document the book held before the run."
        )
    }

    /// A directory the run created goes too (= the boss's directive is
    /// "不留痕" = leave no trace).
    func testTheRollbackRemovesTheDirectoryTheRunCreated() async throws {
        let fm = FileManager.default
        let source = fm.temporaryDirectory
            .appendingPathComponent("wenshu-rollback-src-\(UUID().uuidString)")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try "source body".write(
            to: source.appendingPathComponent("a.md"),
            atomically: true,
            encoding: .utf8
        )
        let wsRoot = fm.temporaryDirectory
            .appendingPathComponent("wenshu-rollback-ws-\(UUID().uuidString)")
        let shelfId = UUID()
        let bookId = UUID()
        let bookRoot = wsRoot
            .appendingPathComponent("shelves")
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
        // The book's world folder does not exist yet (= the run creates it).
        let world = bookRoot.appendingPathComponent("world")
        try fm.createDirectory(
            at: wsRoot.appendingPathComponent("reference-library/entities"),
            withIntermediateDirectories: true
        )
        defer {
            try? fm.removeItem(at: source)
            try? fm.removeItem(at: wsRoot)
        }
        let target = makeTarget(
            wsRoot: wsRoot, shelfId: shelfId, bookId: bookId
        )
        let service = ImportService()
        _ = await service.importFiles(
            in: source,
            into: target,
            router: AgentLikeRouter(bookRoot: bookRoot, fileName: "agent.md")
        )
        XCTAssertTrue(fm.fileExists(atPath: world.path))
        await service.cancel()
        await service.rollback()
        XCTAssertFalse(
            fm.fileExists(atPath: world.path),
            "The folder the run created must be gone; = the rollback leaves no trace."
        )
    }
}
