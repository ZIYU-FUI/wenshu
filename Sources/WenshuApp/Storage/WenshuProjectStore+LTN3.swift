// WenshuProjectStore+LTN3.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
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
    }
}
