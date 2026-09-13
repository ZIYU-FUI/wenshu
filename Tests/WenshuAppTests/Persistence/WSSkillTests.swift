//
//  Persistence/WSSkillTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSSkill (= skills @Model)")
struct WSSkillTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSSkill.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSSkill init sets all fields")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let skill = WSSkill(
            name: "reviewer",
            description: "code review helper",
            source: "bundled",
            trustLevel: "trusted",
            path: "/usr/share/wenshu/skills/reviewer"
        )
        context.insert(skill)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSSkill>())
        #expect(fetched.count == 1)
        #expect(fetched[0].name == "reviewer")
        #expect(fetched[0].skillDescription == "code review helper")
        #expect(fetched[0].source == "bundled")
        #expect(fetched[0].trustLevel == "trusted")
        #expect(fetched[0].path == "/usr/share/wenshu/skills/reviewer")
    }

    @Test("WSSkill name uniqueness enforced")
    @MainActor
    func nameUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSSkill(name: "dup", description: "a", source: "s", trustLevel: "trusted", path: "p")
        let b = WSSkill(name: "dup", description: "b", source: "s2", trustLevel: "trusted", path: "p2")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }

    @Test("WSSkill trust level changes accepted (= any of 3 hermes values)")
    @MainActor
    func trustLevelAnyValue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let skill = WSSkill(name: "x", description: "d", source: "s", trustLevel: "trusted", path: "p")
        context.insert(skill)
        for level in ["trusted", "experimental", "blocked"] {
            skill.trustLevel = level
            try context.save()
            #expect(skill.trustLevel == level)
        }
    }
}
