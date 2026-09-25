//
//  EntityKindTests.swift · Wenshu · v2.3 (2026-09-25)
//
//  Tests for the 5-layer kind enum + PersonRole sub-enum +
//  EntityKindSpecific struct + KindSpecificValue enum.
//
//  Verifies:
//  - All 5 kinds are reachable via CaseIterable.
//  - PersonRole round-trips through rawValue.
//  - EntityKindSpecific.empty has all 5 fields nil.
//  - KindSpecificValue round-trips through Codable for each
//    of its 4 cases (string / int / bool / stringArray).
//

import Testing
import Foundation
@testable import WenshuApp

// MARK: - EntityKind

@Suite("EntityKind (v2.3)")
struct EntityKindTests {

    @Test func allFiveKindsArePresent() {
        let all = EntityKind.allCases
        #expect(all.count == 5)
        #expect(all.contains(.person))
        #expect(all.contains(.location))
        #expect(all.contains(.object))
        #expect(all.contains(.ability))
        #expect(all.contains(.event))
    }

    @Test func kindRawValuesMatchSpec() {
        // Raw values are user-facing / stable (= persisted in
        // entities.json). Per the spec, these are the canonical
        // snake_case forms.
        #expect(EntityKind.person.rawValue == "person")
        #expect(EntityKind.location.rawValue == "location")
        #expect(EntityKind.object.rawValue == "object")
        #expect(EntityKind.ability.rawValue == "ability")
        #expect(EntityKind.event.rawValue == "event")
    }

    @Test func kindRoundTripsThroughRawValue() {
        for kind in EntityKind.allCases {
            let parsed = EntityKind(rawValue: kind.rawValue)
            #expect(parsed == kind)
        }
    }

    @Test func kindRoundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for kind in EntityKind.allCases {
            let data = try encoder.encode(kind)
            let decoded = try decoder.decode(EntityKind.self, from: data)
            #expect(decoded == kind)
        }
    }
}

// MARK: - PersonRole

@Suite("PersonRole (v2.3)")
struct PersonRoleTests {

    @Test func allRolesRoundTrip() {
        let roles: [PersonRole] = [
            .protagonist, .antagonist, .deuteragonist,
            .tritagonist, .supporting, .narrator, .other
        ]
        for role in roles {
            let parsed = PersonRole(rawValue: role.rawValue)
            #expect(parsed == role)
        }
    }
}

// MARK: - EntityKindSpecific

@Suite("EntityKindSpecific (v2.3)")
struct EntityKindSpecificTests {

    @Test func emptyHasAllFiveFieldsNil() {
        let empty = EntityKindSpecific.empty
        #expect(empty.field1 == nil)
        #expect(empty.field2 == nil)
        #expect(empty.field3 == nil)
        #expect(empty.field4 == nil)
        #expect(empty.field5 == nil)
    }

    @Test func customInitializerStoresEachField() {
        let specific = EntityKindSpecific(
            field1: .string("主角"),
            field2: .int(24),
            field3: .bool(true),
            field4: .stringArray(["师父", "张三"]),
            field5: .string("修道")
        )
        #expect(specific.field1?.stringValue == "主角")
        #expect(specific.field2?.intValue == 24)
        #expect(specific.field3?.boolValue == true)
        #expect(specific.field4?.stringArrayValue == ["师父", "张三"])
        #expect(specific.field5?.stringValue == "修道")
    }

    @Test func roundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let original = EntityKindSpecific(
            field1: .string("主角"),
            field2: .int(24),
            field3: .bool(false),
            field4: .stringArray(["tag1", "tag2"]),
            field5: .string("note")
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EntityKindSpecific.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - KindSpecificValue

@Suite("KindSpecificValue (v2.3)")
struct KindSpecificValueTests {

    @Test func stringValueAccessor() {
        let value: KindSpecificValue = .string("hello")
        #expect(value.stringValue == "hello")
        #expect(value.intValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.stringArrayValue == nil)
    }

    @Test func intValueAccessor() {
        let value: KindSpecificValue = .int(42)
        #expect(value.intValue == 42)
        #expect(value.stringValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.stringArrayValue == nil)
    }

    @Test func boolValueAccessor() {
        let value: KindSpecificValue = .bool(true)
        #expect(value.boolValue == true)
        #expect(value.stringValue == nil)
        #expect(value.intValue == nil)
        #expect(value.stringArrayValue == nil)
    }

    @Test func stringArrayValueAccessor() {
        let value: KindSpecificValue = .stringArray(["a", "b"])
        #expect(value.stringArrayValue == ["a", "b"])
        #expect(value.stringValue == nil)
        #expect(value.intValue == nil)
        #expect(value.boolValue == nil)
    }

    @Test func allFourCasesRoundTripThroughJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let values: [KindSpecificValue] = [
            .string("s"),
            .int(7),
            .bool(false),
            .stringArray(["x", "y", "z"])
        ]
        for value in values {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(KindSpecificValue.self, from: data)
            #expect(decoded == value)
        }
    }
}