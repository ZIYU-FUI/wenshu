// WenshuInspectorForeshadowTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-02-v2
//
// Inspector 伏笔 tab 真读 CDForeshadow 的 round-trip + 过滤 + 轻量
// 迁移测试。 复用 `WenshuStoreActorLayoutTests.makeInMemoryStore()`
// 范式 + `testMigration_preLT01_wsFile_doesNotLoseData` 的真磁盘迁移
// 路径。 全部 in-memory / 临时 sqlite 目录, 每 test 独立不污染。
//
// 覆盖:
//   - testCreateForeshadowWithChapterAndParagraph
//   - testListForeshadowsForChapter
//   - testListForeshadowsForParagraphPriority
//   - testForeshadowBackwardCompatibilityMigration

import XCTest
@testable import WenshuApp
import CoreData

final class WenshuInspectorForeshadowTests: XCTestCase {

    // MARK: - Fixtures

    /// Build a `WenshuStoreActor` backed by an in-memory CoreData store.
    /// 跟 WenshuStoreActorLayoutTests / WenshuStoreActorTests 同形态 —
    /// 每 test 独立 container, 不污染其他 test。
    private func makeInMemoryStore() -> WenshuStoreActor {
        let container = NSPersistentContainer(
            name: "Wenshu",
            managedObjectModel: makeWenshuModel()
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(String(describing: error))")
        }
        return WenshuStoreActor(container: container)
    }

    /// 旧 v0.01.0 schema — 仅 CDForeshadow 4 字段 (没 chapterID /
    /// paragraphID)。 hand-built 让测试不依赖生产 schema 演进。 其他
    /// entity 跟 v0.01.0 完全一致, 不引 CDLayoutState (= LT-01 新加)。
    private func makePreLT02ForeshadowModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            a.defaultValue = defaultValue
            return a
        }
        func entity(_ name: String, properties: [NSPropertyDescription]) -> NSEntityDescription {
            let e = NSEntityDescription()
            e.name = name
            e.managedObjectClassName = "NSManagedObject"
            e.properties = properties
            return e
        }
        model.entities = [
            entity("CDCharacter", properties: [
                attribute("name", .stringAttributeType),
                attribute("role", .stringAttributeType, optional: true),
                attribute("backstory", .stringAttributeType, optional: true),
                attribute("createdAt", .dateAttributeType)
            ]),
            entity("CDChapter", properties: [
                attribute("title", .stringAttributeType),
                attribute("content", .stringAttributeType, optional: true),
                attribute("chapterIndex", .integer32AttributeType),
                attribute("createdAt", .dateAttributeType)
            ]),
            entity("CDNote", properties: [
                attribute("text", .stringAttributeType),
                attribute("createdAt", .dateAttributeType),
                attribute("tags", .stringAttributeType, optional: true)
            ]),
            entity("CDWorldRule", properties: [
                attribute("rule", .stringAttributeType),
                attribute("category", .stringAttributeType, optional: true),
                attribute("createdAt", .dateAttributeType)
            ]),
            entity("CDForeshadow", properties: [
                // LT-02 v2 之前的 v0.01.0 / LT-01 schema — 仅 4 字段
                attribute("hook", .stringAttributeType),
                attribute("status", .stringAttributeType, optional: true),
                attribute("plantedAt", .dateAttributeType),
                attribute("resolvedAt", .dateAttributeType, optional: true)
            ]),
            entity("CDRevision", properties: [
                attribute("originalChapterID", .UUIDAttributeType),
                attribute("revisedContent", .stringAttributeType, optional: true),
                attribute("reason", .stringAttributeType, optional: true),
                attribute("createdAt", .dateAttributeType),
                attribute("accepted", .booleanAttributeType, defaultValue: false)
            ]),
            entity("CDAIDraft", properties: [
                attribute("prompt", .stringAttributeType),
                attribute("draft", .stringAttributeType, optional: true),
                attribute("model", .stringAttributeType),
                attribute("createdAt", .dateAttributeType),
                attribute("finalizedChapterID", .UUIDAttributeType, optional: true)
            ])
        ]
        return model
    }

    // MARK: - Create + round-trip

    func testCreateForeshadowWithChapterAndParagraph() async throws {
        let store = makeInMemoryStore()
        let chapterID = UUID()
        let paragraphID = UUID()
        let hook = "沈白的伞始终靠在门边, 但他从不接。"
        let plantedAt = Date(timeIntervalSince1970: 1_750_000_000)

        try await store.createForeshadow([
            "hook": hook,
            "status": "active",
            "plantedAt": plantedAt,
            "chapterID": chapterID,
            "paragraphID": paragraphID
        ])

        let byParagraph = try await store.listForeshadows(forParagraph: paragraphID)
        XCTAssertEqual(byParagraph.count, 1, "应为该段落返回恰好 1 条伏笔")
        let row = try XCTUnwrap(byParagraph.first)
        XCTAssertEqual(row.hook, hook)
        XCTAssertEqual(row.status, "active")
        XCTAssertEqual(row.plantedAt, plantedAt)
        XCTAssertEqual(row.chapterID, chapterID, "chapterID 必须跟插入时一致")
        XCTAssertEqual(row.paragraphID, paragraphID, "paragraphID 必须跟插入时一致")
        XCTAssertFalse(row.isResolved, "resolvedAt 缺失时不应该是已回收")
    }

    // MARK: - Filter by chapter

    func testListForeshadowsForChapter() async throws {
        let store = makeInMemoryStore()
        let chapterA = UUID()
        let chapterB = UUID()

        // 5 条 fixture: chapter=A 2 条, chapter=B 1 条, 无 chapter 关联 2 条
        try await store.createForeshadow([
            "hook": "A 章节伏笔 #1 — 钟楼",
            "plantedAt": Date(timeIntervalSince1970: 1_700_000_000),
            "chapterID": chapterA
        ])
        try await store.createForeshadow([
            "hook": "A 章节伏笔 #2 — 邮差",
            "plantedAt": Date(timeIntervalSince1970: 1_700_001_000),
            "chapterID": chapterA
        ])
        try await store.createForeshadow([
            "hook": "B 章节伏笔 — 雪",
            "plantedAt": Date(timeIntervalSince1970: 1_700_002_000),
            "chapterID": chapterB
        ])
        // 两条没 chapter 关联 (= 历史 v0.01.0 旧行)
        try await store.createForeshadow([
            "hook": "无 chapter 旧伏笔 #1",
            "plantedAt": Date(timeIntervalSince1970: 1_700_003_000)
        ])
        try await store.createForeshadow([
            "hook": "无 chapter 旧伏笔 #2",
            "plantedAt": Date(timeIntervalSince1970: 1_700_004_000)
        ])

        let chapterAForeshadows = try await store.listForeshadows(forChapter: chapterA)
        XCTAssertEqual(chapterAForeshadows.count, 2, "chapter=A 应只返回 2 条")
        XCTAssertTrue(chapterAForeshadows.allSatisfy { $0.chapterID == chapterA },
                      "返回的每条都必须绑定到 chapterA, 不能漏到其他 chapter")
        XCTAssertEqual(chapterAForeshadows.map { $0.hook }, [
            "A 章节伏笔 #1 — 钟楼",
            "A 章节伏笔 #2 — 邮差"
        ], "应按 plantedAt 升序排 = 故事时间线")

        let chapterBForeshadows = try await store.listForeshadows(forChapter: chapterB)
        XCTAssertEqual(chapterBForeshadows.count, 1)
        XCTAssertEqual(chapterBForeshadows.first?.chapterID, chapterB)
    }

    // MARK: - Filter by paragraph (priority > chapter)

    func testListForeshadowsForParagraphPriority() async throws {
        let store = makeInMemoryStore()
        let chapterX = UUID()
        let paragraphX = UUID()
        let paragraphY = UUID()

        // 同 chapter 不同 paragraph — inspector 段落选中必须返回段落
        // 级别那条, 不能跟 chapter 过滤混淆 (= 优先级 paragraph > chapter)。
        try await store.createForeshadow([
            "hook": "段落 X 的伏笔",
            "plantedAt": Date(timeIntervalSince1970: 1_700_000_000),
            "chapterID": chapterX,
            "paragraphID": paragraphX
        ])
        try await store.createForeshadow([
            "hook": "段落 Y 的伏笔",
            "plantedAt": Date(timeIntervalSince1970: 1_700_001_000),
            "chapterID": chapterX,
            "paragraphID": paragraphY
        ])

        let paragraphXForeshadows = try await store.listForeshadows(forParagraph: paragraphX)
        XCTAssertEqual(paragraphXForeshadows.count, 1, "段落 X 应只返回 1 条")
        XCTAssertEqual(paragraphXForeshadows.first?.hook, "段落 X 的伏笔")
        XCTAssertEqual(paragraphXForeshadows.first?.paragraphID, paragraphX)

        let paragraphYForeshadows = try await store.listForeshadows(forParagraph: paragraphY)
        XCTAssertEqual(paragraphYForeshadows.count, 1)
        XCTAssertEqual(paragraphYForeshadows.first?.paragraphID, paragraphY)

        // paragraphID 传 nil = 显式想要"无 paragraph 关联" 的伏笔,
        // 这两条 fixture 都有 paragraphID, 应返回空。
        let noParagraph = try await store.listForeshadows(forParagraph: nil)
        XCTAssertEqual(noParagraph.count, 0)
    }

    // MARK: - Migration (v0.01.0 .ws 不破)

    /// Pre-LT-02-v2 model — 同 v0.01.0 (4 字段 CDForeshadow)。
    /// 拿这 schema 写一行带数据的 CDForeshadow, 然后用 v0.02.0 schema
    /// (加了 chapterID / paragraphID) 打开同一个 sqlite 文件 — 必须
    /// 自动轻量迁移成功, 旧行全读出, 旧行 chapterID/paragraphID 为 nil。
    func testForeshadowBackwardCompatibilityMigration() async throws {
        // 1. 临时 sqlite 目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-foreshadow-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storeURL = tempDir.appendingPathComponent("Wenshu.sqlite")

        // 2. 用 v0.01.0 schema 写一行 CDForeshadow
        let oldContainer = NSPersistentContainer(
            name: "Wenshu",
            managedObjectModel: makePreLT02ForeshadowModel()
        )
        let oldDesc = NSPersistentStoreDescription(url: storeURL)
        oldContainer.persistentStoreDescriptions = [oldDesc]
        var oldLoadError: Error?
        oldContainer.loadPersistentStores { _, error in oldLoadError = error }
        XCTAssertNil(oldLoadError,
                     "Pre-LT-02-v2 store must load cleanly: \(String(describing: oldLoadError))")
        let oldContext = oldContainer.viewContext
        let oldRow = NSEntityDescription.insertNewObject(forEntityName: "CDForeshadow", into: oldContext)
        oldRow.setValue("v0.01.0 遗留下来的旧伏笔 — 老邮差的鞋底",
                        forKey: "hook")
        oldRow.setValue("active", forKey: "status")
        oldRow.setValue(Date(timeIntervalSince1970: 1_600_000_000), forKey: "plantedAt")
        try oldContext.save()
        try await Task.sleep(for: .milliseconds(50))

        // 3. 用 v0.02.0 current schema (makeWenshuModel 加了
        //    chapterID/paragraphID) 打开同一 sqlite 文件
        let newContainer = NSPersistentContainer(
            name: "Wenshu",
            managedObjectModel: makeWenshuModel()
        )
        let newDesc = NSPersistentStoreDescription(url: storeURL)
        newDesc.shouldInferMappingModelAutomatically = true
        newDesc.shouldMigrateStoreAutomatically = true
        newContainer.persistentStoreDescriptions = [newDesc]
        var newLoadError: Error?
        newContainer.loadPersistentStores { _, error in newLoadError = error }
        XCTAssertNil(newLoadError,
                     "Migration to LT-02-v2 must succeed: \(String(describing: newLoadError))")

        // 4. 验证旧 CDForeshadow 行全读出, chapterID/paragraphID 为 nil
        let newContext = newContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDForeshadow")
        let rows = try newContext.fetch(request)
        XCTAssertEqual(rows.count, 1, "旧 CDForeshadow 行必须活下来")
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.value(forKey: "hook") as? String,
                       "v0.01.0 遗留下来的旧伏笔 — 老邮差的鞋底",
                       "旧行 hook 必须保留原值")
        XCTAssertEqual(row.value(forKey: "status") as? String, "active")
        XCTAssertEqual(row.value(forKey: "chapterID") as? UUID, nil,
                       "旧行 chapterID 字段值必须为 nil")
        XCTAssertEqual(row.value(forKey: "paragraphID") as? UUID, nil,
                       "旧行 paragraphID 字段值必须为 nil")

        // 5. 把这个迁移后的容器包进 WenshuStoreActor, 验证 list 接口
        //    也能读 (即 WenshuStoreActor 用的 viewContext 不抛 decode 错)。
        let store = WenshuStoreActor(container: newContainer)
        let listAll = try await store.listForeshadows()
        XCTAssertEqual(listAll.count, 1)
        let firstRow = try XCTUnwrap(listAll.first)
        XCTAssertEqual(firstRow.hook, "v0.01.0 遗留下来的旧伏笔 — 老邮差的鞋底")
        XCTAssertNil(firstRow.chapterID, "迁移后旧行 chapterID 必须 nil")
        XCTAssertNil(firstRow.paragraphID, "迁移后旧行 paragraphID 必须 nil")

        // 兜底 = paragraphID == nil 过滤 = 装机 user 没进段落选中时显示全部旧行
        let legacyFallback = try await store.listForeshadows(forParagraph: nil)
        XCTAssertEqual(legacyFallback.count, 1,
                       "兜底路径必须返回全部 paragraphID == nil 的旧伏笔")
    }
}
