//
//  StripBacklinksAndVersionTests.swift
//
//  Round-67 boss 2026-10-10 "强制去反链, 还有强制去版本记录,
//  这两条规则也要求一下" feedback.
//
//  Tests `ImportDocumentTemplate.stripUselessLines`:
//   - mid-paragraph `[[xxx]]` removal (= the
//     previous whole-line-only filter missed
//     "见 [[02-朝代]]" style lines; = the new
//     inline strip catches them)
//   - `![[xxx]]` image-embed removal
//   - version record line detection (= Chinese
//     and English prefixes)
//   - non-prefix false-positive check (= "日期:
//     2026 春节" should NOT be stripped;
//     = "日期" is not in the no-list)
//
//  Combined with the LLM-prompt-side rule in
//  WenshuConductorImportRouter.rewriteModeBlock.reorganize
//  (= the "双机制" boss requested 2026-10-10; = rule-level
//  + LLM-level strip; = same pattern as round-66
//  dedup).
//

import XCTest
@testable import WenshuApp

final class StripBacklinksAndVersionTests: XCTestCase {

    // MARK: - 强制去反链 (inline)

    func test_stripUselessLines_midParagraphBacklink_inline() throws {
        // Arrange: backlink appears mid-paragraph (= not
        // a whole-line; = the previous whole-line
        // filter missed this; = the new inline
        // strip catches it).
        let input = "见 [[02-朝代]] 这边"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert: backlink removed, surrounding
        // text kept, double-space collapsed.
        XCTAssertFalse(
            output.contains("[[02-朝代]]"),
            "inline backlink should be stripped"
        )
        XCTAssertTrue(
            output.contains("见") && output.contains("这边"),
            "surrounding text should be kept"
        )
    }

    func test_stripUselessLines_imageEmbed_inline() throws {
        // Arrange: `![[图片.png]]` (= Obsidian image
        // embed syntax; = the leading `!` distinguishes
        // from regular backlinks).
        let input = "下面是插图: ![[图片.png]] 看上面"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert: image embed removed, surrounding
        // text kept.
        XCTAssertFalse(
            output.contains("![[图片.png]]"),
            "image embed should be stripped"
        )
        XCTAssertTrue(output.contains("下面是插图"))
        XCTAssertTrue(output.contains("看上面"))
    }

    func test_stripUselessLines_multipleBacklinksOnOneLine() throws {
        // Arrange: 2 backlinks on one line.
        let input = "故事 A [[实体1]] 加上 B [[实体2]] 描述"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert: both backlinks removed.
        XCTAssertFalse(output.contains("[[实体1]]"))
        XCTAssertFalse(output.contains("[[实体2]]"))
        XCTAssertTrue(output.contains("故事 A"))
        XCTAssertTrue(output.contains("描述"))
    }

    func test_stripUselessLines_wholeLineBacklink_stillWorks() throws {
        // Arrange: whole-line backlink (= the
        // previous filter caught this; = the
        // new code should still drop the
        // whole line).
        let input = "[[孤立的反链]]"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert: the line is dropped (= only
        // an empty string or original body
        // remains; = no "[[ ]]" content).
        XCTAssertFalse(
            output.contains("[[孤立的反链]]"),
            "whole-line backlink should still be dropped"
        )
    }

    func test_stripUselessLines_textWithoutBacklinks_unchanged() throws {
        // Arrange: regular body text with no
        // backlinks; = the strip should be a
        // no-op.
        let input = "这是普通正文\n第二行也是\n第三行"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert: text preserved.
        XCTAssertEqual(
            output, input,
            "regular text without backlinks should be unchanged"
        )
    }

    // MARK: - 强制去版本记录

    func test_stripUselessLines_chineseVersionPrefix_dropped() throws {
        // Arrange: version record line.
        let input = "上次更新: 2026-10-10\n\n正文内容"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert: version line dropped; = body
        // text kept.
        XCTAssertFalse(
            output.contains("上次更新"),
            "chinese version record should be dropped"
        )
        XCTAssertTrue(
            output.contains("正文内容"),
            "body text should be kept"
        )
    }

    func test_stripUselessLines_englishVersionPrefix_dropped() throws {
        // Arrange: English version record line.
        let input = "Created: 2026-10-10\n\nBody content"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert.
        XCTAssertFalse(output.contains("Created"))
        XCTAssertTrue(output.contains("Body content"))
    }

    func test_stripUselessLines_modifyRecord_dropped() throws {
        // Arrange: "修改记录: v1 / v2 / v3".
        let input = "修改记录: v1 / v2 / v3\n\n正文"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert.
        XCTAssertFalse(output.contains("修改记录"))
        XCTAssertTrue(output.contains("正文"))
    }

    func test_stripUselessLines_versionNumber_dropped() throws {
        // Arrange: "版本: 0.5" (= a version number line).
        let input = "版本: 0.5\n\n正文"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert.
        XCTAssertFalse(output.contains("版本"))
        XCTAssertTrue(output.contains("正文"))
    }

    func test_stripUselessLines_date_keptNotStripped() throws {
        // Arrange: "日期: 2026 春节" (= NOT in the
        // no-list; = the label "日期" doesn't match
        // any of our version prefixes; = the line
        // should NOT be stripped). This guards
        // against false-positives.
        let input = "日期: 2026 春节\n\n正文"
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert: "日期" line kept.
        XCTAssertTrue(
            output.contains("日期"),
            "\"日期\" is NOT in the no-list; = the line should be kept"
        )
    }

    func test_stripUselessLines_combinedBacklinkAndVersion() throws {
        // Arrange: real-world 故事宪法-style body
        // (= has both Obsidian backlinks and
        // version record lines).
        let input = """
        上次更新: 2026-10-10
        修改记录: v1 / v2 / v3

        # 故事宪法

        这是世界观描述。[[01-基础设定]] 这里补充。

        ## 核心设定

        Created: 2026-01-01
        一些核心内容
        """
        // Act.
        let output = ImportDocumentTemplate.stripUselessLines(input)
        // Assert: all version + backlink noise
        // stripped; = body content kept.
        XCTAssertFalse(output.contains("上次更新"))
        XCTAssertFalse(output.contains("修改记录"))
        XCTAssertFalse(output.contains("[[01-基础设定]]"))
        XCTAssertFalse(output.contains("Created:"))
        XCTAssertTrue(output.contains("故事宪法"))
        XCTAssertTrue(output.contains("核心设定"))
        XCTAssertTrue(output.contains("一些核心内容"))
    }
}
