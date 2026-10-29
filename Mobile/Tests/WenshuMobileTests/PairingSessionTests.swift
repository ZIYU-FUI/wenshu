import Foundation
import Testing
import WenshuMobileKit
@testable import WenshuMobileApp

@Suite("PairingSessionTests")
struct PairingSessionTests {
    private static let tokenService = "com.wenshu.mobile.tests.device-token"

    @Test @MainActor func aWellFormedCodeStartsAPairingAndIsHeld() {
        let store = ConnectionStore()
        let session = PairingSession(store: store, tokenStore: DeviceTokenStore(service: Self.tokenService))

        let code = session.start()

        #expect(code.isPlainDigits)
        #expect(session.code == code)
        #expect(store.state == .pairing(code))
        #expect(store.state.isBusy)
    }

    @Test @MainActor func aCodeThatIsNotWellFormedIsRefused() {
        let store = ConnectionStore()
        let session = PairingSession(store: store, tokenStore: DeviceTokenStore(service: Self.tokenService))

        let refused = session.start(code: PairingCode(value: "12a456"))

        #expect(!refused)
        #expect(session.code == nil)
        #expect(store.lastError != nil)
        guard case let .refused(reason) = store.state else {
            Issue.record("a code that is not well formed must be refused")
            return
        }
        #expect(!reason.isEmpty)
    }

    @Test @MainActor func aCodeOfDigitsFromAnotherScriptIsRefused() {
        let store = ConnectionStore()
        let session = PairingSession(store: store, tokenStore: DeviceTokenStore(service: Self.tokenService))
        let foreign = PairingCode(value: String(repeating: "\u{FF10}", count: 6))

        #expect(foreign.isWellFormed)
        #expect(!foreign.isPlainDigits)
        #expect(!session.start(code: foreign))
    }

    @Test @MainActor func theMacSaysWhyItRefused() {
        let store = ConnectionStore()
        let session = PairingSession(store: store, tokenStore: DeviceTokenStore(service: Self.tokenService))

        session.refuse(reason: "That code belongs to another Mac.")

        guard case let .refused(reason) = store.state else {
            Issue.record("the refusal must say what the Mac said")
            return
        }
        #expect(reason == "That code belongs to another Mac.")
        #expect(store.lastError == reason)
    }

    @Test @MainActor func theTokenTheMacReturnsSurvivesARelaunch() throws {
        let account = "pairing-session-tests-token"
        let tokenStore = DeviceTokenStore(service: Self.tokenService, account: account)
        tokenStore.delete()
        defer { tokenStore.delete() }

        let store = ConnectionStore()
        let session = PairingSession(store: store, tokenStore: tokenStore)

        session.accept(companion: CompanionInfo(name: "Studio", revision: 4), token: "token-abc-123")

        #expect(store.state == .connected(CompanionInfo(name: "Studio", revision: 4)))
        #expect(session.token == "token-abc-123")

        let relaunched = PairingSession(
            store: ConnectionStore(),
            tokenStore: DeviceTokenStore(service: Self.tokenService, account: account)
        )
        #expect(relaunched.restore())
        #expect(relaunched.token == "token-abc-123")
    }

    @Test @MainActor func noTokenReachesUserDefaultsOrAFile() throws {
        let account = "pairing-session-tests-defaults"
        let tokenStore = DeviceTokenStore(service: Self.tokenService, account: account)
        tokenStore.delete()
        defer { tokenStore.delete() }

        let token = "token-\(UUID().uuidString)"
        let session = PairingSession(store: ConnectionStore(), tokenStore: tokenStore)
        session.accept(companion: CompanionInfo(name: "Studio", revision: 1), token: token)

        let defaults = UserDefaults.standard.dictionaryRepresentation()
        let traces = defaults.filter {
            $0.key.contains(token) || String(describing: $0.value).contains(token)
        }
        #expect(traces.isEmpty)

        let root = packageRoot()
        for path in [
            "Sources/WenshuMobileApp/Features/Connection/Service/DeviceTokenStore.swift",
            "Sources/WenshuMobileApp/Features/Connection/Service/PairingSession.swift",
        ] {
            let source = try String(contentsOf: root.appendingPathComponent(path))
            for line in source.split(separator: "\n") {
                let code = line.components(separatedBy: "//").first ?? ""
                #expect(!code.contains("UserDefaults"))
                #expect(!code.contains("FileManager"))
            }
        }
    }

    /// The package root, from this file's own path.
    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
