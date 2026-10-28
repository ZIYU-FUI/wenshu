import Foundation

/// A command the device sends to the Mac.
///
/// The device never writes the library itself: it asks the Mac to, and
/// the Mac applies the change against its own revision. Every command
/// carries the revision it was based on, so a Mac that has moved on can
/// refuse instead of overwriting.
public struct LinkCommand: Sendable, Codable, Equatable {
    public enum Kind: String, Sendable, Codable {
        case listChapters
        case readChapter
        case writeChapter
        case listReferences
        case readReference
    }

    public var kind: Kind
    public var identifier: String
    public var baseRevision: Int
    public var body: String

    public init(kind: Kind, identifier: String, baseRevision: Int, body: String = "") {
        self.kind = kind
        self.identifier = identifier
        self.baseRevision = baseRevision
        self.body = body
    }

    /// The frame this command travels in.
    public func envelope() -> LinkEnvelope {
        let payload = (try? JSONEncoder.link.encode(self)) ?? Data()
        return LinkEnvelope(kind: .command, payload: payload)
    }
}
