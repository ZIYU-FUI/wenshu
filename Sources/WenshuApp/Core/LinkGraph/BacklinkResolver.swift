//
//  BacklinkResolver.swift · Wenshu · v0.19 ticket 12 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入'.
//
//  异步解析 markdown content + 入库 LinkIndex, 拿双向索引.
//  接口对齐 Obsidian Backlinks plugin 真值:
//  - resolve(content, sourceDocId, documentIndex): 解析 + 清空旧链接 + 批量入库
//  - backlinks(forDocId): 反向查所有 source (Backlinks 面板)
//  - forwardLinks(forDocId): 正向查所有 target (Outgoing links 面板)
//
//  跟 v0.18 ticket 04 AgentRuntime (actor + Sendable + Task) 同范式.
//

import Foundation

/// DocumentIndex: 把 doc 名 (filename / 显示名) 映射到 doc_id (UUID)
/// BacklinkResolver 用它解析 `[[name]]` → target_doc_id
public protocol DocumentIndexing: Sendable {
    /// 给 doc 显示名 (例如 "林黛玉"), 拿 doc_id (可空, 因为 [[new name]] 暂未对应到已有文档)
    func docId(forName name: String) async -> String?
    /// 给 doc_id, 拿显示名 (反向, 给面板渲染用)
    func name(forDocId docId: String) async -> String?
}

/// BacklinkResolver: 异步协调 Markdown 解析 + LinkIndex 入库
public actor BacklinkResolver {
    private let index: LinkIndex
    private let documentIndex: DocumentIndexing

    public init(index: LinkIndex, documentIndex: DocumentIndexing) {
        self.index = index
        self.documentIndex = documentIndex
    }

    /// 解析 markdown content, 清空 sourceDocId 的旧链接, 批量入库新链接
    public func resolve(content: String, sourceDocId: String) async throws {
        let parsed = InternalLinkParser.parse(content)
        // 清空旧链接 (文档重写时)
        try await index.removeAll(sourceDocId: sourceDocId)
        // 批量入库
        for link in parsed {
            let targetDocId = await documentIndex.docId(forName: link.target)
            try await index.add(
                Link(
                    sourceDocId: sourceDocId,
                    targetRef: link.target,
                    targetDocId: targetDocId,
                    line: link.line,
                    offset: link.offset
                )
            )
        }
    }

    /// 反向查: 给 docId, 拿所有 backlinks (引用它的 source 链接列表)
    public func backlinks(forDocId docId: String) async throws -> [Link] {
        // 1) 先用 docId 反查 (target 已解析的链接)
        let resolved = try await index.searchBackward(targetDocId: docId)
        // 2) 再用 doc 显示名反查 (target 未解析的链接, 比如 [[name]] 对应 doc 已改名)
        let name = await documentIndex.name(forDocId: docId) ?? ""
        if !name.isEmpty {
            let unresolved = try await index.searchBackward(targetRef: name)
            // 合并去重 (Apple HIG: Set 语义)
            let combined = resolved + unresolved.filter { u in !resolved.contains(where: { $0.sourceDocId == u.sourceDocId && $0.offset == u.offset }) }
            return combined.sorted { $0.createdAt > $1.createdAt }
        }
        return resolved
    }

    /// 反向查: 给显示名 (filename), 拿所有 backlinks
    public func backlinks(forName name: String) async throws -> [Link] {
        try await index.searchBackward(targetRef: name)
    }

    /// 正向查: 给 sourceDocId, 拿它引用的所有 target (Outgoing links)
    public func forwardLinks(forDocId docId: String) async throws -> [Link] {
        try await index.searchForward(sourceDocId: docId)
    }
}
