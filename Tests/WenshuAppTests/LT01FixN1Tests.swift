// LT01FixN1Tests.swift · 文枢 (Wenshu) · v0.02.0 LT-N1-cc + LT-N1-revise
//
// **LT-N1-cc** (5 cases) — 工程主体:
//   1. ProjectListStore.load() 调 loadAll() 后 @Published projects 填充
//   2. ProjectListStore.create() 把新项目 insert(at: 0)
//   3. ProjectListStore.delete() 按 id 移除
//   4. WenshuProjectStore.loadAll() 按 createdAt 降序
//   5. LayoutShellView.topLeft slot 挂的是 ProjectBrowserView (降级为静态字符串检查)
//
// **LT-N1-revise** (4 cases) — 修 reviewer 4 个 P0 阻塞:
//   6. testProjectDetailView_usesPickerSegmented         (P0-1)
//   7. testChapterTreeView_requiresProjectId             (P0-2)
//   8. testWenshuProjectStore_listChapters_scopedToProject (P0-3)
//   9. testChapterRow_id_isStable                         (P0-4)
//
// 数据填充用 `store.create(name:style:waterLevel:tags:)` 而非 `store.save(...)`,
// 因为 `loadAll()` 走 `listTaggedNotes(prefix: "project-")` 然后 JSONDecoder 解
// ProjectSnapshot — 而 `save()` 把 `initialStory` 原文写到 note.text (非 JSON),
// loadAll() 会静默 skip。

import XCTest
@testable import WenshuApp
import CoreData

final class LT01FixN1Tests: XCTestCase {

    // MARK: - Helpers

    /// Build a `WenshuProjectStore` backed by an in-memory CoreData store.
    /// 沿用 WenshuProjectStoreTests.makeStore() 的 in-memory pattern。
    private func makeStore() -> WenshuProjectStore {
        let container = NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(String(describing: error))")
        }
        let storeActor = WenshuStoreActor(container: container)
        return WenshuProjectStore(storeActor: storeActor)
    }

    /// LT-N1-revise helper: returns both the project store and the underlying
    /// `WenshuStoreActor` so tests can seed CDChapter rows + `chapter-meta-<id>`
    /// CDNote rows that the public store API doesn't yet expose (v0.04.0 升 schema
    /// 之前不暴露 createChapter, 详见 REVIEW-LT-N1 §3.3.2 / DESIGN-LT-N1 §4.2)。
    private func makeStoreWithActor() -> (WenshuProjectStore, WenshuStoreActor) {
        let container = NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(String(describing: error))")
        }
        let storeActor = WenshuStoreActor(container: container)
        let store = WenshuProjectStore(storeActor: storeActor)
        return (store, storeActor)
    }

    // MARK: - Case 1: load

    /// ProjectListStore.load() 必须把 WenshuProjectStore.loadAll() 的结果填进 @Published projects
    func testProjectListStore_load_fetchesAllProjects() async throws {
        let store = makeStore()
        _ = try await store.create(name: "项目A", style: "轻松", waterLevel: 5, tags: ["测试"])
        _ = try await store.create(name: "项目B", style: "严肃", waterLevel: 7, tags: [])
        let list = await ProjectListStore(store: store)
        await list.load()
        let projects = await list.projects
        XCTAssertEqual(projects.count, 2, "load() 后必须包含已保存的 2 个项目")
        let names = Set(projects.map { $0.name })
        XCTAssertEqual(names, Set(["项目A", "项目B"]))
    }

    // MARK: - Case 2: create

    /// ProjectListStore.create() 必须把新项目 insert(at: 0) (列表顶)
    func testProjectListStore_create_appendsAtTop() async throws {
        let store = makeStore()
        _ = try await store.create(name: "旧项目", style: "轻松", waterLevel: 5, tags: [])
        let list = await ProjectListStore(store: store)
        await list.load()
        await list.create(name: "新项目", style: "严肃", verbosity: 7, tags: [])
        let projects = await list.projects
        XCTAssertEqual(projects.count, 2)
        XCTAssertEqual(projects.first?.name, "新项目", "create 后新项目必须在列表顶 (createdAt 倒序)")
    }

    // MARK: - Case 3: delete

    /// ProjectListStore.delete() 必须按 id 移除
    func testProjectListStore_delete_removesById() async throws {
        let store = makeStore()
        _ = try await store.create(name: "保留", style: "轻松", waterLevel: 5, tags: [])
        _ = try await store.create(name: "删除", style: "严肃", waterLevel: 7, tags: [])
        let list = await ProjectListStore(store: store)
        await list.load()
        let projectsBefore = await list.projects
        guard let toDelete = projectsBefore.first(where: { $0.name == "删除" }) else {
            XCTFail("找不到名为 '删除' 的项目")
            return
        }
        await list.delete(id: toDelete.id)
        let projects = await list.projects
        XCTAssertEqual(projects.count, 1, "delete 后剩 1 个")
        XCTAssertFalse(projects.contains { $0.id == toDelete.id }, "被删 id 必须不在列表中")
        XCTAssertEqual(projects.first?.name, "保留")
    }

    // MARK: - Case 4: loadAll 排序

    /// WenshuProjectStore.loadAll() 必须按 createdAt 降序 (最新在前)
    func testWenshuProjectStore_loadAll_returnsSortedByCreatedAtDesc() async throws {
        let store = makeStore()
        _ = try await store.create(name: "A-早", style: "轻松", waterLevel: 5, tags: [])
        try await Task.sleep(nanoseconds: 20_000_000)  // 20ms 间隔确保 createdAt 不同
        _ = try await store.create(name: "B-晚", style: "严肃", waterLevel: 7, tags: [])
        let loaded = try await store.loadAll()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].name, "B-晚", "最新的必须在第一位")
        XCTAssertEqual(loaded[1].name, "A-早", "最早的必须在第二位")
    }

    // MARK: - Case 5: LayoutShellView 集成 (降级为静态字符串检查)

    /// LayoutShellView 的 topLeft slot 必须挂 ProjectBrowserView, 不是老 ProjectListView
    func testLayoutShellView_topLeft_isProjectBrowserView() throws {
        let layoutShellPath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/t_4c608c99-lt01-n1-cc/Sources/WenshuApp/Views/Layout/LayoutShellView.swift"
        let content = try String(contentsOfFile: layoutShellPath, encoding: .utf8)
        XCTAssertTrue(content.contains("ProjectBrowserView"),
                      "LayoutShellView 必须挂载 ProjectBrowserView (派单 LT-N1 §3 集成要求)")
        // 验证 topLeft slot 范围 (取 topLeft 字符串后 400 字符) 不直接挂 ProjectListView()
        if let topLeftRange = content.range(of: "topLeft") {
            let start = topLeftRange.lowerBound
            let end = content.index(start, offsetBy: 400, limitedBy: content.endIndex) ?? content.endIndex
            let snippet = String(content[start..<end])
            XCTAssertFalse(snippet.contains("ProjectListView()"),
                           "topLeft slot 不应直接挂 ProjectListView() (ProjectBrowserView 持有 5 tab)")
        }
    }

    // MARK: - Case 6 (LT-N1-revise P0-1): ProjectDetailView 用 Picker.segmented + 5 tab

    /// P0-1 修: ProjectDetailView 必须用 `Picker.segmented` (5 tab 居中铺满),
    /// **不**用 `TabView`. 来源: 派单 t_e7c367ae Step 1 P0-1 修法 + 装机 user
    /// 8/7 OOB 拍板(designer §8 选项 A). 这是 reviewer §3.1.1 的核心阻塞:
    /// CC 不能用 TabView 偷换 Picker.segmented.
    ///
    /// 静态字符串检查 (沿用 §3.3.5 Case 5 的降级方案 — 渲染级测试留 swift run
    /// WenshuApp 给 PM-direct cua-driver 验)。
    func testProjectDetailView_usesPickerSegmented() throws {
        let detailPath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/t_4c608c99-lt01-n1-revise/Sources/WenshuApp/Views/Project/ProjectDetailView.swift"
        let content = try String(contentsOfFile: detailPath, encoding: .utf8)
        XCTAssertTrue(content.contains(".pickerStyle(.segmented)"),
                      "ProjectDetailView 必须使用 .pickerStyle(.segmented) (P0-1 修法)")
        XCTAssertFalse(content.contains("TabView("),
                       "ProjectDetailView 严禁使用 TabView — reviewer §3.1.1 派单 vs 设计稿矛盾")
        // 5 tab 居中铺满: 项目 / 章节 / 设定 / 资料 / 看板
        for tab in ["项目", "章节", "设定", "资料", "看板"] {
            XCTAssertTrue(content.contains("\"\(tab)\""),
                          "ProjectDetailView Picker 必须包含 5 tab 「\(tab)」")
        }
    }

    // MARK: - Case 7 (LT-N1-revise P0-2): ChapterTreeView 必须接 projectId (非可选)

    /// P0-2 修: ChapterTreeView.init 必须接 `projectId: UUID` (非可选).
    /// 旧版 `projectId: UUID?` 让章节 tab 死路径 — 永远 projectId == nil
    /// → ChapterTreeView 走 emptyState (reviewer §3.3.1)。
    /// 静态字符串检查 init signature。
    func testChapterTreeView_requiresProjectId() throws {
        let chapterPath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/t_4c608c99-lt01-n1-revise/Sources/WenshuApp/Views/Project/ChapterTreeView.swift"
        let content = try String(contentsOfFile: chapterPath, encoding: .utf8)
        XCTAssertTrue(content.contains("let projectId: UUID"),
                      "ChapterTreeView 必须把 projectId 声明为非可选 UUID (P0-2 修法)")
        XCTAssertTrue(content.contains("init(projectId: UUID"),
                      "ChapterTreeView.init 必须接 projectId: UUID (非可选) (P0-2 修法)")
        XCTAssertFalse(content.contains("let projectId: UUID?"),
                       "ChapterTreeView 不能保留可选 UUID (reviewer §3.3.1 死路径)")
        XCTAssertFalse(content.contains("init(projectId: UUID?"),
                       "ChapterTreeView.init 不能保留可选 UUID (reviewer §3.3.1 死路径)")
    }

    // MARK: - Case 8 (LT-N1-revise P0-3): listChapters 按 projectId 隔离

    /// P0-3 修: `WenshuProjectStore.listChapters(projectId:)` 必须按
    /// projectId 过滤, 不能跨项目串章节. 旧版调 `storeActor.listChapters()`
    /// 无参 → 全局 fetch 所有 CDChapter (reviewer §3.3.2 P0 阻塞)。
    ///
    /// 测试方法 (不动 schema, 沿用 DESIGN-LT-N1 §4.2 chapter-meta CDNote):
    /// 1. 在 in-memory store 里 seed 2 个 CDChapter + 2 个 chapter-meta CDNote
    ///    (一个 tag = "chapter-meta-<projectA>", 一个 tag = "chapter-meta-<projectB>")
    /// 2. listChapters(projectId: A) 必须只返回 A 的章节
    /// 3. listChapters(projectId: B) 必须只返回 B 的章节
    func testWenshuProjectStore_listChapters_scopedToProject() async throws {
        let (store, storeActor) = makeStoreWithActor()

        let projectA = UUID()
        let projectB = UUID()

        // Seed CDChapter rows directly (no createChapter API at v0.02.0).
        let context = await storeActor.container.viewContext
        try await context.perform {
            let chapterA1 = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
            chapterA1.setValue("A 第一章", forKey: "title")
            chapterA1.setValue(0, forKey: "chapterIndex")
            chapterA1.setValue(Date(), forKey: "createdAt")

            let chapterA2 = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
            chapterA2.setValue("A 第二章", forKey: "title")
            chapterA2.setValue(1, forKey: "chapterIndex")
            chapterA2.setValue(Date(), forKey: "createdAt")

            let chapterB1 = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
            chapterB1.setValue("B 第一章", forKey: "title")
            chapterB1.setValue(0, forKey: "chapterIndex")
            chapterB1.setValue(Date(), forKey: "createdAt")

            // chapter-meta-<projectId> CDNote per DESIGN-LT-N1 §4.2.
            let metaA = NSEntityDescription.insertNewObject(forEntityName: "CDNote", into: context)
            metaA.setValue("[\"A 第一章\",\"A 第二章\"]", forKey: "text")
            metaA.setValue("chapter-meta-\(projectA.uuidString)", forKey: "tags")
            metaA.setValue(Date(), forKey: "createdAt")

            let metaB = NSEntityDescription.insertNewObject(forEntityName: "CDNote", into: context)
            metaB.setValue("[\"B 第一章\"]", forKey: "text")
            metaB.setValue("chapter-meta-\(projectB.uuidString)", forKey: "tags")
            metaB.setValue(Date(), forKey: "createdAt")

            try context.save()
        }

        let chaptersA = try await store.listChapters(projectId: projectA)
        let chaptersB = try await store.listChapters(projectId: projectB)

        XCTAssertEqual(chaptersA.count, 2, "项目 A 必须有 2 章")
        XCTAssertEqual(Set(chaptersA.map(\.title)), Set(["A 第一章", "A 第二章"]),
                       "项目 A 的章节不能含 B 的章节 (P0-3 跨项目隔离)")
        XCTAssertTrue(chaptersA.allSatisfy { $0.projectId == projectA },
                      "所有返回章节的 projectId 字段必须 = projectA")

        XCTAssertEqual(chaptersB.count, 1, "项目 B 必须有 1 章")
        XCTAssertEqual(Set(chaptersB.map(\.title)), Set(["B 第一章"]),
                       "项目 B 的章节不能含 A 的章节 (P0-3 跨项目隔离)")
        XCTAssertTrue(chaptersB.allSatisfy { $0.projectId == projectB },
                      "所有返回章节的 projectId 字段必须 = projectB")
    }

    // MARK: - Case 9 (LT-N1-revise P0-4): ChapterRow.id 必须稳定

    /// P0-4 修: `ChapterRow.id` 不能每次 listChapters() 都生成新 UUID
    /// (旧版用 `UUID()` 让 SwiftUI List diff 失效, 行 view 闪烁, reviewer
    /// §3.1.2 P0 阻塞). 修法: id 用 `NSManagedObjectID.uriRepresentation()`
    /// → 同一 CDChapter 行多次 fetch id 必须相同。
    func testChapterRow_id_isStable() async throws {
        let (store, storeActor) = makeStoreWithActor()
        let projectId = UUID()

        // Seed 2 chapters
        let context = await storeActor.container.viewContext
        try await context.perform {
            let c1 = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
            c1.setValue("第一章", forKey: "title")
            c1.setValue(0, forKey: "chapterIndex")
            c1.setValue(Date(), forKey: "createdAt")

            let c2 = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
            c2.setValue("第二章", forKey: "title")
            c2.setValue(1, forKey: "chapterIndex")
            c2.setValue(Date(), forKey: "createdAt")

            let meta = NSEntityDescription.insertNewObject(forEntityName: "CDNote", into: context)
            meta.setValue("[\"第一章\",\"第二章\"]", forKey: "text")
            meta.setValue("chapter-meta-\(projectId.uuidString)", forKey: "tags")
            meta.setValue(Date(), forKey: "createdAt")

            try context.save()
        }

        // 第一次读
        let first = try await store.listChapters(projectId: projectId)
        XCTAssertEqual(first.count, 2, "seed 2 chapter 后必须返回 2")

        // 第二次读 — id 必须稳定
        let second = try await store.listChapters(projectId: projectId)
        XCTAssertEqual(second.count, 2)

        let firstIDs = first.map(\.id)
        let secondIDs = second.map(\.id)
        XCTAssertEqual(firstIDs, secondIDs,
                       "ChapterRow.id 在多次 listChapters 调用间必须稳定 (P0-4 修法)")
        XCTAssertFalse(firstIDs.contains(""),
                       "ChapterRow.id 不能为空字符串 (P0-4 修法)")
        XCTAssertEqual(Set(firstIDs).count, firstIDs.count,
                       "同一 store 的 2 个不同章节必须有不同 id (P0-4 修法)")
    }
}
