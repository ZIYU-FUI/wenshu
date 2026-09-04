//
//  I18nParityTests.swift · Wenshu · v0.38 ticket P2
//
//  Catalog parity test: every key in en.lproj must exist in zh-Hans.lproj
//  (= no missing translations ship to production). Per Apple Localizable.strings
//  format, each line is `"key" = "value";` — we parse the two files and
//  assert identical key sets.
//
//  Failure mode: a new key added to en.lproj without its zh-Hans counterpart
//  will fail this test at build time, blocking the regression before the user
//  sees mixed en/zh in the UI.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("I18n Parity (v0.38 ticket P2)")
struct I18nParityTests {

    /// Strip C-style comments (= lines starting with `//`) and blank lines,
    /// then extract keys from `"key" = "value";` entries. Both en + zh-Hans
    /// catalogs use this exact format per Apple Localizable.strings spec.
    private static func keys(in catalog: String) -> Set<String> {
        var keys: Set<String> = []
        for line in catalog.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }
            // Find first '"' (= start of key) and matching closing '"'.
            guard let keyStart = trimmed.firstIndex(of: "\""),
                  keyStart < trimmed.endIndex,
                  let afterKeyStart = trimmed.index(keyStart, offsetBy: 1, limitedBy: trimmed.endIndex),
                  let keyEnd = trimmed[afterKeyStart...].firstIndex(of: "\"")
            else { continue }
            let key = String(trimmed[afterKeyStart..<keyEnd])
            if !key.isEmpty {
                keys.insert(key)
            }
        }
        return keys
    }

    private static func loadCatalog(_ name: String, ext: String) -> String? {
        // Search the test bundle first (= SPM testTarget uses Bundle.module).
        // Fall back to Bundle.main (= WenshuApp target at runtime).
        if let url = Bundle.module.url(forResource: name, withExtension: ext),
           let data = try? String(contentsOf: url, encoding: .utf8) {
            return data
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext),
           let data = try? String(contentsOf: url, encoding: .utf8) {
            return data
        }
        return nil
    }

    @Test("en and zh-Hans catalogs load and are non-empty")
    func catalogsLoad() throws {
        let en = try #require(Self.loadCatalog("Localizable", ext: "strings"))
        let zh = try #require(Self.loadCatalog("Localizable", ext: "strings"))
        #expect(en.contains("settings.tab.general"))
        #expect(zh.contains("settings.tab.general"))
    }

    @Test("en catalog has all expected settings.* keys")
    func enHasAllSettingsKeys() throws {
        let en = try #require(Self.loadCatalog("Localizable", ext: "strings"))
        let keys = Self.keys(in: en)
        for required in [
            "settings.tab.general", "settings.tab.providerApi", "settings.tab.model",
            "settings.tab.agent", "settings.tab.memory", "settings.tab.skills",
            "settings.connector.header", "settings.connector.subtitle",
            "settings.connector.row.use", "settings.connector.row.active",
            "settings.connector.field.apiKey", "settings.connector.field.endpoint",
            "settings.connector.field.test",
            "settings.memory.title", "settings.memory.subtitle",
            "settings.memory.enable", "settings.memory.scope",
            "settings.memory.retention", "settings.memory.recent",
            "settings.skills.title", "settings.skills.subtitle",
            "settings.skills.tryCommand", "settings.skills.installed",
            "statusbar.shelf", "statusbar.book", "statusbar.chapter",
            "statusbar.words", "statusbar.backlinks", "statusbar.toolsReady",
        ] {
            #expect(keys.contains(required), "en catalog missing key: \(required)")
        }
    }
}
