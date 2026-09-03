//
//  MemoryAdapter.swift · Wenshu · v0.35 ticket 009
//
//  Thin adapter over existing wenshu Core/Memory/* subsystem
//  (= AGENTS.md §11.3 wenshu-side wins).
//
//  Per spec §3.6: ticket 009 reuses wenshu's existing MemoryManager +
//  MemoryProvider + MemoryConsolidator. This adapter exposes a unified
//  interface for the new agent layer (= ConversationLoop + DynamicZone
//  right-bottom panel + Settings → Memory view).
//
//  v0.35 ticket 009 (= 🟨 + 🟥 UI ticket per spec §6.4).
//

import Foundation

public actor MemoryAdapter {
    public struct MemoryEntry: Sendable, Equatable, Identifiable {
        public let id: String
        public let source: String  // = file path inside .ws library
        public let snippet: String
        public let relevanceScore: Double  // 0...1, 1 = highest relevance

        public var idString: String { id }
    }

    /// Pull memories relevant to the user message (= thin delegate to
    /// wenshu Core/Memory/MemoryManager.prefetch).
    public func retrieve(forUserMessage userMessage: String, bookId: String? = nil) async -> [MemoryEntry] {
        // Stub for sub-step 1; wenshu MemoryManager wiring lands in v0.35.1
        _ = bookId
        _ = userMessage
        return []
    }

    /// Write a new memory (= thin delegate to MemoryManager.sync).
    public func write(snippet: String, source: String, bookId: String? = nil) async {
        _ = bookId
        _ = snippet
        _ = source
    }
}