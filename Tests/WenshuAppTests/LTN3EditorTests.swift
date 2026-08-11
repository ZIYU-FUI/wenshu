// LTN3EditorTests.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 5 个测试覆盖 LT-N3 全部产出 (DESIGN-LT-N3.md §9.3 + §1 步 4-10):
//   1. WenshuProjectStore.chapterContent round-trip (load / save / 回读 / 跨章节隔离)
//   2. EditorContentStore load 拉 content + 字数
//   3. EditorContentStore updateContent → flush 写回 .ws
//   4. EditorOutlineStore load 拉项目下章节列表 + 跨项目隔离
//   5. EditorView source-level: topCenter 接管 PlaceholderContent
//      (替代真 UI 验证 — 沿 LT-N1 / V0-fix-4 source-level 范式)
//
// 边界 (沿 AGENTS §12 + task body):
//   - 不动 WenshuStoreActor / CoreData entity / Package.swift / Info.plist
//   - chapter content 走 CDNote tag-scoping (chapter-content-<id>),
//     跟 LT-N2 chat-<uuid> 范式一致

import XCTest
@testable import WenshuApp
import CoreData

final class LTN3EditorTests: XCTestCase {

    // MARK: - Fixtures

    /// 跟 LTN2ChatTests 同范式 — in-memory CoreData, 隔离每个 test。
    /// 同时返回 storeActor 让 fixture 写 CDChapter rows 用。
    private func makeStore() -> (WenshuProjectStore, WenshuStoreActor) {
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

    /// 单纯拿 store (不需要 storeActor 的 fixture 用)
    private func makeStoreOnly() -> WenshuProjectStore {
        makeStore().0
    }

    /// Seed 一组 chapters 给 projectId — 写真实 CDChapter rows + chapter-meta
    /// CDNote, 模拟 LT-N1 listChapters(projectId:) 的输入条件。
    /// 挂成 static 非 isolated 函数, 避免 @MainActor test 调它时 self 跨 boundary。
    private static func seedChapters(
        storeActor: WenshuStoreActor,
        projectId: UUID,
        titles: [String]
    ) async throws {
        // 写 chapter-meta CDNote (titles 数组)
        let titleJSON = try JSONSerialization.data(withJSONObject: titles, options: [])
        let titleText = String(data: titleJSON, encoding: .utf8) ?? ""
        try await storeActor.createNote([
            "text": titleText,
            "tags": "chapter-meta-\(projectId.uuidString)",
            "createdAt": Date()
        ])
        // 写 CDChapter rows
        let container = await storeActor.container
        let ctx = container.viewContext
        try await ctx.perform {
            for (i, title) in titles.enumerated() {
                let chapter = NSEntityDescription.insertNewObject(forEntityName: "CDChapter", into: ctx)
                chapter.setValue(title, forKey: "title")
                chapter.setValue("", forKey: "content")
                chapter.setValue(Int32(i + 1), forKey: "chapterIndex")
                chapter.setValue(Date(), forKey: "createdAt")
            }
            try ctx.save()
        }
    }

    // MARK: - 1. WenshuProjectStore chapter content round-trip

    func testWenshuProjectStore_chapterContent_roundTrip() async throws {
        let store = makeStoreOnly()
        let chapterId = "x-coredata://test/CDChapter/p1"

        // 初始: load 应返回 "" (空字符串)
        let initial = try await store.loadChapterContent(chapterId: chapterId)
        XCTAssertEqual(initial, "", "新章节 load 应返回空字符串")

        // save 后 load 回读
        try await store.saveChapterContent(chapterId: chapterId, content: "第一章正文。")
        let afterSave = try await store.loadChapterContent(chapterId: chapterId)
        XCTAssertEqual(afterSave, "第一章正文。", "save 后 load 应回读相同内容")

        // 二次 save 覆盖旧版 (delete + recreate 范式)
        try await store.saveChapterContent(chapterId: chapterId, content: "第一章正文。v2 修订")
        let afterRewrite = try await store.loadChapterContent(chapterId: chapterId)
        XCTAssertEqual(afterRewrite, "第一章正文。v2 修订", "二次 save 应覆盖旧版")

        // tag-scoping: 不同 chapterId 互不串
        let otherChapterId = "x-coredata://test/CDChapter/p2"
        try await store.saveChapterContent(chapterId: otherChapterId, content: "第二章正文")
        let otherLoaded = try await store.loadChapterContent(chapterId: otherChapterId)
        XCTAssertEqual(otherLoaded, "第二章正文", "其他 chapter 独立存")
        let firstStill = try await store.loadChapterContent(chapterId: chapterId)
        XCTAssertEqual(firstStill, "第一章正文。v2 修订", "章节 1 内容不被章节 2 干扰")
    }

    // MARK: - 2. EditorContentStore load 拉 content + 字数

    @MainActor
    func testEditorContentStore_load_populatesContentAndWordCount() async throws {
        let store = makeStoreOnly()
        let chapterId = "x-coredata://test/CDChapter/p10"
        // 5 段文本用 4 个空格分隔 = 5 个 split 块 = wordCount 5
        try await store.saveChapterContent(chapterId: chapterId, content: "这是 一段 测试 正文 五个字")

        let editorStore = EditorContentStore(chapterId: chapterId, store: store)
        XCTAssertEqual(editorStore.content, "", "init 后 content 应为空字符串")
        XCTAssertEqual(editorStore.wordCount, 0, "init 后 wordCount 应为 0")
        XCTAssertFalse(editorStore.isDirty, "init 后 isDirty 应为 false")

        await editorStore.load()

        let content = editorStore.content
        XCTAssertEqual(content, "这是 一段 测试 正文 五个字", "load 后 content 从 store 拉")
        // wordCount 走 content.split { $0.isWhitespace }.count —— 5 个词
        let wordCount = editorStore.wordCount
        XCTAssertEqual(wordCount, 5, "load 后 wordCount = 5 (按空白 split)")
        XCTAssertFalse(editorStore.isDirty, "load 后 isDirty 应为 false")
    }

    // MARK: - 3. EditorContentStore updateContent + flush 写回

    @MainActor
    func testEditorContentStore_updateContentAndFlush_persistsToStore() async throws {
        let store = makeStoreOnly()
        let chapterId = "x-coredata://test/CDChapter/p20"
        try await store.saveChapterContent(chapterId: chapterId, content: "初始内容")

        let editorStore = EditorContentStore(chapterId: chapterId, store: store)
        await editorStore.load()
        XCTAssertEqual(editorStore.content, "初始内容", "load 应拉到 store 现有内容")

        // updateContent: 立即更新 content + isDirty = true
        editorStore.updateContent("更新后的内容 新版")
        XCTAssertEqual(editorStore.content, "更新后的内容 新版", "updateContent 立即更新 content")
        XCTAssertTrue(editorStore.isDirty, "updateContent 后 isDirty = true")

        // flush: 写回 store
        await editorStore.flush()
        XCTAssertFalse(editorStore.isDirty, "flush 后 isDirty = false")

        // 验证 store 真回读
        let afterFlush = try await store.loadChapterContent(chapterId: chapterId)
        XCTAssertEqual(afterFlush, "更新后的内容 新版", "flush 后 store 持久化新内容")
    }

    // MARK: - 4. EditorOutlineStore load 拉项目下章节 + 跨项目隔离

    @MainActor
    func testEditorOutlineStore_load_listsChaptersForProject() async throws {
        let (store, storeActor) = makeStore()
        let projectId = UUID()
        let otherProjectId = UUID()

        try await Self.seedChapters(storeActor: storeActor, projectId: projectId, titles: ["第 1 章", "第 2 章"])

        let outlineStore = EditorOutlineStore(projectId: projectId, store: store)
        await outlineStore.load()

        XCTAssertEqual(outlineStore.chapters.count, 2, "projectId 下应拉 2 章节")
        XCTAssertEqual(outlineStore.chapters[0].title, "第 1 章")
        XCTAssertEqual(outlineStore.chapters[1].title, "第 2 章")

        // 跨项目隔离: otherProjectId 不应拉到任何章节
        let otherOutline = EditorOutlineStore(projectId: otherProjectId, store: store)
        await otherOutline.load()
        XCTAssertEqual(otherOutline.chapters.count, 0, "其他 project 不应能拉到本 project 章节")
    }

    // MARK: - 5. EditorView source-level: topCenter 接管 PlaceholderContent

    /// 沿 V0-fix-4 / LT-N1 source-level 范式 — LT-N3 拍板真值 = topCenter
    /// 接管 PlaceholderContent, 渲染 EditorView。 真 UI 验证留给装机
    /// user cua-driver 实机跑。
    func testLayoutShellView_topCenterRendersEditorView() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("Sources/WenshuApp/Views/Layout/LayoutShellView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            source.contains("EditorView("),
            "LayoutShellView.topCenter 必须接管 PlaceholderContent, 渲染 EditorView (LT-N3)"
        )
        // 修真前分支含 "中上" + "PlaceholderContent" 注释作为 hint，
        // 修真后应只剩 EditorView 接管。检查是否不再走旧 HStack + EditorOutlineView 占位。
        XCTAssertFalse(
            source.contains("HStack(spacing: 0) {\n                        EditorOutlineView(chapters: [])"),
            "LayoutShellView.topCenter 不应再走 LT-01-fix19 占位 HStack + EditorOutlineView(chapters: [])"
        )
    }
}
