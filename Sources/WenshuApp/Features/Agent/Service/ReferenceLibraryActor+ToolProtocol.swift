//
//  ReferenceLibraryActor+ToolProtocol.swift
//
//  The LLM-facing dispatcher of the reference library, and the JSON helpers it writes with.
//
//  Why: the dispatcher's own concern (= reading the envelope, routing the action, writing the reply) is separate from the CRUD it calls, and the JSON helpers are used only here.
//

import Foundation
import WenshuAgent

extension ReferenceLibraryActor {
    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw ReferenceLibraryError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as ReferenceLibraryError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: ReferenceLibraryError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = ReferenceLibraryAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: ReferenceLibraryError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find / upsert)"
                )
            )
        }

        do {
            switch action {
            case .create:
                let title = envelope["title"] as? String ?? ""
                let layer = envelope["layer"] as? String ?? "raw"
                let category = envelope["category"] as? String
                // Tags is an optional [String] in the envelope. Accept
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // provide any tags).
                let tagsArray = envelope["tags"] as? [String] ?? []
                let tags = Set(tagsArray)
                let entityType = envelope["entity_type"] as? String ?? "other"
                let source = envelope["source"] as? String
                let url = envelope["url"] as? String
                let summary = envelope["summary"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let reference = try await createReference(
                    title: title,
                    bodyMarkdown: body,
                    layer: layer,
                    category: category,
                    tags: tags,
                    entityType: entityType,
                    source: source,
                    url: url,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, reference: reference, created: true)

            case .read:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw ReferenceLibraryError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let (reference, body) = try await readReference(id: id)
                return Self.encodeSuccessRead(action: action, reference: reference, body: body)

            case .update:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw ReferenceLibraryError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let category = envelope["category"] as? String
                let entityType = envelope["entity_type"] as? String
                let source = envelope["source"] as? String
                let url = envelope["url"] as? String
                let summary = envelope["summary"] as? String
                let body = Self.extractMarkdown(envelope)
                let reference = try await updateReference(
                    id: id,
                    title: title,
                    bodyMarkdown: body,
                    category: category,
                    entityType: entityType,
                    source: source,
                    url: url,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, reference: reference, created: false)

            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw ReferenceLibraryError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                try await deleteReference(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                let layer = envelope["layer"] as? String
                let references = try await listReferences(layer: layer)
                return Self.encodeSuccessList(action: action, references: references)

            case .find:
                let title = envelope["title"] as? String ?? ""
                let layer = envelope["layer"] as? String
                let reference = try await findReference(title: title, layer: layer)
                return Self.encodeSuccessFind(action: action, reference: reference)

            case .upsert:
                let title = envelope["title"] as? String ?? ""
                let layer = envelope["layer"] as? String ?? "raw"
                let category = envelope["category"] as? String
                let tagsArray = envelope["tags"] as? [String] ?? []
                let tags = Set(tagsArray)
                let entityType = envelope["entity_type"] as? String ?? "other"
                let source = envelope["source"] as? String
                let url = envelope["url"] as? String
                let summary = envelope["summary"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let reference = try await upsertReference(
                    title: title,
                    bodyMarkdown: body,
                    layer: layer,
                    category: category,
                    tags: tags,
                    entityType: entityType,
                    source: source,
                    url: url,
                    summary: summary
                )
                // The "created" flag in the JSON envelope tells the
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // the update branch.
                let wasCreated = Date().timeIntervalSince(reference.createdAt) < 1.0
                return Self.encodeSuccess(action: action, reference: reference, created: wasCreated)

            case .extend:
                // Self-evolution mechanism. The agent finds an
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // already exists) rather than rewriting the body.
                let id = envelope["id"] as? String
                    ?? (envelope["id"] as? [String: Any])?["value"] as? String
                let sectionTitle = envelope["section_title"] as? String ?? ""
                let sectionBody = envelope["section_body"] as? String
                    ?? envelope["markdown"] as? String
                    ?? envelope["body"] as? String
                    ?? ""
                let tagsArray = envelope["tags"] as? [String] ?? []
                let tags = Set(tagsArray)
                let summary = envelope["summary"] as? String
                let source = envelope["source"] as? String
                let url = envelope["url"] as? String
                guard let idRaw = id, let parsed = UUID(uuidString: idRaw) else {
                    return Self.encodeFailure(
                        action: action,
                        error: .invalidInput(
                            reason: "extend: id is required and must be a UUID (= use `find` first to get it)"
                        )
                    )
                }
                guard !sectionTitle.isEmpty else {
                    return Self.encodeFailure(
                        action: action,
                        error: .invalidInput(
                            reason: "extend: section_title is required (= the heading for the new section)"
                        )
                    )
                }
                let reference = try await extendReference(
                    id: parsed,
                    sectionTitle: sectionTitle,
                    sectionBody: sectionBody,
                    tags: tags,
                    summary: summary,
                    source: source,
                    url: url
                )
                return Self.encodeSuccess(action: action, reference: reference, created: false)
            }
        } catch let error as ReferenceLibraryError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: ReferenceLibraryError.underlying(String(describing: error))
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

    private static func encodeSuccess(
        action: ReferenceLibraryAction,
        reference: ReferenceDescriptor? = nil,
        created: Bool? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let reference {
            payload["reference"] = descriptorToJSON(reference)
        }
        if let created {
            payload["created"] = created
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: ReferenceLibraryAction,
        reference: ReferenceDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "reference": descriptorToJSON(reference),
            "body": body ?? "",
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessFind(
        action: ReferenceLibraryAction,
        reference: ReferenceDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue, "found": reference != nil]
        if let reference {
            payload["reference"] = descriptorToJSON(reference)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: ReferenceLibraryAction,
        references: [ReferenceDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "references": references.map { descriptorToJSON($0) },
        ]
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: ReferenceLibraryAction?,
        error: ReferenceLibraryError
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

    private static func descriptorToJSON(_ d: ReferenceDescriptor) -> [String: Any] {
        var dict: [String: Any] = [
            "id": d.id.uuidString,
            "title": d.title,
            "displayTitle": d.displayTitle ?? d.title,
            "layer": d.layer,
            "entity_type": d.entityType,
            "summary": d.summary,
            "createdAt": d.createdAt.formatted(.iso8601),
            "updatedAt": d.updatedAt.formatted(.iso8601),
        ]
        if let category = d.category {
            dict["category"] = category
        }
        if let source = d.source {
            dict["source"] = source
        }
        if let url = d.url {
            dict["url"] = url
        }
        // Tags are emitted sorted (= the LLM / agent UI sees a
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // — consumers don't need to handle missing-key vs nil).
        dict["tags"] = d.tags
        return dict
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"ReferenceLibraryTool: JSON encode failed\"}"
        }
        return s
    }
}
