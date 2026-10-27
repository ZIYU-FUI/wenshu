//
//  Persistence/WSStore.swift
//
//  The one store the whole app reads and writes.
//
//  Every repository resolves its container through this type, so the
//  app has one store instead of one per repository.
//

import Foundation
import SwiftData

/// The container a repository reads and writes.
///
/// The app has one store: the warehouse container once the app
/// activates it, the Application Support container before that. The
/// container is resolved per operation and not captured when the
/// repository is built, because `WSPersistenceContainer.current`
/// changes when the warehouse is activated (= a repository built
/// before that moment would keep reading and writing the store it saw
/// at construction time).
///
/// A caller that names a container (= a test, an isolated run) keeps
/// that container for every operation.
@MainActor
public struct WSStore {
    /// The container the caller named (= nil = the app's live store).
    private let namedContainer: ModelContainer?

    public init(container: ModelContainer? = nil) {
        self.namedContainer = container
    }

    /// The container to use right now.
    public var container: ModelContainer {
        namedContainer ?? WSPersistenceContainer.current
    }

    /// The context of the current container.
    public var context: ModelContext { container.mainContext }
}
