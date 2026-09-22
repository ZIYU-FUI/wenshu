//
//  LiveChatRepository.swift · Wenshu · refactor chat-mvvm-3layer C-4
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

/// SwiftData-backed ChatRepositoryProtocol implementation.
/// @unchecked Sendable: holds no mutable state. All reads of
/// WSChatRepository.shared hop to MainActor (= the SwiftData
/// wrapper's isolation); the only stored reference is the
/// global singleton lookup (= trivially Sendable).
public final class LiveChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    public init() {}

    public func append(_ message: ChatMessage, sessionId: String) async throws {
        let stored = Self.makeStored(from: message)
        try await Self.runOnMainActor {
            try WSChatRepository.shared.append(stored, sessionId: sessionId)
        }
    }

    public func loadMessages(sessionId: String) async throws -> [ChatMessage] {
        let stored: [StoredChatMessage] = try await Self.runOnMainActor {
            try WSChatRepository.shared.loadMessages(sessionId: sessionId)
        }
        return stored.compactMap(Self.makeDomain(from:))
    }

    public func summarizeIfNeeded(
        sessionId: String,
        lastN: Int,
        threshold: Int,
        verifier: WenshuVerifier
    ) async throws {
        // WSChatRepository.summarizeIfNeeded is @MainActor + async.
        // Calling a @MainActor-isolated async method from a
        // nonisolated context triggers an automatic actor hop
        // (= the await suspends, re-schedules on MainActor, runs
        // the body, then resumes the caller). No manual wrap
        // needed (= MainActor.run only accepts sync closures).
        try await WSChatRepository.shared.summarizeIfNeeded(
            sessionId: sessionId,
            lastN: lastN,
            threshold: threshold,
            verifier: verifier
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
    public func copyChatUpload(sourceURL: URL, intoLibraryAt path: String) async throws -> String? {
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
    public static let shared = LiveChatRepository()
}
