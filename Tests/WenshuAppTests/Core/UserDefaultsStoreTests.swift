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

    init() {
        for key in WenshuDefaultsKey.allCases {
            UserDefaultsStore.shared.remove(key)
        }
    }

    // MARK: - String

    @Test("String read returns empty string fallback when key absent")
    func stringFallback() {
        #expect(store.string(forKey: .llmModel) == "")
    }

    @Test("String round-trips through set + get")
    func stringRoundTrip() {
        store.setString("providerApi", forKey: .settingsTab)
        #expect(store.string(forKey: .settingsTab) == "providerApi")
    }

    @Test("String with explicit fallback returns fallback when key absent")
    func stringWithFallback() {
        #expect(store.string(forKey: .userAddress, fallback: "用户") == "用户")
    }

    @Test("String with explicit fallback returns stored value when present")
    func stringWithFallbackStored() {
        store.setString("老板", forKey: .userAddress)
        #expect(store.string(forKey: .userAddress, fallback: "用户") == "老板")
    }

    // MARK: - Bool

    @Test("Bool defaults to false when key absent")
    func boolDefault() {
        #expect(store.bool(forKey: .debugNoKeychain) == false)
    }

    @Test("Bool round-trips through set + get")
    func boolRoundTrip() {
        store.setBool(true, forKey: .debugNoKeychain)
        #expect(store.bool(forKey: .debugNoKeychain) == true)
    }

    // MARK: - Int

    @Test("Int defaults to 0 when key absent")
    func intDefault() {
        #expect(store.int(forKey: .monthlyCredits) == 0)
    }

    @Test("Int round-trips through set + get")
    func intRoundTrip() {
        store.setInt(4242, forKey: .monthlyCredits)
        #expect(store.int(forKey: .monthlyCredits) == 4242)
    }

    // MARK: - Double

    @Test("Double defaults to 0.0 when key absent")
    func doubleDefault() {
        #expect(store.double(forKey: .monthlyCredits) == 0.0)
    }

    @Test("Double round-trips through set + get")
    func doubleRoundTrip() {
        store.setDouble(3.14, forKey: .monthlyCredits)
        #expect(store.double(forKey: .monthlyCredits) == 3.14)
    }

    // MARK: - Data

    @Test("Data returns nil when key absent")
    func dataNilWhenAbsent() {
        #expect(store.data(forKey: .openTabs) == nil)
    }

    @Test("Data round-trips through set + get")
    func dataRoundTrip() {
        let blob = Data([1, 2, 3, 4, 5])
        store.setData(blob, forKey: .openTabs)
        #expect(store.data(forKey: .openTabs) == blob)
    }

    // MARK: - UUID

    @Test("UUID returns nil when key absent")
    func uuidNilWhenAbsent() {
        #expect(store.uuid(forKey: .activeTabId) == nil)
    }

    @Test("UUID round-trips through set + get")
    func uuidRoundTrip() {
        let id = UUID()
        store.setUUID(id, forKey: .activeTabId)
        #expect(store.uuid(forKey: .activeTabId) == id)
    }

    @Test("UUID set to nil removes the key")
    func uuidSetNilRemoves() {
        let id = UUID()
        store.setUUID(id, forKey: .activeTabId)
        #expect(store.uuid(forKey: .activeTabId) == id)
        store.setUUID(nil, forKey: .activeTabId)
        #expect(store.uuid(forKey: .activeTabId) == nil)
    }

    // MARK: - Remove

    @Test("remove clears a previously-stored value")
    func removeClearsValue() {
        store.setString("anthropic", forKey: .llmActiveConnector)
        #expect(store.string(forKey: .llmActiveConnector) == "anthropic")
        store.remove(.llmActiveConnector)
        #expect(store.string(forKey: .llmActiveConnector) == "")
    }

    // MARK: - Key namespace coverage (= G-2 cluster key registry)

    @Test("WenshuDefaultsKey.allCases covers 19 typed settings keys")
    func keyEnumCompleteness() {
        // Wenshu's G-2 cluster (= the keys written/read by @Observable
        // models) maps 1:1 to WenshuDefaultsKey cases. Adding a new
        // case here is the canonical way to onboard a new persisted
        // setting (= typo-proof).
        #expect(WenshuDefaultsKey.allCases.count == 19)
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
        store.setString("anthropic", forKey: .llmActiveConnector)
        // A SwiftUI view using @AppStorage("wenshu.llm.activeConnector")
        // would read this exact key path.
        #expect(UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector") == "anthropic")
    }
}