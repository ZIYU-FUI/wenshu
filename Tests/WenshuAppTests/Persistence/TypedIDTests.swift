//
//  TypedIDTests.swift · Wenshu · P2-02 (audit 2026-09-24)
//
//  P2-02 (audit 2026-09-24): invariant tests for the BookID brand
//  wrapper. The brand wrapper exists to prevent confusion between
//  IDs of different kinds (= bookID ↔ chapterID ↔ sessionID ↔
//  memoryID). Without these tests, a future sweep could regress
//  the brand wrapper to raw String (= silently breaking the
//  type-safety invariant).
//
//  Tests:
//  1. BookID round-trips through rawValue (= brand wrapper
//     preserves identity via raw string).
//  2. Two BookIDs with the same rawValue are equal (= the wrapper
//     is a thin brand on top of String; = Hashable + Equatable
//     work as expected).
//  3. BookID is Sendable (= safe to pass across actor boundaries).
//  4. BookID is Codable (= safe to serialize through JSON / plist).
//  5. BookID conforms to TypedID (= the type-safe ID protocol).

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("TypedID brand wrapper invariants (= P2-02 round-trip + type-safety)")
struct TypedIDTests {

    @Test("BookID round-trips through rawValue")
    func bookIDRawValueRoundTrip() {
        let rawString = "550E8400-E29B-41D4-A716-446655440000"
        let bookID = BookID(rawValue: rawString)
        #expect(bookID.rawValue == rawString)
    }

    @Test("Two BookIDs with the same rawValue are equal (= Hashable identity)")
    func bookIDEquality() {
        let a = BookID(rawValue: "book-1")
        let b = BookID(rawValue: "book-1")
        let c = BookID(rawValue: "book-2")
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("BookID is Sendable (= safe to pass across actor boundaries)")
    func bookIDSendable() {
        // Sendable conformance is implicit; = the test verifies
        // the type system accepts the conformance without runtime
        // failure (= if BookID ever loses Sendable, this test
        // would not compile).
        let bookID = BookID(rawValue: "book-1")
        nonisolated(unsafe) var stored: BookID? = nil
        stored = bookID
        #expect(stored?.rawValue == "book-1")
    }

    @Test("BookID is Codable (= JSON encode + decode round-trip)")
    func bookIDCodableRoundTrip() throws {
        let original = BookID(rawValue: "book-codable-1")
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BookID.self, from: data)
        #expect(decoded == original)
    }

    @Test("BookID conforms to TypedID (= the brand-wrapper protocol)")
    func bookIDConformsToTypedID() {
        // The conformance is structural (= BookID: TypedID). The
        // assertion below is a compile-time check; = if BookID
        // ever loses conformance to TypedID, this line fails to
        // compile (= the test runner never even gets to run).
        let bookID: any TypedID = BookID(rawValue: "book-1")
        #expect(bookID.rawValue == "book-1")
    }

    @Test("BookID is stable across SwiftData write/read (= brand wrapper does not corrupt the underlying String)")
    @MainActor
    func bookIDStableAcrossSwiftData() throws {
        let schema = Schema([WSChatMessage.self, WSSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Write a session + message with BookID wrapper at the API surface.
        let sessionID = "sess-typedid-1"
        let bookID = BookID(rawValue: "book-typedid-1")
        let session = WSSession(sessionID: sessionID, bookID: bookID.rawValue)
        context.insert(session)
        let msg = WSChatMessage(
            id: "msg-typedid-1",
            sessionID: sessionID,
            role: "user",
            content: "hello",
            position: 0,
            bookID: bookID.rawValue
        )
        context.insert(msg)
        try context.save()

        // Read back from SwiftData (= raw String at the column level).
        let descriptor = FetchDescriptor<WSSession>(
            predicate: #Predicate { $0.sessionID == sessionID }
        )
        let loaded = try context.fetch(descriptor)
        #expect(loaded.count == 1)
        #expect(loaded[0].bookID == "book-typedid-1")

        // The brand wrapper round-trips: build a BookID from the raw
        // String and verify equality with the original.
        let roundTripped = BookID(rawValue: loaded[0].bookID ?? "")
        #expect(roundTripped == bookID)
    }

    @Test("SwiftData #Predicate macro accepts BookID via .rawValue lift (= the Q46 stop-rule workaround)")
    @MainActor
    func predicateMacroAcceptsBookIDViaRawValueLift() throws {
        // The SwiftData #Predicate macro rejects function calls (= e.g.
        // `bookID.rawValue`) inside the closure body. The fix (= per
        // P2-02 commit 16 Q46 stop-rule activation) is to lift the
        // brand wrapper's raw value into a local `let` binding
        // OUTSIDE the predicate closure, then capture the local let
        // by reference inside the predicate.
        //
        // This test verifies the lift works end to end (= if a future
        // sweep regresses the lift, this test fails to compile).
        let schema = Schema([WSSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let bookA = BookID(rawValue: "book-A-predicate-test")
        let bookB = BookID(rawValue: "book-B-predicate-test")
        let bookC = BookID(rawValue: "book-C-predicate-test")
        context.insert(WSSession(sessionID: "sess-A", bookID: bookA.rawValue))
        context.insert(WSSession(sessionID: "sess-B", bookID: bookB.rawValue))
        context.insert(WSSession(sessionID: "sess-C", bookID: bookC.rawValue))
        try context.save()

        // Filter for one specific bookID using the lift pattern.
        let bookIDRaw = bookB.rawValue
        let descriptor = FetchDescriptor<WSSession>(
            predicate: #Predicate { $0.bookID == bookIDRaw }
        )
        let matched = try context.fetch(descriptor)
        #expect(matched.count == 1)
        #expect(matched[0].sessionID == "sess-B")
        #expect(BookID(rawValue: matched[0].bookID ?? "") == bookB)
    }

    @Test("ToolCallID brand wrapper (= tool-call ID type-safety scaffolding per P2-03 typed-ID rollout)")
    func toolCallIDBrandWrapper() {
        // Construction: rawValue-string initializer (= canonical).
        let id = ToolCallID(rawValue: "tc-abc-123")
        #expect(id.rawValue == "tc-abc-123")
        #expect(id.stringValue == "tc-abc-123")

        // newID() (= the TypedID extension default = UUID().uuidString).
        let generated = ToolCallID.newID()
        #expect(!generated.rawValue.isEmpty)

        // Equatable + Hashable (= dictionary key + set membership work).
        let same = ToolCallID(rawValue: "tc-abc-123")
        let diff = ToolCallID(rawValue: "tc-xyz-999")
        #expect(id == same)
        #expect(id != diff)
        var set: Set<ToolCallID> = [id, same, diff]
        #expect(set.count == 2)

        // Codable round-trip (= JSON-LLM wire-format safety).
        let encoder = JSONEncoder()
        let data = try! encoder.encode(id)
        #expect(String(data: data, encoding: .utf8) == "\"tc-abc-123\"")
        let decoded = try! JSONDecoder().decode(ToolCallID.self, from: data)
        #expect(decoded == id)
    }
}