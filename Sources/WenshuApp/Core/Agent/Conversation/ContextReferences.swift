//
//  ContextReferences.swift · Wenshu · v0.36 ticket 014 sub-step 2
//
//  Cross-reference table between LLMMessage.id and source file paths
//  (= ticket 003 L40 acceptance criterion + spec §3.1 L198-199).
//
//  When a message is compressed (= older non-cached messages get truncated),
//  the user may want to navigate back to the original source file
//  (= e.g. a character description in `world/` or `characters/` folder).
//  ContextReferences maintains a LLMMessage.id → file URL mapping that
//  survives compression (= the ChatViewCompressionRow preserves id per
//  ticket 003 sub-step 5; this map preserves the original source).
//
//  Per ADR-0011 (deterministic compression policy) + ADR-0009 (wenshu-side
//  wins), ContextReferences is a pure data layer (= no LLM calls, no
//  filesystem I/O at runtime; the map is populated at message-construction
//  time when the message is loaded from disk).
//
//  v0.36 sub-step 2 of 2 for ticket 014.
//

import Foundation

/// A single source reference for a message in the conversation context.
/// Records the origin file path (= .md inside `.ws` library per wenshu §11)
/// and optional section anchor (= `#heading` for direct navigation).
public struct ContextReference: Sendable, Equatable, Codable {
    public let messageID: UUID          // = ChatMessage.id (UUID)
    public let sourceFile: URL          // absolute path to source .md file
    public let sectionAnchor: String?   // optional #anchor for in-file nav
    public let excerpt: String?         // optional text excerpt from source

    public init(
        messageID: UUID,
        sourceFile: URL,
        sectionAnchor: String? = nil,
        excerpt: String? = nil
    ) {
        self.messageID = messageID
        self.sourceFile = sourceFile
        self.sectionAnchor = sectionAnchor
        self.excerpt = excerpt
    }
}

/// Bidirectional index of ContextReferences.
/// Lookup O(1) by messageID; reverse lookup O(N) by source file path.
/// Stored in-memory only ( = rebuilt from filesystem metadata when session
/// starts; no on-disk persistence in v0.36).
public actor ContextReferences {

    private var byID: [UUID: ContextReference] = [:]
    private var byFile: [URL: Set<UUID>] = [:]

    public init() {}

    /// Add a new reference (= caller is message-construction path).
    public func add(_ reference: ContextReference) {
        byID[reference.messageID] = reference
        byFile[reference.sourceFile, default: []].insert(reference.messageID)
    }

    /// Remove a reference (= called when message is removed from context).
    public func remove(messageID: UUID) {
        guard let ref = byID.removeValue(forKey: messageID) else { return }
        byFile[ref.sourceFile]?.remove(messageID)
        if byFile[ref.sourceFile]?.isEmpty == true {
            byFile.removeValue(forKey: ref.sourceFile)
        }
    }

    /// Lookup reference by messageID (= O(1)).
    public func reference(for messageID: UUID) -> ContextReference? {
        return byID[messageID]
    }

    /// Reverse lookup: all message IDs referencing a given source file
    /// (= O(1) for the set, O(N) to enumerate).
    public func messageIDs(for sourceFile: URL) -> Set<UUID> {
        return byFile[sourceFile] ?? []
    }

    /// Total reference count (= for diagnostics + UI).
    public var count: Int {
        return byID.count
    }

    /// All references (= sorted by messageID for stable UI display).
    public var allReferences: [ContextReference] {
        return byID.values.sorted { $0.messageID.uuidString < $1.messageID.uuidString }
    }

    /// Clear all references (= called on session reset).
    public func clear() {
        byID.removeAll()
        byFile.removeAll()
    }
}

/// Pure function (= deterministic) that builds initial ContextReferences
/// from a list of LLMMessage + their source file metadata. Used at session
/// startup (= reads filesystem metadata, populates actor).
public enum ContextReferencesBuilder {

    /// Build ContextReference entries from paired (message, sourceFile) list.
    public static func build(
        pairs: [(messageID: UUID, sourceFile: URL, sectionAnchor: String?, excerpt: String?)]
    ) -> [ContextReference] {
        return pairs.map { pair in
            ContextReference(
                messageID: pair.messageID,
                sourceFile: pair.sourceFile,
                sectionAnchor: pair.sectionAnchor,
                excerpt: pair.excerpt
            )
        }
    }
}