import Foundation

/// The wire contract between the device and the Mac companion.
///
/// Every command the device sends is one envelope, and every reply is one
/// envelope, so the two sides agree on a single frame instead of a shape
/// per feature. The version travels in the frame: a peer that speaks a
/// different version is refused at the handshake, not mid-session.
public struct LinkEnvelope: Sendable, Codable, Equatable {
    /// The envelope format version this build speaks.
    public static let currentVersion = 1

    public var version: Int
    public var kind: Kind
    public var identifier: UUID
    public var sentAt: Date
    public var payload: Data

    public enum Kind: String, Sendable, Codable {
        case handshake
        case handshakeAccepted
        case handshakeRefused
        case command
        case event
        case ack
        case error
    }

    public init(
        version: Int = LinkEnvelope.currentVersion,
        kind: Kind,
        identifier: UUID = UUID(),
        sentAt: Date = Date(),
        payload: Data = Data()
    ) {
        self.version = version
        self.kind = kind
        self.identifier = identifier
        // The frame carries whole seconds, so the value is truncated
        // here: a frame that goes out and comes back is the same frame.
        self.sentAt = sentAt.truncatedToSecond
        self.payload = payload
    }

    /// Whether this build can read a frame with the given version.
    public static func accepts(version other: Int) -> Bool {
        other == currentVersion
    }

    public func encoded() throws -> Data {
        // The wire format carries whole seconds, so the timestamp is
        // truncated before it is written. Without this the frame that
        // comes back is not the frame that went out.
        var frame = self
        frame.sentAt = sentAt.truncatedToSecond
        return try JSONEncoder.link.encode(frame)
    }

    public static func decode(_ data: Data) throws -> LinkEnvelope {
        try JSONDecoder.link.decode(LinkEnvelope.self, from: data)
    }
}

extension Date {
    /// The timestamp precision the wire format carries.
    var truncatedToSecond: Date {
        Date(timeIntervalSince1970: timeIntervalSince1970.rounded(.down))
    }
}

extension JSONEncoder {
    /// One encoder for the link: ISO-8601 dates, sorted keys, so two
    /// peers that encode the same frame produce the same bytes.
    static let link: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    /// The matching decoder for `JSONEncoder.link`.
    static let link: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
