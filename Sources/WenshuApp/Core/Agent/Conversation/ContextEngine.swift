//
//  ContextEngine.swift · Wenshu · v0.35 ticket 003 sub-step 3
//
//  Context aggregation facade. Maps to hermes context_engine.py
//  (= 924 LOC ABC interface). Wenshu-side wins per AGENTS.md §11.3:
//  the existing wenshu Core/Memory/* subsystem already implements
//  world/character/foreshadow prefetch + retrieval (= MemoryManager +
//  MemoryProvider + MemoryConsolidator). This ContextEngine is a thin
//  facade that exposes a unified API over those existing primitives.
//
//  Responsibilities:
//    - aggregateContextForTurn(bookId:userMessage:) -> ContextBundle
//      (= combines memory prefetch + character/world retrieval)
//    - formatContextBundle(_:) -> String
//      (= renders the context as a system-prompt dynamic tier)
//

import Foundation

public actor ContextEngine {

    public struct ContextBundle: Sendable {
        public let memories: [MemoryEntry]
        public let characterContext: [String]
        public let worldContext: [String]
        public let foreshadowContext: [String]

        public var isEmpty: Bool {
            memories.isEmpty && characterContext.isEmpty
                && worldContext.isEmpty && foreshadowContext.isEmpty
        }
    }

    /// Lightweight memory entry (= consumed from wenshu Core/Memory in
    /// subsequent tickets; stub shape for sub-step 3).
    public struct MemoryEntry: Sendable {
        public let source: String  // file path
        public let snippet: String
        public init(source: String, snippet: String) {
            self.source = source
            self.snippet = snippet
        }
    }

    public init() {}

    /// Aggregate context for one conversation turn (= hermes
    /// context_engine.aggregate_context entry).
    ///
    /// In sub-step 3 this returns an empty ContextBundle (= wenshu Core/Memory
    /// integration lands in ticket 009 per spec §3.6 wenshu-side wins).
    public func aggregateContextForTurn(
        bookId: String?,
        userMessage: String
    ) async -> ContextBundle {
        // TODO(ticket-009): wire MemoryManager.prefetch + character/world
        // retrieval from wenshu Core/Memory/* subsystem
        _ = bookId
        _ = userMessage
        return ContextBundle(
            memories: [],
            characterContext: [],
            worldContext: [],
            foreshadowContext: []
        )
    }

    /// Format a context bundle as a system-prompt dynamic tier (= renders
    /// for LLM consumption).
    public func formatContextBundle(_ bundle: ContextBundle) -> String {
        var sections: [String] = []
        if !bundle.memories.isEmpty {
            let memoryLines = bundle.memories.map { "- [\($0.source)] \($0.snippet)" }.joined(separator: "\n")
            sections.append("Relevant memories:\n\\(memoryLines)")
        }
        if !bundle.characterContext.isEmpty {
            sections.append("Characters:\n" + bundle.characterContext.joined(separator: "\n"))
        }
        if !bundle.worldContext.isEmpty {
            sections.append("World:\n" + bundle.worldContext.joined(separator: "\n"))
        }
        if !bundle.foreshadowContext.isEmpty {
            sections.append("Foreshadowing:\n" + bundle.foreshadowContext.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n---\n\n")
    }
}