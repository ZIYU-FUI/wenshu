//
//  ChapterFocusLockDialog.swift · wenshu · chapter-dialog 2026-09-28 T1
//
//  Allow/Deny dialog model for the chapter focus lock (= §11.23
//  MVP auto-Allow + §11.24 dialog UX). When the LLM's tool call
//  hits ChapterFocusLockedError, the conductor (= ChapterFocusLockWrappedTool)
//  presents a dialog request via ChapterFocusLockDialogPresenter
//  (= a tiny AppStateLocator-style singleton that holds the
//  current pending request). ChatZoneView observes the presenter
//  and renders the .alert(item:) with Allow / Deny buttons. The
//  user's choice resumes the conductor's continuation; = Allow
//  releases the lock + retries, = Deny throws DatasetLockDeniedByBoss
//  (= the LLM receives the error and decides what to do next).
//
//  Apple HIG alert (= .alert(item:) + primaryButton Allow +
//  secondaryButton Deny) matches the macOS canonical dialog UX
//  (= same shape as System Settings permission prompts).
//

import SwiftUI

/// chapter-dialog 2026-09-28 T1: model for the Allow/Deny dialog
/// shown when the LLM hits the chapter focus lock. Carries the
/// chapter path (= for the title), the tool name (= for context),
/// a human-readable summary (= from the LLM's tool input; = the
/// LLM tells the user what it wants to do), and the continuation
/// that the conductor awaits. The dialog's buttons resume the
/// continuation with the user's choice.
///
/// `Identifiable` so ChatZoneView can use the request as the
/// `item:` parameter of `.alert(item:)`. The id is generated at
/// construction time (= each new request gets a fresh id so
/// SwiftUI's item-binding treats it as a new presentation).
struct ChapterFocusLockDialogRequest: Identifiable, Sendable {
    let id: UUID
    let chapterPath: String
    let toolName: String
    let summary: String
    let continuation: CheckedContinuation<Bool, Never>

    init(
        chapterPath: String,
        toolName: String,
        summary: String,
        continuation: CheckedContinuation<Bool, Never>
    ) {
        self.id = UUID()
        self.chapterPath = chapterPath
        self.toolName = toolName
        self.summary = summary
        self.continuation = continuation
    }
}

/// chapter-dialog 2026-09-28 T1: bridge between the conductor
/// (= background actor that wants to present a dialog) and
/// ChatZoneView (= SwiftUI view that renders the alert). Mirrors
/// the AppStateLocator pattern (= @MainActor singleton + weak
/// ref to the view-side presenter) so background actors can
/// surface UI requests without coupling to SwiftUI directly.
///
/// The presenter holds the current pending request (= nil = no
/// dialog visible). The conductor's `present(...)` enqueues the
/// request and awaits the continuation; = ChatZoneView's body
/// reads `pendingRequest` and renders the .alert(item:).
@MainActor
final class ChapterFocusLockDialogPresenter {
    static let shared = ChapterFocusLockDialogPresenter()
    /// The current pending dialog request (= nil = no dialog).
    /// ChatZoneView binds to this via the @Bindable / @Observable
    /// observation surface (= the `pendingRequest` setter
    /// triggers SwiftUI's body re-render).
    var pendingRequest: ChapterFocusLockDialogRequest?
    private init() {}

    /// Conductor-side entry point. Async because the dialog's
    /// choice is delivered via the continuation (= the conductor
    /// `await`s the user's Allow/Deny decision). Returns true
    /// (= Allow) or false (= Deny).
    ///
    /// The conductor is responsible for setting up the dialog
    /// surface before calling this (= the presenter only enqueues
    /// + awaits the continuation).
    func present(
        chapterPath: String,
        toolName: String,
        summary: String
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let request = ChapterFocusLockDialogRequest(
                chapterPath: chapterPath,
                toolName: toolName,
                summary: summary,
                continuation: continuation
            )
            self.pendingRequest = request
        }
    }

    /// User-allow path (= ChatZoneView's Allow button calls this).
    /// Resumes the continuation with true (= Allow).
    func allowCurrentRequest() {
        guard let request = pendingRequest else { return }
        pendingRequest = nil
        request.continuation.resume(returning: true)
    }

    /// User-deny path (= ChatZoneView's Deny button calls this).
    /// Resumes the continuation with false (= Deny).
    func denyCurrentRequest() {
        guard let request = pendingRequest else { return }
        pendingRequest = nil
        request.continuation.resume(returning: false)
    }
}

/// chapter-dialog 2026-09-28 T1: SwiftUI alert content view that
/// ChatZoneView hosts. Renders an Apple HIG permission-prompt-style
/// dialog (= title + message + primaryButton Allow + secondaryButton
/// Deny). The view's actions delegate to the presenter (= no
/// business logic in the view itself).
///
/// `title` and `message` come from the request's chapterPath +
/// summary; = localized via `WenshuI18n.t(...)`.
struct ChapterFocusLockDialogAlert: View {
    let request: ChapterFocusLockDialogRequest

    var body: some View {
        // SwiftUI alert builder returns a configured Alert; = the
        // host view's `.alert(item: $pendingDialog)` modifier uses
        // the Alert's content to render the dialog. We split this
        // into a static method so unit tests can verify the alert's
        // buttons + title without instantiating a SwiftUI view.
        let alert = Self.makeAlert(for: request)
        return Color.clear.alert(
            item: Binding(
                get: { request },
                set: { _ in }
            ),
            content: { _ in alert }
        )
    }

    /// Pure builder for the Alert (= testable without a SwiftUI
    /// view host). Both the Allow and Deny actions delegate to
    /// the presenter (= the view layer is dumb).
    static func makeAlert(for request: ChapterFocusLockDialogRequest) -> Alert {
        let chapterName = (request.chapterPath as NSString)
            .lastPathComponent
            .replacingOccurrences(of: ".md", with: "")
        return Alert(
            title: Text(String(localized: "chatview.focus_lock.title")
                .replacingOccurrences(of: "{chapter}", with: chapterName)),
            message: Text(request.summary),
            primaryButton: .default(
                Text(String(localized: "chatview.focus_lock.allow")),
                action: {
                    ChapterFocusLockDialogPresenter.shared.allowCurrentRequest()
                }
            ),
            secondaryButton: .cancel(
                Text(String(localized: "chatview.focus_lock.deny")),
                action: {
                    ChapterFocusLockDialogPresenter.shared.denyCurrentRequest()
                }
            )
        )
    }
}