//
//  ChatViewModelDefaultModelTests.swift · Wenshu · v0.24 boss验收
//
//  Boss 2026-08-24 反馈: 没配任何 key 时, 左下 model picker 不应默认显示
//  'MiniMax M3', 应显示 '无模型可用' placeholder.
//
//  Boss commit c83a131b2 fixed App.swift line 219 (SettingView.llmModel default),
//  line 1278 (ChatZoneView.currentModel default), line 1346 (model menu text
//  "无模型可用" when currentModel empty), line 1358 (fallback section skip
//  if empty). But ChatView.swift line 72 (ChatViewModel.currentModel default)
//  and line 149 (send() fallback) were claimed but not actually fixed
//  (commit message has doc drift).
//
//  These tests verify the EXPECTED behavior across all 4 locations:
//  - App.swift SettingView.llmModel = "" (default)
//  - App.swift ChatZoneView.currentModel = "" (default)
//  - App.swift ChatZoneView Menu Text shows "无模型可用" when empty
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

    @Test("App.swift SettingView.llmModel default = '' when no UserDefaults")
    func testAppSettingViewDefault() async {
        clearModelDefaults()
        // @AppStorage default is read at runtime — we can't easily construct a
        // SettingView in tests, but we can verify the @AppStorage source string.
        // Direct read of UserDefaults simulates no setting.
        let saved = UserDefaults.standard.string(forKey: "wenshu.llm.model")
        #expect(saved == nil, "UserDefaults 'wenshu.llm.model' should be unset (clean test)")

        // The fix is at App.swift:222: @AppStorage default = "" (not WenshuLLMModel.m3.rawValue)
        // Source code verification (file:line check):
        let appSwiftURL = URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/App.swift")
        let appSwift = try? String(contentsOf: appSwiftURL, encoding: .utf8)
        #expect(appSwift != nil, "App.swift must be readable")
        // v0.24 boss验收fix line: 222 in App.swift has @AppStorage("wenshu.llm.model") default = "" (NOT WenshuLLMModel.m3.rawValue).
        let hasEmptyDefault = appSwift!.contains("@AppStorage(\"wenshu.llm.model\") private var llmModel: String = \"\"")
        #expect(hasEmptyDefault, "App.swift SettingView.llmModel default must be '' (v0.24 boss fix)")
    }

    @Test("App.swift ChatZoneView.currentModel default = '' when no UserDefaults")
    func testAppChatZoneDefault() async {
        clearModelDefaults()
        let appSwift = try? String(contentsOf: URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/App.swift"), encoding: .utf8)
        #expect(appSwift != nil)
        // v0.24 boss fix: line 1281: @AppStorage default = "" (NOT WenshuLLMModel.m3.rawValue).
        let hasEmptyDefault = appSwift!.contains("@AppStorage(\"wenshu.llm.model\") private var currentModel: String = \"\"")
        #expect(hasEmptyDefault, "App.swift ChatZoneView.currentModel default must be '' (v0.24 boss fix)")
    }

    @Test("App.swift model menu text shows '无模型可用' when currentModel empty")
    func testAppMenuTextPlaceholder() async {
        let appSwift = try? String(contentsOf: URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/App.swift"), encoding: .utf8)
        #expect(appSwift != nil)
        // v0.24 boss fix: line 1349: 'Text(currentModel.isEmpty ? "无模型可用" : ...)'.
        let hasPlaceholder = appSwift!.contains("currentModel.isEmpty ? \"无模型可用\"")
        #expect(hasPlaceholder, "App.swift model menu must show '无模型可用' when empty (v0.24 boss fix)")
    }

    // MARK: - ChatView.swift (boss's commit message claims — NOT YET FIXED)

    @Test("ChatView.swift ChatViewModel.currentModel default = '' (NOT YET FIXED)")
    func testChatViewModelDefault() async {
        clearModelDefaults()
        let chatView = try? String(contentsOf: URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Chat/ChatView.swift"), encoding: .utf8)
        #expect(chatView != nil)
        // BOSS CLAIMED: 'ChatView.swift line 72' should be '... ?? ""' (empty).
        // ACTUAL (per git show c83a131b2:ChatView.swift): line 72 STILL has
        // '... ?? WenshuLLMModel.m3.rawValue' — boss's commit message drift.
        // This test currently FAILS, exposing the doc drift.
        let hasEmptyDefault = chatView!.contains("UserDefaults.standard.string(forKey: \"wenshu.llm.model\") ?? \"\"")
        #expect(hasEmptyDefault, "ChatView.swift ChatViewModel.currentModel default should be '' (boss to fix in follow-up)")
    }

    @Test("ChatView.swift send() fallback uses empty string (NOT YET FIXED)")
    func testChatViewSendFallback() async {
        clearModelDefaults()
        let chatView = try? String(contentsOf: URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Chat/ChatView.swift"), encoding: .utf8)
        #expect(chatView != nil)
        // v0.24 boss fix targets ChatView.swift line 149:
        //   was: '?? "MiniMax-M3"'
        //   should be: '?? ""'  (empty string when no UserDefaults)
        // ACTUAL (per git show c83a131b2:ChatView.swift): line 149 STILL has
        //   '?? "MiniMax-M3"' — boss's commit message drift.
        // This test catches the actual bug: line 149 still has '?? "MiniMax-M3"'
        // instead of '?? ""'. The test currently FAILS, exposing the doc drift.
        let line149Content = chatView!.components(separatedBy: "\n").first(where: { $0.contains("currentModel: String = UserDefaults.standard.string(forKey:") && $0.contains("MiniMax") })
        #expect(line149Content == nil, "ChatView.swift line 149 should not have '?? \"MiniMax-M3\"' fallback (boss to fix)")
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
        // Boss fix: keychain operation -34018 (errSecMissingEntitlement) was
        // showing generic Swift error. Now has graceful error message.
        // The fix is in code (not testable directly without entitlements), so
        // we verify the code path exists.
        let providerKeychainURL = URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Core/Provider/ProviderKeychain.swift")
        let providerKeychain = try? String(contentsOf: providerKeychainURL, encoding: .utf8)
        #expect(providerKeychain != nil, "ProviderKeychain.swift must be readable")
        // The fix should mention -34018 OR errSecMissingEntitlement OR
        // a graceful error pattern.
        let mentions34018 = providerKeychain!.contains("34018") ||
                             providerKeychain!.contains("errSecMissingEntitlement")
        #expect(mentions34018, "ProviderKeychain.swift should reference 34018 or errSecMissingEntitlement (boss fix)")
    }
}