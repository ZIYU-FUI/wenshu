//
//  BookChapterActor+ToolProtocol.swift
//
//  The chapter actor's tool-protocol face: the LLM-facing dispatcher
//  and the JSON helpers it answers with.
//
//  Why: the dispatcher and its JSON helpers are one cluster (= the actor's
//  own protocol surface), and the file was over the file-size cap.
//
import Foundation

extension BookChapterActor {
    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookChapterError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as BookChapterError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookChapterError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = BookChapterAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: BookChapterError.invalidInput(
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
                error: BookChapterError.invalidInput(
                    reason: "scope guard failed: \(error.localizedDescription)"
                )
            )
        }

        do {
            switch action {
            case .create:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookChapterError.invalidInput(reason: "create requires 'book_id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let summary = envelope["summary"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let chapter = try await createChapter(
                    bookId: bookId,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, chapter: chapter)

            case .read:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookChapterError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let (chapter, body) = try await readChapter(id: id)
                return Self.encodeSuccessRead(action: action, chapter: chapter, body: body)

            case .update:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookChapterError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let summary = envelope["summary"] as? String
                let body = Self.extractMarkdown(envelope)
                // Read the existing body before the update so the success envelope can
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // `new_text` for the in-chat preview card.
                let oldBody: String
                do {
                    let (_, existing) = try await readChapter(id: id)
                    oldBody = existing ?? ""
                } catch {
                    // If the chapter didn't exist (= treat as create-flavored update), we
                    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                    // body means the entire new body is "+" lines.
                    oldBody = ""
                }
                let chapter = try await updateChapter(
                    id: id,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary
                )
                let tierName = Self.tierName(for: id, across: (try? readTiers()) ?? [])
                    ?? "drafts"
                return Self.encodeSuccessUpdate(
                    action: action,
                    chapter: chapter,
                    oldBody: oldBody,
                    newBody: body,
                    tierName: tierName
                )

            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookChapterError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                try await deleteChapter(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookChapterError.invalidInput(reason: "list requires 'book_id' (UUID string)")
                }
                let chapters = try await listChapters(bookId: bookId)
                return Self.encodeSuccessList(action: action, chapters: chapters)

            case .find:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookChapterError.invalidInput(reason: "find requires 'book_id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let chapter = try await findChapter(bookId: bookId, title: title)
                return Self.encodeSuccessFind(action: action, chapter: chapter)
            }
        } catch let error as BookChapterError {
            return Self.encodeFailure(action: action, error: error)
        } catch let error as ChapterFocusLockedError {
            // The lock is the conductor's business (= it asks the user), = so
            // the typed error must reach it as a throw, = not as an envelope.
            throw error
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookChapterError.underlying(String(describing: error))
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
        action: BookChapterAction,
        chapter: ChapterDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let chapter {
            payload["chapter"] = descriptorToJSON(chapter)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: BookChapterAction,
        chapter: ChapterDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "chapter": descriptorToJSON(chapter),
            "body": body ?? "",
        ]
        return encodeJSON(payload)
    }

    /// / Variant for the `update` action — enriches the envelope with a
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / reads `diff.stats`).
    private static func encodeSuccessUpdate(
        action: BookChapterAction,
        chapter: ChapterDescriptor,
        oldBody: String,
        newBody: String,
        tierName: String
    ) -> String {
        let diff = computeUnifiedDiff(old: oldBody, new: newBody)
        let stats = ChatToolDiffPreview.LineStats(
            addedLines: diff.addedLines,
            removedLines: diff.removedLines,
            addedChars: diff.addedChars,
            removedChars: diff.removedChars
        )
        let diffBlock: [String: Any] = [
            "path": "\(tierName)/\(chapter.id.uuidString).md",
            "old_text": oldBody,
            "new_text": newBody,
            "stats": [
                "added_chars": stats.addedChars,
                "removed_chars": stats.removedChars,
                "added_lines": stats.addedLines,
                "removed_lines": stats.removedLines,
            ] as [String: Int],
        ]
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "chapter": descriptorToJSON(chapter),
            "kind": "diff",
            "diff": diffBlock,
            "diff_text": diff.text,
        ]
        return encodeJSON(payload)
    }

    // / Plain unified-diff product (= text + line / char counts). Pure function
    // / so it's reachable from unit tests without an actor.

    // / Compute a minimal unified diff between two strings (= the form hermes
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / new\n@@\n-removed line\n+added line\n context\n"

    private static func encodeSuccessFind(
        action: BookChapterAction,
        chapter: ChapterDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue, "found": chapter != nil]
        if let chapter {
            payload["chapter"] = descriptorToJSON(chapter)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookChapterAction,
        chapters: [ChapterDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "chapters": chapters.map { descriptorToJSON($0) },
        ]
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookChapterAction?,
        error: BookChapterError
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

    /// / Encode a BookScopeViolation into the standard failure envelope. See
    /// / BookWorldTool.encodeFailureScopeViolation for the matching contract.
    private static func encodeFailureScopeViolation(
        action: BookChapterAction,
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

    private static func descriptorToJSON(_ d: ChapterDescriptor) -> [String: Any] {
        return [
            "id": d.id.uuidString,
            "book_id": d.bookId.uuidString,
            "title": d.title,
            "summary": d.summary,
            "createdAt": d.createdAt.formatted(.iso8601),
            "updatedAt": d.updatedAt.formatted(.iso8601),
        ]
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookChapterTool: JSON encode failed\"}"
        }
        return s
    }
}
