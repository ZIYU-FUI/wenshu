//
//  AsyncDelegationScopeTests.swift · Wenshu ·  (2026-10-23)
//
//  The scope a delegation carries.
//
//  The registry is ONE instance for the whole app, so a handle that does
//  not say which chat asked for it belongs to every chat at once. The
//  scope is written AT CREATION (= when the handle is made), because
//  once it is missing it cannot be recovered later.
//
//  The book travels beside the session because the two session-id shapes
//  carry different information: a per-book chat's id is
//  `book:<uuid>:default` (= the book is inside it), but a brand new
//  chat's id is `s_<uuid>` (= the book is NOT). So the read asks for
//  both halves and a same-session / different-book delegation is not
//  part of the scope's list.
//
//

import Foundation
import Testing
import WenshuData
@testable import WenshuApp

@Suite("AsyncDelegation scope (which chat and book asked for this sub-agent)")
struct AsyncDelegationScopeTests {

    private static let sessionID = SessionID(rawValue: "book:book-A:default")
    private static let otherSessionID = SessionID(rawValue: "book:book-B:default")
    private static let bookA = BookID(rawValue: "book-A")
    private static let bookB = BookID(rawValue: "book-B")

    // MARK: - The handle carries the scope it was created with

    @Test("a handle carries the session and the book it was created with")
    func handleCarriesItsScope() {
        let scope = AgentScope(sessionID: Self.sessionID, bookID: Self.bookA)
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "scope probe",
            scope: scope
        )

        #expect(handle.scope == scope)
        #expect(handle.scope?.sessionID == Self.sessionID)
        #expect(handle.scope?.bookID == Self.bookA)
    }

    @Test("a handle created without a scope has none")
    func handleWithoutScopeHasNone() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "no scope probe"
        )

        #expect(handle.scope == nil)
    }

    // MARK: - The registry answers for exactly one scope

    @Test("handles(scope:) returns the delegation that carries that scope")
    func handlesReturnsTheScopedDelegation() async {
        let registry = AsyncDelegationRegistry()
        let scope = AgentScope(sessionID: Self.sessionID, bookID: Self.bookA)

        let mine = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "mine",
            scope: scope
        )
        await registry.register(handle: mine)

        let found = await registry.handles(scope: scope)

        #expect(found.count == 1)
        #expect(found.first?.id == mine.id)
        #expect(found.first?.userMessage == "mine")
    }

    @Test("the same session in a different book is not part of the scope")
    func sameSessionDifferentBookIsNotReturned() async {
        let registry = AsyncDelegationRegistry()
        let scope = AgentScope(sessionID: Self.sessionID, bookID: Self.bookA)

        // Same session id, different book.
        let otherBook = BackgroundDelegationHandle(
            agentName: "writer",
            userMessage: "another book's delegation",
            scope: AgentScope(sessionID: Self.sessionID, bookID: Self.bookB)
        )
        await registry.register(handle: otherBook)

        let found = await registry.handles(scope: scope)

        #expect(found.isEmpty)
    }

    @Test("a delegation with no scope is never returned")
    func unscopedDelegationIsNeverReturned() async {
        let registry = AsyncDelegationRegistry()
        let scope = AgentScope(sessionID: Self.sessionID, bookID: Self.bookA)

        await registry.register(
            handle: BackgroundDelegationHandle(
                agentName: "auditor",
                userMessage: "unscoped delegation"
            )
        )

        let found = await registry.handles(scope: scope)

        #expect(found.isEmpty)
    }

    @Test("a delegation from another session is not part of the scope")
    func otherSessionIsNotReturned() async {
        let registry = AsyncDelegationRegistry()
        let scope = AgentScope(sessionID: Self.sessionID, bookID: Self.bookA)

        await registry.register(
            handle: BackgroundDelegationHandle(
                agentName: "analyst",
                userMessage: "another session's delegation",
                scope: AgentScope(sessionID: Self.otherSessionID, bookID: Self.bookA)
            )
        )

        let found = await registry.handles(scope: scope)

        #expect(found.isEmpty)
    }

    @Test("handles(scope:) returns the newest delegation first")
    func handlesReturnsNewestFirst() async {
        let registry = AsyncDelegationRegistry()
        let scope = AgentScope(sessionID: Self.sessionID, bookID: Self.bookA)

        let older = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "older",
            state: .running,
            startedAt: Date(timeIntervalSince1970: 1_000),
            scope: scope
        )
        let newer = BackgroundDelegationHandle(
            agentName: "writer",
            userMessage: "newer",
            state: .running,
            startedAt: Date(timeIntervalSince1970: 2_000),
            scope: scope
        )

        await registry.register(handle: older)
        await registry.register(handle: newer)

        let found = await registry.handles(scope: scope)

        #expect(found.count == 2)
        #expect(found.first?.id == newer.id)
        #expect(found.last?.id == older.id)
    }

    // MARK: - delegate() stamps the scope onto the handle it registers

    @Test("delegate() writes the scope onto the handle it registers")
    func delegateWritesScopeOntoTheHandle() async throws {
        let registry = AsyncDelegationRegistry()
        let scope = AgentScope(sessionID: Self.sessionID, bookID: Self.bookA)

        let result = try await delegate(
            subagentProfile: "researcher",
            task: "scope probe through delegate()",
            registry: registry,
            scope: scope
        )

        #expect(result.handle.scope == scope)

        let found = await registry.handles(scope: scope)
        #expect(found.count == 1)
        #expect(found.first?.id == result.handle.id)
    }

    @Test("delegate() without a scope registers a handle with no scope")
    func delegateWithoutScopeRegistersAnUnscopedHandle() async throws {
        let registry = AsyncDelegationRegistry()

        let result = try await delegate(
            subagentProfile: "researcher",
            task: "no scope through delegate()",
            registry: registry
        )

        #expect(result.handle.scope == nil)

        // The handle is still registered (= the scope is optional, not
        // a gate on the delegation itself).
        let stored = await registry.get(id: result.handle.id)
        #expect(stored != nil)
        #expect(stored?.agentName == "researcher")
    }
}
