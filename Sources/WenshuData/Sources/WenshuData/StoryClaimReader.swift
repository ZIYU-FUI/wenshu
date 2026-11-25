//
//  StoryClaimReader.swift
//
//  The claims a book already writes down, read back out of its own
//  field lines.
//
//  Why: the consistency kernel weighs claims (= who is where, who is
//  alive, what a rule forbids), and it is proven against arguments a
//  test wrote by hand. Nothing in the tree ever pointed it at a book,
//  so the kernel has never seen the text it will actually be asked
//  about.
//
//  So this file reads the book's own field lines. A book states its
//  world as lines of the shape `name: value` and `- **name**: value`,
//  and a line of that shape IS a claim: what it is about, the property
//  it gives, the value it gives it. The reader is a parser over those
//  lines and nothing else.
//
//  Three decisions the reader makes, and why:
//
//  - a document's TITLE names its subject. A sheet about a character
//    is titled with the character's name, and a sheet about a place is
//    titled with the place's name, so the title is the subject the
//    claims under are stated.
//  - a claim's grade comes from the line's own weight. A line the
//    book states flatly is stated firmly; a line the book marks as a
//    placeholder (= a template the writer has not filled in yet) is
//    not a claim at all, because a template states nothing.
//  - a claim's chapter is the document's own moment. A chapter's claim
//    belongs to that chapter; a document that is not a chapter (= a
//    setting sheet, = a character sheet) states what holds beside the
//    chapters rather than inside them.
//
//  The vocabulary is the book's, not this file's, so it is written as
//  code points (= the file stays English-only, and the marker can
//  still change without a code edit).
//
//  This file opens no file and writes no file: it reads text and
//  returns claims. Where a book's text comes from, and who weighs the
//  claims, belong to other layers.
//

import Foundation

/// One document a book wrote, as the reader sees it.
public struct StoryDocument: Sendable, Equatable {
    /// The document's title (= its first heading, = the subject its
    /// claims are stated under).
    public let title: String
    /// The document's own text (= the markdown the writer's words live
    /// in).
    public let text: String
    /// The moment of the story the document belongs to (= the book's
    /// own position). Nil = the document is not a chapter, so what it
    /// states holds beside the chapters rather than inside them.
    public let chapter: Int?

    public init(title: String, text: String, chapter: Int? = nil) {
        self.title = title
        self.text = text
        self.chapter = chapter
    }
}

/// The claims a book's own field lines state.
public enum StoryClaimReader {
    /// The weight a flatly stated line carries.
    ///
    /// A line the book writes as a plain statement is a statement it
    /// stands behind, so it weighs a full claim. A weaker line would
    /// weigh less, and a line below the kernel's own threshold
    /// contradicts nothing.
    public static let firmGrade: Double = 1.0

    /// The weight a line the book only hints at carries.
    ///
    /// A line the book marks as uncertain (= "probably", = "it seems")
    /// is a hint about the world, and a hint contradicts nothing: the
    /// kernel ignores any claim below its threshold, so a hint sits
    /// below it.
    public static let hintedGrade: Double = 0.25

    /// The claims a document states.
    ///
    /// The document's title names the subject. Each of its field lines
    /// names one attribute and its value, so a document of `n` field
    /// lines yields `n` claims.
    ///
    /// The order is the document's own order, so the same book always
    /// reads the same way.
    public static func claims(in document: StoryDocument) -> [StoryFact] {
        let subject = document.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty else { return [] }
        var claims: [StoryFact] = []
        for (index, line) in document.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            guard let field = FieldLine.read(String(line)) else { continue }
            // A template the writer has not filled in states nothing,
            // = so the line states no claim.
            guard !StoryClaimReader.isTemplate(field.value) else { continue }
            claims.append(StoryFact(
                id: "\(subject)#\(index)",
                subject: subject,
                attribute: field.name,
                value: field.value,
                grade: field.grade,
                chapter: document.chapter
            ))
        }
        return claims
    }

    /// The claims of several documents, in the order they were given.
    ///
    /// Two documents about the same subject (= a character sheet and a
    /// chapter that mentions the character) are read as two sets of
    /// claims under one subject, = so the kernel can weigh them
    /// together.
    public static func claims(in documents: [StoryDocument]) -> [StoryFact] {
        documents.flatMap { claims(in: $0) }
    }

    // MARK: - The weight a value carries

    /// The weight a value carries.
    ///
    /// A value the book marks as a template (= a `<...>` the writer has
    /// not filled in) states nothing, = so it is not a claim at all.
    /// A value the book marks as uncertain states a hint, = and a hint
    /// weighs less than the kernel's threshold, = so it contradicts
    /// nothing.
    static func grade(of value: String) -> Double {
        if hintWords.contains(where: { value.contains($0) }) {
            return hintedGrade
        }
        return firmGrade
    }

    /// Whether a value is a template the writer has not filled in.
    ///
    /// A template states nothing, = so a line that carries one states
    /// no claim at all. = A claim of weight zero would read the same to
    /// a reader, = but the reader here is the book's own account of
    /// what it says, = and a book that says nothing has said nothing.
    static func isTemplate(_ value: String) -> Bool {
        value.contains("<")
    }

    /// The words a book uses when it is not sure.
    ///
    /// The book's own words, written as code points (= the file stays
    /// English-only). A hint is a hint about the world, and the kernel
    /// weighs a hint below its threshold.
    private static let hintWords: Set<String> = [
        "\u{53EF}\u{80FD}", // may
        "\u{5927}\u{6982}", // probably
        "\u{4E5F}\u{8BB8}", // perhaps
        "\u{4F3C}\u{4F3C}", // seems
        "\u{770B}\u{6765}", // appears
        "\u{6216}\u{8BB8}", // maybe
    ]
}

/// The colon a book writes its field lines with.
///
/// The template ships the half-width colon, but a book a writer filled
/// in by hand carries the full-width one (= the punctuation the same
/// book uses two lines away), so a reader that reads only the
/// half-width one reads nothing from exactly the books a human wrote.
private let fieldColon: Character = ":"
private let fieldFullWidthColon: Character = "\u{FF1A}"

/// One field line of a book's own document.
private struct FieldLine {
    /// The property the line states (= the line's name).
    let name: String
    /// The value the line gives that property.
    let value: String
    /// How firmly the book states it.
    let grade: Double

    /// Read one line, or nil when the line states no property.
    ///
    /// The line shapes that state a property:
    ///
    /// - `- name: value` (= the template's own field lines);
    /// - `- **name**: value` (= the bold field lines a filled book
    ///   writes);
    /// - the template's own header names without a bullet (= `entityType`,
    ///   `tags`, `summary`).
    ///
    /// A line that states no property is one of: a heading (= its name
    /// is the section's title, = not a property of the subject), a
    /// bullet with no name (= prose), a link list (= `[[...]]`, =
    /// another document's name, = not a value), a block quote (= = = a
    /// citation, = = not the book's own statement), and a table row
    /// (= = = = a table, = = = not a field).
    static func read(_ line: String) -> FieldLine? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // A heading names a section, not a property.
        guard !trimmed.hasPrefix("#") else { return nil }
        // A quote is the book's citation of someone else.
        guard !trimmed.hasPrefix(">") else { return nil }
        // A table row is a table, not a field.
        guard !trimmed.hasPrefix("|") else { return nil }
        // A horizontal rule is a rule, not a field.
        guard trimmed != "---" else { return nil }

        // A field line is a BULLET. = A bare line is prose: = a
        // sentence that happens to hold a colon is not a field, = and
        // reading it as one turns a paragraph into a claim. = The books
        // this reader serves write their fields as bullets, = and the
        // template's own header lines (= `entityType` / `tags` /
        // `summary`) are the one shape a book carries without a bullet,
        // = so they are read by their own name below.
        guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") else {
            return Self.templateHeader(in: trimmed)
        }
        let head = String(trimmed.dropFirst(2))
        // A link list names other documents; a link with a colon after
        // it still states nothing of the subject, so a head that is
        // only a link is not a name.
        if head.hasPrefix("[[") {
            return nil
        }
        // A bold head (= `- **name**: value`).
        if head.hasPrefix("**") {
            // The head's own name is between the FIRST pair of stars:
            // the closing pair is the one that ends the name, and a
            // value may carry a star of its own.
            guard let opening = head.range(of: "**"),
                  let closing = head.range(of: "**", range: head.index(after: opening.lowerBound) ..< head.endIndex)
            else { return nil }
            let rest = head[closing.upperBound...].trimmingCharacters(in: .whitespaces)
            guard let colon = rest.firstIndex(of: fieldColon)
                ?? rest.firstIndex(of: fieldFullWidthColon) else { return nil }
            // The name is what the line calls the property, = so it
            // carries the bold part and whatever the book wrote
            // between it and the colon (= a note in brackets).
            let name = String(head[opening.upperBound ..< closing.lowerBound])
                + String(rest[..<colon])
            let value = String(rest[rest.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            guard !trimmedName.isEmpty, !value.isEmpty else { return nil }
            return FieldLine(
                name: trimmedName,
                value: value,
                grade: StoryClaimReader.grade(of: value)
            )
        }
        // A plain head (= `- name: value`).
        guard let colon = head.firstIndex(of: fieldColon)
            ?? head.firstIndex(of: fieldFullWidthColon) else { return nil }
        let name = String(head[..<colon]).trimmingCharacters(in: .whitespaces)
        let value = String(head[head.index(after: colon)...])
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !value.isEmpty else { return nil }
        return FieldLine(
            name: name,
            value: value,
            grade: StoryClaimReader.grade(of: value)
        )
    }

    /// The header line the book's own template writes without a bullet.
    ///
    /// The template puts three lines at the top of every document: =
    /// the kind of thing the document is about, = its tags, = and its
    /// one-line summary. = A book that fills them in states them, = so
    /// they are claims. = Every other bare line is prose, = because a
    /// sentence that happens to hold a colon is not a field.
    private static func templateHeader(in line: String) -> FieldLine? {
        guard let colon = line.firstIndex(of: fieldColon)
            ?? line.firstIndex(of: fieldFullWidthColon) else { return nil }
        let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
        guard templateHeaderNames.contains(name) else { return nil }
        let value = String(line[line.index(after: colon)...])
            .trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        return FieldLine(
            name: name,
            value: value,
            grade: StoryClaimReader.grade(of: value)
        )
    }

    /// The names the book's own template writes at the top of a
    /// document.
    ///
    /// The book's own words, written as code points (= the file stays
    /// English-only).
    private static let templateHeaderNames: Set<String> = [
        "\u{5B9E}\u{4F53}\u{7C7B}\u{578B}", // the kind of thing
        "\u{6807}\u{7B7E}", // tags
        "\u{6458}\u{8981}", // summary
    ]
}
