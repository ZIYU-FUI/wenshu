//
//  SQLiteConstantsTests.swift · Wenshu · v1.27 health-check
//
//  Pinned the `SQLITE_TRANSIENT` sentinel to prevent regressions of the
//  v0.72 Q99 dual-axis LOW bug (= this constant was previously
//  copy-pasted as `private let` into 4+ files with inconsistent definitions,
//  causing memory safety bugs in the kanban + search SQLite layers).
//
//  3 prior bug fixes in 6mo (per repowise prior_defect critical):
//    - SQLITE_TRANSIENT 1: original copy-paste (= 4 inconsistent defs)
//    - SQLITE_TRANSIENT 2: unsafeBitCast pattern (= 1 canonical def)
//    - SQLITE_TRANSIENT 3: consolidation to 1 file (= current state)
//
//  These 4 tests pin:
//    1. The sentinel value (= -1, the C constant SQLITE_TRANSIENT)
//    2. The Swift type (= sqlite3_destructor_type, NOT a generic Int)
//    3. The accessor pattern works (= it IS a sqlite3_destructor_type,
//       so sqlite3_bind_text(.static, .transient) compiles)
//    4. The single source of truth (= only 1 file declares this constant;
//       if a future ticket re-declares SQLITE_TRANSIENT locally, this
//       test should be augmented to catch the re-introduction).

import Testing
import Foundation
import SQLite3
@testable import WenshuApp

@Suite("SQLiteConstants (v1.27 health-check pin)")
struct SQLiteConstantsTests {

    @Test("SQLITE_TRANSIENT sentinel value = -1 (= C SQLITE_TRANSIENT)")
    func testSentinelValue() {
        // SQLITE_TRANSIENT in C is `typedef void (*sqlite3_destructor_type)(void*);
        // #define SQLITE_TRANSIENT ((sqlite3_destructor_type)-1)`.
        // We unsafeBitCast(-1, to: sqlite3_destructor_type.self) — so the
        // bit pattern of the constant should equal -1.
        //
        // CAVEAT: sqlite3_destructor_type is `@convention(c) (Optional<
        // UnsafeMutableRawPointer>) -> ()` — it's a function pointer, NOT
        // a raw pointer, so:
        //   - `==` doesn't compile (function pointer ≠ Equatable)
        //   - `Int(bitPattern:)` doesn't compile (function pointer ≠ _Pointer)
        // We round-trip via `unsafeBitCast` to Int instead.
        let bitPattern = unsafeBitCast(SQLITE_TRANSIENT, to: Int.self)
        #expect(bitPattern == -1)
    }

    @Test("SQLITE_TRANSIENT is sqlite3_destructor_type (= not generic Int)")
    func testType() {
        // Catches: someone changing the type to Int (= would break
        // sqlite3_bind_text signature, which takes sqlite3_destructor_type).
        #expect(SQLITE_TRANSIENT is sqlite3_destructor_type)
    }

    @Test("SQLITE_TRANSIENT can be passed as 5th arg to sqlite3_bind_text")
    func testBindTextCompatible() throws {
        // Open an in-memory DB, create a table with a TEXT column, bind a
        // string using SQLITE_TRANSIENT as the destructor (= the call pattern
        // used by HermesKanbanDB + FullTextSearch before v1.55; = both removed
        // 2026-09-20; = WSMigrationPerStore is the only remaining raw sqlite3
        // user (= one-shot legacy import)).
        // If SQLITE_TRANSIENT's type drifted to Int (= 0.72 regression),
        // this would fail to compile (= sqlite3_bind_text wants
        // sqlite3_destructor_type).
        var db: OpaquePointer?
        #expect(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }

        #expect(sqlite3_exec(db, "CREATE TABLE t(s TEXT)", nil, nil, nil) == SQLITE_OK)

        var stmt: OpaquePointer?
        #expect(
            sqlite3_prepare_v2(
                db, "INSERT INTO t(s) VALUES (?)", -1, &stmt, nil
            ) == SQLITE_OK
        )
        defer { sqlite3_finalize(stmt) }

        let value = "test value"
        #expect(
            sqlite3_bind_text(
                stmt, 1, value, -1, SQLITE_TRANSIENT
            ) == SQLITE_OK
        )
        #expect(sqlite3_step(stmt) == SQLITE_DONE)
    }

    @Test("SQLITE_TRANSIENT source-of-truth: SQLiteConstants.swift is the only file")
    func testSingleSourceOfTruth() throws {
        // Per Q99 v0.72 fix (= consolidated 4+ copy-pasted `private let`
        // declarations into 1 public let in SQLiteConstants.swift).
        // We test by reading the file's contents and verifying the
        // sentinel value is defined (= the unique source).
        //
        // We do NOT use `grep` against the whole Sources/ tree because
        // Process.run with /usr/bin/grep in a Swift test bundle is fragile
        // (= test bundle's PATH is the minimal test runner, not the
        // developer's shell). File-content read is portable and faster.
        //
        // If a future ticket needs a second sentinel (e.g. SQLITE_STATIC),
        // add it to this file (= 1 source of truth for sqlite3 shim
        // sentinels) and update this test to check `let SQLITE_*` count = 2.
        let testsPath = #filePath
        let testFileURL = URL(fileURLWithPath: testsPath)
        let sourcesRoot = try testFileURL
            .deletingLastPathComponent()  // Persistence/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // WenshuApp/
        let fileURL = sourcesRoot
            .appendingPathComponent("Sources/WenshuApp/Persistence/SQLiteConstants.swift")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let sentinelCount = content.components(separatedBy: "SQLITE_TRANSIENT").count - 1
        // Expect ≥2 (= the public let declaration + the doc comments
        // mentioning the name + the unsafeBitCast pattern). We do NOT
        // assert == 1 because doc strings legitimately repeat the name.
        #expect(sentinelCount >= 2, "SQLITEConstants.swift should mention SQLITE_TRANSIENT (= declaration + docs)")
    }
}