//
//  Persistence/WSPreferenceTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSPreference (= preferences @Model)")
struct WSPreferenceTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSPreference.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSPreference init sets key + value + updatedAt")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let before = Date()
        let pref = WSPreference(key: "appearance.mode", value: "dark")
        context.insert(pref)
        try context.save()
        let after = Date()
        let fetched = try context.fetch(FetchDescriptor<WSPreference>())
        #expect(fetched.count == 1)
        #expect(fetched[0].key == "appearance.mode")
        #expect(fetched[0].value == "dark")
        #expect(fetched[0].updatedAt >= before && fetched[0].updatedAt <= after)
    }

    @Test("WSPreference update(value:) mutates value + bumps updatedAt")
    @MainActor
    func updateValue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let pref = WSPreference(key: "k", value: "old")
        context.insert(pref)
        try context.save()
        let original = pref.updatedAt
        try? Thread.sleep(forTimeInterval: 0.05)  // v0.72 Q99 MED fix: bumped from 0.01 (= too flaky on slow CI; = needs > Date precision)
        pref.update(value: "new")
        try context.save()
        #expect(pref.value == "new")
        #expect(pref.updatedAt > original)
    }

    @Test("WSPreference key uniqueness enforced")
    @MainActor
    func keyUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSPreference(key: "dup", value: "v1")
        let b = WSPreference(key: "dup", value: "v2")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }
}
