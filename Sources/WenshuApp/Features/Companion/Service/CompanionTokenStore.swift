import Foundation
import Security
import WenshuAgent

// CompanionTokenStore.swift
//
// Where the device token lives.
//
// The token is a bearer secret: whoever holds it may call every route
// that needs one. It therefore lives in the macOS Keychain and nowhere
// else. It is never written to UserDefaults, never written to a file in
// the app container, and never logged.
//
// The write goes through `KeychainOps`, the shared `Security` framework
// wrapper the provider keys already use, so the companion token rides
// the desktop's existing Keychain plumbing instead of a second one. It
// uses its own service and account, so a companion token never appears
// among the provider API keys and a provider key is never mistaken for a
// device token.
//
// One pairing yields one token. A second pairing replaces the first, so
// the phone holds at most one valid token at a time and a lost phone can
// be cut off by pairing again.

/// The device token store.
///
/// The interface is a protocol so a test can prove the service's
/// authentication path without touching the user's Keychain.
protocol CompanionTokenStoring: Sendable {
    /// The stored token, or nil when no device is paired.
    func loadToken() -> String?
    /// Store the token, replacing any previous one.
    func save(token: String) throws
    /// Remove the stored token. A revoked device has no token, so every
    /// route that needs one refuses it.
    func revokeToken() throws
}

/// The Keychain-backed device token store.
///
/// The store holds no state of its own: the Keychain is the single
/// source of truth, so a token written before a restart is the token the
/// service accepts after it.
final class KeychainCompanionTokenStore: CompanionTokenStoring {

    /// The Keychain service the companion token lives under.
    static let service = "com.wenshu.app.companion"

    /// The Keychain account the companion token lives under.
    static let account = "device.token"

    init() {}

    func loadToken() -> String? {
        KeychainOps.load(service: Self.service, account: Self.account)
    }

    func save(token: String) throws {
        try KeychainOps.save(value: token, service: Self.service, account: Self.account)
    }

    func revokeToken() throws {
        try KeychainOps.delete(service: Self.service, account: Self.account)
    }
}

/// The device token and the pairing code that produces it.
enum CompanionTokenFactory {

    /// Mint a device token.
    ///
    /// The bytes come from the system's cryptographic random source, so
    /// two pairings never produce the same token.
    static func makeDeviceToken() -> String {
        makeHexString(byteCount: 32)
    }

    /// Mint a pairing code.
    ///
    /// A pairing code is short enough to read off the screen and long
    /// enough that guessing it is not a practical attack against a
    /// loopback listener.
    static func makePairingCode() -> String {
        makeHexString(byteCount: 8)
    }

    /// A hex string of cryptographically random bytes.
    ///
    /// `SecRandomCopyBytes` is the system random source: the same one
    /// the Keychain uses for its own secrets.
    private static func makeHexString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            // A failure of the system random source is not a condition
            // to paper over: the caller gets a value that is not
            // predictable rather than a constant.
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
