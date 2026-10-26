//
//  ImportEnvelopeTests.swift
//
//  Round-trip tests for the v2.7 markdown import wire
//  shapes. T1 of the import feature ticket set; = see
//  .scratch/2026-10-09-md-import-feature/tickets.md.
//

import XCTest
import Foundation
@testable import WenshuApp

final class ImportEnvelopeTests: XCTestCase {

    // MARK: - BookFolder (the SSOT for the standard book folders)

    func testBookFolder_hasSevenCases() throws {
        // The enum has 7 cases (= the 2026-10-25 residue
        // cleanup dropped `foreshadowing` and `placeholders`,
        // whose storage models and scope entries went with
        // the right-rail feature). The first 5 are the
        // import-path standard folders; = the remaining 2 are
        // non-import: ideas / sessions).
        // The first 5 (= import-path standard folders) stay
        // world / characters / outlines / chapters / drafts
        // (= the boss's established sidebar UX). The 6th case
        // is `ideas` (= the loose-settings folder for "loose
        // settings + future ideas"; = a separate import folder
        // per the round-60 directive).
        XCTAssertEqual(BookFolder.allCases.count, 7)
    }

    func testBookFolder_firstFiveAreUserVisible() throws {
        // The first 5 cases are the standard import folders
        // (= matches `LibraryBootstrapper` seed order
        // + the legacy NewLibraryOutlineView's folder catalog).
        let firstFive = Array(BookFolder.allCases.prefix(5))
        XCTAssertEqual(firstFive.map(\.rawValue), [
            "world", "characters", "outlines", "chapters", "drafts"
        ])
    }

    func testBookFolder_directoryNameMatchesRawValue() throws {
        // SSOT assertion: the on-disk directory name equals the
        // raw value for the 5 standard import cases (= the
        // folder catalog carries the canonical mapping for
        // the 2 hidden cases = ideas / sessions).
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
            )
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(ImportRoutingResult.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }

    // MARK: - ImportEnvelope round-trip

}
