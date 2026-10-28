import Foundation

/// What the device knows about its link to the Mac.
///
/// The states are ordered by how much they can do: a device that has
/// not paired yet reads nothing, and a device whose Mac is offline says
/// so instead of showing a library that is no longer current.
public enum ConnectionState: Sendable, Equatable {
    case idle
    case pairing(PairingCode)
    case connected(CompanionInfo)
    case offline(reason: String)
    case refused(reason: String)

    /// Whether the device may show library content.
    public var canReadLibrary: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    public var isBusy: Bool {
        if case .pairing = self {
            return true
        }
        return false
    }

    /// The companion, when the link is live.
    public var companion: CompanionInfo? {
        if case let .connected(info) = self {
            return info
        }
        return nil
    }
}

/// The code the user types on the device to claim a session.
public struct PairingCode: Sendable, Equatable, CustomStringConvertible {
    public let value: String

    public init(value: String) {
        self.value = value
    }

    /// A pairing code is a fixed-width group of digits.
    public var isWellFormed: Bool {
        value.count == 6 && value.allSatisfy(\.isNumber)
    }

    public var description: String {
        value
    }
}

/// What the Mac tells the device about itself when it accepts a pairing.
public struct CompanionInfo: Sendable, Equatable {
    public let name: String
    public let revision: Int

    public init(name: String, revision: Int) {
        self.name = name
        self.revision = revision
    }
}
