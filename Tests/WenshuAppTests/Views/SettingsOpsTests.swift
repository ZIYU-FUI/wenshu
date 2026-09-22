//
//  SettingsOpsTests.swift · Wenshu · v1.72 settings-kanban-todo-mvvm T3a
//
//  Behavior + source-level tests for `SettingsOps` (= the stateless
//  enum extracted from SettingView in v1.72 T3b). Per boss
//  2026-09-22 OOB '按MVVM UI 业务 数据，三分离': SettingView currently
//  owns the business logic for the 9-tab Settings pane. The fix per
//  ADR-0009 + the v1.70 editor-mvvm precedent + the v1.72 T1/T2
//  Kanban/Todo sibling arcs is the same lift-out, but Settings has
//  3 surface areas (= ProviderKeychain IO / ProviderFetcher async /
//  Set<String> expansion state) so the helper carries more seams.
//
//  Public surface (= 5 entry points):
//    1. refreshProviderStatus() -> Set<String> (= the providers-with-keys set)
//    2. reloadModels(provider:keychain:fetcher:) async -> [String]
//    3. keyPrefix12(provider:keychain:) -> String
//    4. saveApiKey(provider:draft:keychain:notify:) -> SaveResult
//    5. toggleExpansion(provider:in:) -> Set<String> (= the expansion toggle)
//
//  Coverage (= 12 tests):
//    1. `fileExistsAtCanonicalPath` — source-level guard
//    2. `refreshProviderStatusReturnsSetFromKeychain`
//    3. `reloadModelsUsesEmptyKeyWhenKeychainEmpty`
//    4. `reloadModelsCallsFetcherWithLoadedKey`
//    5. `keyPrefix12ReturnsEmptyWhenNoKey`
//    6. `keyPrefix12ReturnsFirst12CharsWhenKey`
//    7. `saveApiKeyRejectsEmptyDraft` (whitespace + empty)
//    8. `saveApiKeyPersistsAndNotifiesOnSuccess`
//    9. `saveApiKeyReportsErrorOnKeychainFailure`
//   10. `toggleExpansionAddsSlugWhenAbsent`
//   11. `toggleExpansionRemovesSlugWhenPresent`
//   12. `saveApiKeyClearsDraftAndCollapsesOnSuccess`
//
//  Mock strategy (= v1.70 WikiLinkNavigation + v1.72 T1/T2 precedent):
//  no mock framework. Real /tmp fixture for the SettingsOps scope.
//  InMemoryKeychainStore (= already shipped per AGENTS.md §11.1) for
//  the keychain seam. A tiny `StubProviderFetcher` for the async
//  fetcher seam (= captures the (provider, apiKey) tuple).

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("v1.72 settings-kanban-todo-mvvm T3a — SettingsOps (Settings pane business layer)")
struct SettingsOpsTests {

    // MARK: - Fixtures

    private func makeInMemoryKeychain() -> ProviderKeychainStoring {
        InMemoryKeychainStore()
    }

    /// Stub fetcher that records its inputs and returns a canned
    /// model id list. Mirrors v1.70 WikiLinkNavigation's MockReference
    /// Store pattern (= a thin concrete struct that satisfies the
    /// helper's protocol seam).
    private final class StubProviderFetcher: SettingsOps.ProviderFetcherSeam {
        var lastProvider: Provider?
        var lastAPIKey: String?
        var cannedIDs: [String] = []
        func loadModelIds(provider: Provider, apiKey: String) async -> [String] {
            lastProvider = provider
            lastAPIKey = apiKey
            return cannedIDs
        }
    }

    // MARK: - Source-level structural assertions

    @Test("SettingsOps.swift exists at the canonical path under Views/Settings/")
    func fileExistsAtCanonicalPath() throws {
        // #filePath = .../Tests/WenshuAppTests/Views/SettingsOpsTests.swift
        // (= 4 segments above the file: Views -> WenshuAppTests ->
        // Tests -> worktree = repo root).
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()  // Views/        -> WenshuAppTests/
            .deletingLastPathComponent()  // WenshuAppTests/ -> Tests/
            .deletingLastPathComponent()  // Tests/         -> <worktree>/
            .deletingLastPathComponent()  // <worktree>/    -> repo root
        let sourcePath = repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("WenshuApp")
            .appendingPathComponent("Views")
            .appendingPathComponent("Settings")
            .appendingPathComponent("SettingsOps.swift")
            .path
        #expect(FileManager.default.fileExists(atPath: sourcePath),
                "SettingsOps.swift must exist at \(sourcePath) (= v1.72 T3b extraction target)")
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("enum SettingsOps"),
                "SettingsOps.swift must declare `enum SettingsOps` (= v1.70 stateless-enum pattern)")
        #expect(source.contains("ProviderFetcherSeam"),
                "SettingsOps must declare the `ProviderFetcherSeam` (= the fetcher bypass seam)")
    }

    // MARK: - refreshProviderStatus

    @Test("refreshProviderStatus returns the Set<String> from the keychain")
    func refreshProviderStatusReturnsSetFromKeychain() throws {
        let keychain = makeInMemoryKeychain()
        try keychain.saveKeySync("anthropic-key", for: .anthropic)
        try keychain.saveKeySync("openai-key", for: .openai)
        let providersWithKeys = SettingsOps.refreshProviderStatus(keychain: keychain)
        #expect(providersWithKeys.contains(.anthropic.slug))
        #expect(providersWithKeys.contains(.openai.slug))
        #expect(providersWithKeys.count == 2,
                "Exactly 2 providers must be reported as configured")
    }

    @Test("refreshProviderStatus returns empty set when no keys")
    func refreshProviderStatusEmptyWhenNoKeys() throws {
        let keychain = makeInMemoryKeychain()
        let providersWithKeys = SettingsOps.refreshProviderStatus(keychain: keychain)
        #expect(providersWithKeys.isEmpty,
                "Empty keychain must yield an empty set (= the view's footer '0 / N configured' path)")
    }

    // MARK: - reloadModels

    @Test("reloadModels uses empty apiKey when keychain has no key for the provider")
    func reloadModelsUsesEmptyKeyWhenKeychainEmpty() async throws {
        let keychain = makeInMemoryKeychain()
        let fetcher = StubProviderFetcher()
        let ids = await SettingsOps.reloadModels(provider: .anthropic, keychain: keychain, fetcher: fetcher)
        #expect(fetcher.lastProvider == .anthropic,
                "reloadModels must pass the supplied provider to the fetcher")
        #expect(fetcher.lastAPIKey == "",
                "Empty keychain → empty apiKey passed to fetcher (= SettingView's `loadKeySync(...) ?? \"\"`)")
        #expect(ids.isEmpty,
                "Stub fetcher returns its canned list; = the view's liveModelIds receives whatever the fetcher returns")
    }

    @Test("reloadModels calls fetcher with the loaded keychain key")
    func reloadModelsCallsFetcherWithLoadedKey() async throws {
        let keychain = makeInMemoryKeychain()
        try keychain.saveKeySync("sk-test-anthropic-12345", for: .anthropic)
        let fetcher = StubProviderFetcher()
        fetcher.cannedIDs = ["claude-sonnet-4", "claude-opus-4"]
        let loaded = await SettingsOps.reloadModels(provider: .anthropic, keychain: keychain, fetcher: fetcher)
        #expect(fetcher.lastAPIKey == "sk-test-anthropic-12345",
                "reloadModels must pass the keychain-loaded key (= the production fetcher auth)")
        #expect(loaded == ["claude-sonnet-4", "claude-opus-4"],
                "reloadModels returns the fetcher's model ids (= the liveModelIds assignment)")
    }

    // MARK: - keyPrefix12

    @Test("keyPrefix12 returns empty when no key for the provider")
    func keyPrefix12ReturnsEmptyWhenNoKey() throws {
        let keychain = makeInMemoryKeychain()
        let prefix = SettingsOps.keyPrefix12(provider: .anthropic, keychain: keychain)
        #expect(prefix == "",
                "Missing keychain entry → empty prefix (= SettingView's `guard let key ... else { return \"\" }`)")
    }

    @Test("keyPrefix12 returns first 12 chars when key present")
    func keyPrefix12ReturnsFirst12CharsWhenKey() throws {
        let keychain = makeInMemoryKeychain()
        try keychain.saveKeySync("sk-ant-1234567890abcdef", for: .anthropic)
        let prefix = SettingsOps.keyPrefix12(provider: .anthropic, keychain: keychain)
        #expect(prefix == "sk-ant-12345",
                "keyPrefix12 must return exactly the first 12 chars (= the legacy Apple-style key fingerprint)")
    }

    // MARK: - saveApiKey

    @Test("saveApiKey rejects empty / whitespace-only drafts")
    func saveApiKeyRejectsEmptyDraft() throws {
        let keychain = makeInMemoryKeychain()
        for emptyDraft in ["", "   ", "\t\n  "] {
            let result = SettingsOps.saveApiKey(
                provider: .anthropic, draft: emptyDraft, keychain: keychain
            )
            #expect(result.didSave == false,
                    "Empty / whitespace draft must NOT save (= SettingView's `trimmed.isEmpty` guard)")
            #expect(result.error == nil,
                    "Empty draft is NOT an error (= silent no-op, matches View semantics)")
        }
    }

    @Test("saveApiKey persists AND clears the draft AND collapses the editor on success")
    func saveApiKeyPersistsAndNotifiesOnSuccess() throws {
        let keychain = makeInMemoryKeychain()
        let result = SettingsOps.saveApiKey(
            provider: .anthropic, draft: "sk-new-key", keychain: keychain
        )
        #expect(result.didSave == true,
                "Successful save must return didSave=true (= the view's SwiftUI-side resets gate)")
        #expect(result.error == nil)
        #expect(result.shouldClearDraft == true,
                "Successful save must clear the draft (= SettingView's `apiDraftKey = \"\"`)")
        #expect(result.shouldCollapse == true,
                "Successful save must collapse the editor (= SettingView's `apiExpandedProviders.remove(provider.slug)`)")
        #expect(result.shouldNotify == true,
                "Successful save must notify (= SettingView's `NotificationCenter.post(name:.wenshuProviderKeychainChanged)`)")
        let loaded = keychain.loadKeySync(for: .anthropic)
        #expect(loaded == "sk-new-key",
                "Keychain must contain the persisted key (= the round-trip invariant)")
    }

    @Test("saveApiKey reports error when keychain throws")
    func saveApiKeyReportsErrorOnKeychainFailure() throws {
        // Use a failing keychain to verify the error path.
        struct FailingKeychain: ProviderKeychainStoring {
            func saveKeySync(_ key: String, for provider: Provider) throws {
                throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "fake failure"])
            }
            func loadKeySync(for provider: Provider) -> String? { nil }
            func deleteKeySync(for provider: Provider) throws {}
            func listProvidersWithKeys() -> [String] { [] }
            func loadMetadata(for provider: Provider) -> ProviderKeychainMetadata? { nil }
            func saveMetadata(_ metadata: ProviderKeychainMetadata, for provider: Provider) throws {}
        }
        let result = SettingsOps.saveApiKey(
            provider: .anthropic, draft: "valid-key", keychain: FailingKeychain()
        )
        #expect(result.didSave == false)
        #expect(result.error != nil,
                "Keychain failure must surface an error string (= SettingView's catch-block localizes it)")
        #expect(result.shouldClearDraft == false,
                "Failed save must NOT clear the draft (= the user keeps their typed key for retry)")
        #expect(result.shouldCollapse == false,
                "Failed save must NOT collapse the editor (= the user retries without re-expanding)")
        #expect(result.shouldNotify == false,
                "Failed save must NOT post the notification (= the keychain didn't actually change)")
    }

    // MARK: - toggleExpansion

    @Test("toggleExpansion adds the slug when absent")
    func toggleExpansionAddsSlugWhenAbsent() throws {
        let result = SettingsOps.toggleExpansion(provider: .anthropic, in: [])
        #expect(result.contains(.anthropic.slug),
                "Absent slug must be inserted (= SettingView.toggleExpand's `if contains ... else insert` branch)")
    }

    @Test("toggleExpansion removes the slug when present")
    func toggleExpansionRemovesSlugWhenPresent() throws {
        var input: Set<String> = [.anthropic.slug, .openai.slug]
        let result = SettingsOps.toggleExpansion(provider: .anthropic, in: input)
        #expect(!result.contains(.anthropic.slug),
                "Present slug must be removed (= SettingView.toggleExpand's `if contains ... remove` branch)")
        #expect(result.contains(.openai.slug),
                "Unrelated slugs must be preserved (= no-op on the rest of the set)")
        _ = input  // silence unused-let under @Suite re-instantiation
    }
}