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

    /// The 5 import folders
    /// (= world / characters /
    /// outlines / chapters /
    /// drafts) each map to a
    /// template (= the 5 templates
    /// are the canonical import
    /// surface).
    func test_allFiveFoldersHaveTemplate() {
        let importFolders: [BookFolder] = [.world, .characters, .outlines, .chapters, .drafts]
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
