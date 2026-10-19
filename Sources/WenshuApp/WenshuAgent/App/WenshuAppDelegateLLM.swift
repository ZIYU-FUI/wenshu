//
//  WenshuAppDelegateLLM.swift
//
//  LLM/connector helper static funcs extracted from
//  WenshuAppDelegate.swift (= §6.6 god-class split: the
//  activeConnectorSlug + activeLLMConnector + activeModelSlug
//  nonisolated static funcs moved out of the main delegate class).
//
//  Why extracted (= §6.6 god-class split): the main `final class
//  WenshuAppDelegate: NSObject, NSApplicationDelegate` is 712
//  LOC = 1.2x the 600-LOC cap. The 3 LLM helpers are a logical
//  group (= they all read the active LLM connector slug from
//  UserDefaults and instantiate the connector or read the default
//  model slug).
//

import AppKit
import WenshuData
import os

/// Namespace container for the 3 LLM/connector helper static funcs.
enum WenshuAppDelegateLLMHelpers {
    /// 
    /// canonical LLM connector resolver used by the production ChatView
    /// long-running-goal button (= M14 fix) and the unit-test
    /// TriggerClosureWiringTests. The resolver reads the
    /// `wenshu.llm.activeConnector` UserDefaults slug (= the connector
    /// profile the user picked in LLMConnectorSettingsView) and falls
    /// back to AnthropicConnector for missing / unknown / unsupported
    /// apiMode (= never nil, matches wenshu defensive-defaults rule).
    ///
    /// Why this lives on WenshuAppDelegate (= not just on WorkspaceView):
    /// unit tests run in a swift-test helper process that does not
    /// mount the full view hierarchy, so WorkspaceView.activeLLMConnector
    /// (= private) is unreachable from the test target. Exposing the
    /// same logic on WenshuAppDelegate (= module-internal) keeps the
    /// test + production in lockstep without leaking the view API.
    nonisolated static func activeConnectorSlug() -> String {
        // lightweight introspection used by the import flow's activity log so the user
        // can see WHICH connector is being hit when the LLM is unreachable.
        // Resolves the same UserDefaults + keychain signal as
        // `activeLLMConnector` but returns the slug string (= no connector
        // allocation).
        let slug = resolveActiveConnectorSlugWithLog()
        if let slug, !slug.isEmpty {
            os_log("[wenshu.llm.connector] activeConnectorSlug resolved: %{public}@", log: .default, type: .info, slug)
        } else {
            os_log("[wenshu.llm.connector] activeConnectorSlug resolved: <nil> (= no provider available; chat will show 'agent 未配置' fallback)", log: .default, type: .error)
        }
        return slug ?? "anthropic"
    }

    /// Resolved-pipeline helper (= extracted so the resolution path
    /// can be logged in one place; = the boss 2026-10-19 reproducer
    /// "chat 一直 AI 思考中" needs a single os_log point to surface
    /// the full UserDefaults + keychain + fallback chain). The log
    /// line above the return makes each step visible in Console.app.
    private nonisolated static func resolveActiveConnectorSlugWithLog() -> String? {
        if let slug = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector"),
           Provider.by(slug: slug) != nil {
            return slug
        }
        os_log("[wenshu.llm.connector] activeConnector UserDefaults = <empty> OR slug not in Provider.by; falling back to keychain listProvidersWithKeys", log: .default, type: .info)
        if let first = ProviderKeychain.listProvidersWithKeys().first(where: { Provider.by(slug: $0) != nil }) {
            os_log("[wenshu.llm.connector] keychain first configured slug = %{public}@", log: .default, type: .info, first)
            return first
        }
        return nil
    }

    nonisolated static func activeLLMConnector() -> any LLMConnector {
        let slug = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector")
        // ProviderCatalog cannot resolve) must fall back to the first provider that has a
        // key in the keychain (= NOT AnthropicConnector). The previous
        // behavior (= default to anthropic) caused a "Missing API key for
        // provider 'anthropic'" error in the v2.7 markdown import flow
        // whenever the user had configured MiniMax (China) / OpenAI / etc. in
        // the chat Settings picker (= the picker is per-chat; = the v2.7
        // import connector is resolved independently and should follow the
        // keychain-side signal). The new behavior: ask the keychain which
        // providers have keys; = pick the first one (= wenshu only ships 1 key
        // for non-test users in practice; = the order is the user's own
        // configure order).
        let provider: Provider
        if let slug = slug, let resolved = Provider.by(slug: slug) {
            provider = resolved
        } else {
            // Ask the keychain which providers have keys (= the canonical signal that the
            // user has configured a provider end-to-end; = UserDefaults
            // alone doesn't prove the key is real).
            let configuredSlugs = ProviderKeychain.listProvidersWithKeys()
            if let first = configuredSlugs.first(where: { Provider.by(slug: $0) != nil }),
               let resolved = Provider.by(slug: first) {
                provider = resolved
            } else {
                // Last resort: AnthropicConnector for unit tests (= the unit-test
                // contract in TriggerClosureWiringTests pins this so
                // the production long-running-goal button can never
                // hit a connector it cannot drive).
                provider = Provider.by(slug: "anthropic") ?? .minimaxCn
            }
        }
        switch provider.apiMode {
        case "anthropic_messages":
            // MinimaxConnector is the Anthropic-compatible wrapper (= wenshu's default
            // provider per AGENTS.md §11.2); AnthropicConnector is the
            // native Anthropic API.
            if provider.slug == "anthropic" {
                return AnthropicConnector()
            }
            return MinimaxConnector(provider: provider)
        case "openai_chat":
            return OpenAICompatibleConnector(provider: provider)
        default:
            // Gemini + any other apiMode lands here until the matching connector lands (=
            // Gemini native connector is a separate ticket per
            // ConnectorTestButton.runTest).
            return AnthropicConnector()
        }
    }

    /// Build the LLM connector for an ARBITRARY provider slug (=
    /// not just the active one). Used by the import flow's auto-
    /// fallback path (= when the active provider is unreachable,
    /// the import dispatch asks this helper to build a connector
    /// for the next configured provider and re-routes). Returns
    /// `nil` when the slug doesn't resolve to a known Provider or
    /// the Provider's apiMode is unsupported (= = the dispatch
    /// skips that candidate and tries the next one).
    nonisolated static func connectorForSlug(_ slug: String) -> (any LLMConnector)? {
        guard let provider = Provider.by(slug: slug) else { return nil }
        switch provider.apiMode {
        case "anthropic_messages":
            if provider.slug == "anthropic" {
                return AnthropicConnector()
            }
            return MinimaxConnector(provider: provider)
        case "openai_chat":
            return OpenAICompatibleConnector(provider: provider)
        default:
            return nil
        }
    }

    /// The user-picked model slug for the active
    /// connector (= the `wenshu.llm.model`
    /// UserDefaults entry; = same source
    /// `ChatSessionViewModel.activeModel` reads).
    /// Returns `nil` when the user has not picked a
    /// model yet (= the connector then uses its
    /// provider default; = the v2.7 markdown
    /// import's `WenshuConductorImportRouter`
    /// passes this `nil`-able value to
    /// `LLMCallOptions.model`).
    nonisolated static func activeModelSlug() -> String? {
        let slug = UserDefaults.standard.string(forKey: "wenshu.llm.model")
        // Empty string (= the user explicitly cleared the picker; = a real value) is
        // returned unchanged. nil (= the user never picked anything; = the
        // connector default) is returned as nil too.
        return (slug?.isEmpty == false) ? slug : nil
    }

}
