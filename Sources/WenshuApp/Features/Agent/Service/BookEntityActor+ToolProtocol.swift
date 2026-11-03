//
//  BookEntityActor+ToolProtocol.swift
//
//  The entity actor's tool-protocol face: the LLM-facing dispatcher and
//  the JSON helpers it answers with.
//
//  Why: the dispatcher and its JSON helpers are one cluster (= the actor's
//  own protocol surface), and the file was over the file-size cap.
//
import Foundation

extension BookEntityActor {
    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    /// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / scope-guard contract).
    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookEntityError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as BookEntityError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookEntityError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = BookEntityAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: BookEntityError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find)"
                )
            )
        }

        // Scope guard: every action MUST carry a `book_id` matching the chat session's
        // currently-bound book.
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
                error: BookEntityError.invalidInput(
                    reason: "scope guard failed: \(error.localizedDescription)"
                )
            )
        }

        do {
            switch action {
            case .create:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookEntityError.invalidInput(reason: "create requires 'book_id' (UUID string)")
                }
                let kind = envelope["kind"] as? String ?? ""
                let name = envelope["name"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let aliases = (envelope["aliases"] as? [String]) ?? []
                let tags = (envelope["tags"] as? [String]) ?? []
                let description = envelope["description"] as? String ?? ""
                let attributes = (envelope["attributes"] as? [String: String]) ?? [:]
                let entity = try await createEntity(
                    bookId: bookId,
                    kind: kind,
                    name: name,
                    bodyMarkdown: body,
                    aliases: aliases,
                    tags: tags,
                    description: description,
                    attributes: attributes
                )
                return Self.encodeSuccess(action: action, entity: entity)

            case .read:
                guard let idRaw = envelope["id"] as? String, !idRaw.isEmpty else {
                    throw BookEntityError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let id = EntityID(rawValue: idRaw)
                let (entity, body) = try await readEntity(id: id)
                return Self.encodeSuccessRead(action: action, entity: entity, body: body)

            case .update:
                guard let idRaw = envelope["id"] as? String, !idRaw.isEmpty else {
                    throw BookEntityError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let id = EntityID(rawValue: idRaw)
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookEntityError.invalidInput(reason: "update requires 'book_id' (UUID string)")
                }
                let kind = envelope["kind"] as? String ?? ""
                let name = envelope["name"] as? String ?? ""
                let body = Self.extractMarkdown(envelope).isEmpty ? nil : Self.extractMarkdown(envelope)
                let aliases = envelope["aliases"] as? [String]
                let tags = envelope["tags"] as? [String]
                let description = envelope["description"] as? String
                let attributes = envelope["attributes"] as? [String: String]
                let entity = try await updateEntity(
                    id: id,
                    bookId: bookId,
                    kind: kind,
                    name: name,
                    bodyMarkdown: body,
                    aliases: aliases,
                    tags: tags,
                    description: description,
                    attributes: attributes
                )
                return Self.encodeSuccess(action: action, entity: entity)

            case .delete:
                guard let idRaw = envelope["id"] as? String, !idRaw.isEmpty else {
                    throw BookEntityError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                let id = EntityID(rawValue: idRaw)
                try await deleteEntity(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookEntityError.invalidInput(reason: "list requires 'book_id' (UUID string)")
                }
                let kindFilter: EntityKind? = (envelope["kind"] as? String).flatMap(EntityKind.init(rawValue:))
                let entities = try await listEntities(bookId: bookId, kind: kindFilter)
                return Self.encodeSuccessList(action: action, entities: entities)

            case .find:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookEntityError.invalidInput(reason: "find requires 'book_id' (UUID string)")
                }
                let kind = envelope["kind"] as? String ?? ""
                let name = envelope["name"] as? String ?? ""
                guard let parsedKind = EntityKind(rawValue: kind) else {
                    throw BookEntityError.invalidInput(
                        reason: "find requires 'kind' (one of: person / location / object / ability / event)"
                    )
                }
                let entity = try await findEntity(bookId: bookId, kind: parsedKind, name: name)
                return Self.encodeSuccessFind(action: action, entity: entity)
            }
        } catch let error as BookEntityError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookEntityError.underlying(String(describing: error))
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

    private static func descriptorToJSON(_ entity: EntityDescriptor) -> [String: Any] {
        return [
            "id": entity.id.rawValue,
            "book_id": entity.bookID.rawValue,
            "kind": entity.kind.rawValue,
            "name": entity.name,
            "aliases": entity.aliases,
            "tags": entity.tags,
            "description": entity.description,
            "attributes": entity.attributes,
            "kind_specific": String(describing: entity.kindSpecific),
            "body_excerpt": entity.bodyExcerpt,
            "created_at": entity.createdAt.formatted(.iso8601),
            "updated_at": entity.updatedAt.formatted(.iso8601),
        ]
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookEntityTool: JSON encode failed\"}"
        }
        return s
    }

    private static func encodeSuccess(
        action: BookEntityAction,
        entity: EntityDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let entity {
            payload["entity"] = descriptorToJSON(entity)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: BookEntityAction,
        entity: EntityDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "entity": descriptorToJSON(entity),
            "body": body ?? "",
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookEntityAction,
        entities: [EntityDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "entities": entities.map { descriptorToJSON($0) },
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessFind(
        action: BookEntityAction,
        entity: EntityDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        payload["entity"] = entity.map { descriptorToJSON($0) } ?? NSNull()
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookEntityAction?,
        error: BookEntityError
    ) -> String {
        var payload: [String: Any] = [
            "ok": false,
            "error_kind": errorKind(for: error),
            "error": error.errorDescription ?? String(describing: error),
        ]
        if let action {
            payload["action"] = action.rawValue
        }
        return encodeJSON(payload)
    }

    private static func encodeFailureScopeViolation(
        action _: BookEntityAction,
        error: BookScopeViolation
    ) -> String {
        let payload: [String: Any] = [
            "ok": false,
            "error_kind": "book_scope_violation",
            "error": error.errorDescription ?? String(describing: error),
        ]
        return encodeJSON(payload)
            .replacingOccurrences(of: "{\n", with: "{")
            .replacingOccurrences(of: "}\n", with: "}")
    }

    private static func errorKind(for error: BookEntityError) -> String {
        switch error {
        case .emptyName: return "empty_name"
        case .entryNotFound: return "entry_not_found"
        case .invalidInput: return "invalid_input"
        case .underlying: return "underlying_error"
        }
    }
}
