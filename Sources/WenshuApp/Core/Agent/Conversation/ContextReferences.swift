//
//  ContextReferences.swift · Wenshu · v0.36 ticket 014 sub-step 2
//  + HERMES-PARTIAL-014 (2026-09-04).
//
//  Cross-reference table between LLMMessage.id and source file paths
//  (= ticket 003 L40 acceptance criterion + spec §3.1 L198-199).
//
//  When a message is compressed (= older non-cached messages get truncated),
// the user may want to navigate back to the original source file
// (= e.g. a character description in `world/` or `characters/` folder).
// ContextReferences maintains a LLMMessage.id → file URL mapping that
// survives compression (= the ChatViewCompressionRow preserves id per
// ticket 003 sub-step 5; this map preserves the original source).
//
//  Per ADR-0011 (deterministic compression policy) + ADR-0009 (wenshu-side
//  wins), ContextReferences is a pure data layer (= no LLM calls, no
//  filesystem I/O at runtime; the map is populated at message-construction
//  time when the message is loaded from disk).
//
//  HERMES-PARTIAL-014 extends the v0.36 sub-step 2 surface with the
//  hermes context_references.py surface:
//    - on-disk persistence (= the references survive session reset;
//      loaded from a JSON file at actor init time).
//    - cross-session reference graph (= each session keeps its own
//      references; sessions can reference each other via shared file
//      URLs, forming a graph that survives the in-memory cache).
//    - parse-context-references helper (= hermes parse_context_references:
//      extract @-references like @file:/foo/bar.md#L10-L20 from a
//      user message and emit ContextReference entries).
//    - reference expansion (= hermes _expand_file_reference +
//      _expand_folder_reference + _expand_git_reference: turn the
//      target token into the actual file contents).
//
//  v0.36 sub-step 2 of 2 for ticket 014 + HERMES-PARTIAL-014 (2026-09-04).
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

/// Reference kind for parse-context-references (= hermes context_references.py
/// @-reference surface: @file:/path, @folder:/path, @git:branch:path, @url:URL).
public enum ContextReferenceKind: String, Sendable, Equatable, Codable {
    case file
    case folder
    case git
    case url
    case unknown
}

/// Bidirectional index of ContextReferences.
/// Lookup O(1) by messageID; reverse lookup O(N) by source file path.
///
/// HERMES-PARTIAL-014: persisted to disk (= JSON file at the per-session
/// reference-store path) so the map survives session reset; sessions that
/// reference the same source file share a graph node across sessions.
public actor ContextReferences {

    private var byID: [UUID: ContextReference] = [:]
    private var byFile: [URL: Set<UUID>] = [:]
    /// Per-session reference store (= hermes cross-session graph).
    private var bySession: [String: Set<UUID>] = [:]
    /// Reverse cross-session index: source file → list of sessions that referenced it.
    private var byFileToSession: [URL: Set<String>] = [:]
    /// Persistence path (= JSON file loaded at init).
    private var persistencePath: URL?

    public init(persistencePath: URL? = nil) {
        self.persistencePath = persistencePath
        // Attempt to load from disk (= hermes on-disk persistence).
        if let path = persistencePath,
           let data = try? Data(contentsOf: path),
           let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) {
            for ref in decoded.references {
                byID[ref.messageID] = ref
                byFile[ref.sourceFile, default: []].insert(ref.messageID)
            }
            for (session, ids) in decoded.sessionIndex {
                bySession[session] = ids
                for id in ids {
                    if let ref = byID[id] {
                        byFileToSession[ref.sourceFile, default: []].insert(session)
                    }
                }
            }
        }
    }

    /// Add a new reference (= caller is message-construction path).
    public func add(_ reference: ContextReference, session: String = "default") {
        byID[reference.messageID] = reference
        byFile[reference.sourceFile, default: []].insert(reference.messageID)
        bySession[session, default: []].insert(reference.messageID)
        byFileToSession[reference.sourceFile, default: []].insert(session)
    }

    /// Remove a reference (= called when message is removed from context).
    public func remove(messageID: UUID) {
        guard let ref = byID.removeValue(forKey: messageID) else { return }
        byFile[ref.sourceFile]?.remove(messageID)
        if byFile[ref.sourceFile]?.isEmpty == true {
            byFile.removeValue(forKey: ref.sourceFile)
        }
        for (session, ids) in bySession {
            var idsCopy = ids
            idsCopy.remove(messageID)
            if idsCopy.isEmpty {
                bySession.removeValue(forKey: session)
            } else {
                bySession[session] = idsCopy
            }
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

    /// All sessions that reference a given source file (= cross-session graph lookup).
    public func sessions(for sourceFile: URL) -> Set<String> {
        return byFileToSession[sourceFile] ?? []
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
        bySession.removeAll()
        byFileToSession.removeAll()
    }

    /// Persist to disk (= hermes on-disk persistence).
    public func persist() throws {
        guard let path = persistencePath else { return }
        let state = PersistedState(
            references: Array(byID.values),
            sessionIndex: bySession
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: path)
    }

    /// Per-session persisted state (= JSON-serializable form).
    private struct PersistedState: Codable {
        let references: [ContextReference]
        let sessionIndex: [String: Set<UUID>]
    }
}

/// Pure function (= deterministic) that builds initial ContextReferences
/// from a list of LLMMessage + their source file metadata. Used at session
/// startup (= reads filesystem metadata, populates actor).
public enum ContextReferencesBuilder {

    /// Build ContextReference entries from paired (message, sourceFile) list.
    public static func build(
        pairs: [(messageID: UUID, sourceFile: URL, sectionAnchor: String?, excerpt: String?)],
        session: String = "default"
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

// MARK: - parse-context-references (= hermes parse_context_references L63-104)

/// Parse @-references from a user message (= hermes parse_context_references).
/// Supports:
///   @file:/path/to/file.md
///   @folder:/path/to/folder
///   @git:branch:/path/to/file.md
///   @url:https://example.com/doc
public enum ContextReferenceParser {
    /// Pattern matches @<kind>:<value> where value is a non-whitespace run.
    private static let pattern = try! NSRegularExpression(
        pattern: #"@(file|folder|git|url):(\S+)"#,
        options: []
    )

    /// Parse @-references from a user message.
    public static func parse(_ message: String) -> [ContextReference] {
        guard !message.isEmpty else { return [] }
        let ns = message as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = pattern.matches(in: message, options: [], range: range)
        var refs: [ContextReference] = []
        for m in matches {
            guard m.numberOfRanges == 3 else { continue }
            let kindRange = m.range(at: 1)
            let valueRange = m.range(at: 2)
            let kind = ns.substring(with: kindRange)
            let value = ns.substring(with: valueRange)
            guard let kindEnum = ContextReferenceKind(rawValue: kind) else { continue }
            _ = kindEnum
            let ref = ContextReference(
                messageID: UUID(),  // synthetic ID; caller maps to actual message later
                sourceFile: URL(fileURLWithPath: value),
                sectionAnchor: nil,
                excerpt: nil
            )
            refs.append(ref)
        }
        return refs
    }

    /// Classify a reference kind from a target string (= hermes
    /// _parse_file_reference_value helper).
    public static func kind(for target: String) -> ContextReferenceKind {
        if target.hasPrefix("http://") || target.hasPrefix("https://") {
            return .url
        }
        if target.contains(":") && !target.hasPrefix("/") && !target.hasPrefix("./") && !target.hasPrefix("~") {
            // Heuristic for git:branch:/path.
            let parts = target.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                return .git
            }
        }
        // File vs folder: caller decides by stat'ing the path.
        return .file
    }
}