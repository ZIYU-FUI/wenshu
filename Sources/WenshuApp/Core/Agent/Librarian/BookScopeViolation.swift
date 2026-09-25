//
//  BookScopeViolation.swift · Wenshu · v2.1 (2026-09-25)
//
//  Hard validation rule: an agent book_X tool rejects any input whose
//  `book_id` does not match the chat session's currently bound book.
//
//  Two flavors:
//    1. currentChatBookID == nil  (no book selected, e.g. onboarding)
//    2. currentChatBookID != provided  (cross-book write attempt)
//
//  The error is thrown by the actor and serialized into the LLM
//  dispatcher JSON envelope as `{"ok":false, "error": "<message>"}`.
//  The message is intentionally soft: it guides the LLM to ask the
//  user to switch books OR re-issue with the bound book id.
//

import Foundation

enum BookScopeViolation: Error, LocalizedError, Sendable, Equatable {
    /// The chat session is not bound to any book (= the user has not
    /// picked one in the sidebar yet, or the chat predates the
    /// v1.79 row-level split).
    case noChatBookBound(providedBookID: UUID?)

    /// The chat session is bound to a different book than the one the
    /// LLM tried to write.
    case crossBookWrite(currentChatBookID: UUID, providedBookID: UUID)

    var errorDescription: String? {
        switch self {
        case .noChatBookBound(let provided):
            if let provided {
                return Self.noChatBookBoundMessage(provided: provided)
            }
            return Self.noChatBookBoundMessageNoProvided()
        case .crossBookWrite(let current, let provided):
            return Self.crossBookWriteMessage(current: current, provided: provided)
        }
    }

    /// LLM-facing soft message: ask the user to pick a book, then
    /// retry. Includes the provided id so the LLM can tell the user
    /// "the book you wanted was X".
    private static func noChatBookBoundMessage(provided: UUID) -> String {
        "I cannot edit book \(provided.uuidString): the current chat session is not bound to any book. Ask the user to pick a book in the sidebar before asking me to edit one."
    }

    /// Fallback when no `provided` UUID was sent (= LLM called the
    /// tool without a book_id at all; = this path is normally caught
    /// earlier by `invalidInput`, but defensive for completeness).
    private static func noChatBookBoundMessageNoProvided() -> String {
        "I cannot edit any book: the current chat session is not bound to one. Ask the user to pick a book in the sidebar before asking me to edit one."
    }

    /// LLM-facing soft message for cross-book writes. Gives the LLM
    /// the exact two options it should offer to the user:
    /// (1) switch the chat session's bound book;
    /// (2) re-issue with the bound book's id (= same-name typo case).
    private static func crossBookWriteMessage(current: UUID, provided: UUID) -> String {
        """
        I am bound to chat session for book \(current.uuidString); you asked me to edit book \(provided.uuidString). I will not cross-write between books. Two options:
          1. Ask the user to switch the chat session to the book they want edited (= pick \(provided.uuidString) in the sidebar).
          2. If you meant the current book and the names are similar (= same-character-name typos are common), re-issue the call with book_id=\(current.uuidString).
        """
    }
}

// MARK: - Validation helper

enum BookScopeGuard {
    /// Validate that a tool call's `providedBookID` matches the chat
    /// session's currently-bound book. Throws `BookScopeViolation`
    /// when the guard rejects the call (= the tool MUST NOT write
    /// before calling this).
    ///
    /// Parameters:
    /// - providedBookID: the book id from the JSON envelope (= nil
    ///   when the LLM forgot to send `book_id`).
    /// - currentChatBookIDProvider: closure returning the chat
    ///   session's currently bound book (= nil when no book is
    ///   selected).
    ///
    /// Returns silently on success; throws `BookScopeViolation` on
    /// failure (= caller catches via existing execute() error path).
    static func validate(
        providedBookID: UUID?,
        currentChatBookIDProvider: () -> UUID?
    ) throws {
        let current = currentChatBookIDProvider()
        guard let current else {
            throw BookScopeViolation.noChatBookBound(providedBookID: providedBookID)
        }
        if let provided = providedBookID, provided != current {
            throw BookScopeViolation.crossBookWrite(
                currentChatBookID: current,
                providedBookID: provided
            )
        }
        // Defensive: providedBookID == nil means the LLM forgot the
        // field. The tool's own invalidInput check should catch this
        // first (= via `Self.parseUUID`), but the guard rejects
        // uniformly as a backstop.
        if providedBookID == nil {
            throw BookScopeViolation.noChatBookBound(providedBookID: nil)
        }
    }
}