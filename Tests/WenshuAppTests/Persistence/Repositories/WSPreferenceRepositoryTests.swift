//
//  Persistence/Repositories/WSPreferenceRepositoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 2

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSPreferenceRepository (= SwiftData @Model generic K/V store)")
struct WSPreferenceRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSPreferenceRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSPreferenceRepository(container: container)
    }

    @Test("set + get round-trip")
    @MainActor
    func setAndGet() throws {
        let repo = try makeRepository()
        try repo.set(key: "appearance.mode", value: "dark")
        let value = try repo.get(key: "appearance.mode")
        #expect(value == "dark")
    }

    @Test("set overwrites existing value")
    @MainActor
    func overwrite() throws {
        let repo = try makeRepository()
        try repo.set(key: "k", value: "old")
        try repo.set(key: "k", value: "new")
        #expect(try repo.get(key: "k") == "new")
    }

    @Test("get returns nil for missing key")
    @MainActor
    func getMissing() throws {
        let repo = try makeRepository()
        let value = try repo.get(key: "nope")
        #expect(value == nil)
    }

    @Test("remove deletes the row")
    @MainActor
    func remove() throws {
        let repo = try makeRepository()
        try repo.set(key: "k", value: "v")
        try repo.remove(key: "k")
        let value = try repo.get(key: "k")
        #expect(value == nil)
    }

    @Test("allKeys returns all stored keys")
    @MainActor
    func allKeys() throws {
        let repo = try makeRepository()
        try repo.set(key: "k1", value: "v1")
        try repo.set(key: "k2", value: "v2")
        try repo.set(key: "k3", value: "v3")
        let keys = try repo.allKeys()
        #expect(Set(keys) == Set(["k1", "k2", "k3"]))
    }
}
