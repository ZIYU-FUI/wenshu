//
//  EntityDescriptorTests.swift · Wenshu · v2.3 (2026-09-25)
//
//  Tests for EntityID brand wrapper + EntityDescriptor value
//  type + BodyExcerpt helper.
//
//  Verifies:
//  - EntityID conforms to TypedID, Round-trips rawValue, .newID
//    produces unique UUIDs, == by rawValue.
//  - EntityDescriptor default initializer populates every field;
//    round-trips through Codable.
//  - BodyExcerpt.make returns full body when under 200 chars,
//    truncates at line break when longer, falls back to ellipsis.
//

import Testing
import Foundation
@testable import WenshuApp

// MARK: - EntityID

@Suite("EntityID (v2.3)")
struct EntityIDTests {

    @Test func newID_ProducesUniqueUUID() {
        let a = EntityID.newID()
        let b = EntityID.newID()
        #expect(a != b)
        #expect(!a.rawValue.isEmpty)
    }

    @Test func rawValueRoundTrip() {
        let uuid = "12345678-1234-1234-1234-123456789012"
        let id = EntityID(rawValue: uuid)
        #expect(id.rawValue == uuid)
    }

    @Test func equalityIsByRawValue() {
        let a = EntityID(rawValue: "abc")
        let b = EntityID(rawValue: "abc")
        let c = EntityID(rawValue: "def")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func hashableByRawValue() {
        let id1 = EntityID(rawValue: "abc")
        let id2 = EntityID(rawValue: "abc")
        var set: Set<EntityID> = []
        set.insert(id1)
        set.insert(id2)
        #expect(set.count == 1)
    }

    @Test func codableRoundTrip() throws {
        let id = EntityID.newID()
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(EntityID.self, from: data)
        #expect(decoded == id)
    }
}

// MARK: - EntityDescriptor

@Suite("EntityDescriptor (v2.3)")
struct EntityDescriptorTests {

    @Test func defaultInitializerPopulatesEveryField() {
        let bookID = BookID.newID()
        let id = EntityID.newID()
        let descriptor = EntityDescriptor(
            id: id,
            bookID: bookID,
            kind: .person,
            name: "Lin Fan",
            aliases: ["凡人"],
            tags: ["主角", "修道"],
            description: "Main character",
            attributes: ["hairColor": "black"],
            kindSpecific: EntityKindSpecific(
                field1: .string("protagonist"),
                field2: .int(24)
            ),
            bodyExcerpt: "Lin Fan is...",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        #expect(descriptor.id == id)
        #expect(descriptor.bookID == bookID)
        #expect(descriptor.kind == .person)
        #expect(descriptor.name == "Lin Fan")
        #expect(descriptor.aliases == ["凡人"])
        #expect(descriptor.tags == ["主角", "修道"])
        #expect(descriptor.description == "Main character")
        #expect(descriptor.attributes["hairColor"] == "black")
        #expect(descriptor.kindSpecific.field1?.stringValue == "protagonist")
        #expect(descriptor.kindSpecific.field2?.intValue == 24)
        #expect(descriptor.bodyExcerpt == "Lin Fan is...")
    }

    @Test func defaultValuesAreEmpty() {
        let descriptor = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .location,
            name: "Beijing"
        )
        #expect(descriptor.aliases.isEmpty)
        #expect(descriptor.tags.isEmpty)
        #expect(descriptor.description.isEmpty)
        #expect(descriptor.attributes.isEmpty)
        #expect(descriptor.kindSpecific == .empty)
        #expect(descriptor.bodyExcerpt.isEmpty)
    }

    @Test func roundTripsThroughJSON() throws {
        let original = EntityDescriptor(
            id: EntityID.newID(),
            bookID: BookID.newID(),
            kind: .ability,
            name: "御剑术",
            aliases: ["御剑"],
            tags: ["剑修", "主动技能"],
            description: "以气御剑",
            attributes: ["element": "金"],
            kindSpecific: EntityKindSpecific(
                field1: .string("sword"),
                field2: .stringArray(["剑修", "气御"])
            ),
            bodyExcerpt: "剑者..."
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EntityDescriptor.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - BodyExcerpt

@Suite("BodyExcerpt (v2.3)")
struct BodyExcerptTests {

    @Test func shortBodyReturnsFull() {
        let body = "Hello, world."
        #expect(BodyExcerpt.make(from: body) == body)
    }

    @Test func exactlyMaxLengthReturnsFull() {
        let body = String(repeating: "a", count: BodyExcerpt.maxLength)
        #expect(BodyExcerpt.make(from: body) == body)
    }

    @Test func longBodyTruncatesAtLineBreak() {
        // First newline occurs before the maxLength cutoff.
        // Body itself is much longer than maxLength so we
        // exercise the truncate-at-newline branch.
        let firstLine = String(repeating: "a", count: 80)
        let secondLine = String(repeating: "b", count: 200)
        let body = "\(firstLine)\n\(secondLine)"
        let excerpt = BodyExcerpt.make(from: body)
        #expect(excerpt == firstLine)
        #expect(!excerpt.contains("b"))
    }

    @Test func longBodyWithoutNewlineGetsEllipsis() {
        let body = String(repeating: "x", count: BodyExcerpt.maxLength + 50)
        let excerpt = BodyExcerpt.make(from: body)
        #expect(excerpt.hasSuffix("…"))
        #expect(excerpt.count <= BodyExcerpt.maxLength + 1)
    }
}