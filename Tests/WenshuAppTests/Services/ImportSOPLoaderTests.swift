//
//  ImportSOPLoaderTests.swift · wenshu · round-73 (= boss 2026-10-10)
//
//  Unit tests for the SOP loader. The
//  test covers:
//
//    1. `sopName(for:)` trigger lookup
//    2. `loadRaw(named:)` from a real
//       bundle (= the .md file compiled in
//       via `.process("Resources")`)
//    3. `substitute(...)` placeholder
//       substitution
//
//  The test is intentionally hermetic:
//  no LLM, no actor, no async. Pure
//  synchronous lookup + string ops.
//

import XCTest
@testable import WenshuApp

final class ImportSOPLoaderTests: XCTestCase {

    // MARK: - sopName(for:) lookup

    func testSopNameForWorldReturnsImportWorldPrompt() {
        XCTAssertEqual(
            ImportSOPTrigger.sopName(for: .world),
            "ImportWorldPrompt"
        )
    }

    func testSopNameForOtherFoldersReturnsNil() {
        // Per boss 2026-10-10 "我建议你
        // 导入世界观就单独的一个提示
        // 词文件, 别和导入其他的通
        // 用": only world has a SOP
        // right now.
        XCTAssertNil(ImportSOPTrigger.sopName(for: .characters))
        XCTAssertNil(ImportSOPTrigger.sopName(for: .outlines))
        XCTAssertNil(ImportSOPTrigger.sopName(for: .chapters))
        XCTAssertNil(ImportSOPTrigger.sopName(for: .drafts))
        XCTAssertNil(ImportSOPTrigger.sopName(for: .ideas))
    }

    // MARK: - loadRaw(named:) — needs the real bundle

    func testLoadRawReturnsSOPText() throws {
        // The .md file shipped via
        // `.process("Resources")` in
        // Package.swift should be
        // resolvable from `Bundle.module`.
        // Debug: print the bundle URL.
        let debugBundle = Bundle.module
        NSLog("[test] Bundle.module path = %@", debugBundle.bundlePath)
        for url in debugBundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? [] {
            NSLog("[test] found md at: %@", url.lastPathComponent)
        }
        let loader = ImportSOPLoader(bundle: Bundle.module)
        let text = try loader.loadRaw(named: "ImportWorldPrompt")
        XCTAssertGreaterThan(
            text.count, 100,
            "ImportWorldPrompt.md should be a real SOP (= > 100 chars), not a stub."
        )
        // Sanity-check key SOP content
        // (= the SOP actually tells the
        // agent about 6 必填).
        XCTAssertTrue(text.contains("核心设定"))
        XCTAssertTrue(text.contains("地理或位置"))
        XCTAssertTrue(text.contains("体系或规则"))
        XCTAssertTrue(text.contains("历史脉络"))
        XCTAssertTrue(text.contains("与其他元素的关系"))
        XCTAssertTrue(text.contains("关键场景种子"))
    }

    func testLoadRawMissingFileThrows() {
        let loader = ImportSOPLoader(bundle: Bundle.module)
        XCTAssertThrowsError(
            try loader.loadRaw(named: "ImportDefinitelyDoesNotExist")
        ) { error in
            // The error must be the
            // `fileMissing` case (= not a
            // generic Swift error).
            guard let loaderError = error as? ImportSOPLoader.LoaderError else {
                XCTFail("Expected ImportSOPLoader.LoaderError, got \(error)")
                return
            }
            switch loaderError {
            case .fileMissing:
                break // expected
            default:
                XCTFail("Expected .fileMissing, got \(loaderError)")
            }
        }
    }

    // MARK: - substitute(...) — placeholder replacement

    func testSubstituteReplacesAllPlaceholders() {
        let input = """
        path: {filePath}
        body len: {body}
        book: {bookTitle}
        bookPath: {bookPath}
        date: {today}
        """

        let out = ImportSOPLoader.substitute(
            input,
            filePath: "/tmp/a.md",
            body: "hello world content here",
            bookPath: "/ws/十二地仙",
            bookTitle: "十二地仙"
        )

        XCTAssertTrue(out.contains("/tmp/a.md"))
        XCTAssertTrue(out.contains("hello world content here"))
        XCTAssertTrue(out.contains("/ws/十二地仙"))
        XCTAssertTrue(out.contains("十二地仙"))
        // today should be filled with a
        // non-empty ISO-8601 date string.
        XCTAssertFalse(out.contains("{today}"))
        // None of the original
        // placeholders remain.
        XCTAssertFalse(out.contains("{filePath}"))
        XCTAssertFalse(out.contains("{body}"))
        XCTAssertFalse(out.contains("{bookPath}"))
        XCTAssertFalse(out.contains("{bookTitle}"))
    }

    func testSubstituteLeavesUnknownPlaceholdersIntact() {
        let input = "known: {filePath}, unknown: {mystery}"
        let out = ImportSOPLoader.substitute(
            input,
            filePath: "/tmp/a.md",
            body: "x",
            bookPath: "/ws",
            bookTitle: "T"
        )
        XCTAssertTrue(out.contains("known: /tmp/a.md"))
        XCTAssertTrue(
            out.contains("{mystery}"),
            "Unknown placeholders must be left intact (= caller's bug; = SOP loader does NOT silently drop)."
        )
    }

    func testSubstitutePreservesRealBracesInBodyContent() {
        // Body content may legitimately
        // contain `{...}` (= e.g.
        // template syntax, code, JSON).
        // The loader must replace ONLY the
        // known placeholders; = not the
        // literal `{` characters in the
        // body.
        let body = "JSON snippet: {\"key\": \"value\"}"
        let out = ImportSOPLoader.substitute(
            "{body}",
            filePath: "/x",
            body: body,
            bookPath: "/y",
            bookTitle: "z"
        )
        XCTAssertEqual(out, body)
    }
}