//
//  ImportServiceTests.swift
//
//  T2 of the v2.7 markdown import feature. Tests the
//  orchestrator (= the 4-phase walk → dedup → route →
//  write pipeline) against a temp directory + a stub
//  ImportRouter.
//

import XCTest
@testable import WenshuApp

@MainActor
final class ImportServiceTests: XCTestCase {

    // MARK: - Test fixtures

    /// A stub router that returns canned routing results
    /// keyed by the source file's BASENAME (= avoids
    /// path-encoding fragility on macOS = the
    /// `/private/var` vs `/var` symlink path normalization
    /// can corrupt exact-path lookups).
    actor StubImportRouter: ImportRouter {
        let canned: [String: ImportRoutingResult]
        init(_ canned: [String: ImportRoutingResult]) {
            self.canned = canned
        }
        func route(_ input: ImportFileInput) async throws -> ImportRoutingResult {
            let basename = (input.filePath as NSString).lastPathComponent
            if let r = canned[basename] { return r }
            return ImportRoutingResult(
                destination: .referenceLibrary,
                title: "stub", summary: "stub summary",
                tags: ["stub"], entityType: "other",
                category: nil, confidence: 1.0
            )
        }
    }

    private func makeSourceDir(_ files: [String: String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-import-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        for (rel, body) in files {
            let url = dir.appendingPathComponent(rel)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try body.data(using: .utf8)!.write(to: url)
        }
        return dir
    }

    private func makeWsRoot() throws -> (URL, UUID, UUID) {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-wsroot-\(UUID().uuidString)")
        let shelfId = UUID()
        let bookId = UUID()
        let bookDir = wsRoot
            .appendingPathComponent("shelves")
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
        for folder in ["world", "characters", "outlines", "chapters", "drafts"] {
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent(folder),
                withIntermediateDirectories: true
            )
        }
        try FileManager.default.createDirectory(
            at: wsRoot.appendingPathComponent("reference-library/entities"),
            withIntermediateDirectories: true
        )
        return (wsRoot, shelfId, bookId)
    }

    private func makeStore(root: URL) -> any ReferenceStoring {
        return FileSystemReferenceStore(referenceLibraryRoot: root)
    }

    private func makeTarget(wsRoot: URL, shelfId: UUID, bookId: UUID, store: any ReferenceStoring) -> ImportTarget {
        return ImportTarget(
            wsRoot: wsRoot,
            bookId: bookId,
            shelfId: shelfId,
            referenceStore: store
        )
    }

    // MARK: - Phase 1: walk

    func testImportFiles_walksMdRecursively() async throws {
        let src = try makeSourceDir([
            "a.md": "alpha",
            "sub1/b.md": "beta",
            "sub1/sub2/c.md": "gamma",
            "sub1/d.txt": "should be skipped"
        ])
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let svc = ImportService()
        struct ThrowRouter: ImportRouter {
            func route(_ input: ImportFileInput) async throws -> ImportRoutingResult {
                throw NSError(domain: "test", code: 1)
            }
        }
        let tasks = await svc.importFiles(in: src, into: target, router: ThrowRouter())
        XCTAssertEqual(tasks.count, 3, "should walk 3 .md files recursively")
        let names = Set(tasks.map { ($0.sourcePath as NSString).lastPathComponent })
        XCTAssertEqual(names, Set(["a.md", "b.md", "c.md"]))
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Phase 4: write (= book-folder path)

    func testImportFiles_writesBookFolderBodyVerbatim() async throws {
        let body = "The kingdom of Eryndor lies...\n\n  -- chapter 1"
        let src = try makeSourceDir(["eryndor.md": body])
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let svc = ImportService()
        let canned: [String: ImportRoutingResult] = [
            "eryndor.md": ImportRoutingResult(
                destination: .bookFolder(.world),
                title: "Eryndor kingdom", summary: "stub",
                tags: [], entityType: "other",
                category: nil, confidence: 1.0
            )
        ]
        let tasks = await svc.importFiles(in: src, into: target, router: StubImportRouter(canned))
        XCTAssertEqual(tasks.count, 1)
        if tasks[0].state != .done {
            XCTFail("expected .done, got state=\(tasks[0].state) err=\(tasks[0].errorMessage ?? "nil")")
        }
        XCTAssertEqual(tasks[0].destination, .bookFolder(.world))
        // The body lands verbatim at the standard 5-folder path.
        // v2.7: filename derives from the LLM-supplied
        // title (= the v2.7 dedup rule; = the boss's
        // "ID 的事还没有修" feedback; = the new file's
        // name = "Eryndor kingdom.md").
        let expectedURL = wsRoot
            .appendingPathComponent("shelves")
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
            .appendingPathComponent("world")
            .appendingPathComponent("Eryndor kingdom.md")
        let written = try String(contentsOf: expectedURL, encoding: .utf8)
        XCTAssertEqual(written, body, "body must be byte-equal to the source")
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Phase 2: dedup

    func testImportFiles_skipsAlreadyImported() async throws {
        let body = "verbatim body"
        let src = try makeSourceDir(["a.md": body])
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let svc = ImportService()
        let canned: [String: ImportRoutingResult] = [
            "a.md": ImportRoutingResult(
                destination: .referenceLibrary,
                title: "t", summary: "s", tags: ["stub"],
                entityType: "other", category: nil, confidence: 1.0
            )
        ]
        // First import.
        let first = await svc.importFiles(in: src, into: target, router: StubImportRouter(canned))
        if first.isEmpty || first[0].state != .done {
            XCTFail("first import failed: err=\(first.first?.errorMessage ?? "nil")")
            return
        }
        // Second import: cache diff sees the body hash matches the prior import.
        let second = await svc.importFiles(in: src, into: target, router: StubImportRouter(canned))
        if second.isEmpty || second[0].state != .skipped {
            XCTFail("second import: state=\(second.first?.state.rawValue ?? "nil") err=\(second.first?.errorMessage ?? "nil")")
        }
        XCTAssertEqual(second[0].destination, .referenceLibrary)
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Phase 3: route (= concurrent dispatch)

    func testImportFiles_concurrentDispatch() async throws {
        var files: [String: String] = [:]
        for i in 0..<10 {
            files["file\(i).md"] = "body \(i)"
        }
        let src = try makeSourceDir(files)
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let svc = ImportService()
        actor SleepingRouter: ImportRouter {
            func route(_ input: ImportFileInput) async throws -> ImportRoutingResult {
                try await Task.sleep(nanoseconds: 50_000_000)
                return ImportRoutingResult(
                    destination: .referenceLibrary, title: "t", summary: "s",
                    tags: [], entityType: "other", category: nil, confidence: 1.0
                )
            }
        }
        let start = Date()
        let tasks = await svc.importFiles(in: src, into: target, router: SleepingRouter())
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(tasks.count, 10)
        XCTAssertEqual(tasks.filter { $0.state == .done }.count, 10)
        XCTAssertLessThan(elapsed, 0.4, "10 files at 4-way parallel should be under 400 ms (observed: \(elapsed))")
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Edge case: CJK filenames

    func testImportFiles_handlesCJKFilenames() async throws {
        let body = "唐诗内容"
        let src = try makeSourceDir([
            "世界观.md": body,
            "角色.md": body,
            "草稿.md": body
        ])
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let svc = ImportService()
        var canned: [String: ImportRoutingResult] = [:]
        for rel in ["世界观.md", "角色.md", "草稿.md"] {
            canned[rel] = ImportRoutingResult(
                destination: .bookFolder(.world),
                title: "t-\(rel)", summary: "s", tags: [],
                entityType: "other", category: nil, confidence: 1.0
            )
        }
        let tasks = await svc.importFiles(in: src, into: target, router: StubImportRouter(canned))
        XCTAssertEqual(tasks.count, 3)
        let names = Set(tasks.map { ($0.sourcePath as NSString).lastPathComponent })
        XCTAssertEqual(names, Set(["世界观.md", "角色.md", "草稿.md"]))
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Crypto helper

    func testSha256_isStableAcrossRuns() {
        let a = ImportService.sha256("hello world")
        let b = ImportService.sha256("hello world")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, ImportService.sha256("hello world!"))
    }
}
