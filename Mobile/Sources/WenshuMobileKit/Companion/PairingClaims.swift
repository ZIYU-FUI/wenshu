import Foundation

/// What the device claims when it asks the Mac for a pairing.
///
/// The claim is what the Mac checks before it grants a session: the
/// device name it shows the user, the public key it will use for the
/// session, and the protocol versions it can speak.
public struct PairingClaims: Sendable, Codable, Equatable {
    public var deviceName: String
    public var publicKey: Data
    public var supportedVersions: [Int]

    public init(deviceName: String, publicKey: Data, supportedVersions: [Int]) {
        self.deviceName = deviceName
        self.publicKey = publicKey
        self.supportedVersions = supportedVersions
    }

    /// The claims a device sends when it only knows the pairing code.
    public static func initial(deviceName: String, publicKey: Data) -> PairingClaims {
        PairingClaims(
            deviceName: deviceName,
            publicKey: publicKey,
            supportedVersions: [LinkEnvelope.currentVersion]
        )
    }

    /// Whether the Mac can be spoken to at all: one shared version.
    public func hasCommonVersion(with other: [Int]) -> Bool {
        supportedVersions.contains { other.contains($0) }
    }
}
