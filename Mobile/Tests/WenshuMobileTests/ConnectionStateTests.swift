import Foundation
import Testing
@testable import WenshuMobileKit

@Test func aFreshDeviceHasNoLink() {
    let state = ConnectionState.idle
    #expect(!state.canReadLibrary)
    #expect(!state.isBusy)
}

@Test func aPairedDeviceMayReadTheLibrary() {
    let state = ConnectionState.connected(CompanionInfo(name: "Studio", revision: 4))
    #expect(state.canReadLibrary)
    #expect(state.companion?.name == "Studio")
}

@Test func anOfflineDeviceMayNotReadTheLibrary() {
    let state = ConnectionState.offline(reason: "The Mac is asleep.")
    #expect(!state.canReadLibrary)
    #expect(state.companion == nil)
}

@Test func aPairingCodeIsSixDigits() {
    #expect(PairingCode(value: "123456").isWellFormed)
    #expect(!PairingCode(value: "12345").isWellFormed)
    #expect(!PairingCode(value: "12345a").isWellFormed)
}
