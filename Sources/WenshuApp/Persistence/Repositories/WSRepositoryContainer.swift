//
//  Persistence/Repositories/WSRepositoryContainer.swift · Wenshu · v0.72 SwiftData migration Phase 3
//
//  Migration commit 33 of 42: Repository singletons + WSRepositoryContainer.
//  Per AGENTS.md §11.4.
//
//  Adds a `shared` static singleton to each of the 9 Repositories (= matches
//  the old actor-construction pattern: call sites do `try await X.shared.add(...)`).
//  Plus a WSRepositoryContainer that bundles all 9 into a single @MainActor
//  @Observable singleton (= apps that want one entry point can pass it down
//  via SwiftUI .environment).
//
//  All singletons share the same WSPersistenceContainer (= single ModelContainer
//  shared across all 9 repositories).

import Foundation
import SwiftData

/// One-stop entry point holding all 9 Repositories.
/// Apps inject this via SwiftUI .environment(\.repositoryContainer).
///
/// NOTE: 9 of the 23 SwiftData @Model classes have a Repository (= the 9 listed below).
/// The remaining 14 (@Model classes for sub-types like WSAttachment, WSForeshadowing,
/// WSPlaceholder, WSOutlineNode, WSOutlineDocument, etc.) are accessed directly via
/// WSPersistenceContainer.shared (= no repository layer needed; = they're either
/// transient view data or simple CRUD wrappers).
@MainActor
@Observable
public final class WSRepositoryContainer {
    public let memory: WSMemoryRepository
    public let chat: WSChatRepository
    public let todo: WSTodoRepository
    public let bookmark: WSBookmarkRepository
    public let kanban: WSKanbanRepository
    public let link: WSLinkRepository
    public let book: WSBookRepository
    public let providerKey: WSProviderKeyRepository
    public let preference: WSPreferenceRepository

    public init(container: ModelContainer = WSPersistenceContainer.current) {
        self.memory = WSMemoryRepository(container: container)
        self.chat = WSChatRepository(container: container)
        self.todo = WSTodoRepository(container: container)
        self.bookmark = WSBookmarkRepository(container: container)
        self.kanban = WSKanbanRepository(container: container)
        self.link = WSLinkRepository(container: container)
        self.book = WSBookRepository(container: container)
        self.providerKey = WSProviderKeyRepository(container: container)
        self.preference = WSPreferenceRepository(container: container)
    }

    public static let shared: WSRepositoryContainer = {
        MainActor.assumeIsolated {
            WSRepositoryContainer()
        }
    }()
}

// MARK: - Per-Repository singletons (= for call sites that want only one repo)

extension WSMemoryRepository {
    @MainActor public static let shared = WSMemoryRepository()
}
extension WSChatRepository {
    @MainActor public static let shared = WSChatRepository()
}
extension WSTodoRepository {
    @MainActor public static let shared = WSTodoRepository()
}
extension WSBookmarkRepository {
    @MainActor public static let shared = WSBookmarkRepository()
}
extension WSKanbanRepository {
    @MainActor public static let shared = WSKanbanRepository()
}
extension WSLinkRepository {
    @MainActor public static let shared = WSLinkRepository()
}
extension WSBookRepository {
    @MainActor public static let shared = WSBookRepository()
}
extension WSProviderKeyRepository {
    @MainActor public static let shared = WSProviderKeyRepository()
}
extension WSPreferenceRepository {
    @MainActor public static let shared = WSPreferenceRepository()
}
