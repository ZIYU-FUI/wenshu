// DefaultProjectService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Defaults
// Responsibilities: ProjectService 委派实现 — 透传到 WenshuProjectStore.shared
// Inputs: 项目 id、ProjectSnapshot
// Outputs: ProjectSnapshot、[ProjectSnapshot]
// Dependencies: WenshuProjectStore.shared (红线 #3 不破现有单例)
// Threading: Sendable

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1 + 红线 #3): 委派不替代。 把 protocol
/// 调用透传到 `WenshuProjectStore.shared`,不替换 store 实现。
struct DefaultProjectService: ProjectService {
    private let store: WenshuProjectStore

    init(store: WenshuProjectStore = .shared) {
        self.store = store
    }

    func loadProject(id: UUID) async throws -> ProjectSnapshot {
        // WenshuProjectStore 没有显式 loadProject API,沿 loadAll
        // 过滤 — 后续 PM 拍 schema 时补 single-load API。
        let all = try await store.loadAll()
        guard let hit = all.first(where: { $0.id == id }) else {
            throw ProjectServiceError.notFound(id)
        }
        return hit
    }

    func saveProject(_ snapshot: ProjectSnapshot) async throws {
        try await store.save(
            project: snapshot,
            characters: [],
            worldRules: [],
            initialStory: ""
        )
    }

    func listProjects() async throws -> [ProjectSnapshot] {
        try await store.loadAll()
    }
}

enum ProjectServiceError: Error {
    case notFound(UUID)
}