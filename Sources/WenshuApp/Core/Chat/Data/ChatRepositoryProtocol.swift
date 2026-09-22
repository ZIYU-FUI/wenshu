//
//  ChatRepositoryProtocol.swift · Wenshu · refactor chat-mvvm-3layer C-4
//
//  Data-layer seam for the chat feature. Decouples the business
//  layer (= ChatSessionViewModel) from the concrete SwiftData wrapper
//  (= WSChatRepository.shared) so:
//  - Unit tests can inject an in-memory fake (= no SwiftData stack
//    needed; = each test starts with an empty chat history and runs
//    in milliseconds).
//  - Future backends (= remote chat sync, alternative stores like
//    SQLite or a remote DB) can be added by writing a new
//    ChatRepositoryProtocol implementer; = business layer stays put.
//
//  Surface (= the minimal contract the business layer needs):
//    - append(_:sessionId:)  — write one chat message
//    - loadMessages(sessionId:)  — read full history for one session
//    - summarizeIfNeeded(sessionId:lastN:threshold:verifier:)
//      — trigger LLM-driven context compression when history grows
//
//  Each method takes + returns domain types (= ChatMessage, not
//  StoredChatMessage). The mapping to StoredChatMessage (= the
//  SwiftData row shape) lives inside the Live implementation.
//  This keeps the protocol store-agnostic: a future non-SwiftData
//  backend doesn't need to deal with the leaner stored type.
//
//  Async + throws (not @MainActor-isolated at the protocol level):
//  The Live impl hops to MainActor internally (= WSChatRepository is
//  @MainActor) and Swift's actor-isolation checker handles the
//  cross-actor call. Callers (= ChatSessionViewModel, also @MainActor)
//  can call these methods directly without ceremony.
//
//  Sendable conformance: protocol declarations are implicitly
//  Sendable when the witness (= the concrete impl) is Sendable.
//  `LiveChatRepository` (= future commit) will mark itself
//  `final class ... : @unchecked Sendable` because it holds a
//  SwiftData ModelContext reference (= SwiftData's ModelContext is
//  not Sendable across actors; = we never cross actors with it
//  anyway because every method hops to MainActor inside).
//

import Foundation

/// Data-layer seam for chat persistence. Implementers handle the
/// concrete storage (SwiftData, in-memory fake, remote backend, …).
public protocol ChatRepositoryProtocol: Sendable {
    /// Append one chat message to the given session. Silent no-op
    /// (= `try?` + no throw visible to caller) is the convention —
    /// persistence failures should not crash the chat pipeline.
    func append(_ message: ChatMessage, sessionId: String) async throws

    /// Load the full history of one session, oldest first.
    /// Returns an empty array (= not throw) when the session is
    /// new or the store is unavailable — callers render the empty
    /// state directly.
    func loadMessages(sessionId: String) async throws -> [ChatMessage]

    /// Trigger LLM-driven summarization (= hermes `ConversationCompression`)
    /// when the history grows past `threshold` (= in turns). The
    /// `verifier` is the LLM verifier (= same one used by the chat
    /// pipeline) — the repository doesn't own the LLM client.
    func summarizeIfNeeded(
        sessionId: String,
        lastN: Int,
        threshold: Int,
        verifier: WenshuVerifier
    ) async throws

    /// C-6: copy a user-picked chat attachment (e.g. a screenshot
    /// from .fileImporter) into the library's canonical
    /// `cache/chat-uploads/` dir. Returns the destination absolute
    /// path on success; nil (= silent no-op) when the source file
    /// is missing, the extension isn't whitelisted, or the
    /// library path is empty.
    ///
    /// Caller responsibility (= business layer):
    ///   - read `wenshu.libraryPath` from UserDefaults and pass it
    ///     as `intoLibraryAt`. This is an app-config lookup (= OK
    ///     for the business layer to read UserDefaults directly);
    ///     FileManager / filesystem IO is NOT.
    ///   - decide when to clear the draft (= call `clearAttachedImage`
    ///     on the view model after the send).
    ///
    /// File extension whitelist (= common screenshot formats):
    ///   png / jpg / jpeg / gif / heic.
    func copyChatUpload(sourceURL: URL, intoLibraryAt path: String) async throws -> String?
}
