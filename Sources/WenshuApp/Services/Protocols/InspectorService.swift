// InspectorService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Protocols
// Responsibilities: inspector (右上) 标注读取与保存
// Inputs: 项目 id、AnnotationSnapshot
// Outputs: [AnnotationSnapshot]
// Dependencies: InspectorViewModel (默认实现委派 .shared 单例)
// Threading: Sendable，async 函数跨 actor 调度

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1): 右上 inspector 标注读写抽象。 默认
/// 实现走 `InspectorViewModel.shared`,不在此卡实装 CoreData 持久化
/// (沿 AGENTS §5.2 .ws schema = PM 拍)。
protocol InspectorService: Sendable {
    func loadAnnotations(projectId: UUID) async throws -> [AnnotationSnapshot]
    func saveAnnotation(_ annotation: AnnotationSnapshot) async throws
}

/// 占位 type — B+ 重不实装 annotation 持久化 schema (红线)。 给协议
/// 满足编译需要,等 PM 拍 .ws annotation schema 后再补字段。
struct AnnotationSnapshot: Identifiable, Sendable, Equatable {
    let id: UUID
    let projectId: UUID
    let chapterId: String?
    let paragraphId: UUID?
    let kind: String
    let payload: String
    let createdAt: Date
}