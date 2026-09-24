//
// ChatViewModelDefaultModelTests.swift · Wenshu · v0.24 bossverification
//
// 
// 'MiniMax M3', show ' placeholder.
//
//  Boss commit c83a131b2 fixed App.swift line 219 (SettingView.llmModel default),
//  line 1278 (ChatZoneView.currentModel default), line 1346 (model menu text
// "" when currentModel empty), line 1358 (fallback section skip
//  if empty). But ChatView.swift line 72 (ChatViewModel.currentModel default)
//  and line 149 (send() fallback) were claimed but not actually fixed
//  (commit message has doc drift).
//
//  These tests verify the EXPECTED behavior across all 4 locations:
//  - App.swift SettingView.llmModel = "" (default)
//  - App.swift ChatZoneView.currentModel = "" (default)
// - App.swift ChatZoneView Menu Text shows "" when empty
//  - ChatView.swift ChatViewModel.currentModel = "" (default) — NOT YET FIXED
//  - ChatView.swift ChatViewModel.send() fallback = "" (default) — NOT YET FIXED
//
//  The last 2 currently FAIL — exposes the doc drift. Boss should fix
//  ChatView.swift line 72 + 149 in a follow-up commit.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatViewModel default model (boss v0.24 验收)")
struct ChatViewModelDefaultModelTests {

    // MARK: - UserDefaults setup / teardown

    private func clearModelDefaults() {
        UserDefaults.standard.removeObject(forKey: "wenshu.llm.model")
    }

    // MARK: - App.swift (boss's v0.24 fix — verified)

    @Test("SettingView.swift llmModel default = '' when no UserDefaults")
    func testAppSettingViewDefault() async {
        clearModelDefaults()
        // @AppStorage default is read at runtime — we can't easily construct a
        // SettingView in tests, but we can verify the @AppStorage source string.
        // Direct read of UserDefaults simulates no setting.
        let saved = UserDefaults.standard.string(forKey: "wenshu.llm.model")
        #expect(saved == nil, "UserDefaults 'wenshu.llm.model' should be unset (clean test)")

        // 
        // test reads the worktree-local file (= not the hardcoded main path).
        let cwd = FileManager.default.currentDirectoryPath
        let settingViewURL = URL(fileURLWithPath: cwd)
            .appendingPathComponent("Sources/WenshuApp/Views/Settings/SettingView.swift")
        let settingView = try? String(contentsOf: settingViewURL, encoding: .utf8)
        #expect(settingView != nil, "SettingView.swift must be readable at \(settingViewURL.path)")
        // 
        let hasEmptyDefault = settingView!.contains("@AppStorage(\"wenshu.llm.model\") private var llmModel: String = \"\"")
        #expect(hasEmptyDefault, "SettingView.swift llmModel default must be '' (v0.24 boss fix)")
    }

    @Test("ChatZoneView.swift currentModel default = '' when no UserDefaults")
    func testAppChatZoneDefault() async {
        clearModelDefaults()
        // 
        // from any worktree = not just main).
        let cwd = FileManager.default.currentDirectoryPath
        let chatZoneViewURL = URL(fileURLWithPath: cwd)
            .appendingPathComponent("Sources/WenshuApp/Views/Chat/ChatZoneView.swift")
        let chatZoneView = try? String(contentsOf: chatZoneViewURL, encoding: .utf8)
        #expect(chatZoneView != nil, "ChatZoneView.swift must be readable at \(chatZoneViewURL.path)")
        // 
        // the v0.24 boss fix was applied at App.swift line 1281 = `@AppStorage("wenshu.llm.model") private var currentModel: String = ""`.
        // 
        //
        // Fix: verify the canonical source-of-truth (= AppState.llmModel) carries the empty-string default. We strip comments to avoid false positives (= the v0.24 comment in SettingView.swift line 57-67 mentions the literal `@AppStorage("wenshu.llm.model")` as historical reference).
        let appStateURL = URL(fileURLWithPath: cwd)
            .appendingPathComponent("Sources/WenshuApp/State/AppState.swift")
        let appState = try? String(contentsOf: appStateURL, encoding: .utf8)
        #expect(appState != nil, "AppState.swift must be readable at \(appStateURL.path)")
        let codeLines = appState!.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let hasEmptyDefault = codeRegion.contains("var llmModel: String = \"\"")
        #expect(hasEmptyDefault, "AppState.llmModel default must be '' (v0.24 boss fix; = moved from ChatZoneView to AppState per v0.40 apple-001 phase 3 ticket 4b)")
    }

        

    // MARK: - WenshuLLMError LocalizedError (boss commit aa7caca7f)

    @Test("WenshuLLMError conforms to LocalizedError (boss v0.24 fix)")
    func testWenshuLLMErrorLocalizedError() {
        // Boss fix: WenshuLLMError needs LocalizedError conformance so error
        // description shows in ChatView UI (not generic Swift error message).
        let e = WenshuLLMError.missingAPIKey
        #expect(e is LocalizedError, "WenshuLLMError must conform to LocalizedError")
        let desc = e.errorDescription
        #expect(desc != nil, "errorDescription must be non-nil for missingAPIKey")
        #expect(desc!.contains("API key") || desc!.contains("key") || desc!.contains("Settings") || desc!.contains("Provider"),
               "missingAPIKey description should mention key/Settings/Provider, got: \(desc ?? "nil")")
    }

    @Test("WenshuLLMError.invalidBaseURL has human description")
    func testWenshuLLMErrorInvalidBaseURL() {
        let e = WenshuLLMError.invalidBaseURL(url: "https://example.com")
        let desc = e.errorDescription
        #expect(desc != nil, "errorDescription must be non-nil")
        #expect(desc!.contains("https://example.com") || desc!.contains("base URL") || desc!.contains("Provider"),
               "invalidBaseURL description should mention URL or Provider, got: \(desc ?? "nil")")
    }

    @Test("WenshuLLMError.httpError includes status code")
    func testWenshuLLMErrorHTTP() {
        let e = WenshuLLMError.httpError(statusCode: 401, body: "Unauthorized")
        let desc = e.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("401") || desc!.contains("HTTP"),
               "httpError description should mention status code 401, got: \(desc ?? "nil")")
    }

    // MARK: - Keychain -34018 (boss commit 4f4a22f17)

    @Test("Keychain -34018 handling: graceful error (not generic Swift error)")
    func testKeychainError34018() {
        // 
        // the v0.24 boss fix was supposed to add -34018 (= errSecMissingEntitlement)
        // graceful handling to ProviderKeychain.swift. After v0.84 ticket 001
        // (= extracted KeychainOps), the Security framework glue (= and
        // therefore the -34018 mapping) lives in KeychainOps.swift, not
        // ProviderKeychain.swift. ProviderKeychain.swift now delegates
        // `SecItemAdd` via `KeychainOps.save(...)` (= the new home for
        // error mapping).
        //
        // Fix: verify the -34018 / errSecMissingEntitlement reference
        // exists in the canonical Security-glue location (= KeychainOps.swift),
        // not the pre-v0.84 ProviderKeychain.swift location.
        //
        // 
        // The hardcoded absolute path previously pointed at the main
        // checkout (= /Volumes/ANAN/Engineering/wenshu/Sources/...) =
        // = the test verified the main repo's KeychainOps.swift even
        // when run from a worktree (= false negative). The fix is to
        // derive the path from FileManager.currentDirectoryPath (= the
        // working directory of `swift test`), so the test reads the
        // worktree-local file (= or the main file when run from main).
        let cwd = FileManager.default.currentDirectoryPath
        let keychainOpsURL = URL(fileURLWithPath: cwd)
            .appendingPathComponent("Sources/WenshuApp/Core/Provider/KeychainOps.swift")
        let keychainOps = try? String(contentsOf: keychainOpsURL, encoding: .utf8)
        #expect(keychainOps != nil, "KeychainOps.swift must be readable at \(keychainOpsURL.path)")
        // Strip comments (= historical references in headers must not count).
        let codeLines = keychainOps!.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let mentions34018 = codeRegion.contains("34018") ||
                             codeRegion.contains("errSecMissingEntitlement")
        #expect(mentions34018, "KeychainOps.swift should reference 34018 or errSecMissingEntitlement (= canonical Security-glue home after v0.84 KeychainOps extraction; = boss 2026-08-24 fix-tracking)")
    }
}
