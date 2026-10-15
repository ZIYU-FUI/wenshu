//
//  WorldSubSectionSplitTests.swift
//
//  Round-69 tests (= boss 2026-10-10 OOB "6 份必填,
//  其它不在 6 份里的, 可以自定义名字" + "不要备注
//  标题的文档. 其它不在六份里的, 可以单独写文档,
//  约等于备注").
//
//  Tests `WenshuConductorImportRouter.parseAndMap` (= the
//  public LLM-response parser) handling of the new
//  round-69 `required: Bool` field in extraFiles:
//   - 6 必填 elements are kept (= they have `required =
//     true`)
//   - N 自定义 elements are kept (= they have `required
//     = false`)
//   - cap = 6 required + 5 custom = 11 total
//   - boss banned "备注" as a title (= old wenshu 7th
//     H2; = dropped)
//   - the cap prioritizes required over custom (= if
//     LLM returns 11+ elements, we keep the first 6
//     required + up to 5 custom)
//
//  Round-69 also tests `WorldSubSection` enum (= the
//  6 mandatory world/ sub-section names = 核心设定 /
//  地理或位置 / 体系或规则 / 历史脉络 / 与其他元素的
//  关系 / 关键场景种子). The enum's `filename` matches
//  the H2 title verbatim (= boss mandated "标题就是
//  这 6 份的标题").
//

import XCTest
@testable import WenshuApp

final class WorldSubSectionSplitTests: XCTestCase {

    // MARK: - WorldSubSection enum

    func test_WorldSubSection_6Cases_matchH2Titles() throws {
        // Assert: the 6 enum rawValues match the
        // boss-mandated H2 titles verbatim
        // (= "标题就是这 6 份的标题").
        XCTAssertEqual(WorldSubSection.core.rawValue, "核心设定")
        XCTAssertEqual(WorldSubSection.geography.rawValue, "地理或位置")
        XCTAssertEqual(WorldSubSection.system.rawValue, "体系或规则")
        XCTAssertEqual(WorldSubSection.history.rawValue, "历史脉络")
        XCTAssertEqual(WorldSubSection.relations.rawValue, "与其他元素的关系")
        XCTAssertEqual(WorldSubSection.scenes.rawValue, "关键场景种子")
    }

    func test_WorldSubSection_filename_equalsRawValue() throws {
        // Assert: filename = rawValue (= boss
        // mandated; = the on-disk filename =
        // the H2 title).
        for sub in WorldSubSection.allCases {
            XCTAssertEqual(
                sub.filename, sub.rawValue,
                "filename must equal H2 title for \(sub)"
            )
            XCTAssertEqual(sub.displayName, sub.rawValue)
        }
    }

    func test_WorldSubSection_skeleton_isNonEmptyAndStartsWithH2() throws {
        // Assert: each skeleton starts with the
        // canonical H2 heading (= so the
        // LLM's fillable body sits under
        // the right H2).
        for sub in WorldSubSection.allCases {
            let s = sub.skeleton
            XCTAssertTrue(
                s.contains("## \(sub.rawValue)"),
                "skeleton for \(sub) must contain the H2 heading"
            )
        }
    }

    func test_WorldSubSection_noRemarksCase() throws {
        // Assert: 备注 is NOT a case
        // (= boss "不要备注标题的文档"
        // = the old wenshu 7th H2 is
        // dropped entirely).
        XCTAssertFalse(
            WorldSubSection.allCases.contains { $0.rawValue == "备注" },
            "WorldSubSection must NOT have a 备注 case (= boss banned 2026-10-10)"
        )
    }

    // MARK: - Parser: 6 必填 + 5 自定义 cap

    private func makeRawJSON(extraFilesJSON: String) -> String {
        return """
        {"title":"世界观元素","summary":"一个世界观","tags":["test"],"destination":"bookFolder","folder":"world","rewrittenBody":"","extraFiles":\(extraFilesJSON)}
        """
    }

    func test_parseAndMap_extraFiles_6Required_allKept() throws {
        // Arrange: 6 valid required extraFiles (= the
        // canonical world/ 6-必填 case).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"核心设定","body":"这个元素是什么","required":true},
          {"folder":"world","title":"地理或位置","body":"地形描述","required":true},
          {"folder":"world","title":"体系或规则","body":"能力描述","required":true},
          {"folder":"world","title":"历史脉络","body":"起源描述","required":true},
          {"folder":"world","title":"与其他元素的关系","body":"引用列表","required":true},
          {"folder":"world","title":"关键场景种子","body":"场景列表","required":true}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 6 required kept; = all 6 marked
        // required = true.
        XCTAssertEqual(result.extraFiles.count, 6)
        XCTAssertTrue(result.extraFiles.allSatisfy { $0.required })
        // Assert: titles match the 6 H2 titles.
        let titles = Set(result.extraFiles.map { $0.title })
        XCTAssertEqual(
            titles,
            Set([
                "核心设定", "地理或位置", "体系或规则",
                "历史脉络", "与其他元素的关系", "关键场景种子"
            ])
        )
    }

    func test_parseAndMap_extra_files_5Custom_allKept() throws {
        // Arrange: 5 valid custom extraFiles (= boss
        // "约等于备注" = LLM-chosen titles).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"十二生肖原型","body":"鼠牛虎兔...","required":false},
          {"folder":"world","title":"元炁体系","body":"气的运行","required":false},
          {"folder":"world","title":"时间线","body":"1945 至今","required":false},
          {"folder":"world","title":"蛇生肖考","body":"宋慈上一代","required":false},
          {"folder":"world","title":"家传三代","body":"爷传爹","required":false}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 5 custom kept; = all 5 marked
        // required = false.
        XCTAssertEqual(result.extraFiles.count, 5)
        XCTAssertTrue(result.extraFiles.allSatisfy { !$0.required })
    }

    func test_parseAndMap_extra_files_6RequiredPlus5Custom_11Kept() throws {
        // Arrange: 11 elements (= 6 required + 5
        // custom; = exactly the cap).
        var elements: [String] = []
        // 6 required
        for title in ["核心设定", "地理或位置", "体系或规则", "历史脉络", "与其他元素的关系", "关键场景种子"] {
            elements.append("""
            {"folder":"world","title":"\(title)","body":"内容","required":true}
            """)
        }
        // 5 custom
        for title in ["十二生肖原型", "元炁体系", "时间线", "蛇生肖考", "家传三代"] {
            elements.append("""
            {"folder":"world","title":"\(title)","body":"内容","required":false}
            """)
        }
        let rawJSON = makeRawJSON(extraFilesJSON: "[\(elements.joined(separator: ","))]")
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 11 total kept (= 6+5; = at cap).
        XCTAssertEqual(result.extraFiles.count, 11)
        let requiredCount = result.extraFiles.filter { $0.required }.count
        let customCount = result.extraFiles.filter { !$0.required }.count
        XCTAssertEqual(requiredCount, 6)
        XCTAssertEqual(customCount, 5)
    }

    func test_parseAndMap_extra_files_6RequiredPlus6Custom_5CustomDropped() throws {
        // Arrange: 12 elements (= 6 required + 6
        // custom; = 1 over the custom cap).
        var elements: [String] = []
        for title in ["核心设定", "地理或位置", "体系或规则", "历史脉络", "与其他元素的关系", "关键场景种子"] {
            elements.append("""
            {"folder":"world","title":"\(title)","body":"内容","required":true}
            """)
        }
        for title in ["A", "B", "C", "D", "E", "F"] {
            elements.append("""
            {"folder":"world","title":"\(title)","body":"内容","required":false}
            """)
        }
        let rawJSON = makeRawJSON(extraFilesJSON: "[\(elements.joined(separator: ","))]")
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: 11 total kept (= 6 required + 5
        // custom; = the 6th custom "F" was dropped
        // because the cap is 5).
        XCTAssertEqual(result.extraFiles.count, 11)
        let customTitles = result.extraFiles.filter { !$0.required }.map { $0.title }
        XCTAssertEqual(customTitles.sorted(), ["A", "B", "C", "D", "E"])
    }

    func test_parseAndMap_extra_files_beiZhuTitle_dropped() throws {
        // Arrange: an extraFile with title = "备注"
        // (= the old wenshu 7th H2; = boss
        // banned 2026-10-10 "不要备注标题的
        // 文档"; = the orchestrator
        // drops it).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"核心设定","body":"内容","required":true},
          {"folder":"world","title":"备注","body":"不能写备注","required":true}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: only 核心设定 kept (= 备注 dropped
        // by the boss-banned-title filter).
        XCTAssertEqual(result.extraFiles.count, 1)
        XCTAssertEqual(result.extraFiles[0].title, "核心设定")
    }

    func test_parseAndMap_extra_files_requiredFieldMissing_defaultsFalse() throws {
        // Arrange: extraFile WITHOUT the
        // `required` field (= old round-67
        // LLM behavior; = defaults to
        // false = treated as custom).
        let rawJSON = makeRawJSON(extraFilesJSON: """
        [
          {"folder":"world","title":"核心设定","body":"内容"},
          {"folder":"world","title":"A","body":"内容"},
          {"folder":"world","title":"B","body":"内容"}
        ]
        """)
        // Act.
        let result = WenshuConductorImportRouter.parseAndMap(
            raw: rawJSON,
            body: "original",
            fallbackTitle: "fallback",
            filePath: "/tmp/test.md"
        )
        // Assert: all 3 kept (= none marked
        // required = all 3 treated as
        // custom; = cap = 5 so no
        // dropping).
        XCTAssertEqual(result.extraFiles.count, 3)
        XCTAssertTrue(result.extraFiles.allSatisfy { !$0.required })
    }
}
