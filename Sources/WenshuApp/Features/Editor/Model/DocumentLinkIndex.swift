// Sources/WenshuApp/Features/Editor/Model/DocumentLinkIndex.swift
//
// The documents a document points at.
//
// The boss (2026-10-26): an index's link list read as plain text in
// the document; = the app has a document card, = so the list should
// be cards. That means the reader sees the body without the link
// lines, = and the cards say the same thing in the app's own shape.
//
// So this type reads a body twice: the names it links to (= the
// cards), and the body with the link sections taken out (= what the
// reader sees beside the cards).

import Foundation

enum DocumentLinkIndex {

    /// The names a body links to (= "核心设定.md"), in the order they
    /// appear, without duplicates.
    static func linkedNames(in body: String) -> [String] {
        var names: [String] = []
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let name = linkName(inLine: String(line)) else { continue }
            if !names.contains(name) { names.append(name) }
        }
        return names
    }

    /// The name one line links to, when the line is nothing but a link.
    ///
    /// A link line is a list item whose content is one wiki link
    /// (= `[[核心设定.md]]`). The list marker may be `-`, `*`, `+` or
    /// a number, = and a link may carry an id (= `[[名字|路径]]`).
    static func linkName(inLine line: String) -> String? {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("- ") || text.hasPrefix("* ") || text.hasPrefix("+ ") {
            text = String(text.dropFirst(2))
        } else if let dot = text.firstIndex(of: "."),
                  text.distance(from: text.startIndex, to: dot) <= 3,
                  text[text.index(after: dot)...].hasPrefix(" ") {
            text = String(text[text.index(after: dot)...].dropFirst())
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[["), trimmed.hasSuffix("]]") else { return nil }
        let inside = String(trimmed.dropFirst(2).dropLast(2))
        let name = inside.split(separator: "|", maxSplits: 1).first.map(String.init) ?? ""
        return name.isEmpty ? nil : name
    }

    /// The body without its link sections.
    ///
    /// A link section is a heading whose items are all links (= the
    /// index's "required children" block). The section goes away as a
    /// whole (= the heading with it), = because the cards take its
    /// place. A heading that also introduces other content stays, =
    /// and keeps the text that is not a link.
    static func bodyWithoutLinkSections(_ body: String) -> String {
        var output: [String] = []
        var headingIndex: Int? = nil
        var sectionHasLink = false
        var sectionHasOther = false

        func closeSection() {
            if let index = headingIndex, sectionHasLink, !sectionHasOther {
                output.remove(at: index)
            }
            headingIndex = nil
            sectionHasLink = false
            sectionHasOther = false
        }

        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                closeSection()
                headingIndex = output.count
                output.append(text)
                continue
            }
            if linkName(inLine: trimmed) != nil {
                sectionHasLink = true
                continue
            }
            if !trimmed.isEmpty { sectionHasOther = true }
            output.append(text)
        }
        closeSection()
        return output.joined(separator: "\n")
    }
}
