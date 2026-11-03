//
//  BookOutlineActor+ToolProtocol.swift
//
//  The outline actor's tool-protocol face: the LLM-facing dispatcher and
//  the JSON helpers it answers with.
//
//  Why: the dispatcher and its JSON helpers are one cluster (= the actor's
//  own protocol surface), and the file was over the file-size cap.
//
import Foundation

extension BookOutlineActor {
    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookOutlineError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as BookOutlineError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookOutlineError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = BookOutlineAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: BookOutlineError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find)"
                )
            )
        }

        // Scope guard: see BookWorldActor (= identical contract).
        do {
            try BookScopeGuard.validate(
                providedBookID: Self.parseUUID(envelope["book_id"]),
                currentChatBookIDProvider: currentChatBookIDProvider
            )
        } catch let violation as BookScopeViolation {
            return Self.encodeFailureScopeViolation(action: action, error: violation)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookOutlineError.invalidInput(
                    reason: "scope guard failed: \(error.localizedDescription)"
                )
            )
        }

        do {
            switch action {
            case .create:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookOutlineError.invalidInput(reason: "create requires 'book_id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let summary = envelope["summary"] as? String ?? ""
                let parent = Self.parseOptionalUUID(envelope["parent"])
                let order = (envelope["order"] as? Int) ?? 0
                let body = Self.extractMarkdown(envelope)
                let outline = try await createOutline(
                    bookId: bookId,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary,
                    parent: parent,
                    order: order
                )
                return Self.encodeSuccess(action: action, outline: outline)

            case .read:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookOutlineError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let (outline, body) = try await readOutline(id: id)
                return Self.encodeSuccessRead(action: action, outline: outline, body: body)

            case .update:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookOutlineError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let summary = envelope["summary"] as? String
                let parentRaw = envelope["parent"]
                let parent: UUID? = (parentRaw is NSNull)
                    ? nil
                    : Self.parseOptionalUUID(parentRaw)
                let order = envelope["order"] as? Int
                let body = Self.extractMarkdown(envelope)
                let outline = try await updateOutline(
                    id: id,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary,
                    parent: parent,
                    order: order
                )
                return Self.encodeSuccess(action: action, outline: outline)

            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookOutlineError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                try await deleteOutline(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookOutlineError.invalidInput(reason: "list requires 'book_id' (UUID string)")
                }
                let outlines = try await listOutlines(bookId: bookId)
                return Self.encodeSuccessList(action: action, outlines: outlines)

            case .find:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookOutlineError.invalidInput(reason: "find requires 'book_id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let outline = try await findOutline(bookId: bookId, title: title)
                return Self.encodeSuccessFind(action: action, outline: outline)
            }
        } catch let error as BookOutlineError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookOutlineError.underlying(String(describing: error))
            )
        }
    }

    // MARK: - JSON helpers

    private static func extractMarkdown(_ envelope: [String: Any]) -> String {
        if let m = envelope["markdown"] as? String, !m.isEmpty {
            return m
        }
        if let b = envelope["body"] as? String {
            return b
        }
        return ""
    }

    private static func parseUUID(_ any: Any?) -> UUID? {
        if let s = any as? String {
            return UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let dict = any as? [String: Any], let s = dict["value"] as? String {
            return UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    /// / parseOptionalUUID: returns nil when the value is missing OR
    /// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / this for fields where nil means "no change".
    private static func parseOptionalUUID(_ any: Any?) -> UUID? {
        if any == nil {
            return nil
        }
        if let s = any as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t.lowercased() == "null" {
                return nil
            }
            return UUID(uuidString: t)
        }
        return nil
    }

    private static func encodeSuccess(
        action: BookOutlineAction,
        outline: OutlineEntryDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let outline {
            payload["outline"] = descriptorToJSON(outline)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: BookOutlineAction,
        outline: OutlineEntryDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "outline": descriptorToJSON(outline),
            "body": body ?? "",
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessFind(
        action: BookOutlineAction,
        outline: OutlineEntryDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue, "found": outline != nil]
        if let outline {
            payload["outline"] = descriptorToJSON(outline)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookOutlineAction,
        outlines: [OutlineEntryDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "outlines": outlines.map { descriptorToJSON($0) },
        ]
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookOutlineAction?,
        error: BookOutlineError
    ) -> String {
        var payload: [String: Any] = [
            "ok": false,
            "error": error.errorDescription ?? "unknown error",
        ]
        if let action {
            payload["action"] = action.rawValue
        }
        return encodeJSON(payload)
    }

    /// / Encode a BookScopeViolation into the standard failure envelope.
    /// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / contract.
    private static func encodeFailureScopeViolation(
        action: BookOutlineAction,
        error: BookScopeViolation
    ) -> String {
        let payload: [String: Any] = [
            "ok": false,
            "action": action.rawValue,
            "error": error.errorDescription ?? "unknown error",
            "error_kind": "book_scope_violation",
        ]
        return encodeJSON(payload)
    }

    private static func descriptorToJSON(_ d: OutlineEntryDescriptor) -> [String: Any] {
        var dict: [String: Any] = [
            "id": d.id.uuidString,
            "book_id": d.bookId.uuidString,
            "title": d.title,
            "summary": d.summary,
            "order": d.order,
            "createdAt": d.createdAt.formatted(.iso8601),
            "updatedAt": d.updatedAt.formatted(.iso8601),
        ]
        if let parent = d.parent {
            dict["parent"] = parent.uuidString
        }
        return dict
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookOutlineTool: JSON encode failed\"}"
        }
        return s
    }
}
