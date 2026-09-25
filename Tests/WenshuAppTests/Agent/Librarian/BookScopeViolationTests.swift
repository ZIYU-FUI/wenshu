//
//  BookScopeViolationTests.swift · Wenshu · v2.1 (2026-09-25)
//
//  Unit tests for the book scope guard. Two halves:
//    1. BookScopeGuard.validate: throws the right BookScopeViolation
//       flavor for the right input (= no chat bound / cross-book).
//    2. BookScopeViolation.errorDescription: the soft LLM-facing
//       message is shaped for the user (= includes both UUIDs so
//       the LLM can guide them to switch / re-issue).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookScopeGuard (v2.1)")

struct BookScopeViolationTests {

    // MARK: - BookScopeGuard.validate

    @Test func validate_matchingBookIDs_returns() throws {
        let chatBook = UUID()
        let provided = chatBook
        // Should NOT throw.
        try BookScopeGuard.validate(
            providedBookID: provided,
            currentChatBookIDProvider: { chatBook }
        )
    }

    @Test func validate_noChatBookBound_throwsNoChatBookBound() {
        let provided = UUID()
        #expect(throws: BookScopeViolation.self) {
            try BookScopeGuard.validate(
                providedBookID: provided,
                currentChatBookIDProvider: { nil }
            )
        }
    }

    @Test func validate_crossBookWrite_throwsCrossBookWrite() {
        let chatBook = UUID()
        let requestedBook = UUID()
        let thrown = #expect(throws: BookScopeViolation.self) {
            try BookScopeGuard.validate(
                providedBookID: requestedBook,
                currentChatBookIDProvider: { chatBook }
            )
        }
        // Soft message: both UUIDs must appear (= so the LLM can
        // tell the user which book to switch to).
        if case .crossBookWrite(let cur, let prov) = thrown {
            #expect(cur == chatBook)
            #expect(prov == requestedBook)
        } else {
            Issue.record("expected crossBookWrite, got \(String(describing: thrown))")
        }
    }

    @Test func validate_missingProvidedAndChatBound_throwsNoChatBookBound() {
        let chatBook = UUID()
        // Defensive path: provider returns a book, but the LLM forgot
        // to send book_id. validate still rejects (= falls into the
        // nil-provided branch).
        #expect(throws: BookScopeViolation.self) {
            try BookScopeGuard.validate(
                providedBookID: nil,
                currentChatBookIDProvider: { chatBook }
            )
        }
    }

    // MARK: - BookScopeViolation.errorDescription

    @Test func errorDescription_noChatBookBound_mentionsPickBook() {
        let violation = BookScopeViolation.noChatBookBound(providedBookID: UUID())
        let msg = violation.errorDescription ?? ""
        #expect(msg.contains("not bound"))
        #expect(msg.contains("sidebar"))
        #expect(!msg.isEmpty)
    }

    @Test func errorDescription_crossBookWrite_offersBothOptions() {
        let cur = UUID()
        let prov = UUID()
        let violation = BookScopeViolation.crossBookWrite(
            currentChatBookID: cur,
            providedBookID: prov
        )
        let msg = violation.errorDescription ?? ""
        #expect(msg.contains(cur.uuidString))
        #expect(msg.contains(prov.uuidString))
        // The two options must be spelled out (= so the LLM does
        // not have to invent them).
        #expect(msg.contains("switch"))
        #expect(msg.contains("re-issue"))
    }
}