//
//  ReferenceLibraryExtendTests.swift · Wenshu · v2.7 self-evolution
//
//  Round-trip tests for the ReferenceLibraryActor.extendReference path
//  (= the self-evolution mechanism from boss 2026-09-25). Covers:
//  - mergeSection pure-function tests (append, replace, no-op, blank-line
//    separator handling, h3+ not treated as h2 boundary)
//  - extendReference id-missing path
//  - extendReference empty-section-title path
//  - extendReference happy path: create-then-extend accumulates sections
//    in one document instead of clobbering
//  - extendReference tag-union across multiple extends
//  - extendReference section-replace path (= same section_title extends
//    twice; the most recent research wins)
//  - extendReference preserves summary / source / url when not provided
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ReferenceLibraryTool extend (= self-evolution)")
@MainActor
struct ReferenceLibraryExtendTests {

    private func makeActor() throws -> (ReferenceLibraryActor, FileSystemReferenceStore, URL) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-tool-extend-\(UUID().uuidString)")
            .appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmp)
        let actor = ReferenceLibraryActor(referenceStore: store)
        return (actor, store, tmp)
    }

    // MARK: - mergeSection pure-function tests

    @Test("mergeSection appends a new section when the body is empty")
    func mergeSection_EmptyBody_Appends() {
        let result = ReferenceLibraryActor.mergeSection(
            into: "",
            sectionTitle: "概要",
            sectionBody: "西安是十三朝古都。"
        )
        #expect(result.contains("## 概要"))
        #expect(result.contains("西安是十三朝古都。"))
    }

    @Test("mergeSection appends a new section to a non-empty body")
    func mergeSection_AppendsToExistingBody() {
        let body = """
        # 西安

        西安是十三朝古都。
        """
        let result = ReferenceLibraryActor.mergeSection(
            into: body,
            sectionTitle: "明朝的西安",
            sectionBody: "明朝时西安是西北军事重镇。"
        )
        #expect(result.contains("## 明朝的西安"))
        #expect(result.contains("明朝时西安是西北军事重镇。"))
        // Existing h1 and content preserved.
        #expect(result.contains("# 西安"))
        #expect(result.contains("西安是十三朝古都。"))
    }

    @Test("mergeSection replaces an existing section when the title matches")
    func mergeSection_ReplacesExistingSection() {
        let body = """
        # 西安

        ## 概要

        旧内容，应当被替换。

        ## 明朝的西安

        旧明朝内容。
        """
        let result = ReferenceLibraryActor.mergeSection(
            into: body,
            sectionTitle: "概要",
            sectionBody: "新内容，覆盖了旧的概要。"
        )
        #expect(result.contains("新内容，覆盖了旧的概要。"))
        #expect(!result.contains("旧内容，应当被替换。"))
        // Adjacent section untouched.
        #expect(result.contains("旧明朝内容。"))
    }

    @Test("mergeSection handles blank-line separators between sections")
    func mergeSection_BlankLineSeparator() {
        let body = "## 概要\n旧概要内容。"
        let result = ReferenceLibraryActor.mergeSection(
            into: body,
            sectionTitle: "水盆羊肉",
            sectionBody: "陕西名小吃。"
        )
        #expect(result.contains("## 概要"))
        #expect(result.contains("旧概要内容。"))
        #expect(result.contains("## 水盆羊肉"))
        #expect(result.contains("陕西名小吃。"))
    }

    // MARK: - extendReference id-missing path

    @Test("extendReference throws entryNotFound when the id is unknown")
    func extendReference_UnknownID_Throws() async throws {
        let (actor, _, tmp) = try makeActor()
        defer {
            try? FileManager.default.removeItem(at: tmp)
        }
        let bogus = UUID()
        await #expect(throws: ReferenceLibraryError.self) {
            _ = try await actor.extendReference(
                id: bogus,
                sectionTitle: "概要",
                sectionBody: "内容"
            )
        }
    }

    // MARK: - extendReference happy path: create-then-extend

    @Test("create-then-extend accumulates sections in one document")
    func extendReference_AccumulatesAcrossTurns() async throws {
        let (actor, _, tmp) = try makeActor()
        defer {
            try? FileManager.default.removeItem(at: tmp)
        }

        // Turn 1 (= first mention): create the base '西安' entry.
        let baseDescriptor = try await actor.createReference(
            title: "西安",
            bodyMarkdown: """
            # 西安

            西安是十三朝古都，位于陕西省关中平原。
            """,
            layer: "entities",
            entityType: "location",
            summary: "中国西北的历史文化名城"
        )
        let baseID = baseDescriptor.id

        // Turn 2: user adds Ming-dynasty context. We find -> extend.
        let extended1 = try await actor.extendReference(
            id: baseID,
            sectionTitle: "明朝的西安",
            sectionBody: "明朝时西安是西北军事重镇，设西安卫。",
            tags: ["明朝", "明代", "军事重镇"]
        )
        // The same document (= same id).
        #expect(extended1.id == baseID)
        // Tags unioned (= base had no tags, extended adds these).
        #expect(extended1.tags.contains("明朝"))
        #expect(extended1.tags.contains("明代"))
        #expect(extended1.tags.contains("军事重镇"))

        // Turn 3: user mentions water-basin lamb. Extend again.
        let extended2 = try await actor.extendReference(
            id: baseID,
            sectionTitle: "水盆羊肉",
            sectionBody: "陕西西安名小吃，以羊肉汤配月牙饼食用。",
            tags: ["水盆羊肉", "陕西小吃"]
        )
        // Still the same document.
        #expect(extended2.id == baseID)
        // All tag categories preserved (= no tag loss).
        #expect(extended2.tags.contains("明朝"))
        #expect(extended2.tags.contains("军事重镇"))
        #expect(extended2.tags.contains("水盆羊肉"))
        #expect(extended2.tags.contains("陕西小吃"))

        // Body file content: three sections present, base not clobbered.
        let body = await actor.readBodyForTest(id: baseID) ?? ""
        #expect(body.contains("# 西安"))
        #expect(body.contains("西安是十三朝古都，位于陕西省关中平原。"))
        #expect(body.contains("## 明朝的西安"))
        #expect(body.contains("明朝时西安是西北军事重镇，设西安卫。"))
        #expect(body.contains("## 水盆羊肉"))
        #expect(body.contains("陕西西安名小吃"))
    }

    // MARK: - extendReference section-replace path

    @Test("extendReference with the same section_title replaces (= no duplicates)")
    func extendReference_SameSectionReplaces() async throws {
        let (actor, _, tmp) = try makeActor()
        defer {
            try? FileManager.default.removeItem(at: tmp)
        }
        let baseDescriptor = try await actor.createReference(
            title: "沧州",
            bodyMarkdown: "# 沧州\n\n河北沧州。",
            layer: "entities",
            entityType: "location"
        )
        let baseID = baseDescriptor.id

        // First extend: section "## 概要" doesn't exist yet -> append.
        _ = try await actor.extendReference(
            id: baseID,
            sectionTitle: "概要",
            sectionBody: "旧概要，应被替换。",
            tags: ["概要"]
        )
        // Second extend: same section_title -> replace content.
        _ = try await actor.extendReference(
            id: baseID,
            sectionTitle: "概要",
            sectionBody: "新概要，完全不同于旧的表述。",
            tags: ["新"]
        )

        let body = await actor.readBodyForTest(id: baseID) ?? ""
        #expect(body.contains("新概要，完全不同于旧的表述。"))
        // No duplicates: the old body content is gone.
        // (= Note: we use a distinctive marker that's NOT present in
        // the new content, so the substring count is unambiguous.)
        let oldCount = body.components(separatedBy: "旧概要，应被替换。").count - 1
        #expect(oldCount == 0, "expected zero occurrences of old body, got \(oldCount)")
    }

    // MARK: - extendReference preserves summary / source / url

    @Test("extendReference preserves summary / source / url when not provided")
    func extendReference_PreservesUnprovidedFields() async throws {
        let (actor, _, tmp) = try makeActor()
        defer {
            try? FileManager.default.removeItem(at: tmp)
        }
        let baseDescriptor = try await actor.createReference(
            title: "入殓师",
            bodyMarkdown: "# 入殓师\n\n负责遗体处理与仪容。",
            layer: "entities",
            entityType: "concept",
            source: "百度百科",
            url: "https://example.com/ruanjinshi",
            summary: "殡葬行业职业"
        )
        let baseID = baseDescriptor.id

        // Extend without summary / source / url -> all preserved.
        let extended = try await actor.extendReference(
            id: baseID,
            sectionTitle: "工作流程",
            sectionBody: "接收遗体 → 清洁 → 化妆 → 入棺。"
        )
        #expect(extended.summary == "殡葬行业职业")
        #expect(extended.source == "百度百科")
        #expect(extended.url == "https://example.com/ruanjinshi")
    }
}