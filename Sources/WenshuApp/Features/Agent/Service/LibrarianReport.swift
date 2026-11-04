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
        case report(LibrarianResult)

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
            return .report(LibrarianResult(skipped: reason))
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
        return .report(result)
    }

    /// The text the conversation shows for a parsed report.
    static func text(for result: LibrarianResult) -> String {
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
        return lines.joined(separator: "\n")
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
