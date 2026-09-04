//
//  LongFormGuardrailsTests.swift · Wenshu · P1 ticket #6 (PORT-LONGFORM-001, 2026-09-04)
//
//  8 round-trip tests for LongFormGuardrails actor (the Swift
//  port of hermes's `agent/specialized/long_form_guardrails.py`):
//
//    1. testLoadGuardrails_fromBookConfig
//    2. testAddGuardrail_persistsToBookConfig
//    3. testRemoveGuardrail_removesFromBookConfig
//    4. testCheck_constraintViolation_returnsViolation
//    5. testCheck_constraintPass_noViolation
//    6. testCheck_strictEnforcement_rejectsResponse
//    7. testCheck_warnEnforcement_appendsWarning
//    8. testExtractConstraints_fromBookContext
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a per-book subdirectory that mirrors the
//  production walk (`<shelvesRoot>/<shelf>/books/<id>/`).
//  Caller-side teardown is not required (= the directory is
//  /tmp + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors BookCountStatusTests (= uses the real
//  LibraryStores struct + FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("LongFormGuardrails (PORT-LONGFORM-001)")
struct LongFormGuardrailsTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    /// Returns the BookStore + the underlying stores bundle (so
    /// each test can create its own per-book subdir under
    /// `stores.shelvesRoot`).
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p1-06-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        return (BookStore(stores: stores), stores)
    }

    /// Build a per-test book directory under `stores.shelvesRoot`.
    /// Creates `<shelvesRoot>/<shelf-uuid>/books/<book-uuid>/`
    /// so `BookStore.bookDirectory(bookId:)` returns the URL.
    private static func makeBookDir(under stores: LibraryStores, bookId: UUID) throws -> URL {
        let shelfUUID = UUID().uuidString
        let bookDir = stores.shelvesRoot
            .appendingPathComponent(shelfUUID, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        return bookDir
    }

    /// Build a BookStore + a per-book subdir for the supplied bookId.
    /// Convenience composition of `makeBookStore` + `makeBookDir`.
    private static func makeBookStoreWithDir(for bookId: UUID) throws -> (BookStore, URL) {
        let (store, stores) = try makeBookStore()
        let dir = try makeBookDir(under: stores, bookId: bookId)
        return (store, dir)
    }

    private static func sampleBookId() -> UUID { UUID() }

    // MARK: - Test 1: loadGuardrails reads the sidecar

    @Test("loadGuardrails returns auto-derived set when no sidecar exists")
    func testLoadGuardrails_fromBookConfig() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let actor = LongFormGuardrails(bookStore: store)

        let rows = try await actor.loadGuardrails(for: bookId)

        // The actor auto-derives the initial 6 (= 1 per kind).
        #expect(rows.count == LongFormGuardrailKind.allCases.count)
        #expect(rows.allSatisfy { $0.isAutoDerived })
        let kinds = Set(rows.map { $0.kind })
        #expect(kinds == Set(LongFormGuardrailKind.allCases))
    }

    // MARK: - Test 2: add persists to the sidecar

    @Test("add persists a user-authored guardrail to the sidecar")
    func testAddGuardrail_persistsToBookConfig() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let actor = LongFormGuardrails(bookStore: store)

        let row = LongFormGuardrail(
            kind: .constraint,
            source: .bookContext,
            enforce: .strict,
            name: "POV: 1st person limited",
            description: "Every chapter must be written from protagonist POV",
            pattern: "omniscient, third person",
            isAutoDerived: false
        )
        try await actor.add(row, to: bookId)

        let reloaded = try await actor.loadGuardrails(for: bookId)
        let saved = reloaded.first { $0.id == row.id }
        #expect(saved != nil)
        #expect(saved?.name == "POV: 1st person limited")
        #expect(saved?.enforce == .strict)
        #expect(saved?.pattern == "omniscient, third person")
        #expect(saved?.isAutoDerived == false)
    }

    // MARK: - Test 3: remove clears the sidecar entry

    @Test("remove deletes the guardrail from the sidecar")
    func testRemoveGuardrail_removesFromBookConfig() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let actor = LongFormGuardrails(bookStore: store)

        let row = LongFormGuardrail(
            kind: .selfProof,
            source: .bookContext,
            enforce: .warn,
            name: "Citation required",
            description: "Every claim must include a citation token",
            isAutoDerived: false
        )
        try await actor.add(row, to: bookId)
        try await actor.remove(id: row.id, from: bookId)

        let reloaded = try await actor.loadGuardrails(for: bookId)
        #expect(!reloaded.contains { $0.id == row.id })
    }

    // MARK: - Test 4: constraint violation

    @Test("check returns a violation when a forbidden word appears")
    func testCheck_constraintViolation_returnsViolation() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let actor = LongFormGuardrails(bookStore: store)

        let row = LongFormGuardrail(
            kind: .constraint,
            source: .bookContext,
            enforce: .warn,
            name: "No omniscient POV",
            description: "No omniscient POV",
            pattern: "omniscient",
            isAutoDerived: false
        )
        let violations = try await actor.check(
            "The story begins.\nAn omniscient narrator watches over the city.\n",
            against: [row]
        )
        #expect(violations.count == 1)
        let firstViolation = violations.first
        #expect(firstViolation?.kind == .constraint)
        #expect(firstViolation?.lineNumber == 2)
        let reason = firstViolation?.reason ?? ""
        #expect(reason.contains("omniscient"))
    }

    // MARK: - Test 5: constraint pass

    @Test("check returns no violation when the forbidden word is absent")
    func testCheck_constraintPass_noViolation() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let actor = LongFormGuardrails(bookStore: store)

        let row = LongFormGuardrail(
            kind: .constraint,
            source: .bookContext,
            enforce: .strict,
            name: "No omniscient POV",
            description: "No omniscient POV",
            pattern: "omniscient",
            isAutoDerived: false
        )
        let violations = try await actor.check(
            "I walked into the room and looked around.\nThe light was dim.\n",
            against: [row]
        )
        #expect(violations.isEmpty)
    }

    // MARK: - Test 6: strict enforcement rejects the response

    @Test("applyEnforcement throws when a strict guardrail produces a critical violation")
    func testCheck_strictEnforcement_rejectsResponse() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let actor = LongFormGuardrails(bookStore: store)

        let row = LongFormGuardrail(
            kind: .constraint,
            source: .bookContext,
            enforce: .strict,
            name: "No omniscient POV",
            description: "No omniscient POV",
            pattern: "omniscient",
            defaultSeverity: .critical,
            isAutoDerived: false
        )
        let text = "An omniscient narrator watches."
        let violations = try await actor.check(text, against: [row])
        #expect(violations.contains { $0.severity == .critical })

        // applyEnforcement must throw on a strict + critical
        // combination.
        #expect(throws: LongFormGuardrailsError.self) {
            try actor.applyEnforcementSync(text, violations: violations, against: [row])
        }
    }

    // MARK: - Test 7: warn enforcement appends a warning block

    @Test("applyEnforcement appends a warning block when a warn guardrail fires")
    func testCheck_warnEnforcement_appendsWarning() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let actor = LongFormGuardrails(bookStore: store)

        let row = LongFormGuardrail(
            kind: .constraint,
            source: .bookContext,
            enforce: .warn,
            name: "No omniscient POV",
            description: "No omniscient POV",
            pattern: "omniscient",
            defaultSeverity: .warning,
            isAutoDerived: false
        )
        let text = "An omniscient narrator watches."
        let violations = try await actor.check(text, against: [row])
        let result = try actor.applyEnforcementSync(text, violations: violations, against: [row])
        #expect(result.contains(text))
        #expect(result.contains("LongFormGuardrails warning"))
        #expect(result.contains("Constraint"))
    }

    // MARK: - Test 8: extractConstraints from book context

    @Test("extractConstraints produces one guardrail per kind from the book context")
    func testExtractConstraints_fromBookContext() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let actor = LongFormGuardrails(bookStore: store)

        let derived = await actor.extractConstraints(
            from: "The novel follows Lyra through a magic-tainted world where she must confront her past."
        )
        #expect(derived.count == LongFormGuardrailKind.allCases.count)
        #expect(derived.allSatisfy { $0.isAutoDerived })
        let kinds = Set(derived.map { $0.kind })
        #expect(kinds == Set(LongFormGuardrailKind.allCases))
        // Each row carries a non-empty description (the actor
        // builds it from the supplied book context).
        #expect(derived.allSatisfy { !$0.description.isEmpty })
    }
}

// MARK: - Synchronous applyEnforcement helper for tests

extension LongFormGuardrails {
    /// Test-only synchronous wrapper (= the actor's
    /// `applyEnforcement` is `throws` but not `async`; this
    /// helper exists to bridge `#expect(throws:)` calls in tests).
    /// Marked `nonisolated` to match the underlying method.
    nonisolated func applyEnforcementSync(_ text: String,
                                          violations: [LongFormGuardrailViolation],
                                          against guardrails: [LongFormGuardrail]) throws -> String {
        try self.applyEnforcement(text, violations: violations, against: guardrails)
    }
}