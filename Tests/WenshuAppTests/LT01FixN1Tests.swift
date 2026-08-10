// LT01FixN1Tests.swift · 文枢 (Wenshu) · v0.02.0 LT-N1-cc
//
// 5 个 case 验证 LT-N1 工程实现的 4 项 API + LayoutShellView 集成:
//   1. ProjectListStore.load() 调 loadAll() 后 @Published projects 填充
//   2. ProjectListStore.create() 把新项目 insert(at: 0)
//   3. ProjectListStore.delete() 按 id 移除
//   4. WenshuProjectStore.loadAll() 按 createdAt 降序
//   5. LayoutShellView.topLeft slot 挂的是 ProjectBrowserView (降级为静态字符串检查)
//
// 数据填充用 `store.create(name:style:waterLevel:tags:)` 而非 `store.save(...)`,
// 因为 `loadAll()` 走 `listTaggedNotes(prefix: "project-")` 然后 JSONDecoder 解
// ProjectSnapshot — 而 `save()` 把 `initialStory` 原文写到 note.text (非 JSON),
// loadAll() 会静默 skip。所以本卡 5 个 case 一律走 `create()` API。

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
}
