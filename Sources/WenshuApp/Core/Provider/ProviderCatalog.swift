// ProviderCatalog.swift

import Foundation

enum ProviderCatalog {
    static func defaultModels(for slug: String) -> [String] {
        Provider.by(slug: slug)?.defaultModels ?? []
    }

    static func provider(slug: String) -> Provider {
        Provider.by(slug: slug) ?? .minimaxCn
    }

    /// ProviderProfileExt lookup.
    /// Returns the per-slug extension or nil (= caller falls back to .empty).
    static func profileExt(for slug: String) -> ProviderProfileExt? {
        profileExts[slug]
    }

    /// ProviderProfileExt catalog.
    /// v1 deployment ships only minimax cn (= Anthropic-compatible protocol).
    static let profileExts: [String: ProviderProfileExt] = [
        "minimax-cn": ProviderProfileExt(
            aliases: ["minimax"],
            displayName: "minimax cn",
            description: "Wenshu v1 LLM provider (Anthropic-compatible protocol)",
            signupURL: "https://platform.minimaxi.com/",
            userAgentStrategy: .customBrowserUA,
            requestQuirks: [.useAnthropicVersionHeader]
        )
    ]
}