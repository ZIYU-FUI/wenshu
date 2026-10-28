import Foundation
import Observation
import WenshuMobileKit

/// The single owner of the link state for the app.
///
/// The store holds the state and the transitions; it does not open a
/// socket. A transport that exists later replaces the transition calls
/// and nothing else.
@MainActor
@Observable
final class ConnectionStore {
    private(set) var state: ConnectionState = .idle
    private(set) var lastError: String?

    func beginPairing(code: PairingCode) {
        guard code.isWellFormed else {
            state = .refused(reason: "The pairing code is not well formed.")
            return
        }
        state = .pairing(code)
    }

    func accept(companion: CompanionInfo) {
        state = .connected(companion)
        lastError = nil
    }

    func reportOffline(reason: String) {
        state = .offline(reason: reason)
    }

    func reportRefusal(reason: String) {
        state = .refused(reason: reason)
        lastError = reason
    }

    func reset() {
        state = .idle
        lastError = nil
    }

    /// The one-line state label the UI shows.
    var statusLabel: String {
        switch state {
        case .idle:
            "Not paired"
        case .pairing:
            "Pairing"
        case .connected:
            "Connected"
        case .offline:
            "Offline"
        case .refused:
            "Refused"
        }
    }
}
