//
//  LibrarianReport.swift · Wenshu
//
//  Reading what the librarian reported.
//
//  The librarian's prompt asks for a JSON object: = how many
//  documents landed, = which ones, = what happened to each, = and the
//  notes. = That JSON was never parsed, = so the report the user saw
//  was the raw string the model produced, = and the `LibrarianResult`
//  type that was supposed to carry it had no producer at all.
//
//  This is the reader. = It takes the model's text and says what the
//  run actually did, = in the app's own vocabulary, = so the run can
//  report it the way every other run reports (= which documents, =
//  which layer, = which duplicates, = what went wrong).
//
//  Two properties, = and both of them are about not lying:
//
//  - A report that cannot be read is NOT read as "nothing landed".
//    = It is read as a failure, = because a run that says nothing
//    parseable did not do what it said, = and the user must be told
//    that rather than shown an empty success.
//  - The counts come from the report, = not from the run's own
//    optimism. = If the model says two documents landed, = the result
//    says two, = even if the library holds three.
//

import Foundation
import WenshuData

/// What the librarian's report said.
enum LibrarianReport {

    /// One document the run says it touched.
    struct DocumentAction: Sendable, Equatable {
        /// The document's title.
        let title: String
        /// The document's id, = when the report carries one.
        let id: UUID?
        /// What happened to it: = created, = extended, = updated, =
        /// or it was a duplicate (= already there).
        let action: Action

        /// What the run did to a document.
        enum Action: String, Sendable, Equatable {
            case created
            case extended
            case updated
            /// The document was already there, = under the same title.
            case duplicate
            /// The report named an action this app does not know.
            case unknown
        }
    }

    /// The outcome of reading a report.
    enum Parsed: Sendable, Equatable {
        /// The report was read.
        case report(LibrarianResult, documents: [DocumentAction])

        /// The text was not a report this app can read.
        ///
        /// The run's own text is carried along, = because the user
        /// deserves to see what the run actually said, = even when the
        /// app could not make sense of it.
        case unreadable(text: String)
    }

    /// Read the model's report.
    ///
    /// - Parameter text: what the run produced.
    /// - Returns: the result, = or that the text was not a report.
    static func parse(_ text: String) -> Parsed {
        guard let payload = jsonObject(in: text) else {
            return .unreadable(text: text)
        }
        // The out-of-scope shape: = the run declined, = and says why.
        if let landed = payload["landed"] as? Bool, landed == false {
            let reason = payload["reason"] as? String ?? "out of scope"
            return .report(LibrarianResult(skipped: reason), documents: [])
        }

        guard let landed = (payload["landed"] as? Int) ?? (payload["landed"] as? NSNumber)?.intValue else {
            return .unreadable(text: text)
        }

        var documentIDs: [UUID] = []
        var duplicateTitles: [String] = []
        var layers: [UUID: String] = [:]
        var documents: [DocumentAction] = []

        if let rawDocuments = payload["documents"] as? [[String: Any]] {
            for raw in rawDocuments {
                let title = raw["title"] as? String ?? ""
                let id = (raw["id"] as? String).flatMap(UUID.init(uuidString:))
                let action = DocumentAction.Action(
                    rawValue: (raw["action"] as? String ?? "").lowercased()
                ) ?? .unknown
                documents.append(DocumentAction(title: title, id: id, action: action))
                if let id {
                    documentIDs.append(id)
                }
                if action == .duplicate {
                    duplicateTitles.append(title)
                }
            }
        }

        let notes = (payload["notes"] as? [String]) ?? []

        // The count the report gives is the count the result carries,
        // = and the documents it names are the ones it landed. = When
        // the report says two and names one, = the result says two
        // and names one: = the result does not correct the model, = it
        // reports it.
        var result = LibrarianResult(
            documentIDs: documentIDs,
            duplicateTitles: duplicateTitles,
            layers: layers,
            indexed: false,
            archiveTarget: nil,
            errorMessage: nil,
            skipped: nil
        )
        if landed != documentIDs.count && !documents.isEmpty {
            result = LibrarianResult(
                documentIDs: documentIDs,
                duplicateTitles: duplicateTitles,
                layers: layers,
                indexed: false,
                archiveTarget: nil,
                errorMessage: "the report said \(landed) document(s) landed but named \(documentIDs.count)",
                skipped: nil
            )
        }
        if !notes.isEmpty {
            let noteText = notes.joined(separator: "; ")
            if result.errorMessage == nil {
                result = LibrarianResult(
                    documentIDs: result.documentIDs,
                    duplicateTitles: result.duplicateTitles,
                    layers: result.layers,
                    indexed: result.indexed,
                    archiveTarget: result.archiveTarget,
                    errorMessage: nil,
                    skipped: noteText
                )
            }
        }
        return .report(result, documents: documents)
    }

    // MARK: - The verification

    /// What the library actually holds for a document the report
    /// named.
    ///
    /// The report is what the MODEL said. = This is what the library
    /// holds. = The two are not the same thing, = and the difference
    /// is the whole point: = a model can say it landed a document it
    /// never wrote, = and it can write a document into the raw layer
    /// (= which the user cannot see) = and say it landed it.
    enum Actual: Sendable, Equatable {
        /// The document is there, = in a layer the user can see.
        case presentInVisibleLayer
        /// The document is there, = in the raw layer: = the user
        /// cannot see it, = so a report that says "landed" is a
        /// report the user cannot act on.
        case presentInRawLayer
        /// The library does not hold it.
        case absent
    }

    /// One document's verification.
    struct Verification: Sendable, Equatable {
        /// The title the report named.
        let title: String
        /// What the library holds for it.
        let actual: Actual
    }

    /// Check what the report claims against what the library holds.
    ///
    /// The titles are matched by the corpus's own rule (= trimmed, =
    /// case-insensitive, = whitespace-collapsed), = so a document the
    /// model wrote under a slightly different spelling is found and
    /// not reported missing.
    ///
    /// - Parameters:
    ///   - actions: what the report said about each document.
    ///   - references: what the library holds.
    /// - Returns: one verification per document the report named.
    static func verify(
        _ actions: [DocumentAction],
        against references: [Reference]
    ) -> [Verification] {
        actions.map { action in
            let actual: Actual
            if let match = references.first(where: {
                Reference.titlesMatch($0.title, action.title)
            }) {
                actual = match.layer == .layerRaw ? .presentInRawLayer : .presentInVisibleLayer
            } else {
                actual = .absent
            }
            return Verification(title: action.title, actual: actual)
        }
    }

    /// The text the conversation shows for a parsed report.
    ///
    /// The verifications are what the library holds, = and they are
    /// printed apart from the model's own words. = A report that
    /// says "landed two documents" and then says that the library
    /// holds none of them is a report the user can act on; = a report
    /// that only says "landed two documents" is a promise.
    ///
    /// - Parameters:
    ///   - result: what the run reported.
    ///   - verifications: what the library holds, = when it could be
    ///     read.
    static func text(
        for result: LibrarianResult,
        verifications: [Verification]? = nil,
        unreadableNotice: String = ""
    ) -> String {
        if let skipped = result.skipped, result.documentIDs.isEmpty {
            return "The librarian did not land anything: \(skipped)"
        }
        var lines: [String] = []
        let count = result.documentIDs.count
        lines.append("The librarian landed \(count) document(s).")
        if !result.duplicateTitles.isEmpty {
            lines.append("Already there, = not landed again: \(result.duplicateTitles.joined(separator: ", ")).")
        }
        if let error = result.errorMessage {
            lines.append("Note: \(error)")
        }
        // The corpus could not be read. = The check did not run, = so
        // the report says that, = and it says NOTHING about the
        // documents being there or not. = A line that named the
        // documents as missing would be a fact the check never got.
        if !unreadableNotice.isEmpty {
            lines.append(unreadableNotice)
        }
        lines.append(contentsOf: verificationLines(verifications))
        return lines.joined(separator: "\n")
    }

    /// The lines that say what the library holds.
    ///
    /// The text is the user's, = and it reads as a sentence. = The
    /// house's "= " marker is for the source, = and a line the user
    /// reads in a conversation with a dash in it reads as a machine
    /// printing its own notes.
    private static func verificationLines(_ verifications: [Verification]?) -> [String] {
        guard let verifications, !verifications.isEmpty else { return [] }
        var lines: [String] = []
        let present = verifications.filter { $0.actual != .absent }.count
        lines.append("Checked against the library: \(present) of \(verifications.count) document(s) are there.")
        for verification in verifications {
            switch verification.actual {
            case .presentInVisibleLayer:
                lines.append("  \(verification.title): in the library.")
            case .presentInRawLayer:
                lines.append("  \(verification.title): in the library, in the raw layer, where the user cannot see it.")
            case .absent:
                lines.append("  \(verification.title): NOT in the library, so it did not land.")
            }
        }
        return lines
    }

    // MARK: - The JSON

    /// The JSON object in a run's text.
    ///
    /// A model may wrap its JSON in prose or in a code fence, = so
    /// the object is looked for inside the text rather than assumed
    /// to be the whole of it.
    private static func jsonObject(in text: String) -> [String: Any]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = decode(trimmed) { return direct }

        // A fenced block.
        if let fenceStart = trimmed.range(of: "```"),
           let fenceEnd = trimmed.range(of: "```", range: fenceStart.upperBound..<trimmed.endIndex) {
            let inner = trimmed[fenceStart.upperBound..<fenceEnd.lowerBound]
            let withoutTag = inner.split(separator: "\n", maxSplits: 1).last.map(String.init) ?? String(inner)
            if let decoded = decode(withoutTag.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return decoded
            }
        }

        // The first balanced object in the text.
        guard let start = trimmed.firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = start
        while index < trimmed.endIndex {
            let character = trimmed[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 {
                    let slice = String(trimmed[start...index])
                    return decode(slice)
                }
            }
            index = trimmed.index(after: index)
        }
        return nil
    }

    private static func decode(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
