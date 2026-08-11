// LT01FixN3Tests.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 5 测试覆盖 LT-N3 全部产出 (派单 §Step 5):
//   1. testEditorView_requiresChapterId          (init 必须接 chapterId)
//   2. testEditorOutlineView_scopedToProject      (跨项目不串)
//   3. testWenshuProjectStore_saveChapterContent_persists  (round-trip)
//   4. testWenshuProjectStore_loadChapterContent_returnsSaved (load 后内容一致)
//   5. testProjectDetailView_selectedChapterId_routesToEditor (selectedChapterID 真生效)
//
// 设计文档真值: DESIGN-LT-N3.md (commit fee40c656) + 派单 §Step 5 5 个 case。
//
// 范式: 沿 LT01FixN1Tests 的 in-memory CoreData + @MainActor test pattern。
// 静态字符串检查的 worktree 路径用 `#filePath` 动态计算 (跟 LT01FixN1Tests
// 同范式), 不硬编码 worktree 名。
//
// 沿 LT01FixN1Tests 修真 (2026-08-11): seed CDChapter + chapter-meta 走
// inline `await storeActor.container.viewContext` + `context.perform { ... }`,
// 不用 helper 函数 (避免 Swift 6 strict concurrency "sending self" 警告
// — LT01FixN1Tests 同修真)。

import XCTest
@testable import WenshuApp
import CoreData

final class LT01FixN3Tests: XCTestCase {

    // MARK: - Helpers

    /// 项目根路径, 沿 LT01FixN1Tests 范式: `#filePath` (本测试文件路径
    /// → 上 3 级 = 项目根)。
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // <project_root>/
    }

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

    /// LT-N3 helper: returns both the project store and the underlying
    /// `WenshuStoreActor` so tests can seed CDChapter rows + `chapter-meta-<id>`
    /// CDNote rows that the public store API doesn't yet expose (v0.04.0 升
    /// schema 之前不暴露 createChapter, 沿 LT-N1 §4.2 真值)。
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

    // MARK: - Case 1: EditorView 必须接 chapterId (binding 版, 沿 90680db55)

    /// 派单 §Step 5 Case 1: EditorView.init 必须接 chapterId (binding 版,
    /// 沿 LT-N3-cc 修真 commit 90680db55 — selectedChapterID @Binding,
    /// LayoutShellView 顶层 @State 驱动, 跟 ProjectDetailView binding 链路
    /// 自洽)。 静态字符串检查 (沿 LT01FixN1 Case 5 / 6 降级方案)。
    func testEditorView_requiresChapterId() throws {
        let editorPath = projectRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Editor/EditorView.swift")
            .path
        let content = try String(contentsOfFile: editorPath, encoding: .utf8)
        // selectedProjectID 必须存在 (派单 §Step 1 接口契约, binding)
        XCTAssertTrue(content.contains("selectedProjectID: Binding<UUID?>"),
                      "EditorView 必须接 selectedProjectID: Binding<UUID?> (派单 §Step 1 接口契约, 沿 90680db55 binding 真值)")
        // selectedChapterID 必须存在 (派单 §Step 1 + Case 1 接口契约, binding)
        XCTAssertTrue(content.contains("selectedChapterID: Binding<String?>"),
                      "EditorView.init 必须接 selectedChapterID: Binding<String?> (派单 §Step 1 + Case 1)")
        // init 必须包含 binding 形参
        XCTAssertTrue(content.contains("init(\n        selectedProjectID: Binding<UUID?>,\n        selectedChapterID: Binding<String?>"),
                      "EditorView.init 必须接 (selectedProjectID: Binding<UUID?>, selectedChapterID: Binding<String?>) (派单 §Step 5 Case 1, 沿 90680db55 真值)")
    }

    // MARK: - Case 2: EditorOutlineStore 跨项目隔离

    /// 派单 §Step 5 Case 2: EditorOutlineStore 跨项目不串 (跟 LT-N1
    /// ChapterTreeStore 一致)。 沿 LT-N1 P0-3 修法: listChapters(projectId:)
    /// 走 chapter-meta-<projectId> CDNote tag scoping, 不跨项目。
    @MainActor
    func testEditorOutlineView_scopedToProject() async throws {
        let (store, storeActor) = makeStoreWithActor()
        let projectA = UUID()
        let projectB = UUID()

        // Seed 2 chapters for projectA, 1 chapter for projectB (inline 沿
        // LT01FixN1Tests 范式, 避免 Swift 6 strict concurrency "sending
        // self" 警告 = helper 函数横跨 actor 边界)。
        let context = await storeActor.container.viewContext
        try await context.perform {
            let cA1 = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
            cA1.setValue("A 第一章", forKey: "title")
            cA1.setValue(0, forKey: "chapterIndex")
            cA1.setValue(Date(), forKey: "createdAt")

            let cA2 = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
            cA2.setValue("A 第二章", forKey: "title")
            cA2.setValue(1, forKey: "chapterIndex")
            cA2.setValue(Date(), forKey: "createdAt")

            let cB1 = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
            cB1.setValue("B 第一章", forKey: "title")
            cB1.setValue(0, forKey: "chapterIndex")
            cB1.setValue(Date(), forKey: "createdAt")

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

        // EditorOutlineStore.load() 必须只拉 projectId 自己的章节
        let outlineA = await EditorOutlineStore(projectId: projectA, store: store)
        await outlineA.load()
        let chaptersA = await outlineA.chapters
        XCTAssertEqual(chaptersA.count, 2, "projectA 应该有 2 章")
        XCTAssertEqual(Set(chaptersA.map(\.title)), Set(["A 第一章", "A 第二章"]),
                       "projectA 的章节不能含 projectB 的章节 (P0-3 跨项目隔离)")
        XCTAssertTrue(chaptersA.allSatisfy { $0.projectId == projectA },
                      "所有返回章节的 projectId 字段必须 = projectA")

        let outlineB = await EditorOutlineStore(projectId: projectB, store: store)
        await outlineB.load()
        let chaptersB = await outlineB.chapters
        XCTAssertEqual(chaptersB.count, 1, "projectB 应该有 1 章")
        XCTAssertEqual(chaptersB.first?.title, "B 第一章",
                       "projectB 的章节不能含 projectA 的章节 (P0-3 跨项目隔离)")
        XCTAssertTrue(chaptersB.allSatisfy { $0.projectId == projectB },
                      "所有返回章节的 projectId 字段必须 = projectB")
    }

    // MARK: - Case 3: saveChapterContent round-trip

    /// 派单 §Step 5 Case 3: WenshuProjectStore.saveChapterContent 持久化
    /// + 后续 loadChapterContent 能读回去 (round-trip 不丢数据)。
    func testWenshuProjectStore_saveChapterContent_persists() async throws {
        let (store, storeActor) = makeStoreWithActor()
        let projectId = UUID()

        // Seed 1 chapter (inline 沿 LT01FixN1Tests 范式)
        let chapterId: String = try await {
            let context = await storeActor.container.viewContext
            return try await context.perform {
                let chapter = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: context)
                chapter.setValue("第一章", forKey: "title")
                chapter.setValue(0, forKey: "chapterIndex")
                chapter.setValue(Date(), forKey: "createdAt")
                chapter.setValue("", forKey: "content")

                let meta = NSEntityDescription.insertNewObject(forEntityName: "CDNote", into: context)
                meta.setValue("[\"第一章\"]", forKey: "text")
                meta.setValue("chapter-meta-\(projectId.uuidString)", forKey: "tags")
                meta.setValue(Date(), forKey: "createdAt")

                try context.save()
                return WenshuStoreActor.stableChapterID(for: chapter)
            }
        }()

        let newContent = "这是 LT-N3 编辑器写入的章节正文。\n第二段用于验证换行保留。"
        try await store.saveChapterContent(
            chapterId: chapterId,
            content: newContent
        )

        // 验证: load 回去必须拿到原文
        let loaded = try await store.loadChapterContent(
            chapterId: chapterId
        )
        XCTAssertEqual(loaded, newContent,
                       "saveChapterContent 后必须能用 loadChapterContent 读回原文")
    }

    // MARK: - Case 4: loadChapterContent 返回 saved content

    /// 派单 §Step 5 Case 4: WenshuProjectStore.loadChapterContent 必须返回
    /// CDChapter.content 字段 (不光 list 元数据, 真接 content)。
    func testWenshuProjectStore_loadChapterContent_returnsSaved() async throws {
        let (store, _) = makeStoreWithActor()
        let chapterId = "lt-n3-test-chapter-\(UUID().uuidString)"
        let initialContent = "首次 seed 的章节内容, 用于验证 loadChapterContent 真读 CDNote (沿 90680db55 修真, 章节正文存 chapter-content-<id> tag CDNote)"

        // 修真后 90680db55: 章节正文存在 CDNote (tag = chapter-content-<id>),
        // 不存 CDChapter.content。 seed 用 WenshuProjectStore.saveChapterContent。
        try await store.saveChapterContent(
            chapterId: chapterId,
            content: initialContent
        )

        let loaded = try await store.loadChapterContent(
            chapterId: chapterId
        )
        XCTAssertEqual(loaded, initialContent,
                       "loadChapterContent 必须返回 saveChapterContent 写入的 CDNote.text (沿 90680db55 修真)")
    }

    // MARK: - Case 5: ProjectDetailView selectedChapterID 路由到 EditorView

    /// 派单 §Step 5 Case 5: ProjectDetailView.selectedChapterID 真生效 —
    /// 章节 tab row tap 设置 selectedChapterID + push EditorView (派单
    /// §Step 4 路由)。 静态字符串检查 (沿 LT01FixN1 Case 5 降级方案)。
    func testProjectDetailView_selectedChapterId_routesToEditor() throws {
        let detailPath = projectRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Project/ProjectDetailView.swift")
            .path
        let content = try String(contentsOfFile: detailPath, encoding: .utf8)
        // selectedChapterID 必须存在 (派单 §Step 4 真值, binding 修真后 90680db55)
        XCTAssertTrue(content.contains("selectedChapterID"),
                      "ProjectDetailView 必须有 selectedChapterID (派单 §Step 4, 沿 90680db55 binding 真值)")
        // 修真后 90680db55: ProjectDetailView 不自挂 NavigationStack,
        // 路由由 LayoutShellView 顶层 NavigationStack 接管, push EditorView
        // 通过 binding selectedChapterID 驱动 topCenter (不重复 push)。
        // 这里检查 ChapterTreeView onSelectChapter callback 把 selectedChapterID
        // 驱动到顶层 (selectedChapterID = chapterId + dismiss pop 回 topCenter)。
        XCTAssertTrue(content.contains("ChapterTreeView"),
                      "ProjectDetailView 修真后用 ChapterTreeView + onSelectChapter 驱动 selectedChapterID binding (派单 §Step 4 真值, 沿 90680db55)")
        XCTAssertTrue(content.contains("onSelectChapter") || content.contains("selectedChapterID ="),
                      "ProjectDetailView 必须驱动 selectedChapterID binding (派单 §Step 4, 沿 90680db55 binding 真值)")
    }
}
