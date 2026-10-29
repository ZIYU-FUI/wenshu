import Foundation
import Observation
import WenshuMobileKit

/// The owner of the pairing flow.
///
/// The session starts a pairing, holds the code while the Mac is
/// answering, and moves the link's state when the Mac answers. It opens
/// no socket: a transport that exists later replaces the transition
/// calls and nothing else.
@MainActor
@Observable
final class PairingSession {
    private let store: ConnectionStore
    private let tokenStore: DeviceTokenStore

    /// The code the person reads aloud, held while the Mac answers.
    private(set) var code: PairingCode?

    /// The token the Mac returned, kept so the link survives a relaunch.
    private(set) var token: String?

    init(store: ConnectionStore, tokenStore: DeviceTokenStore = DeviceTokenStore()) {
        self.store = store
        self.tokenStore = tokenStore
    }

    /// Start a pairing: make a code, show it, and wait for the Mac.
    @discardableResult
    func start() -> PairingCode {
        let code = PairingCode.make()
        _ = start(code: code)
        return code
    }

    /// Start a pairing with a code the flow was given.
    ///
    /// A code that is not well formed is refused, and the refusal says
    /// so: the person read it wrong, and the screen must say that.
    @discardableResult
    func start(code: PairingCode) -> Bool {
        guard code.isPlainDigits else {
            store.reportRefusal(reason: String(localized: "That pairing code is not six plain digits."))
            return false
        }
        self.code = code
        store.beginPairing(code: code)
        return true
    }

    /// The Mac accepted: the link is live, and the token is kept.
    ///
    /// A token the Keychain refuses is a link that cannot survive a
    /// relaunch, so it is refused rather than promised.
    func accept(companion: CompanionInfo, token: String) {
        do {
            try tokenStore.save(token)
        } catch {
            store.reportRefusal(reason: String(localized: "The device token could not be kept."))
            return
        }
        self.token = token
        code = nil
        store.accept(companion: companion)
    }

    /// The Mac refused: the screen says what the Mac said.
    func refuse(reason: String) {
        code = nil
        store.reportRefusal(reason: reason)
    }

    /// The Mac is not answering.
    func reportOffline(reason: String = String(localized: "The Mac did not answer.")) {
        code = nil
        store.reportOffline(reason: reason)
    }

    /// After a relaunch: the token the Mac gave us is still in the
    /// Keychain, so the link can be made again.
    @discardableResult
    func restore() -> Bool {
        guard let token = tokenStore.load() else {
            return false
        }
        self.token = token
        return true
    }
}
