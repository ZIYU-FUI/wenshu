//
//  SettingsOps.swift · Wenshu · v1.72 settings-kanban-todo-mvvm T3b
//
//  Settings pane business layer, extracted from SettingView.
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' + ADR-0009
//  + the v1.72 T1 KanbanOps + v1.72 T2 TodoOps precedents:
//  SettingView currently owns the business logic for the 9-tab
//  Settings pane (= 5 private methods touching ProviderKeychain +
//  ProviderFetcher + Set<String> expansion state). This helper lifts
//  the business layer into a stateless enum so the View can become
//  a pure consumer.
//
//  Why a stateless enum (not @Observable class):
//  - The 4 SwiftUI @State properties (= liveModelIds / providers-
//    WithKeys / apiExpandedProviders / apiDraftKey / apiError) are
//    pure observable UI state. The business layer (= what's in the
//    keychain / what model ids to fetch / what to toggle) is
//    stateless.
//  - The View holds the @State (= per ADR-0009 = the View layer
//    owns reactive state); the helper is pure behavior on inputs.
//  - Same v1.70 editor-mvvm / v1.72 KanbanOps / TodoOps shape.
//
//  Why 2 seams (= ProviderKeychainStoring + ProviderFetcherSeam):
//  - ProviderKeychainStoring (= shipped per AGENTS.md §11.1 = a
//    protocol with saveKeySync / loadKeySync / listProvidersWithKeys
//    + deleteKeySync). Tests inject InMemoryKeychainStore (=
//    Apple-default-first = no entitlement required); production
//    wires ProviderKeychain (= the Apple Keychain-backed singleton
//    per AGENTS.md §11 baseline).
//  - ProviderFetcherSeam (= a thin protocol with one async method).
//    Production wires ProviderFetcher (= the URLSession-backed
//    static enum); tests pass StubProviderFetcher (= the in-file
//    capture-and-return struct).
//
//  Apple HIG canonical pattern: stateless business-layer enum +
//  per-call Result structs (= matches Foundation URLSession's
//  completion-handler shape; = no leaky global state).
//
//  All methods are @MainActor-isolated because:
//  - The View writes through ProviderKeychain + ProviderFetcher on
//    @MainActor.
//  - The Result types are simple value types; = no shared mutation.
//
//  Public surface (= 5 entry points + 2 seams):
//    - refreshProviderStatus(keychain:) -> Set<String>
//    - reloadModels(provider:keychain:fetcher:) async -> [String]
//    - keyPrefix12(provider:keychain:) -> String
//    - saveApiKey(provider:draft:keychain:) -> SaveResult
//    - toggleExpansion(provider:in:) -> Set<String>
//    - ProviderKeychainStoring (= shipped seam; = no definition here)
//    - ProviderFetcherSeam (= NEW seam; = the fetcher bypass)
//
//  Result types (= SaveResult with 4 booleans):
//    - didSave (= the success flag; = the only state the helper
//      asserts)
//    - shouldClearDraft (= the View's `apiDraftKey = ""` reset)
//    - shouldCollapse (= the View's `apiExpandedProviders.remove`)
//    - shouldNotify (= the View's `NotificationCenter.post`)
//    - error (= the localized error string for the View's
//      `apiError` @State)
//  The 3 should* booleans are derived from didSave (= they're the
//  SwiftUI-side effects that follow success). Splitting them lets
//  the View handle each one as its own @State mutation (= no
//  business-logic-in-the-view coupling on the ordering of resets).
//
//  Out of scope (= NOT moved here, stays in SettingView):
//    - UI state (= liveModelIds / providersWithKeys / apiExpanded-
//      Providers / apiDraftKey / apiError @State).
//    - .onChange(of: selectedTab) triggers / .task / .searchable
//      (= SwiftUI reactive triggers per ADR-0009).
//    - Picker / Toggle / Button / Section / Form views (= pure
//      layout, no business logic).
//    - The 9 tab definitions (= generalTab / providerApiTab /
//      modelTab / memoryTab / skillsTab etc.; = the View owns
//      layout).
//
//  Honest scope note (= Q46 stop-rule boundary):
//    The original SettingView.toggleExpand had a SwiftUI-side
//    coupling: when the user EXPANDS a provider, the helper
//    pre-fills apiDraftKey with the existing key's prefix (=
//    `apiDraftKey = currentDraftPreview(for: p)` = the editing UX).
//    That pre-fill is a SwiftUI binding assignment (= stays in the
//    View). SettingsOps.toggleExpansion only computes the new
//    Set<String>; = the View drives the apiDraftKey reset.
//
//  Scope-explicit omissions (= out of v1.72 T3b; = separate tickets):
//    - The SettingsView's 9 tabs ARE NOT being split into separate
//      tab views yet (= e.g. ProviderApiTabView, ModelTabView).
//      That decomposition is a separate v1.7x ticket (= the
//      "right column MVVM split" arc per boss OOB '按MVVM UI 业务 数据').
//    - The keychain-changed NotificationCenter post stays in the
//      View (= the helper just reports shouldNotify; = the View
//      owns the NotificationCenter wiring).

import Foundation

/// Stateless business layer for the Settings pane. Lifts the
/// ProviderKeychain + ProviderFetcher + Set<String> expansion logic
/// out of `SettingView` per the v1.72 UI/业务/数据 separation audit.
@MainActor
enum SettingsOps {

    // MARK: - Seams

    /// Async fetcher seam. Production: `ProviderFetcher.loadModelIds
    /// (provider:apiKey:)`. Tests pass `StubProviderFetcher`. Mirrors
    /// the v1.70 WikiLinkNavigation + ReferenceStoring pattern (= a
    /// thin protocol with one method, satisfied by an in-file struct in
    /// tests).
    ///
    /// `Sendable` (= the fetcher crosses an `await` boundary into a
    /// nonisolated async context; = Swift 6 region isolation
    /// requires the protocol to be Sendable for safe `await fetcher.
    /// loadModelIds(...)` from a `@MainActor` caller). The
    /// `loadModelIds` method itself is `nonisolated` so the protocol
    /// stays sync-to-async (= the caller stays on @MainActor; = the
    /// fetcher hops to its own context for the URLSession work).
    protocol ProviderFetcherSeam: Sendable {
        nonisolated func loadModelIds(provider: Provider, apiKey: String) async -> [String]
    }

    /// Result of saveApiKey. Splits the 3 SwiftUI-side effects into
    /// 3 should* booleans (= the View drives each @State mutation
    /// independently).
    struct SaveResult: Sendable {
        let didSave: Bool
        let error: String?
        let shouldClearDraft: Bool
        let shouldCollapse: Bool
        let shouldNotify: Bool
        init(didSave: Bool, error: String? = nil,
             shouldClearDraft: Bool = false,
             shouldCollapse: Bool = false,
             shouldNotify: Bool = false) {
            self.didSave = didSave
            self.error = error
            self.shouldClearDraft = shouldClearDraft
            self.shouldCollapse = shouldCollapse
            self.shouldNotify = shouldNotify
        }
    }

    // MARK: - refreshProviderStatus

    /// Read which providers currently have a key configured (= the
    /// "N / total" footer counter + the per-row badge). Mirrors
    /// `SettingView.refreshProviderStatus`.
    static func refreshProviderStatus(
        keychain: ProviderKeychainStoring
    ) -> Set<String> {
        Set(keychain.listProvidersWithKeys())
    }

    // MARK: - reloadModels

    /// Load live model ids for the supplied provider via the fetcher
    /// seam. Mirrors `SettingView.reloadModels` (= the `Task { await
    /// reloadModels() }` driver behind the model picker):
    ///   - Loads the apiKey from the keychain (empty string when
    ///     not configured; = SettingView's `?? \"\"` fallback).
    ///   - Delegates to the fetcher (= provider / apiKey → [String]).
    ///   - Returns the fetcher's id list (the View assigns to its
    ///     `liveModelIds` @State).
    /// Caller is responsible for the `isLoadingModels` guard (= a
    /// SwiftUI-side concern; = stays in the View).
    static func reloadModels(
        provider: Provider,
        keychain: ProviderKeychainStoring,
        fetcher: ProviderFetcherSeam
    ) async -> [String] {
        let key = keychain.loadKeySync(for: provider) ?? ""
        return await fetcher.loadModelIds(provider: provider, apiKey: key)
    }

    // MARK: - keyPrefix12

    /// First 12 chars of the configured key (= the "fingerprint"
    /// shown next to each provider row). Empty string when no key
    /// is configured. Mirrors `SettingView.keyPrefix12`.
    static func keyPrefix12(
        provider: Provider,
        keychain: ProviderKeychainStoring
    ) -> String {
        guard let key = keychain.loadKeySync(for: provider), !key.isEmpty else {
            return ""
        }
        return String(key.prefix(12))
    }

    // MARK: - saveApiKey

    /// Persist the typed api key into the keychain (= the
    /// "Save API Key" button handler). Mirrors `SettingView.saveApiKey`:
    ///   - Trims whitespace from the draft.
    ///   - Empty / whitespace-only draft = silent no-op (= matches
    ///     SettingView's `trimmed.isEmpty else { return }` guard;
    ///     = `didSave=false` + `error=nil`).
    ///   - On success, the 3 should* booleans are true (= the View
    ///     drives each SwiftUI-side effect independently: clear the
    ///     draft text field, collapse the editor, post the
    ///     keychain-changed notification).
    ///   - On keychain throw, the 3 should* booleans are false (=
    ///     the View keeps the draft and the expansion for retry).
    static func saveApiKey(
        provider: Provider,
        draft: String,
        keychain: ProviderKeychainStoring
    ) -> SaveResult {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SaveResult(didSave: false, error: nil,
                              shouldClearDraft: false, shouldCollapse: false, shouldNotify: false)
        }
        do {
            try keychain.saveKeySync(trimmed, for: provider)
            return SaveResult(didSave: true, error: nil,
                              shouldClearDraft: true, shouldCollapse: true, shouldNotify: true)
        } catch {
            return SaveResult(didSave: false,
                              error: WenshuI18n.ts("settings.provider.save_failed_message",
                                                   error.localizedDescription),
                              shouldClearDraft: false, shouldCollapse: false, shouldNotify: false)
        }
    }

    // MARK: - toggleExpansion

    /// Toggle a provider's editor expansion. Pure on the input set
    /// (= the View drives any further @State resets, e.g. the
    /// pre-fill `apiDraftKey = currentDraftPreview(for: p)` on expand;
    /// = a SwiftUI binding assignment, not a business rule).
    /// Mirrors `SettingView.toggleExpand`.
    static func toggleExpansion(
        provider: Provider,
        in current: Set<String>
    ) -> Set<String> {
        var next = current
        if next.contains(provider.slug) {
            next.remove(provider.slug)
        } else {
            next.insert(provider.slug)
        }
        return next
    }
}

// MARK: - Production seam: ProviderFetcher adapter

/// Bridges `ProviderFetcher.loadModelIds(provider:apiKey:)` (= the
/// production URLSession-backed static enum) into
/// `SettingsOps.ProviderFetcherSeam`. Mirrors the v1.72 T1
/// BookStoreScopeDirectoryResolver pattern (= a thin concrete type
/// that bridges a global container / static enum to the helper's
/// protocol seam).
@MainActor
struct ProviderFetcherAdapter: SettingsOps.ProviderFetcherSeam {
    func loadModelIds(provider: Provider, apiKey: String) async -> [String] {
        await ProviderFetcher.loadModelIds(provider: provider, apiKey: apiKey)
    }
}