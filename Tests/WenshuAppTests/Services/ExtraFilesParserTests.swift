//
//  ExtraFilesParserTests.swift
//
//  Round-67 ticket 02 tests (= v2.7 round-67).
//  Tests `WenshuConductorImportRouter.parseAndMap` (= public surface)
//  handling of the new `extraFiles` field in the LLM's
//  JSON response (= A's content that doesn't fit B's
//  template; = split out to separate .md files in the
//  same book but a different folder).
//
//  Cases covered:
//   - valid JSON with 3 extraFiles → 3 ExtraFile elements
//     (= folder / title / body fields all parsed)
//   - JSON missing extraFiles key → empty array (backward
//     compat for LLM behavior prior to round-67)
//   - JSON with malformed extraFile element (= missing
//     title) → element dropped, others kept
//   - JSON with 10 extraFiles → only first 5 kept (=
//     orchestrator cap; = LLM-prompt cap is also 5;
//     = 5 is the last-mile safety net)
//   - JSON with unknown folder string → element dropped
//   - JSON with empty body → element dropped
//   - JSON body has \\n escape → unescaped to real newlines
//

import XCTest
@testable import WenshuApp

final class ExtraFilesParserTests: XCTestCase {

    /// Test fixture: a minimal valid LLM JSON response
    /// (= shaped like the real response; = the parser
    /// reads `extraFiles` from this object).
    private func makeRawJSON(
        extraFilesJSON: String
    ) -> String {
        // Wrap the inner extraFiles JSON into a complete
        // ImportDecision JSON (= the parser extracts the
        // first {…} object; = all required top-level
        // fields must be present even if they're dummy
        // values for the test focus).
        return """
        {"title":"测试","summary":"测试摘要","tags":["测试"],"destination":"bookFolder","folder":"world","rewrittenBody":"","extraFiles":\(extraFilesJSON)}
        """
    }

    func test_parseAndMap_extraFiles_3ValidElements_allKept() throws {
        // Arrange: 3 valid extraFiles.
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"祭天","body":"祭天仪式描述"},
          {"folder":"characters","title":"王母娘娘","body":"王母娘娘背景"},
          {"folder":"outlines","title":"故事结构","body":"章节大纲"}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 3 extra files kept, all fields parsed.
        XCTAssertEqual(result.extraFiles.count, 3, "all 3 valid extra files should be kept")
        XCTAssertEqual(result.extraFiles[0].folder, .world)
        XCTAssertEqual(result.extraFiles[0].title, "祭天")
        XCTAssertEqual(result.extraFiles[0].body, "祭天仪式描述")
        XCTAssertEqual(result.extraFiles[1].folder, .characters)
        XCTAssertEqual(result.extraFiles[1].title, "王母娘娘")
        XCTAssertEqual(result.extraFiles[2].folder, .outlines)
    }

    func test_parseAndMap_extraFiles_missingKey_emptyArray() throws {
        // Arrange: JSON without extraFiles key (= pre-round-67
        // LLM behavior; = must be backward compatible).
        let rawJSON = """
        {"title":"测试","summary":"测试摘要","tags":[],"destination":"bookFolder","folder":"world","rewrittenBody":""}
        """
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: extraFiles defaults to empty array.
        XCTAssertTrue(result.extraFiles.isEmpty, "missing extraFiles key should yield empty array")
    }

    func test_parseAndMap_extraFiles_malformedElement_droppedOthersKept() throws {
        // Arrange: 1 valid + 1 element missing title (=
        // malformed; = the parser drops the bad one + keeps
        // the good ones).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"好元素","body":"好内容"},
          {"folder":"world","body":"缺标题"},
          {"folder":"characters","title":"第二个好元素","body":"第二个好内容"}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 2 valid kept, malformed dropped.
        XCTAssertEqual(result.extraFiles.count, 2, "malformed element should be dropped")
        XCTAssertEqual(result.extraFiles[0].title, "好元素")
        XCTAssertEqual(result.extraFiles[1].title, "第二个好元素")
    }

    func test_parseAndMap_extraFiles_10Elements_only5Kept() throws {
        // Arrange: 10 elements (= LLM ignored the
        // prompt's cap of 5; = the orchestrator
        // truncates).
        var elements: [String] = []
        for i in 1...10 {
            elements.append(
                "{\"folder\":\"world\",\"title\":\"文件\(i)\",\"body\":\"内容\(i)\"}"
            )
        }
        let rawJSON = makeRawJSON(extraFilesJSON: "[\(elements.joined(separator: ","))]")
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 5 elements (= the cap).
        XCTAssertEqual(result.extraFiles.count, 5, "cap at 5; = LLM beyond cap gets truncated")
    }

    func test_parseAndMap_extraFiles_unknownFolder_elementDropped() throws {
        // Arrange: 1 valid + 1 with folder = "invalidFolder"
        // (= LLM invented a value; = parser drops it).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"好元素","body":"好内容"},
          {"folder":"invalidFolder","title":"坏元素","body":"坏内容"}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 1 valid kept, unknown folder dropped.
        XCTAssertEqual(result.extraFiles.count, 1)
        XCTAssertEqual(result.extraFiles[0].title, "好元素")
    }

    func test_parseAndMap_extraFiles_emptyBody_elementDropped() throws {
        // Arrange: 1 valid + 1 with empty body (= no
        // point in writing a blank .md).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"好元素","body":"好内容"},
          {"folder":"world","title":"空元素","body":""}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 1 valid kept, empty body dropped.
        XCTAssertEqual(result.extraFiles.count, 1)
        XCTAssertEqual(result.extraFiles[0].title, "好元素")
    }

    func test_parseAndMap_extraFiles_escapedNewlines_unescapedToReal() throws {
        // Arrange: body has \\n escape (= LLM was told
        // to use JSON escape; = parser un-escapes to
        // real newlines).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [{"folder":"world","title":"多行","body":"第一行\\n第二行\\n第三行"}]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: body has real newlines.
        XCTAssertEqual(result.extraFiles.count, 1)
        XCTAssertEqual(
            result.extraFiles[0].body,
            "第一行\n第二行\n第三行",
            "JSON \\\\n should be un-escaped to real newlines"
        )
    }

    func test_parseAndMap_extraFiles_allSixBookFolders_supported() throws {
        // Arrange: 1 element per BookFolder case (= all
        // 6 importTemplate-bearing folders).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"a","body":"1"},
          {"folder":"characters","title":"b","body":"2"},
          {"folder":"outlines","title":"c","body":"3"},
          {"folder":"chapters","title":"d","body":"4"},
          {"folder":"drafts","title":"e","body":"5"},
          {"folder":"ideas","title":"f","body":"6"}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: all 6 BookFolder cases parse (= even
        // though they exceed the cap of 5; = first 5
        // kept; = the 6th dropped).
        XCTAssertEqual(result.extraFiles.count, 5, "cap at 5; = 6th dropped")
        // Verify each of the first 5 maps to the right
        // BookFolder (= comprehensive folder coverage).
        XCTAssertEqual(result.extraFiles[0].folder, .world)
        XCTAssertEqual(result.extraFiles[1].folder, .characters)
        XCTAssertEqual(result.extraFiles[2].folder, .outlines)
        XCTAssertEqual(result.extraFiles[3].folder, .chapters)
        XCTAssertEqual(result.extraFiles[4].folder, .drafts)
    }
}
