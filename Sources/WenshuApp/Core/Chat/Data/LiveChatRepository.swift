//
//  LiveChatRepository.swift
//
//  SwiftData-backed ChatRepositoryProtocol implementation. Thin
//  adapter over `WSChatRepository.shared` (= the @MainActor SwiftData
//  wrapper). The adapter:
//    - Owns the StoredChatMessage ↔ ChatMessage mapping (= where it
//      belongs — the persistence layer speaks StoredChatMessage, the
//      business layer speaks ChatMessage).
//    - Hops to MainActor internally for every call (= WSChatRepository
//      is @MainActor isolated; = each method wraps a single await).
//    - Is marked @unchecked Sendable (= the only stored state is the
//      trivial lookup of WSChatRepository.shared; = cross-actor reads
//      are safe because we always re-enter MainActor before touching
//      the SwiftData wrapper).
//
//  Why a separate class instead of just adopting the protocol on
//  WSChatRepository (= retroactive conformance)? Two reasons:
//    1. WSChatRepository lives in Persistence/ (= the SwiftData
//       bridge layer) and returns StoredChatMessage. The protocol
//       returns ChatMessage (= domain type). Forcing WSChatRepository
//       to know about ChatMessage creates a Persistence → Domain
//       upward dependency (= bad architecture).
//    2. LiveChatRepository is the seam where future backends plug in.
//       It is small (= 4 methods) and stable.
//

import Foundation
import SwiftData

/// SwiftData-backed ChatRepositoryProtocol implementation. Thin
/// @unchecked Sendable: holds no mutable state. All reads of
/// WSChatRepository.shared hop to MainActor (= the SwiftData
/// wrapper's isolation); the only stored reference is the
/// global singleton lookup (= trivially Sendable).
final class LiveChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
/// Optional override (= nil in production). When set, every forwarder
/// uses this container instead of WSChatRepository.shared (= shared
/// always uses WSPersistenceContainer.shared = the global store).
private let containerOverride: ModelContainer?

/// Default initializer (= uses WSChatRepository.shared with the
/// global persistence container). Production callers use this.
///
/// an init variant with an injected
/// container exists below (= LiveChatRepository(container:)) so
/// unit tests can isolate the Live adapter against a per-test
/// in-memory container without polluting the shared singleton.
init() {
    self.containerOverride = nil
}

/// Test-only initializer: back the Live adapter with a custom
/// ModelContainer (= e.g. a per-test in-memory container built via
/// WSPersistenceContainer.makeInMemoryContainer()). All forwarders
/// route through the WSChatRepository built from this container
/// instead of the shared singleton.
///
/// @unchecked Sendable: holds no mutable state. The custom
/// container reference is read-only; all writes go through the
/// WSChatRepository wrapper which is @MainActor-isolated.
init(container: ModelContainer) {
    self.containerOverride = container
}

    /// Helper: resolve the WSChatRepository wrapper to use for a given
    /// call. Returns the custom-container wrapper when one was injected
    /// at init; = falls back to WSChatRepository.shared for production.
    /// The `bookID` parameter is unused here (= future ticket may scope
    /// the lookup further; = currently the only scope mechanism is
    /// per-method predicates).
    ///
    /// @MainActor because WSChatRepository.shared is @MainActor-isolated;
    /// = callers always invoke this from within a MainActor.run block.
    @MainActor
    private func repository(bookID _: BookID?) -> WSChatRepository {
        if let containerOverride {
            return WSChatRepository(container: containerOverride)
        }
        return WSChatRepository.shared
    }

    func append(_ message: ChatMessage, sessionId: SessionID, bookID: BookID?) async throws {
        let stored = Self.makeStored(from: message)
        try await Self.runOnMainActor {
            try self.repository(bookID: bookID).append(stored, sessionId: sessionId.rawValue, bookID: bookID)
        }
    }

    func loadMessages(sessionId: SessionID, bookID: BookID?) async throws -> [ChatMessage] {
        let stored: [StoredChatMessage] = try await Self.runOnMainActor {
            try self.repository(bookID: bookID).loadMessages(sessionId: sessionId.rawValue, bookID: bookID)
        }
        return stored.compactMap(Self.makeDomain(from:))
    }

    func summarizeIfNeeded(
        sessionId: SessionID,
        lastN: Int,
        threshold: Int,
        verifier: WenshuVerifier,
        bookID: BookID?
    ) async throws {
        // WSChatRepository.summarizeIfNeeded is @MainActor + async.
        // Calling a @MainActor-isolated async method from a
        // nonisolated context triggers an automatic actor hop
        // (= the await suspends, re-schedules on MainActor, runs
        // the body, then resumes the caller). No manual wrap
        // needed (= MainActor.run only accepts sync closures).
        // The Bool return value (= "did we summarize?") is dropped
        // here on purpose: the protocol caller doesn't surface it.
        // Callers that need the flag should query the repository
        // directly (= the minimal-seam rule: protocol stays
        // narrow, callers needing richer behavior hit the
        // concrete repository type).
        _ = try await self.repository(bookID: bookID).summarizeIfNeeded(
            sessionId: sessionId.rawValue,
            lastN: lastN,
            threshold: threshold,
            verifier: verifier,
            bookID: bookID
        )
    }

    // C-6: filesystem IO = data-layer concern. The business layer
    // used to call FileManager.default.copyItem directly inside
    // ChatSessionViewModel.attachImage (= violated the
    // UI / business / data separation; = FileManager is data-layer
    // IO). Now the live impl owns:
    //   - extension whitelist (= png / jpg / jpeg / gif / heic)
    //   - directory creation (cache/chat-uploads/)
    //   - unique filename via UUID
    //   - FileManager.copyItem call
    func copyChatUpload(sourceURL: URL, intoLibraryAt path: String) async throws -> String? {
        let fm = FileManager.default
        let ext = sourceURL.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "gif", "heic"].contains(ext) else { return nil }
        guard fm.fileExists(atPath: sourceURL.path) else { return nil }
        guard !path.isEmpty else { return nil }
        let uploadsDir = URL(fileURLWithPath: path)
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent("chat-uploads", isDirectory: true)
        try fm.createDirectory(at: uploadsDir, withIntermediateDirectories: true)
        let destName = UUID().uuidString + "." + ext
        let destURL = uploadsDir.appendingPathComponent(destName)
        // security-scoped resource: NSOpenPanel gives us a URL with
        // sandbox-scoped access; copying into our own uploads dir
        // permanently lifts the scope. For .fileImporter (= the
        // entry point used by the attach button), the picked URL
        // is already accessible in the process sandbox.
        try fm.copyItem(at: sourceURL, to: destURL)
        return destURL.path
    }

    // MARK: - StoredChatMessage ↔ ChatMessage mapping

    /// Convert a ChatMessage (= domain type, may carry streaming parts
    /// + body metadata) into a StoredChatMessage (= the lean SwiftData
    /// row shape: id + source + content + timestamp + tokens + thinking).
    /// Mirrors the per-call conversion that previously lived inline at
    /// the ChatSessionViewModel call sites (= 3 places).
    static func makeStored(from message: ChatMessage) -> StoredChatMessage {
        let sourceString: String
        switch message.source {
        case .user: sourceString = "user"
        case .wenshu: sourceString = "wenshu"
        case .system: sourceString = "system"
        }
        return StoredChatMessage(
            id: message.id.uuidString,
            source: sourceString,
            content: message.content,
            timestamp: message.timestamp,
            tokens: message.tokens,
            // Mirror the legacy call sites' thinking behavior:
            // nil when thinking is nil OR empty string. Empty-string
            // thinking would otherwise round-trip as a phantom
            // reasoning part in the next load (= visible noise in
            // ChatMessageView's reasoning toggle).
            thinking: message.thinking?.isEmpty == false ? message.thinking : nil
        )
    }

    /// Convert a StoredChatMessage back into a ChatMessage. Returns
    /// nil (= drop the record) when the stored id isn't a valid UUID
    /// (= malformed row from legacy data) or the source isn't a
    /// known ChatSource case (= silent data corruption symptom —
    /// the v0.71 P1 batch 6 dual-axis audit added this explicit
    /// drop in place of the previous "silently rewrite to .wenshu"
    /// fallback).
    static func makeDomain(from stored: StoredChatMessage) -> ChatMessage? {
        guard let uuid = UUID(uuidString: stored.id) else { return nil }
        let resolvedRole: ChatRole
        let resolvedSource: ChatSource
        switch stored.source {
        case "user":
            resolvedRole = .user
            resolvedSource = .user
        case "wenshu":
            resolvedRole = .agent
            resolvedSource = .wenshu
        case "system":
            resolvedRole = .system
            resolvedSource = .system
        default:
            return nil
        }
        return ChatMessage(
            id: uuid,
            role: resolvedRole,
            source: resolvedSource,
            content: stored.content,
            timestamp: stored.timestamp,
            tokens: stored.tokens,
            thinking: stored.thinking
        )
    }

    /// Helper: hop to MainActor and run a sync closure (= SwiftData
    /// wrapper methods like append / loadMessages are sync-throws).
    /// Used for sync @MainActor methods where MainActor.run's
    /// sync-only contract applies.
    private static func runOnMainActor<T: Sendable>(
        _ body: @escaping @MainActor () throws -> T
    ) async throws -> T {
        try await MainActor.run { try body() }
    }
}

/// The default singleton instance (= injected into
/// ChatSessionViewModel via `init(repository:)` with default value
/// = `LiveChatRepository.shared`). Tests pass a fake via the same
/// init parameter.
extension LiveChatRepository {
    /// Shared singleton (= `@unchecked Sendable`; = safe because
    /// the class holds no mutable state).
    static let shared = LiveChatRepository()
}
