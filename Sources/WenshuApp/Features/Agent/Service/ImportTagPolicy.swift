// Sources/WenshuApp/Features/Agent/Service/ImportTagPolicy.swift
//
// The tags an imported entity keeps.
//
// The library's rule (the boss, 2026-10-09): = a tag never repeats
// the title (= the title names the entity, = and a tag that says the
// same thing says nothing), = at most three tags (= the sidebar's
// tag facet stays navigable), = and at least one (= an entity with no
// tag never shows up in that facet).
//
// The rule lived in the old import path only, = so the paths that
// came after it (the agent's library import, = the agent's metadata)
// wrote the tags as the model gave them: = four tags, = a tag that
// repeated the title, = or none at all. This type is the one rule
// now, = and every import path asks it.
//
// The rule has a second half (the boss, 2026-10-26): = a tag never
// names a sibling document (= the file names of the folder the
// import writes into). The children have their own place (= the
// index's links, = the card board), = so naming one as a tag says
// nothing twice.

import Foundation

enum ImportTagPolicy {

    /// The most tags one entity carries.
    static let maxTags = 3

    /// The fewest tags one entity carries.
    static let minTags = 1

    /// The tags an imported entity keeps.
    ///
    /// - The title is not a tag (= the title names the entity).
    /// - A tag names no sibling document (= the children have their
    ///   own place).
    /// - A tag repeats no other tag.
    /// - A tag carries no punctuation (= a tag is a few characters).
    /// - At most `maxTags` tags, at least `minTags`.
    /// - When nothing survives, the fallback fills the gap (= the
    ///   app's own vocabulary, = never the title).
    static func tags(
        _ raw: [String],
        title: String,
        siblingNames: [String] = [],
        fallback: [String] = []
    ) -> [String] {
        let titleNorm = normalized(title)
        let siblings = Set(siblingNames.map(normalized))
        var kept: [String] = []
        for tag in raw {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = normalized(trimmed)
            if key == titleNorm { continue }
            if siblings.contains(key) { continue }
            if trimmed.rangeOfCharacter(from: .punctuationCharacters) != nil { continue }
            if kept.contains(where: { normalized($0) == key }) { continue }
            kept.append(trimmed)
            if kept.count == maxTags { break }
        }
        if kept.count < minTags {
            for tag in fallback {
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let key = normalized(trimmed)
                if key == titleNorm { continue }
                if siblings.contains(key) { continue }
                if kept.contains(where: { normalized($0) == key }) { continue }
                kept.append(trimmed)
                if kept.count == maxTags { break }
            }
        }
        return kept
    }

    /// The names a body may not use as tags (= the sibling documents
    /// of the folder the import writes into).
    ///
    /// The names come from the files already in the folder, = with and
    /// without the `.md` suffix, = so both spellings are covered.
    static func siblingNames(inFolderAt folder: URL) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        var names: [String] = []
        for entry in entries where entry.hasSuffix(".md") {
            names.append(entry)
            names.append(String(entry.dropLast(".md".count)))
        }
        return names
    }

    /// The comparison key of a name (= the case and the spacing do not
    /// make two names).
    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
