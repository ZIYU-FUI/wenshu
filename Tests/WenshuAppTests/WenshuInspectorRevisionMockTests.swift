// WenshuInspectorRevisionMockTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-02-v2
//
// Inspector 修订 tab 的 mock 内容测 — 完全脱 store, 脱 LLM。 v0.04.0
// 真接 LLM 之前, 装机 user 实机看到的"3 条候选修订"是
// InspectorViewModel.mockRevisionCandidates 硬编码值。 这些 test 锁
// 死两条不动契约:
//   1. mock.count == 3
//   2. 3 条字段字面值必须跟 InspectorViewModel.mockRevisionCandidates
//      一致 — 任何 CC 自作主张 mock 内容都会被测出 diff。
//
// 不依赖 store / LLM / 任何 IO — 纯 unit test, 跑得飞快。

import XCTest
@testable import WenshuApp

@MainActor
final class WenshuInspectorRevisionMockTests: XCTestCase {

    func testRevisionMockThreeEntries() {
        XCTAssertEqual(InspectorViewModel.mock3.count, 3,
                       "修订 tab 必须显示恰好 3 条 mock — 跟 brief §1 / §2 拍板一致")
    }

    func testRevisionMockFieldConsistency() throws {
        // 拿 mock3 的字段字面值跟 mockRevisionCandidates 互相比对 —
        // 两者是同一个数组但是两个不同的 public static 引用。 任何
        // 拍板层 mock 内容修改都会被这两个数组字面值 diff 抓到。
        let mock3 = InspectorViewModel.mock3
        let canonical = InspectorViewModel.mockRevisionCandidates

        XCTAssertEqual(mock3, canonical,
                       "mock3 必须跟 mockRevisionCandidates 字面值一致")

        // 单独字段断言 — 装机 user 实机看到的"开篇节奏 / 心理动作桥 /
        // 伏笔显化" 三条要严格保留, 任何措辞修改需升 PM-direct。
        XCTAssertEqual(mock3.count, 3)

        let first = try XCTUnwrap(mock3.first, "第一条修订候选必须存在")
        XCTAssertTrue(
            first.revisedContent.contains("雨落在屋顶"),
            "第一条修订候选的 revisedContent 必须含 '雨落在屋顶'"
        )
        XCTAssertTrue(
            first.reason.contains("开篇节奏"),
            "第一条修订候选的 reason 必须含 '开篇节奏'"
        )
        XCTAssertFalse(first.accepted, "候选默认未采用")

        let second = mock3[1]
        XCTAssertTrue(
            second.revisedContent.contains("沈白没说话"),
            "第二条 revisedContent 必须含 '沈白没说话'"
        )
        XCTAssertTrue(
            second.reason.contains("心理-动作桥") || second.reason.contains("心理动作桥"),
            "第二条 reason 必须含 '心理动作桥'"
        )

        let third = mock3[2]
        XCTAssertTrue(
            third.revisedContent.contains("文枢镇开店的人都记得那一天"),
            "第三条 revisedContent 必须含 '文枢镇开店的人都记得那一天'"
        )
        XCTAssertTrue(
            third.reason.contains("伏笔显化"),
            "第三条 reason 必须含 '伏笔显化'"
        )

        // createdAt = hardcoded Date(timeIntervalSince1970: 1_700_xxx_xxx)。
        // 校验 3 条按时间升序 (= cand1 < cand2 < cand3), 跟 mock 列表
        // 顺序一致。
        XCTAssertLessThan(first.createdAt, second.createdAt,
                          "3 条 mock 必须按 createdAt 升序, 第一条最早")
        XCTAssertLessThan(second.createdAt, third.createdAt,
                          "3 条 mock 必须按 createdAt 升序, 第三条最晚")

        // 全部 originalChapterID 跟 ID 都是 fresh UUID — 不同 ID/相同
        // chapterID 不混, 都是 mock 内 distractor。 这里只验 UUID 不
        // 空, 不强行比对相等。
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(second.id, third.id)
        XCTAssertNotEqual(first.id, third.id)
    }
}
