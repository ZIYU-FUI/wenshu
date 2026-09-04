// PlotThreadTools.swift · Wenshu · P1 ticket #8
import Foundation

public enum PlotThreadStatus: String, Sendable, Codable, CaseIterable {
    case open, developing, resolved, abandoned
}

public struct PlotThread: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let bookId: UUID
    public let title: String
    public let status: PlotThreadStatus
    public let introducedIn: UUID?
    public let lastReferencedIn: UUID?
    public let description: String
    public let setupExcerpt: String
    public let payoffExcerpt: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), bookId: UUID, title: String, status: PlotThreadStatus = .open,
                introducedIn: UUID? = nil, lastReferencedIn: UUID? = nil, description: String = "",
                setupExcerpt: String = "", payoffExcerpt: String? = nil, createdAt: Date = .now) {
        self.id = id; self.bookId = bookId; self.title = title; self.status = status
        self.introducedIn = introducedIn; self.lastReferencedIn = lastReferencedIn
        self.description = description; self.setupExcerpt = setupExcerpt
        self.payoffExcerpt = payoffExcerpt; self.createdAt = createdAt
    }
}

public actor PlotThreadTracker {
    private let store: BookProjectConfigStore
    private var threads: [UUID: [PlotThread]] = [:]

    init(bookStore: BookStore) {
        self.store = BookProjectConfigStore(projectRoot: bookStore.stores.referenceLibraryRoot.deletingLastPathComponent())
    }

    public init(projectRoot: URL) { self.store = BookProjectConfigStore(projectRoot: projectRoot) }

    public func add(_ thread: PlotThread) async throws {
        var values = try await load(bookId: thread.bookId)
        values.removeAll { $0.id == thread.id }
        values.append(thread)
        try await save(values, bookId: thread.bookId)
    }

    public func update(_ thread: PlotThread) async throws {
        var values = try await load(bookId: thread.bookId)
        guard let index = values.firstIndex(where: { $0.id == thread.id }) else { return }
        values[index] = thread
        try await save(values, bookId: thread.bookId)
    }

    public func remove(id: UUID) async throws {
        for bookId in threads.keys {
            var values = try await load(bookId: bookId)
            let filtered = values.filter { $0.id != id }
            if filtered.count != values.count { try await save(filtered, bookId: bookId) }
        }
    }

    public func list(bookId: UUID, status: PlotThreadStatus? = nil) async throws -> [PlotThread] {
        let values = try await load(bookId: bookId)
        return values.filter { status == nil || $0.status == status }.sorted { $0.createdAt < $1.createdAt }
    }

    public func staleThreads(bookId: UUID) async throws -> [PlotThread] {
        let values = try await load(bookId: bookId)
        let referenced = Set(values.compactMap(\.lastReferencedIn))
        let chapters = values.compactMap(\.introducedIn)
        let recent = Set(chapters.suffix(3))
        return values.filter { $0.status == .open || $0.status == .developing }
            .filter { $0.lastReferencedIn == nil || !recent.contains($0.lastReferencedIn!) || !referenced.contains($0.lastReferencedIn!) }
    }

    public func recyclingMap(bookId: UUID) async throws -> [UUID: [UUID]] {
        let values = try await load(bookId: bookId)
        var result: [UUID: [UUID]] = [:]
        for thread in values {
            if let chapter = thread.introducedIn { result[chapter, default: []].append(thread.id) }
            if let chapter = thread.lastReferencedIn, chapter != thread.introducedIn { result[chapter, default: []].append(thread.id) }
        }
        return result
    }

    private func load(bookId: UUID) async throws -> [PlotThread] {
        if let cached = threads[bookId] { return cached }
        let config = try await store.loadConfig(bookId: bookId)
        let decoded = config.flatMap { try? JSONDecoder().decode([PlotThread].self, from: Data($0.defaultChapterTemplate.utf8)) } ?? []
        threads[bookId] = decoded
        return decoded
    }

    private func save(_ values: [PlotThread], bookId: UUID) async throws {
        threads[bookId] = values
        let data = try JSONEncoder().encode(values)
        var config = (try await store.loadConfig(bookId: bookId)) ?? BookProjectConfig(bookId: bookId)
        config.defaultChapterTemplate = String(decoding: data, as: UTF8.self)
        try await store.saveConfig(config)
    }
}
