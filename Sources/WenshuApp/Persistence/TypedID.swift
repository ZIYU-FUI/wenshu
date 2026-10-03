//
//  TypedID.swift · Wenshu · P2-02 (audit 2026-09-24)
//
//  Brand-wrapper convention for type-safe IDs. wenshu stores 21 ID
//  fields as raw `String` (= 17 @Model primary keys + 4 cross-boundary
//  foreign keys = bookID / sessionID / chapterID / memoryID); = the
//  compiler cannot distinguish "this is a book ID" from "this is a
//  chapter ID" from "this is a path string". Typos or accidental
//  string swaps compile cleanly and crash at runtime.
//
//  The fix is to wrap each ID type in a brand wrapper (= newtype
//  pattern: zero runtime cost + compile-time guarantee).
//
//  This file ships the convention (= protocol TypedID) + the pilot
//  implementation (= BookID, the highest-volume ID with 29 callers).
//  Future wrappers (ChapterID / SessionID / MemoryID) follow the same
//  template.
//
//  Why a protocol (= not just BookID):
//  - Tests + helper APIs can be generic over TypedID (= e.g. an
//    ID-prefix logger works for any typed ID without code duplication).
//  - Future ID wrappers conform to the same shape; = consistent
//    RawRepresentable + Codable + Hashable + Sendable.
//  - RawRepresentable where RawValue == String is the key: it makes
//    the wrapper Codable-equivalent to a String (= can be passed through
//    SwiftData `@Attribute(.unique)` predicates via .rawValue casts).
//
//  Why Optional<BookID> (= for the global un-attached bucket):
//  - bookID == nil means "the session belongs to the global
//    un-attached bucket" (= used during onboarding + future
//    create-book-via-conversation flows). The Optional<RawValue> on
//    SwiftData @Model side stays as `String?` (= SwiftData's
//    @Attribute doesn't accept brand wrappers as @Model field types
//    yet); = the brand-wrapper is the in-memory API surface (= the
//    SwiftData row stores the raw String?, the app code passes
//    BookID? through the repository layer).
//

import Foundation

/// Convention for type-safe IDs in wenshu. Each entity that needs
/// a typed primary key conforms to this protocol and provides a
/// `rawValue` (= typically a UUID string or a synthesized natural
/// key).
///
/// Use case: prevents compile-time ID confusion (= "this is a book
/// ID" vs "this is a chapter ID" vs "this is a path string").
///
/// See also:
/// - `BookID` (= the pilot implementation; = the most-used cross-
///   boundary ID = 29 callers).
/// - (Future) `ChapterID` / `SessionID` / `MemoryID` / etc. — each
///   follows the same template (`struct X: TypedID { let rawValue: String }`).
protocol TypedID: Hashable, Codable, Sendable, RawRepresentable
    where RawValue == String {
    init(rawValue: String)
}

extension TypedID {
    /// Synthesize a new ID. The default implementation is
    /// `UUID().uuidString`; = concrete types may override for
    /// natural keys (= e.g. `WSBookShelf.id` could derive from
    /// the shelf name's hash), but for now every typed ID uses
    /// UUID for uniformity.
    static func newID() -> Self {
        Self(rawValue: UUID().uuidString)
    }

    /// Convenience accessor (= same as `.rawValue`). Kept for
    /// symmetry with SwiftData's @Attribute path (= SwiftData
    /// reads `\.rawValue` for Codable storage).
    var stringValue: String { rawValue }
}

/// Brand wrapper for a book identifier.
///
/// Why `String?` (= Optional) on the @Model side, `BookID?` (= Optional)
/// on the repository API side: the Optional is the bridge between
/// "no book" (= the global un-attached bucket for onboarding + future
/// create-book-via-conversation flows) and "specific book".
///
/// The `?` is at the wrapper boundary (= `BookID?`), NOT inside the
/// wrapper (= `BookID` is always non-optional; = a non-empty string
/// rawValue). This split lets SwiftData keep the column as
/// `String?` (= the underlying @Model stores raw `String?`), while
/// the public repository API exchanges `BookID?`.
struct BookID: TypedID, Equatable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Convenience initializer for the "no book" (= nil rawValue)
    /// case. Returns `nil` so callers use `BookID(rawValue:)` only
    /// when they have a concrete identifier.
    init?(rawValue: String?) {
        guard let rawValue else { return nil }
        self.rawValue = rawValue
    }
}

/// Brand wrapper for a tool-call identifier (= the `id` field on
/// `ToolUsePart`; = the `tool_call_id` on the LLM-protocol response).
///
/// This commit only INTRODUCES the type (= zero call-site migration).
/// Future commits per P2-03 (逐步 typed-ID rollout) will swap
/// `String` for `ToolCallID` at the call sites that hold a tool-call
/// identifier (ToolUsePart.id, ToolResultPart.toolUseID,
/// ToolDispatchHelpers.makeToolResultMessage). Splitting this work
/// into one-type-per-commit keeps the Q112 1-source-1-test invariant
/// intact (= the actual type swap is a per-umbrella atomic-coupled
/// sweep that crosses multiple files; = each sweep is its own ticket).
struct ToolCallID: TypedID, Equatable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Brand wrapper for a chat-session identifier (= the `sessionID`
/// field on `WSSession` + `WSChatMessage` + `WSSummary`; = the
/// `sessionId` parameter on `ChatRepositoryProtocol`).
///
/// `SessionID` is NOT used as a `@Model` field type (= SwiftData
/// `@Attribute` doesn't accept brand wrappers yet; = the SwiftData
/// rows store raw `String` and the public repository protocol
/// exchanges `SessionID`). The brand wrapper is the in-memory API
/// surface for chat sessions.
///
/// Same one-type-per-commit pattern as `ToolCallID`: this commit
/// introduces the type only. Future commits per P2-03 will swap
/// `String` for `SessionID` at the call sites that hold a chat-session
/// identifier (= the ChatSessionViewModel `sessionId` private + the
/// `ChatRepositoryProtocol.append/loadMessages/summarize` parameters).
struct SessionID: TypedID, Equatable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - String interop

extension BookID {
    /// Lossless String conversion (= for SwiftData predicate
    /// `.keyPath(\.bookID) == bookID.stringValue`).
    var asString: String { rawValue }

    /// Construct from a `String` (= for the SwiftData @Model side,
    /// where the column is stored as `String?` and we want to wrap
    /// it into a `BookID` for in-memory API surface).
    static func fromString(_ rawValue: String) -> BookID {
        BookID(rawValue: rawValue)
    }
}

// MARK: - CustomStringConvertible

extension BookID: CustomStringConvertible {
    var description: String { "BookID(\(rawValue.prefix(8)))" }
}