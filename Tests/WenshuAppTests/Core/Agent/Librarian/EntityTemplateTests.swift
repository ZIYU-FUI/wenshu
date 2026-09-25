//
//  EntityTemplateTests.swift · Wenshu · v2.3 (2026-09-25)
//
//  Tests for the 5 MD template renderers.
//
//  Verifies:
//  - Person with all fields renders role, occupation, affiliation,
//    arc, age.
//  - Location renders locationType, climate, faction, dangerLevel,
//    population.
//  - Object renders objectType, owner, material, magical, origin.
//  - Ability renders abilityType, practitioner, rank, cost,
//    prerequisites.
//  - Event renders eventType, participants, location, dates.
//  - Common metadata (= aliases / tags / attributes) renders for
//    every kind.
//  - Empty / nil fields are omitted (= no "nil" / "null" pollution).
//  - The header (# <name>) + description + footer (---) are
//    always present.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("EntityTemplate (v2.3)")
struct EntityTemplateTests {

    // MARK: - Person

    @Test func person_rendersAllFields() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .person,
            name: "Lin Fan",
            aliases: ["凡人"],
            tags: ["main"],
            description: "Main character of the story.",
            attributes: ["hairColor": "black"],
            kindSpecific: EntityKindSpecific(
                field1: .string("protagonist"),
                field2: .string("constable"),
                field3: .string("Sword Sect"),
                field4: .string("redemption"),
                field5: .int(24)
            )
        )
        let body = EntityTemplate.render(desc)
        #expect(body.contains("# Lin Fan"))
        #expect(body.contains("Main character of the story."))
        #expect(body.contains("**Role**: protagonist"))
        #expect(body.contains("**Occupation**: constable"))
        #expect(body.contains("**Affiliation**: Sword Sect"))
        #expect(body.contains("**Arc**: redemption"))
        #expect(body.contains("**Age**: 24"))
        #expect(body.contains("**Aliases**: 凡人"))
        #expect(body.contains("**Tags**: main"))
        #expect(body.contains("**Haircolor**: black"))
        #expect(body.hasSuffix("---") || body.hasSuffix("---\n"))
    }

    @Test func person_omitsEmptyFields() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .person,
            name: "Empty Person"
        )
        let body = EntityTemplate.render(desc)
        #expect(body.contains("# Empty Person"))
        #expect(body.hasSuffix("---") || body.hasSuffix("---\n"))
        #expect(!body.contains("Role:"))
        #expect(!body.contains("nil"))
    }

    // MARK: - Location

    @Test func location_rendersAllFields() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .location,
            name: "Beijing",
            aliases: [],
            tags: [],
            description: "",
            attributes: [:],
            kindSpecific: EntityKindSpecific(
                field1: .string("city"),
                field2: .string("temperate"),
                field3: .string("Ming Court"),
                field4: .int(3),
                field5: .int(1_000_000)
            )
        )
        let body = EntityTemplate.render(desc)
        #expect(body.contains("**Location Type**: city"))
        #expect(body.contains("**Climate / Era**: temperate"))
        #expect(body.contains("**Controlling Faction**: Ming Court"))
        #expect(body.contains("**Danger Level**: 3"))
        #expect(body.contains("**Population**: 1000000"))
    }

    // MARK: - Object

    @Test func object_rendersAllFields() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .object,
            name: "Jade Sword",
            aliases: [],
            tags: [],
            description: "",
            attributes: [:],
            kindSpecific: EntityKindSpecific(
                field1: .string("sword"),
                field2: .string("Lin Fan"),
                field3: .string("jade"),
                field4: .bool(true),
                field5: .string("Northern Mountains")
            )
        )
        let body = EntityTemplate.render(desc)
        #expect(body.contains("**Object Type**: sword"))
        #expect(body.contains("**Owner**: Lin Fan"))
        #expect(body.contains("**Material**: jade"))
        #expect(body.contains("**Magical**: yes"))
        #expect(body.contains("**Origin**: Northern Mountains"))
    }

    @Test func object_rendersMagicalNo() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .object,
            name: "Plain Sword",
            aliases: [],
            tags: [],
            description: "",
            attributes: [:],
            kindSpecific: EntityKindSpecific(
                field1: .string("sword"),
                field4: .bool(false)
            )
        )
        let body = EntityTemplate.render(desc)
        #expect(body.contains("**Magical**: no"))
    }

    // MARK: - Ability

    @Test func ability_rendersAllFields() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .ability,
            name: "Sword Technique",
            aliases: [],
            tags: [],
            description: "",
            attributes: [:],
            kindSpecific: EntityKindSpecific(
                field1: .string("combat"),
                field2: .string("Lin Fan"),
                field3: .string("intermediate"),
                field4: .string("qi cost"),
                field5: .stringArray(["basic sword", "qi sense"])
            )
        )
        let body = EntityTemplate.render(desc)
        #expect(body.contains("**Ability Type**: combat"))
        #expect(body.contains("**Practitioner**: Lin Fan"))
        #expect(body.contains("**Rank**: intermediate"))
        #expect(body.contains("**Cost**: qi cost"))
        #expect(body.contains("**Prerequisites**: basic sword, qi sense"))
    }

    // MARK: - Event

    @Test func event_rendersAllFields() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .event,
            name: "Battle of Beijing",
            aliases: [],
            tags: [],
            description: "",
            attributes: [:],
            kindSpecific: EntityKindSpecific(
                field1: .string("battle"),
                field2: .stringArray(["Lin Fan", "Wang Yuyan"]),
                field3: .string("Beijing"),
                field4: .string("Year 1449"),
                field5: .string("Year 1449 + 7 days")
            )
        )
        let body = EntityTemplate.render(desc)
        #expect(body.contains("**Event Type**: battle"))
        #expect(body.contains("**Participants**: Lin Fan, Wang Yuyan"))
        #expect(body.contains("**Location**: Beijing"))
        #expect(body.contains("**Start Date**: Year 1449"))
        #expect(body.contains("**End Date**: Year 1449 + 7 days"))
    }

    // MARK: - Common metadata

    @Test func commonMetadata_skipsEmpty() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .person,
            name: "Plain"
        )
        let body = EntityTemplate.render(desc)
        #expect(!body.contains("**Aliases**:"))
        #expect(!body.contains("**Tags**:"))
    }

    @Test func attributesAreSortedByKey() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .person,
            name: "Sorted Test",
            attributes: ["zebra": "z", "alpha": "a", "middle": "m"]
        )
        let body = EntityTemplate.render(desc)
        let alphaIdx = body.range(of: "**Alpha**:")?.lowerBound
        let middleIdx = body.range(of: "**Middle**:")?.lowerBound
        let zebraIdx = body.range(of: "**Zebra**:")?.lowerBound
        #expect(alphaIdx != nil)
        #expect(middleIdx != nil)
        #expect(zebraIdx != nil)
        #expect(alphaIdx! < middleIdx!)
        #expect(middleIdx! < zebraIdx!)
    }

    // MARK: - Structural invariants

    @Test func renderAlwaysEndsWithFooter() {
        let kinds: [EntityKind] = [.person, .location, .object, .ability, .event]
        for kind in kinds {
            let desc = EntityDescriptor(
                id: EntityID.newID(),
                bookID: BookID.newID(),
                kind: kind,
                name: "Test \(kind.rawValue)"
            )
            let body = EntityTemplate.render(desc)
            #expect(body.hasSuffix("---") || body.hasSuffix("---\n"))
        }
    }

    @Test func renderAlwaysHasHeader() {
        let desc = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .person,
            name: "HeaderTest"
        )
        let body = EntityTemplate.render(desc)
        let firstLine = body.split(separator: "\n").first
        #expect(firstLine == "# HeaderTest")
    }
}