// WenshuProjectStore+LTN3.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
<<<<<<< HEAD
// LT-N3 (DESIGN-LT-N3.md §4.2) 需要中上编辑器读写 chapter content。
// 现状:
//   - CDChapter entity 已有 `content` 字段 (schema 不动, AGENTS §12 红线)
//   - WenshuStoreActor 没有 chapter content 专用 setter (不动 actor, AGENTS §12)
//   - WenshuProjectStore.listChapters 以外没有任何 chapter 读写路径
//
// 解决方案 (沿 LT-N2 +LTN2.swift 范式 — 不动 actor, 走 CDNote tag-scoping):
//   chapter content 存为 CDNote, tag = `chapter-content-<chapterId>` (id 是
//   listChapters 返回的 stable String id, 比如 `x-coredata://.../CDChapter/p1`)。
//   读 = listNotesWithMetadata(tag: "chapter-content-<id>") -> first row text
//   写 = deleteNotes(tag: "chapter-content-<id>") + createNote(text, tag, createdAt)
//
// 优点 vs 改 WenshuStoreActor 加 setter:
//   - 沿用 LT-N2 已有的 listNotesWithMetadata / deleteNotes / createNote,
//     无新增 actor API → 跟"不动 WenshuStoreActor signature"硬约束自洽
//   - 沿用 LT-N2 修真 (t_0c3beda1) 已稳的 tag-scoping 路径, 跟 chat
//     history 范式一致 (`chat-<uuid>` vs `chapter-content-<id>` 都 prefix-
//     scoped, 互相不串)
//   - 一行坏数据 = text 字段 nil-tolerant (跟 TaggedNote / NoteRow 范式), 不
//     阻塞 editor 加载
//
// 缺点 (升 v0.05.0 时再修真):
//   - chapter content 跟 CDChapter.content 字段不直接同步 (listChapters
//     返回的 `content` 仍然 = CDChapter.content, 跟 CDNote 存的最新
//     editor 版本可能不一致)。 修真时升级 PM 拍板加 actor setter。

import Foundation

extension WenshuProjectStore {

    /// LT-N3 tag 前缀, 跟现有 `project-<uuid>` / `chat-<uuid>` 区分, 不冲突。
    private static let chapterContentTagPrefix = "chapter-content-"

    /// 算 chapter content 的 tag-scoping tag。 给 2 个公开方法用。
    private func chapterContentTag(for chapterId: String) -> String {
        "\(Self.chapterContentTagPrefix)\(chapterId)"
    }

    // MARK: - 1. loadChapterContent

    /// 从 .ws 拉指定章节的正文 (= `chapter-content-<chapterId>` tag 的最近
    /// 一条 CDNote 的 text 字段)。
    ///
    /// 流程:
    ///   1. 调 `WenshuStoreActor.listNotesWithMetadata(tag:)` 拉 `chapter-content-<id>` 标签
    ///      的 CDNote 行 (L1 修真: tag 用 `==` 严格匹配, 跟 `chat-<uuid>` 范式一致)
    ///   2. 取最近 (createdAt 最新) 的一行 text
    ///   3. 兜底: 没有 row → "" (空章节)
    ///
    /// Returns: editor 正文 String, 失败 / 找不到 → "" (空字符串)。
    /// caller (EditorContentStore.load) 拿空字符串当合法空内容渲染。
    func loadChapterContent(chapterId: String) async throws -> String {
        let rows = try await storeActor.listNotesWithMetadata(tag: chapterContentTag(for: chapterId))
        // 取最新一条 (lexically / temporally 排序: createdAt 倒序 first)。
        // listNotesWithMetadata 暂无 sort descriptor, 在这里按 row.createdAt 排。
        let latest = rows.sorted { $0.createdAt > $1.createdAt }.first
        return latest?.text ?? ""
    }

    // MARK: - 2. saveChapterContent

    /// 保存章节正文到 .ws (= 删 `chapter-content-<id>` tag 旧 CDNote + 写
    /// 1 条新 CDNote, text = 新 content, tag = `chapter-content-<id>`,
    /// createdAt = now)。
    ///
    /// 流程:
    ///   1. 删除该 chapter 的所有旧 chapter-content CDNote (delete + recreate
    ///      范式, 避免 stale row)
    ///   2. 写 1 条新 CDNote
    ///
    /// Errors: delete / createNote 失败 → 向上抛, caller (EditorContentStore.save)
    /// silent-fail 兜底 (沿 v0.01.0 `persist()` 范式)。
    func saveChapterContent(chapterId: String, content: String) async throws {
        let tag = chapterContentTag(for: chapterId)
        try await storeActor.deleteNotes(tag: tag)
        try await storeActor.createNote([
            "text": content,
            "tags": tag,
            "createdAt": Date()
        ])
=======
// LT-N3 designer (commit fee40c656) 拍板 2 新方法 (DESIGN-LT-N3.md §4.2):
//   - loadChapterContent(projectId:chapterId:) → String
//   - saveChapterContent(projectId:chapterId:content:)
//
// 约束 (AGENTS §12 + DESIGN-LT-N3 §4.1):
//   - 不动 WenshuProjectStore.swift 主文件 (本文件 = extension, 沿 LT-N2
//     +LTN2.swift 范式)
//   - 不动 WenshuStoreActor.swift signature (沿 actor listChapters(projectId:)
//     + 直接 await storeActor.container.viewContext 写 CDChapter.content)
//   - 不动 ModelDefinitions.swift (CDChapter.content 字段已存在 schema 里,
//     v0.02.0 实装, 沿用 actor 既有读路径 + 直接 KVC 写路径)
//
// 存储路径:
//   - chapterId = NSManagedObjectID.uriRepresentation().absoluteString
//     (沿 LT-N1 P0-4 拍板真值, 稳定 id, 跨多次 fetch 不变)
//   - 读: actor.listChapters(projectId:) 返回值 ChapterRow.content (String)
//   - 写: context.perform { chapter.setValue(content, forKey: "content") }
//
// 跨项目隔离: listChapters(projectId:) 已经按 projectId 过滤 (P0-3 修),
// loadChapterContent 自动继承。 chapterId 找不到 = 返回 "" (不抛错, 沿
// LT-N1 loadChatHistory 找不到空 list 范式, EditorView 渲染空编辑器)。

import Foundation
import CoreData

extension WenshuProjectStore {

    /// LT-N3 拍板 1/2: 读章节正文。
    ///
    /// 流程:
    ///   1. 调 `storeActor.listChapters(projectId:)` 拉项目隔离的章节行
    ///   2. 在 actor 返回的 `[ChapterRow]` 中按 `chapterId` 找目标行
    ///   3. 返回 `ChapterRow.content` (String, CDChapter.content 字段镜像)
    ///
    /// - Returns: 章节正文 String。
    ///   - 找到 → 返回 CDChapter.content
    ///   - 找不到 → 返回 "" (空字串, 不抛错, 沿 LT-N1 loadChatHistory
    ///     找不到空 list 范式, EditorView 渲染空编辑器)
    func loadChapterContent(projectId: UUID, chapterId: String) async throws -> String {
        let chapters = try await storeActor.listChapters(projectId: projectId)
        guard let target = chapters.first(where: { $0.id == chapterId }) else {
            return ""
        }
        return target.content
    }

    /// LT-N3 拍板 2/2: 保存章节正文。
    ///
    /// 流程:
    ///   1. `await storeActor.container.viewContext` 拿主线程 viewContext
    ///      (actor 暴露 `container: NSPersistentContainer` 公开 let)
    ///   2. `context.perform { ... }` 在 context queue 全量 fetch CDChapter
    ///   3. 按 `WenshuStoreActor.stableChapterID(for:)` 找到目标行
    ///      (= NSManagedObjectID.uriRepresentation().absoluteString)
    ///   4. `target.setValue(content, forKey: "content")` KVC 写
    ///   5. `context.save()` 落盘
    ///
    /// - Parameter projectId: 项目 UUID, 当前未在实现中直接使用 (chapterId
    ///   通过 NSManagedObjectID 唯一标识, 全局稳定; 保留参数是 API 签名
    ///   一致性, 跟 loadChapterContent 配对, 未来 v0.05.0 schema 化后
    ///   可能用作跨项目校验)。
    /// - Throws: 章节不存在 / CoreData 写入失败。
    ///   - 章节不存在 → 抛 NSError(code: 1), caller (EditorContentStore)
    ///     silent-fail 兜底 (跟 ChatViewModel.persist 同范式)。
    func saveChapterContent(projectId: UUID, chapterId: String, content: String) async throws {
        // 沿 LT-N1 test 真值: `await storeActor.container.viewContext` 是
        // 标准 actor 跨边界取 NSManagedObjectContext 写法 (LT01FixN1Tests
        // 第 235 / 293 行同范式)。 compiler 可能在某些上下文报 "no async
        // operations occur" 警告, 但 actor-isolation 仍要求 await — 警告
        // 是误报, 保留 `await`。
        let context = await storeActor.container.viewContext
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDChapter")
            let chapters = try context.fetch(request)
            guard let target = chapters.first(where: {
                WenshuStoreActor.stableChapterID(for: $0) == chapterId
            }) else {
                throw NSError(
                    domain: "WenshuProjectStore.LTN3",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "未找到章节 \(chapterId)"]
                )
            }
            target.setValue(content, forKey: "content")
            if context.hasChanges {
                try context.save()
            }
        }
        _ = projectId  // 静默 unused 警告 — 保留参数是 API 签名一致性
>>>>>>> wenshu/v0.03.0/LT-N3-cc
    }
}
