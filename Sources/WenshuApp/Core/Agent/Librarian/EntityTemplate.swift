//
//  EntityTemplate.swift · Wenshu · v2.3 (2026-09-25)
//
//  Pure-function MD template renderer for the 5 entity kinds.
//
//  Each kind has a fixed template (= renders the entity's
//  structured fields in a stable, readable order). The body
//  markdown is the only free-form content (= user-editable via
//  update). Empty / nil structured fields render as omitted (= no
//  "nil" / "null" / "unknown" pollution).
//
//  Why pure functions (= no SwiftUI / IO / @Model access): the
//  templates are deterministic from an EntityDescriptor alone.
//  The actor layer feeds in the descriptor + the body markdown
//  (= already on disk or in SwiftData); = the template returns
//  the rendered markdown string.
//
//  Output: a single markdown string (= the body that gets
//  written to entities/<id>.md). Caller writes the file.

import Foundation

enum EntityTemplate {

    /// Render a default body for a new entity (= used when the
    /// user creates an entity without supplying body markdown).
    /// The body is the MD template filled with the descriptor's
    /// structured fields; = the user can edit it later via update.
    static func render(_ entity: EntityDescriptor) -> String {
        var lines: [String] = []
        lines.append("# \(entity.name)")
        lines.append("")
        if !entity.description.isEmpty {
            lines.append(entity.description)
            lines.append("")
        }
        renderKindFields(entity, into: &lines)
        if !lines.isEmpty {
            lines.append("")
        }
        lines.append("---")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Per-kind structured fields

    private static func renderKindFields(
        _ entity: EntityDescriptor, into lines: inout [String]
    ) {
        switch entity.kind {
        case .person:
            renderPerson(entity, into: &lines)
        case .location:
            renderLocation(entity, into: &lines)
        case .object:
            renderObject(entity, into: &lines)
        case .ability:
            renderAbility(entity, into: &lines)
        case .event:
            renderEvent(entity, into: &lines)
        }
    }

    private static func renderPerson(
        _ entity: EntityDescriptor, into lines: inout [String]
    ) {
        let ks = entity.kindSpecific
        if let role = ks.field1?.stringValue {
            lines.append("- **Role**: \(role)")
        }
        if let occupation = ks.field2?.stringValue {
            lines.append("- **Occupation**: \(occupation)")
        }
        if let affiliation = ks.field3?.stringValue {
            lines.append("- **Affiliation**: \(affiliation)")
        }
        if let arc = ks.field4?.stringValue {
            lines.append("- **Arc**: \(arc)")
        }
        if let age = ks.field5?.intValue {
            lines.append("- **Age**: \(age)")
        }
        renderCommonMetadata(entity, into: &lines)
    }

    private static func renderLocation(
        _ entity: EntityDescriptor, into lines: inout [String]
    ) {
        let ks = entity.kindSpecific
        if let type = ks.field1?.stringValue {
            lines.append("- **Location Type**: \(type)")
        }
        if let climate = ks.field2?.stringValue {
            lines.append("- **Climate / Era**: \(climate)")
        }
        if let faction = ks.field3?.stringValue {
            lines.append("- **Controlling Faction**: \(faction)")
        }
        if let danger = ks.field4?.intValue {
            lines.append("- **Danger Level**: \(danger)")
        }
        if let population = ks.field5?.intValue {
            lines.append("- **Population**: \(population)")
        }
        renderCommonMetadata(entity, into: &lines)
    }

    private static func renderObject(
        _ entity: EntityDescriptor, into lines: inout [String]
    ) {
        let ks = entity.kindSpecific
        if let type = ks.field1?.stringValue {
            lines.append("- **Object Type**: \(type)")
        }
        if let owner = ks.field2?.stringValue {
            lines.append("- **Owner**: \(owner)")
        }
        if let material = ks.field3?.stringValue {
            lines.append("- **Material**: \(material)")
        }
        if let magical = ks.field4?.boolValue {
            lines.append("- **Magical**: \(magical ? "yes" : "no")")
        }
        if let origin = ks.field5?.stringValue {
            lines.append("- **Origin**: \(origin)")
        }
        renderCommonMetadata(entity, into: &lines)
    }

    private static func renderAbility(
        _ entity: EntityDescriptor, into lines: inout [String]
    ) {
        let ks = entity.kindSpecific
        if let type = ks.field1?.stringValue {
            lines.append("- **Ability Type**: \(type)")
        }
        if let practitioner = ks.field2?.stringValue {
            lines.append("- **Practitioner**: \(practitioner)")
        }
        if let rank = ks.field3?.stringValue {
            lines.append("- **Rank**: \(rank)")
        }
        if let cost = ks.field4?.stringValue {
            lines.append("- **Cost**: \(cost)")
        }
        if let prereqs = ks.field5?.stringArrayValue, !prereqs.isEmpty {
            lines.append("- **Prerequisites**: \(prereqs.joined(separator: ", "))")
        }
        renderCommonMetadata(entity, into: &lines)
    }

    private static func renderEvent(
        _ entity: EntityDescriptor, into lines: inout [String]
    ) {
        let ks = entity.kindSpecific
        if let type = ks.field1?.stringValue {
            lines.append("- **Event Type**: \(type)")
        }
        if let participants = ks.field2?.stringArrayValue, !participants.isEmpty {
            lines.append("- **Participants**: \(participants.joined(separator: ", "))")
        }
        if let location = ks.field3?.stringValue {
            lines.append("- **Location**: \(location)")
        }
        if let startDate = ks.field4?.stringValue {
            lines.append("- **Start Date**: \(startDate)")
        }
        if let endDate = ks.field5?.stringValue {
            lines.append("- **End Date**: \(endDate)")
        }
        renderCommonMetadata(entity, into: &lines)
    }

    /// Common metadata (= aliases / tags / attributes).
    private static func renderCommonMetadata(
        _ entity: EntityDescriptor, into lines: inout [String]
    ) {
        if !entity.aliases.isEmpty {
            lines.append("- **Aliases**: \(entity.aliases.joined(separator: ", "))")
        }
        if !entity.tags.isEmpty {
            lines.append("- **Tags**: \(entity.tags.joined(separator: ", "))")
        }
        if !entity.attributes.isEmpty {
            let sortedKeys = entity.attributes.keys.sorted()
            for key in sortedKeys {
                guard let value = entity.attributes[key] else { continue }
                lines.append("- **\(key.capitalized)**: \(value)")
            }
        }
    }
}