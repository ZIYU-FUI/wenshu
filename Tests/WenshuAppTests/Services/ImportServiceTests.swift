//
//  ImportServiceTests.swift
//
//  T2 of the v2.7 markdown import feature. Tests the
//  orchestrator (= the 4-phase walk → dedup → route →
//  write pipeline) against a temp directory + a stub
//  ImportRouter.
//
//  Apple canonical pattern: the tests inject a
//  `StubImportRouter` that returns canned
//  `ImportRoutingResult` values per file (= no LLM
//  in the test path; = the tests are deterministic; =
//  same pattern the existing e2e ObsidianVaultBatchImportTests
//  uses for the agent stub).
//

import XCTest
@testable import WenshuApp

@MainActor
final class ImportServiceTests: XCTestCase {

    // MARK: - Test fixtures

    /// A stub router that returns canned routing results
    /// keyed by the source file's BASENAME (= the test
    /// sets the canned dict with a basename key like
    /// "世界观.md"; = the stub matches by basename to
    /// avoid path-encoding fragility on macOS = the
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
            // Default routing: every file lands in
            // the reference library (= the tests
            // can override per-file with `canned`).
            return ImportRoutingResult(
                destination: .referenceLibrary,
                title: "stub",
                summary: "stub summary",
                tags: ["stub"],
                entityType: "other",
                category: nil,
                confidence: 1.0
            )
        }
    }

    /// Build a temp directory with the given file map
    /// (= `[relativePath: body]`).
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

    /// Build a temp wsRoot with the standard 5-folder
    /// layout (= the test target book lives in
    /// `<wsRoot>/shelves/<shelfId>/books/<bookId>/`).
    private func makeWsRoot() throws -> (URL, UUID, UUID) {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-wsroot-\(UUID().uuidString)")
        let shelvesRoot = wsRoot.appendingPathComponent("shelves")
        let shelfId = UUID()
        let bookId = UUID()
        let bookDir = shelvesRoot
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
        for folder in ["world", "characters", "outlines", "chapters", "drafts"] {
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent(folder),
                withIntermediateDirectories: true
            )
        }
        // Reference library root.
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
            "sub1/d.txt": "should be skipped"  // non-.md
        ])
        let (_, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: URL(fileURLWithPath: "/private" + src.path).deletingLastPathComponent()
            .appendingPathComponent("wenshu-wsroot-anchor"))
        let target = makeTarget(wsRoot: URL(fileURLWithPath: "/private/tmp"), shelfId: shelfId, bookId: bookId, store: store)
        let svc = ImportService()
        // Override the router to throw (= the test asserts
        // that all .md files were found, = 3 files).
        struct ThrowRouter: ImportRouter {
            func route(_ input: ImportFileInput) async throws -> ImportRoutingResult {
                throw NSError(domain: "test", code: 1)
            }
        }
        let tasks = await svc.importFiles(in: src, into: target, router: ThrowRouter())
        XCTAssertEqual(tasks.count, 3, "should walk 3 .md files recursively (= skip d.txt)")
        let names = Set(tasks.map { ($0.sourcePath as NSString).lastPathComponent })
        XCTAssertEqual(names, Set(["a.md", "b.md", "c.md"]))
        // Cleanup.
        try? FileManager.default.removeItem(at: src)
    }

    // MARK: - Phase 4: write (= book-folder path)

    func testImportFiles_writesBookFolderBodyVerbatim() async throws {
        let body = "The kingdom of Eryndor lies...\n\n  -- chapter 1"
        let src = try makeSourceDir(["世界观.md": body])
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let shelvesRoot = wsRoot.appendingPathComponent("shelves")
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let cache = wsRoot.appendingPathComponent(".import-cache")
        let svc = ImportService()

        let canned: [String: ImportRoutingResult] = [
            "世界观.md": ImportRoutingResult(
                destination: .bookFolder(.world),
                title: "Eryndor kingdom",
                summary: "stub",
                tags: [],
                entityType: "other",
                category: nil,
                confidence: 1.0
            )
        ]
        let tasks = await svc.importFiles(in: src, into: target, router: StubImportRouter(canned))

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].state, .done)
        XCTAssertEqual(tasks[0].destination, .bookFolder(.world))
        // The body lands verbatim (= byte-equal to the
        // source) at the standard 5-folder path.
        let expectedURL = shelvesRoot
            .appendingPathComponent(shelfId.uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
            .appendingPathComponent("world")
            .appendingPathComponent(ImportService.uuidFromHash(tasks[0].contentHash).uuidString + ".md")
        let written = try String(contentsOf: expectedURL, encoding: .utf8)
        XCTAssertEqual(written, body, "body must be byte-equal to the source")
        // Cleanup.
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Phase 2: dedup

    func testImportFiles_skipsAlreadyImported() async throws {
        let body = "verbatim body"
        let src = try makeSourceDir(["a.md": body])
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let shelvesRoot = wsRoot.appendingPathComponent("shelves")
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let cache = wsRoot.appendingPathComponent(".import-cache")
        let svc = ImportService()
        let canned: [String: ImportRoutingResult] = [
            "a.md": ImportRoutingResult(
                destination: .referenceLibrary,
                title: "t", summary: "s", tags: [], entityType: "other", category: nil, confidence: 1.0
            )
        ]
        // First import: 1 .md, 1 done, 1 file written to reference library.
        let first = await svc.importFiles(in: src, into: target, router: StubImportRouter(canned))
        XCTAssertEqual(first.count, 1)
        if first.isEmpty || first[0].state != .done {
            let failMsg = (first.first?.errorMessage ?? "unknown")
            let stateStr = first.first?.state.rawValue ?? "nil"
            print("DEBUG first: state=\(stateStr) err=\(failMsg)")
            XCTFail("first import failed: " + failMsg)
            return
        }
        // Second import of the same directory: the cache
        // diff sees the body hash matches the prior
        // import; = the LLM is NOT dispatched; = the
        // task is marked .skipped with the prior
        // destination attached.
        let second = await svc.importFiles(in: src, into: target, router: StubImportRouter(canned))
        print("DEBUG second: state=\((second.first?.state.rawValue ?? "nil")) err=\((second.first?.errorMessage ?? "nil")")
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second[0].state, .skipped)
        XCTAssertEqual(second[0].destination, .referenceLibrary)
        // Cleanup.
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Phase 4: write (= reference-library path)

    func testImportFiles_writesReferenceLibrary() async throws {
        let body = "Notes on Tang dynasty border poetry"
        let src = try makeSourceDir(["notes.md": body])
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let shelvesRoot = wsRoot.appendingPathComponent("shelves")
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let cache = wsRoot.appendingPathComponent(".import-cache")
        let svc = ImportService()
        let canned: [String: ImportRoutingResult] = [
            "notes.md": ImportRoutingResult(
                destination: .referenceLibrary,
                title: "唐代边塞诗",
                summary: "Tang border poetry notes",
                tags: ["唐诗", "边塞"],
                entityType: "concept",
                category: "I",
                confidence: 0.85
            )
        ]
        let tasks = await svc.importFiles(in: src, into: target, router: StubImportRouter(canned))
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].state, .done)
        // Cleanup.
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Phase 3: route (= concurrent dispatch)

    func testImportFiles_concurrentDispatch() async throws {
        // 10 .md files, each with a unique body. The stub
        // router's `route` sleeps 50 ms; = 10 files at
        // 4-way parallel = ~150 ms (vs 500 ms serial).
        var files: [String: String] = [:]
        for i in 0..<10 {
            files["file\(i).md"] = "body \(i)"
        }
        let src = try makeSourceDir(files)
        let (wsRoot, shelfId, bookId) = try makeWsRoot()
        let store = makeStore(root: wsRoot.appendingPathComponent("reference-library"))
        let shelvesRoot = wsRoot.appendingPathComponent("shelves")
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let cache = wsRoot.appendingPathComponent(".import-cache")
        let svc = ImportService()
        actor SleepingRouter: ImportRouter {
            func route(_ input: ImportFileInput) async throws -> ImportRoutingResult {
                try await Task.sleep(nanoseconds: 50_000_000)  // 50 ms
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
        // 10 * 50 ms / 4 (maxParallel) = ~125 ms. The
        // serial lower bound would be 500 ms. Assert that
        // the elapsed time is closer to the parallel lower
        // bound than to the serial one (= we got at least
        // some 4-way parallelism).
        XCTAssertLessThan(elapsed, 0.4, "10 files at 4-way parallel should be well under 400 ms (= observed: \(elapsed))")
        // Cleanup.
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
        let shelvesRoot = wsRoot.appendingPathComponent("shelves")
        let target = makeTarget(wsRoot: wsRoot, shelfId: shelfId, bookId: bookId, store: store)
        let cache = wsRoot.appendingPathComponent(".import-cache")
        let svc = ImportService()
        // All 3 route to .bookFolder(.world) (= CJK
        // filenames in the source dir work the same as
        // ASCII names).
        var canned: [String: ImportRoutingResult] = [:]
        for (rel, _) in [
            ("世界观.md", "Eryndor"),
            ("角色.md", "Character"),
            ("草稿.md", "Draft")
        ] {
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
        // Cleanup.
        try? FileManager.default.removeItem(at: src)
        try? FileManager.default.removeItem(at: wsRoot)
    }

    // MARK: - Crypto helper

    func testSha256_isStableAcrossRuns() {
        // The dedup key must be stable (= same body
        // hashes to the same SHA-256 every time; = the
        // idempotent re-import depends on it).
        let a = ImportService.sha256("hello world")
        let b = ImportService.sha256("hello world")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, ImportService.sha256("hello world!"))
    }
}
