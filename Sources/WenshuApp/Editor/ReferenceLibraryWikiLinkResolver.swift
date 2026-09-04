// Sources/WenshuApp/Editor/ReferenceLibraryWikiLinkResolver.swift
//
// v0.39 ticket 001 -- WikiLinkResolver conformance that searches
// wenshu's reference-library 4-layer structure for entities matching
// the wiki-link display name. Engine calls this synchronously from
// the styler; wenshu does a single-pass filesystem read (= ~1ms for
// libraries with < 10k entities).
//
// Real API (verified 2026-09-04 from swift-markdown-engine 0.12.0 source):
//   protocol WikiLinkResolver: Sendable {
//     func resolve(displayName: String, range: NSRange) -> WikiLinkResolution?
//     func name(forID id: String) -> String?
//     func fingerprint() -> AnyHashable
//   }
//   struct WikiLinkResolution: Sendable, Equatable {
//     let id: String      // NON-optional
//     let exists: Bool
//   }
// `name(forID:)` and `fingerprint()` have default implementations on
// the protocol (= we override fingerprint() so a rename refreshes link
// display; name(forID:) default returns nil = renderer falls back to
// the stored label).

import Foundation
import CryptoKit
import MarkdownEngine

struct ReferenceLibraryWikiLinkResolver: WikiLinkResolver {
    let referenceLibraryRoot: URL  // = library's reference-library/

    func resolve(displayName: String, range: NSRange) -> WikiLinkResolution? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Search entities/ for matching name field (= case-insensitive).
        // Engine guarantees synchronous call (per MarkdownEditorServices
        // doc comment); wenshu resolution is filesystem read = ~1ms.
        let entitiesDir = referenceLibraryRoot.appendingPathComponent("entities")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: entitiesDir, includingPropertiesForKeys: nil
        ) else {
            return WikiLinkResolution(id: "", exists: false)
        }
        for entry in entries where entry.pathExtension == "json" {
            guard let data = try? Data(contentsOf: entry),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = json["name"] as? String,
                  name.caseInsensitiveCompare(trimmed) == .orderedSame,
                  let id = json["id"] as? String else { continue }
            return WikiLinkResolution(id: id, exists: true)
        }
        // Miss: engine stores link as `[[Name]]` (no id) when resolution
        // returns id="" — no id needed because target doesn't
        // exist (= link displays in gray dashed style per engine default).
        return WikiLinkResolution(id: "", exists: false)
    }

    func name(forID id: String) -> String? {
        // Reverse lookup: id -> name. Engine uses this for `[[Name|<id>]]`
        // storage form to render the latest name when the entity has been
        // renamed since the link was written.
        let entitiesDir = referenceLibraryRoot.appendingPathComponent("entities")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: entitiesDir, includingPropertiesForKeys: nil
        ) else { return nil }
        for entry in entries where entry.pathExtension == "json" {
            guard let data = try? Data(contentsOf: entry),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entryID = json["id"] as? String,
                  entryID == id,
                  let name = json["name"] as? String else { continue }
            return name
        }
        return nil
    }

    func fingerprint() -> AnyHashable {
        // Hash of (id + name) for every known entity. Renaming an entity
        // changes the hash = engine restyles wiki-links without waiting
        // for the next keystroke.
        let entitiesDir = referenceLibraryRoot.appendingPathComponent("entities")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: entitiesDir, includingPropertiesForKeys: nil
        ) else { return Data() }
        var hasher = SHA256()
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where entry.pathExtension == "json" {
            if let data = try? Data(contentsOf: entry) { hasher.update(data: data) }
        }
        return Data(hasher.finalize())
    }
}
