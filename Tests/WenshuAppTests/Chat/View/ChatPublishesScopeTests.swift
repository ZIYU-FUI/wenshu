//
//  ChatPublishesScopeTests.swift · Wenshu
//
//  The chat zone publishes its identity (= session id + book id) onto
//  the shared app state, so the right-hand column's Status page can
//  list this chat's sub-agent tasks.
//
//  The two halves travel as their strong types: the status page builds
//  its registry scope from them directly, so no string conversion
//  happens on the way out.
//
//

import Foundation
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("The chat zone publishes its scope")
struct ChatPublishesScopeTests {

    // MARK: - The published values

    /// The chat zone publishes the session id and the book id it holds.
    @MainActor
    @Test("The chat zone publishes the session id and the book id it holds")
    func publishesSessionAndBook() {
        let fake = FakeChatRepository()
        let vm = ChatViewModel(
            repository: fake,
            bookID: BookID(rawValue: "book-A"),
            providersConfigured: { true }
        )
        let appState = AppState()

        ChatZoneView.publishScope(vm: vm, into: appState)

        #expect(appState.chatSessionID == vm.valueForSessionId(),
                "the published session id must be the chat's own")
        #expect(appState.chatSessionID == SessionID(rawValue: "book:book-A:default"),
                "the published session id must carry the book's scope")
        #expect(appState.chatBookID == BookID(rawValue: "book-A"),
                "the published book id must be the chat's own")
    }

    /// The published values are the strong types the status page reads.
    @MainActor
    @Test("The published scope carries the strong id types")
    func publishesStrongTypes() {
        let fake = FakeChatRepository()
        let vm = ChatViewModel(
            repository: fake,
            bookID: BookID(rawValue: "book-A"),
            providersConfigured: { true }
        )
        let appState = AppState()

        ChatZoneView.publishScope(vm: vm, into: appState)

        // The assignment is the assertion: the fields hold the strong
        // types, so the status page can build its scope from them
        // without converting anything.
        let session: SessionID? = appState.chatSessionID
        let book: BookID? = appState.chatBookID
        #expect(session != nil)
        #expect(book != nil)
    }

    // MARK: - A later change

    /// A later change to the book replaces the published values.
    @MainActor
    @Test("A later change of the book replaces the published scope")
    func aLaterBookChangeReplacesThePublishedScope() {
        let fake = FakeChatRepository()
        let vm = ChatViewModel(
            repository: fake,
            bookID: BookID(rawValue: "book-A"),
            providersConfigured: { true }
        )
        let appState = AppState()
        ChatZoneView.publishScope(vm: vm, into: appState)

        // The chat moves to another book.
        vm.setCurrentBookID(BookID(rawValue: "book-B"))
        ChatZoneView.publishScope(vm: vm, into: appState)

        #expect(appState.chatBookID == BookID(rawValue: "book-B"),
                "the published book id must follow the chat")
        #expect(appState.chatSessionID == vm.valueForSessionId(),
                "the published session id must follow the chat")
        #expect(appState.chatSessionID == SessionID(rawValue: "book:book-B:default"),
                "the session id must carry the new book's scope")
    }

    /// A later change of the session replaces the published session id
    /// and leaves the book alone.
    @MainActor
    @Test("A later change of the session replaces the published session id")
    func aLaterSessionChangeReplacesThePublishedSession() {
        let fake = FakeChatRepository()
        let vm = ChatViewModel(
            repository: fake,
            bookID: BookID(rawValue: "book-A"),
            providersConfigured: { true }
        )
        let appState = AppState()
        ChatZoneView.publishScope(vm: vm, into: appState)
        let firstSession = appState.chatSessionID

        // The chat starts a new session.
        vm.startNewSession()
        ChatZoneView.publishScope(vm: vm, into: appState)

        #expect(appState.chatSessionID != firstSession,
                "the published session id must follow the chat")
        #expect(appState.chatSessionID == vm.valueForSessionId(),
                "the published session id must be the chat's own")
        #expect(appState.chatBookID == BookID(rawValue: "book-A"),
                "the published book id must stay the chat's own")
    }

    // MARK: - The wiring

    /// The chat zone publishes when it appears and whenever either
    /// value changes.
    @Test("The chat zone publishes on appearance and on every change")
    func theChatZonePublishesOnAppearanceAndOnChange() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatZoneView.swift",
            encoding: .utf8
        )
        #expect(source.contains("Self.publishScope(vm: vm, into: envAppState)"),
                "the chat zone must publish its scope")
        #expect(source.contains(".onChange(of: vm.currentBookID)"),
                "the chat zone must react to a change of the book")
        #expect(source.contains(".onChange(of: vm.valueForSessionId())"),
                "the chat zone must react to a change of the session")
    }

    /// The chat zone's own signal for a new session fires on the real
    /// view model.
    ///
    /// The session id lives behind a method on the view model, so the
    /// chat zone watches the method's value. This drives the real view
    /// model and proves the watch fires when the session changes.
    @MainActor
    @Test("The chat zone's session watch fires when the session changes")
    func theSessionWatchFiresOnTheRealViewModel() {
        let fake = FakeChatRepository()
        let vm = ChatViewModel(
            repository: fake,
            bookID: BookID(rawValue: "book-A"),
            providersConfigured: { true }
        )
        let watch = SessionWatch()
        let host = NSHostingView(rootView: AnyView(
            SessionWatchView(vm: vm, watch: watch)
        ))
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 200)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        #expect(watch.fired == false,
                "the watch must not fire before the session changes")

        // The chat starts a new session.
        vm.startNewSession()
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()

        #expect(watch.fired,
                "the chat zone must see the session change")
        #expect(watch.lastSession == vm.valueForSessionId(),
                "the watch must carry the chat's own session id")
    }
}

// MARK: - The session watch

/// Whether the session watch fired.
@MainActor
final class SessionWatch {
    var fired = false
    var lastSession: SessionID?
}

/// A view that watches the session the way the chat zone does.
@MainActor
struct SessionWatchView: View {
    let vm: ChatViewModel
    let watch: SessionWatch

    var body: some View {
        Color.clear
            .onChange(of: vm.valueForSessionId()) { _, newSession in
                watch.fired = true
                watch.lastSession = newSession
            }
    }
}
