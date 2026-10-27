//
//  Persistence/Repositories/WSPreferenceRepository.swift
//
//  Migration commit 32 of 42: WSPreferenceRepository.
//  Per AGENTS.md §11.4.
//
//  Thin wrapper for the `preferences` table from WenshuWorkspace.swift.
//  Generic K/V store (= prefer typed settings on the relevant @Model or
//  @Observable class; = use sparingly).
//
//  Public API:
//    - set(key:value:) throws
//    - get(key:) -> String?
//    - remove(key:) throws
//    - allKeys() -> [String]

import Foundation
import SwiftData

@MainActor
public final class WSPreferenceRepository {
    /// The store this repository reads and writes.
    ///
    /// A named container (= a test, an isolated run) is used as it is.
    /// Without one the repository reads and writes the app's live store
    /// (= the warehouse once it is activated), resolved per operation:
    /// the live store changes when the warehouse is activated, so a
    /// repository built before that moment must not keep the store it
    /// saw at construction time.
    public let store: WSStore
    private var context: ModelContext { store.context }

    public init(container: ModelContainer? = nil) {
        self.store = WSStore(container: container)
    }

    public func set(key: String, value: String) throws {
        let descriptor = FetchDescriptor<WSPreference>(
            predicate: #Predicate { $0.key == key }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(value: value)
        } else {
            let model = WSPreference(key: key, value: value)
            context.insert(model)
        }
        try context.save()
    }

    public func get(key: String) throws -> String? {
        let descriptor = FetchDescriptor<WSPreference>(
            predicate: #Predicate { $0.key == key }
        )
        return try context.fetch(descriptor).first?.value
    }

    public func remove(key: String) throws {
        let descriptor = FetchDescriptor<WSPreference>(
            predicate: #Predicate { $0.key == key }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    public func allKeys() throws -> [String] {
        let descriptor = FetchDescriptor<WSPreference>(
            sortBy: [SortDescriptor(\.key)]
        )
        return try context.fetch(descriptor).map { $0.key }
    }
}
