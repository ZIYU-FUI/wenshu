//
//  ImportDocumentTemplatesTests.swift
//
//  v2.7 round-59. Verifies the 5
//  import document templates (=
//  world / characters / outlines
//  / chapters / drafts) have
//  the canonical structure:
//  1. Each template has a
//     commonHeader (= 3 mandatory
//     metadata rows: 实体类型 /
//     标签 / 摘要).
//  2. Each template has at
//     least 4 mandatory section
//     headings (= ## headings
//     in the body; = the LLM
//     has a fixed shape to fill).
//  3. Each template contains
//     at least one `[TODO: ...]`
//     placeholder (= the LLM's
//     "missing field" marker).
//  4. The BookFolder.importTemplate
//     helper returns the right
//     template for the 5 import
//     folders and nil for the 3
//     non-import folders.
//

import XCTest
@testable import WenshuApp

final class ImportDocumentTemplatesTests: XCTestCase {

    /// The 6 import folders
    /// (= world / characters /
    /// outlines / chapters /
    /// drafts / ideas) each
    /// map to a template
    /// (= the templates are
    /// the canonical import
    /// surface). The boss
    /// 2026-10-10 round-60
    /// added `ideas` (= 构思)
    /// as a 6th import folder
    /// for "loose settings +
    /// future ideas".
    func test_allFiveFoldersHaveTemplate() {
        let importFolders: [BookFolder] = [.world, .characters, .outlines, .chapters, .drafts, .ideas]
        for folder in importFolders {
            XCTAssertNotNil(
                folder.importTemplate,
                "\(folder.rawValue) must have an import template"
            )
        }
    }

    /// The 3 non-import folders
    /// (= sessions / foreshadowing
    /// / placeholders) have no
    /// import template (= they're
    /// internal; = the import
    /// path doesn't surface them).
    func test_nonImportFoldersReturnNil() {
        let nonImportFolders: [BookFolder] = [.sessions, .foreshadowing, .placeholders]
        for folder in nonImportFolders {
            XCTAssertNil(
                folder.importTemplate,
                "\(folder.rawValue) must not have an import template"
            )
        }
    }

    /// v2.7 round-60: drafts and
    /// chapters templates are
    /// structurally identical
    /// (= the boss's "drafts/
    /// 草稿和正文模版一
    /// 致" directive; = the
    /// only difference is the
    /// 字数目标 line: drafts
    /// = "状态：草稿",
    /// chapters = "状态：定
    /// 稿"; = the user can
    /// move a file from
    /// drafts/ to chapters/
    /// without rewriting; =
    /// the file is already
    /// in the right shape).
    /// We compare the section
    /// heading sequence (split
    /// on "## ") and assert
    /// they're equal modulo
    /// the status line.
    func test_draftsAndChaptersTemplatesAreStructurallyIdentical() {
        let chaptersSections = ImportDocumentTemplate.chapters.skeleton
            .components(separatedBy: "## ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let draftsSections = ImportDocumentTemplate.drafts.skeleton
            .components(separatedBy: "## ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // The drafts/chapters
        // share the same
        // ## headings; the
        // 字数目标 line is
        // the only diff
        // (= "状态：草稿"
        // vs "状态：定稿");
        // = strip BOTH status
        // values before
        // comparison (= 草
        // 稿 = 定稿; = they
        // represent the
        // same field at
        // different points
        // in the
        // chapter's
        // lifecycle).
        let normalize: (String) -> String = { section in
            section.replacingOccurrences(of: "状态：草稿", with: "")
                     .replacingOccurrences(of: "状态：定稿", with: "")
                     // Strip the "/ <status>" suffix
                     // (= the word "草稿"
                     // or "定稿" alone, with
                     // any leading space and
                     // slash). The drafts
                     // skeleton has " /
                     // 状态：草稿"; the
                     // chapters skeleton
                     // has " / 状态：定稿";
                     // after the previous
                     // "状态：xxx" replace,
                     // a leading space +
                     // "草稿" or "定稿"
                     // may remain.
                     .replacingOccurrences(of: " / 草稿", with: "")
                     .replacingOccurrences(of: " / 定稿", with: "")
                     .replacingOccurrences(of: "草稿", with: "")
                     .replacingOccurrences(of: "定稿", with: "")
                     // Collapse multiple
                     // spaces + newlines.
                     .replacingOccurrences(
                        of: "  ",
                        with: " "
                     )
                     .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        XCTAssertEqual(
            chaptersSections.map(normalize),
            draftsSections.map(normalize),
            "drafts and chapters must have identical section structure"
        )
    }

    /// v2.7 round-60: ideas
    /// template exists and is
    /// distinct from drafts
    /// (= ideas = "things that
    /// might become X later";
    /// = drafts = "this IS a
    /// chapter but not
    /// finalized"; = the
    /// product rule "新文
    /// 件夹构思，是
    /// 一些零散的设
    /// 定，和未来
    /// 的一些想法
    /// ，不是草稿").
    func test_ideasTemplateIsDistinct() {
        let ideasBody = ImportDocumentTemplate.ideas.skeleton
        // Must contain 灵感来源
        // (= where the idea came
        // from) and 可能成为
        // (= what it might become)
        // = the two key
        // differentiators.
        XCTAssertTrue(ideasBody.contains("灵感来源"), "ideas missing 灵感来源")
        XCTAssertTrue(ideasBody.contains("可能成为"), "ideas missing 可能成为")
        // Must NOT contain the
        // chapter-only "章节
        // 目标" heading (= the
        // idea is not yet a
        // chapter; = a chapter
        // body would be
        // premature).
        XCTAssertFalse(ideasBody.contains("章节目标"), "ideas should not have 章节目标")
    }

    /// Every template contains the
    /// commonHeader (= 3 必填
    /// metadata rows: 实体类型
    /// / 标签 / 摘要; = the
    /// wenshu signature that
    /// makes the document
    /// recognizable as
    /// wenshu-generated).
    func test_everyTemplateHasCommonHeader() {
        for template in ImportDocumentTemplate.allCases {
            let body = template.skeleton
            XCTAssertTrue(
                body.contains("实体类型"),
                "\(template.rawValue) missing 实体类型 in header"
            )
            XCTAssertTrue(
                body.contains("标签"),
                "\(template.rawValue) missing 标签 in header"
            )
            XCTAssertTrue(
                body.contains("摘要"),
                "\(template.rawValue) missing 摘要 in header"
            )
        }
    }

    /// Every template has at
    /// least 4 mandatory
    /// section headings (= the
    /// LLM has a fixed shape
    /// to fill; = the
    /// structure is the
    /// wenshu "signature").
    func test_everyTemplateHasEnoughHeadings() {
        for template in ImportDocumentTemplate.allCases {
            let headingCount = template.skeleton.components(separatedBy: "## ").count - 1
            XCTAssertGreaterThanOrEqual(
                headingCount, 4,
                "\(template.rawValue) has only \(headingCount) ## headings (= expected >= 4)"
            )
        }
    }

    /// Every template contains
    /// at least one `[TODO: ...]`
    /// placeholder (= the LLM's
    /// "missing field" marker;
    /// = the user can search for
    /// `TODO` to find gaps in
    /// their worldbuilding).
    func test_everyTemplateHasTODOPlaceholder() {
        for template in ImportDocumentTemplate.allCases {
            XCTAssertTrue(
                template.skeleton.contains("[TODO:"),
                "\(template.rawValue) missing [TODO: ...] placeholder"
            )
        }
    }

    /// The character template
    /// specifically covers the
    /// 5 core character-profile
    /// elements (= Jerry Jenkins
    /// / Reddit r/writing best
    /// practice): 基本信息 /
    /// 外在形象 / 内在性格 /
    /// 动机与目标 / 角色弧线.
    /// (= the boss's
    /// "一个角色定义应
    /// 该具备什么"
    /// research-driven
    /// requirement).
    func test_characterTemplateCoversCoreProfileElements() {
        let body = ImportDocumentTemplate.characters.skeleton
        XCTAssertTrue(body.contains("基本信息"), "characters missing 基本信息")
        XCTAssertTrue(body.contains("外在形象"), "characters missing 外在形象")
        XCTAssertTrue(body.contains("内在性格"), "characters missing 内在性格")
        XCTAssertTrue(body.contains("动机"), "characters missing 动机")
        XCTAssertTrue(body.contains("角色弧线"), "characters missing 角色弧线")
    }
}
