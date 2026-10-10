//
//  ImportEnvelopeTests.swift
//
//  Round-trip tests for the v2.7 markdown import wire
//  shapes. T1 of the import feature ticket set; = see
//  .scratch/2026-10-09-md-import-feature/tickets.md.
//

import XCTest
@testable import WenshuApp

final class ImportEnvelopeTests: XCTestCase {

    // MARK: - BookFolder (the SSOT for "5 standard folders")

    func testBookFolder_hasEightCases() throws {
        // v2.7 round-60: the enum
        // now has 9 cases
        // (= the boss's
        // "看样需要加一
        // 个目录，放你
        // 现在的草稿
        // ，类似构思"
        // directive added
        // `ideas` after
        // `drafts`; = the
        // first 5 are still
        // the sidebar-
        // visible standard
        // folders; = the
        // remaining 4 are
        // non-sidebar: ideas
        // / sessions /
        // foreshadowing /
        // placeholders).
        // The first 5 (= user
        // visible) stay
        // world / characters
        // / outlines /
        // chapters / drafts
        // (= the boss's
        // established
        // sidebar UX). The
        // 6th case is
        // `ideas` (= the
        // 构思 folder for
        // "loose settings +
        // future ideas";
        // = a separate
        // import folder
        // per the round-60
        // directive).
        XCTAssertEqual(BookFolder.allCases.count, 9)
    }

    func testBookFolder_firstFiveAreUserVisible() throws {
        // The first 5 cases are the sidebar-visible standard
        // folders (= matches `LibraryBootstrapper` seed order
        // + the legacy NewLibraryOutlineView's folder catalog).
        let firstFive = Array(BookFolder.allCases.prefix(5))
        XCTAssertEqual(firstFive.map(\.rawValue), [
            "world", "characters", "outlines", "chapters", "drafts"
        ])
    }

    func testBookFolder_directoryNameMatchesRawValue() throws {
        // SSOT assertion: the on-disk directory name equals the
        // raw value for the 5 sidebar-visible cases (= the
        // folder catalog carries the canonical mapping for
        // the 3 hidden cases = sessions / foreshadowing /
        // placeholders).
        for folder in BookFolder.allCases.prefix(5) {
            XCTAssertEqual(folder.directoryName, folder.rawValue)
        }
    }

    // MARK: - ImportFileInput round-trip

    func testImportFileInput_jsonRoundTrip() throws {
        let original = ImportFileInput(
            filePath: "/Users/me/Library/Mobile Documents/iCloud~md~obsidian/Documents/十二地仙/世界观.md",
            targetBookId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            targetShelfId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            rewriteMode: .searchAndRewrite
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImportFileInput.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testImportFileInput_sendableConformance() throws {
        // Sendable conformance is compile-time (= the test
        // exists to fail the build if a future change
        // breaks it; = the function body is intentionally
        // empty).
        let input: any Sendable = ImportFileInput(
            filePath: "/tmp/x.md",
            targetBookId: UUID(),
            targetShelfId: UUID(),
            rewriteMode: .consolidate
        )
        _ = input
    }

    // MARK: - ImportRoutingResult round-trip

    func testImportRoutingResult_bookFolderRoundTrip() throws {
        let original = ImportRoutingResult(
            destination: .bookFolder(.world),
            title: "Eryndor kingdom overview",
            summary: "The kingdom of Eryndor lies...",
            tags: ["setting", "fantasy"],
            entityType: "location",
            category: nil,
            confidence: 0.92,
            rewrittenBody: nil,
            extraFiles: [],
            needsFilling: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImportRoutingResult.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testImportRoutingResult_referenceLibraryRoundTrip() throws {
        let original = ImportRoutingResult(
            destination: .referenceLibrary,
            title: "唐代边塞诗",
            summary: "Notes on Tang dynasty border poetry",
            tags: ["唐诗", "边塞"],
            entityType: "concept",
            category: "I",
            confidence: 0.85,
            rewrittenBody: nil,
            extraFiles: [],
            needsFilling: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImportRoutingResult.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testImportRoutingResult_allFiveBookFoldersRoundTrip() throws {
        // Each of the 5 sidebar-visible book-folder cases
        // must round-trip cleanly (= the LLM routes to any
        // of the 5; = the wire shape must accept all 5).
        for folder in BookFolder.allCases.prefix(5) {
            let original = ImportRoutingResult(
                destination: .bookFolder(folder),
                title: "test-\(folder.rawValue)",
                summary: "summary",
                tags: [],
                entityType: "other",
                category: nil,
                confidence: 1.0,
                rewrittenBody: nil,
                extraFiles: [],
            needsFilling: false
            )
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(ImportRoutingResult.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }

    // MARK: - ImportEnvelope round-trip

    func testImportEnvelope_importFileRoundTrip() throws {
        let original = ImportEnvelope.importFile(ImportFileInput(
            filePath: "/tmp/世界观.md",
            targetBookId: UUID(),
            targetShelfId: UUID(),
            rewriteMode: .consolidate
        ))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImportEnvelope.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testImportEnvelope_decodeUnknownKindThrows() throws {
        // Defensive: a future envelope case (= e.g. .importFolder)
        // is added with a new Kind raw value; = the existing
        // decoder (= which only knows .importFile today) must
        // throw (= the Apple canonical pattern = fail loud at
        // the wire boundary rather than silently mis-decoding).
        let json = """
        {"kind":"unknownKind","filePath":"/tmp/x.md","targetBookId":"00000000-0000-0000-0000-000000000001","targetShelfId":"00000000-0000-0000-0000-000000000002"}
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ImportEnvelope.self, from: data))
    }
}
