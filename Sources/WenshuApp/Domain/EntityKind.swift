//
//  EntityKind.swift · Wenshu · v2.3 (2026-09-25)
//
//  The 5-layer kind taxonomy (= person / location / object /
//  ability / event). Top-level enum = closed (= the v2.4 product
//  stance: closed-enum pickers, not free-text role entry). All
//  fine-grained roles (= "mentor" / "spirit beast" / "swordsman")
//  are expressed as tags on the Person / Object / Ability entries —
//  not as enum cases.
//
//  Value object (= immutable struct / enum; = no identity). Used
//  by WSEntity, FileSystemEntityStore, BookEntityTool, etc.
//

import Foundation

// MARK: - Top-level kind

enum EntityKind: String, Codable, Sendable, CaseIterable {
    case person
    case location
    case object
    case ability
    case event
}

// MARK: - Person role sub-enum

/// Sub-role for the `.person` kind. Open-ish (= a tag is allowed
/// to differ from a role); the role here is the LLM-prompted
/// default. A "mentor" is `.supporting` with `tags: ["mentor"]`.
enum PersonRole: String, Codable, Sendable {
    case protagonist
    case antagonist
    case deuteragonist
    case tritagonist
    case supporting
    case narrator
    case other
}

// MARK: - Kind-specific value (5 fields per kind)

/// Per-kind enum bag (= 5 fields × kind). The shape is the same
/// across kinds; the meaning of the 5 fields differs (= see
/// spec.md table).
///
/// All fields are optional (= can be omitted). Empty / null is
/// rendered as "skip" in the MD template (= no null pollution).
struct EntityKindSpecific: Codable, Sendable, Equatable {
    var field1: KindSpecificValue?
    var field2: KindSpecificValue?
    var field3: KindSpecificValue?
    var field4: KindSpecificValue?
    var field5: KindSpecificValue?

    init(
        field1: KindSpecificValue? = nil,
        field2: KindSpecificValue? = nil,
        field3: KindSpecificValue? = nil,
        field4: KindSpecificValue? = nil,
        field5: KindSpecificValue? = nil
    ) {
        self.field1 = field1
        self.field2 = field2
        self.field3 = field3
        self.field4 = field4
        self.field5 = field5
    }

    /// Empty (= all 5 fields nil).
    static let empty = EntityKindSpecific()
}

enum KindSpecificValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case stringArray([String])

    // MARK: Convenience accessors

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var stringArrayValue: [String]? {
        if case .stringArray(let a) = self { return a }
        return nil
    }

    // MARK: Codable

    private enum Tag: String, Codable {
        case string, int, bool, stringArray
    }

    private enum CodingKeys: String, CodingKey {
        case tag, value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try container.decode(Tag.self, forKey: .tag)
        switch tag {
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        case .int:
            self = .int(try container.decode(Int.self, forKey: .value))
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case .stringArray:
            self = .stringArray(try container.decode([String].self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let s):
            try container.encode(Tag.string, forKey: .tag)
            try container.encode(s, forKey: .value)
        case .int(let i):
            try container.encode(Tag.int, forKey: .tag)
            try container.encode(i, forKey: .value)
        case .bool(let b):
            try container.encode(Tag.bool, forKey: .tag)
            try container.encode(b, forKey: .value)
        case .stringArray(let a):
            try container.encode(Tag.stringArray, forKey: .tag)
            try container.encode(a, forKey: .value)
        }
    }
}