//
//  UserDefaultsStoreTests.swift · Wenshu
//
//  Test coverage for the G-2 canonical typed wrapper.
//

import Testing
import Foundation
@testable import WenshuApp

@MainActor
@Suite("UserDefaultsStore (= typed UserDefaults wrapper for G-2)")
struct UserDefaultsStoreTests {

    // Reset UserDefaults.standard between tests (= wenshu uses the
    // standard suite; tests must not leak state).
    private let store = UserDefaultsStore.shared

    private func resetDefaults() {
        // Only reset the keys this suite actually uses (= other suites
        // run in parallel and may rely on wenshu.* state being intact).
        UserDefaultsStore.shared.remove(.llmModel)
        UserDefaultsStore.shared.remove(.settingsTab)
        UserDefaultsStore.shared.remove(.userAddress)
        UserDefaultsStore.shared.remove(.debugNoKeychain)
        UserDefaultsStore.shared.remove(.creditsMonthly)
        UserDefaultsStore.shared.remove(.openTabs)
        UserDefaultsStore.shared.remove(.activeTabId)
        UserDefaultsStore.shared.remove(.llmActiveConnector)
    }

    init() {
        // No global reset at suite init (= parallel suites may rely on
        // shared wenshu.* state being intact). Each @Test calls
        // resetDefaults() at entry.
    }

    // MARK: - String

    @Test("String read returns empty string fallback when key absent")
    func stringFallback() {
        resetDefaults()
        #expect(store.string(forKey: .llmModel) == "")
    }

    @Test("String round-trips through set + get")
    func stringRoundTrip() {
        resetDefaults()
        store.setString("providerApi", forKey: .settingsTab)
        #expect(store.string(forKey: .settingsTab) == "providerApi")
    }

    @Test("String with explicit fallback returns fallback when key absent")
    func stringWithFallback() {
        resetDefaults()
        #expect(store.string(forKey: .userAddress, fallback: "用户") == "用户")
    }

    @Test("String with explicit fallback returns stored value when present")
    func stringWithFallbackStored() {
        resetDefaults()
        store.setString("老板", forKey: .userAddress)
        #expect(store.string(forKey: .userAddress, fallback: "用户") == "老板")
    }

    // MARK: - Bool

    @Test("Bool defaults to false when key absent")
    func boolDefault() {
        resetDefaults()
        #expect(store.bool(forKey: .debugNoKeychain) == false)
    }

    @Test("Bool round-trips through set + get")
    func boolRoundTrip() {
        resetDefaults()
        store.setBool(true, forKey: .debugNoKeychain)
        #expect(store.bool(forKey: .debugNoKeychain) == true)
    }

    // MARK: - Int

    @Test("Int defaults to 0 when key absent")
    func intDefault() {
        resetDefaults()
        #expect(store.int(forKey: .creditsMonthly) == 0)
    }

    @Test("Int round-trips through set + get")
    func intRoundTrip() {
        resetDefaults()
        store.setInt(4242, forKey: .creditsMonthly)
        #expect(store.int(forKey: .creditsMonthly) == 4242)
    }

    // MARK: - Double

    @Test("Double defaults to 0.0 when key absent")
    func doubleDefault() {
        resetDefaults()
        #expect(store.double(forKey: .creditsMonthly) == 0.0)
    }

    @Test("Double round-trips through set + get")
    func doubleRoundTrip() {
        resetDefaults()
        store.setDouble(3.14, forKey: .creditsMonthly)
        #expect(store.double(forKey: .creditsMonthly) == 3.14)
    }

    // MARK: - Data

    @Test("Data returns nil when key absent")
    func dataNilWhenAbsent() {
        resetDefaults()
        #expect(store.data(forKey: .openTabs) == nil)
    }

    @Test("Data round-trips through set + get")
    func dataRoundTrip() {
        resetDefaults()
        let blob = Data([1, 2, 3, 4, 5])
        store.setData(blob, forKey: .openTabs)
        #expect(store.data(forKey: .openTabs) == blob)
    }

    // MARK: - UUID

    @Test("UUID returns nil when key absent")
    func uuidNilWhenAbsent() {
        resetDefaults()
        #expect(store.uuid(forKey: .activeTabId) == nil)
    }

    @Test("UUID round-trips through set + get")
    func uuidRoundTrip() {
        resetDefaults()
        let id = UUID()
        store.setUUID(id, forKey: .activeTabId)
        #expect(store.uuid(forKey: .activeTabId) == id)
    }

    @Test("UUID set to nil removes the key")
    func uuidSetNilRemoves() {
        resetDefaults()
        let id = UUID()
        store.setUUID(id, forKey: .activeTabId)
        #expect(store.uuid(forKey: .activeTabId) == id)
        store.setUUID(nil, forKey: .activeTabId)
        #expect(store.uuid(forKey: .activeTabId) == nil)
    }

    // MARK: - Remove

    @Test("remove clears a previously-stored value")
    func removeClearsValue() {
        resetDefaults()
        store.setString("anthropic", forKey: .llmActiveConnector)
        #expect(store.string(forKey: .llmActiveConnector) == "anthropic")
        store.remove(.llmActiveConnector)
        #expect(store.string(forKey: .llmActiveConnector) == "")
    }

    // MARK: - Key namespace coverage (= G-2 cluster key registry)

    @Test("WenshuDefaultsKey.allCases covers 13 typed settings keys")
    func keyEnumCompleteness() {
        // Wenshu's G-2 cluster (= the keys written/read by @Observable
        // models) maps 1:1 to WenshuDefaultsKey cases. Adding a new
        // case here is the canonical way to onboard a new persisted
        // setting (= typo-proof).
        #expect(WenshuDefaultsKey.allCases.count == 13)
    }

    @Test("All WenshuDefaultsKey raw values use the wenshu. namespace prefix")
    func keyPrefixConvention() {
        for key in WenshuDefaultsKey.allCases {
            #expect(key.rawValue.hasPrefix("wenshu."))
        }
    }

    // MARK: - UserDefaults.standard backing (= interop with @AppStorage views)

    @Test("set + get via UserDefaultsStore matches raw UserDefaults read (= interop with @AppStorage)")
    func interopWithRawUserDefaults() {
        resetDefaults()
        store.setString("anthropic", forKey: .llmActiveConnector)
        // A SwiftUI view using @AppStorage("wenshu.llm.activeConnector")
        // would read this exact key path.
        #expect(UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector") == "anthropic")
    }

    // MARK: - Dynamic-key Int (= runtime-computed key names)

    private let dynamicTabKey = "wenshu.tabIndex.testZone"

    @Test("int(forDynamicKey:) returns 0 fallback when key absent")
    func dynamicKeyIntFallback() {
        resetDefaults()
        UserDefaultsStore.shared.remove(forDynamicKey: dynamicTabKey)
        #expect(UserDefaultsStore.shared.int(forDynamicKey: dynamicTabKey) == 0)
    }

    @Test("int(forDynamicKey:) round-trips through set + get")
    func dynamicKeyIntRoundTrip() {
        resetDefaults()
        UserDefaultsStore.shared.setInt(7, forDynamicKey: dynamicTabKey)
        #expect(UserDefaultsStore.shared.int(forDynamicKey: dynamicTabKey) == 7)
    }

    @Test("setInt(_:forDynamicKey:) writes through to raw UserDefaults (= interop)")
    func dynamicKeyIntInteropWithRawUserDefaults() {
        resetDefaults()
        UserDefaultsStore.shared.setInt(42, forDynamicKey: dynamicTabKey)
        // A raw UserDefaults.standard read of the same key path returns
        // the same value (= proves the dynamic-key path shares backing
        // with the static-key path).
        #expect(UserDefaults.standard.integer(forKey: dynamicTabKey) == 42)
    }

    @Test("two dynamic-key writes to different keys do not collide")
    func dynamicKeyIsolation() {
        resetDefaults()
        let keyA = "wenshu.tabIndex.zoneA"
        let keyB = "wenshu.tabIndex.zoneB"
        UserDefaultsStore.shared.setInt(3, forDynamicKey: keyA)
        UserDefaultsStore.shared.setInt(5, forDynamicKey: keyB)
        #expect(UserDefaultsStore.shared.int(forDynamicKey: keyA) == 3)
        #expect(UserDefaultsStore.shared.int(forDynamicKey: keyB) == 5)
    }

    @Test("dynamic-key write does not appear under a static WenshuDefaultsKey")
    func dynamicKeyDoesNotPolluteStaticKeys() {
        resetDefaults()
        // Dynamic-key write to a name that does NOT match any
        // WenshuDefaultsCase rawValue (= the key namespace is shared
        // but each entry is unique). Confirm the static keys remain
        // untouched after the dynamic write.
        let dynamicKey = "wenshu.tabIndex.someZone"
        UserDefaultsStore.shared.setInt(11, forDynamicKey: dynamicKey)
        // Static keys should still be absent (= resetDefaults cleared).
        #expect(UserDefaultsStore.shared.string(forKey: .llmModel) == "")
        #expect(UserDefaultsStore.shared.int(forKey: .debugNoKeychain) == 0)
    }
}