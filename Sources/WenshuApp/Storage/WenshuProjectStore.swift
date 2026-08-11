import Foundation

actor WenshuProjectStore {
    static let shared = WenshuProjectStore()
    /// `internal` (was `private`) — LT-N1-revise tests need to seed
    /// `chapter-meta-<id>` CDNote rows + CDChapter fixtures to verify
    /// P0-3 (project scoping) and P0-4 (stable IDs). Visibility change
    /// does not affect any external caller.
    let storeActor: WenshuStoreActor
    nonisolated let directoryURL: URL

    init(storeActor: WenshuStoreActor? = nil) {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true).appendingPathComponent("wenshu-projects", isDirectory: true)
        directoryURL = directory
        self.storeActor = storeActor ?? .shared
        ensureDirectoryExists()
    }

    private nonisolated func ensureDirectoryExists() {
        do { try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true) }
        catch { FileHandle.standardError.write(Data("WenshuProjectStore: failed to create \(directoryURL.path): \(error)\n".utf8)) }
    }

    func create(name: String, style: String, waterLevel: Int, tags: [String]) async throws -> ProjectSnapshot {
        let snapshot = ProjectSnapshot(name: name, style: style, verbosity: min(max(waterLevel, 1), 9), tags: tags)
        let data = try JSONEncoder().encode(snapshot)
        try await storeActor.createNote(["text": String(decoding: data, as: UTF8.self), "tags": tag(snapshot.id), "createdAt": snapshot.createdAt])
        return snapshot
    }

    func loadAll() async throws -> [ProjectSnapshot] {
        try await storeActor.listTaggedNotes(prefix: "project-").compactMap { row in
            guard let data = row.text.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(ProjectSnapshot.self, from: data)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func delete(id: UUID) async throws { try await storeActor.deleteNotes(tag: tag(id)) }

    func listChapters(projectId: UUID) async throws -> [ChapterSnapshot] {
        // P0-3 fix (LT-N1-revise): previously this called storeActor.listChapters()
        // (no projectId) which leaked chapters from ALL projects. Now we route
        // through the project-scoped storeActor.listChapters(projectId:) which
        // filters by `chapter-meta-<projectId>` CDNote per DESIGN-LT-N1 §4.2.
        try await storeActor.listChapters(projectId: projectId).map { row in
            ChapterSnapshot(id: row.id, projectId: projectId, title: row.title, index: row.index, wordCount: row.content.split { $0.isWhitespace }.count, parentId: nil)
        }
    }

    private func tag(_ id: UUID) -> String { "project-\(id.uuidString)" }

    func save(project: ProjectSnapshot, characters: [CharacterSnapshot], worldRules: [WorldRuleSnapshot], initialStory: String) async throws {
        try await storeActor.createNote(["text": initialStory, "tags": tag(project.id), "createdAt": Date()])
        for character in characters { try await storeActor.createCharacter(["name": character.name, "role": character.role, "backstory": character.backstory, "createdAt": Date()]) }
        for rule in worldRules { try await storeActor.createWorldRule(["rule": rule.rule, "category": rule.category, "createdAt": Date()]) }
    }

    func savedEntityCount() async throws -> Int { try await storeActor.countAll() }
    func firstSavedStory() async throws -> String? { try await storeActor.listNotes().first }
    func savedCharacterNames() async throws -> [String] { try await storeActor.listCharacters() }
    nonisolated func directoryPath() -> String { directoryURL.path }
}

/// P0-4 fix (LT-N1-revise, 2026-08-11): `id` switched from `UUID` to
/// `String` to match `ChapterRow.id` (which is now the stable
/// `objectID.uriRepresentation()`). Was `UUID` previously because
/// `ChapterRow` was generating a fresh `UUID()` per call — see reviewer
/// §3.1.2 for the data-loss bug that caused.
struct ChapterSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let projectId: UUID
    var title: String
    var index: Int
    var wordCount: Int
    var parentId: UUID?
}

@MainActor
final class ProjectListStore: ObservableObject {
    @Published var projects: [ProjectSnapshot] = []
    let store: WenshuProjectStore
    init(store: WenshuProjectStore = .shared) { self.store = store }
    func load() async { projects = (try? await store.loadAll()) ?? [] }
    func create(name: String, style: String, verbosity: Int, tags: [String]) async { if let project = try? await store.create(name: name, style: style, waterLevel: verbosity, tags: tags) { projects.insert(project, at: 0) } }
    func delete(id: UUID) async { try? await store.delete(id: id); projects.removeAll { $0.id == id } }
}

@MainActor
final class ChapterTreeStore: ObservableObject {
    @Published var chapters: [ChapterSnapshot] = []
    let projectId: UUID
    let store: WenshuProjectStore
    init(projectId: UUID, store: WenshuProjectStore = .shared) { self.projectId = projectId; self.store = store }
    func load() async { chapters = (try? await store.listChapters(projectId: projectId)) ?? [] }
}
