// MemoryBackendResolverTests.swift
//
// The rule under test: a user who picks a backend gets that backend, or an
// explanation. Never a silent swap. The mem0 option is not a placeholder —
// MemoryBackend.allCases.count == 2 is asserted in AgentSettingsDefaultsTests
// for exactly that reason.

import Foundation
import Testing
@testable import WenshuAgent

/// A stand-in provider so the resolver can be tested without a real backend.
private struct StubProvider: MemoryProvider {
    let slug: String
    var isEnabled: Bool = true
    func getSystemPrompt() -> String { "" }
    func prefetch(forUserMessage message: String) async -> String { "" }
    func sync(userMessage: String, assistantResponse: String) async {}
    func getToolSchemas() -> [ToolSchema] { [] }
    func preCompressCheckpoint() -> String? { nil }
    func resetCache() {}
}

@Suite("Memory backend resolver")
struct MemoryBackendResolverTests {

    private func resolver(writable: Bool = true) -> MemoryBackendResolver {
        MemoryBackendResolver(
            providers: [
                StubProvider(slug: MemoryBackendResolver.localSlug),
                StubProvider(slug: MemoryBackendResolver.remoteSlug)
            ],
            localDirectoryWritable: { _ in writable }
        )
    }

    @Test("the local backend is chosen by default")
    func localIsTheDefault() {
        let resolved = resolver().resolve(settings: MemorySettings())
        #expect(resolved?.backend == .localMarkdown)
        #expect(resolved?.matchesSelection == true)
        #expect(resolved?.provider.slug == MemoryBackendResolver.localSlug)
    }

    @Test("the remote backend is honoured when configured")
    func remoteHonouredWhenConfigured() {
        var settings = MemorySettings()
        settings.backend = .remoteService
        settings.remoteEndpoint = "https://memory.example.com"
        let resolved = resolver().resolve(settings: settings)
        #expect(resolved?.backend == .remoteService)
        #expect(resolved?.provider.slug == MemoryBackendResolver.remoteSlug)
        #expect(resolved?.matchesSelection == true)
    }

    @Test("a remote selection without an endpoint falls back loudly")
    func remoteWithoutEndpointFallsBackLoudly() {
        var settings = MemorySettings()
        settings.backend = .remoteService
        settings.remoteEndpoint = ""
        let resolved = resolver().resolve(settings: settings)
        #expect(resolved?.backend == .localMarkdown)
        #expect(resolved?.matchesSelection == false)
        #expect(resolved?.substitutedReason == .remoteNotConfigured)
        #expect(resolved?.substitutedReason?.explanation.contains("设置") == true,
                "the explanation must point at the setting that fixes it")
    }

    @Test("a remote selection without a provider falls back loudly")
    func remoteWithoutProviderFallsBack() {
        let resolver = MemoryBackendResolver(
            providers: [StubProvider(slug: MemoryBackendResolver.localSlug)]
        )
        var settings = MemorySettings()
        settings.backend = .remoteService
        settings.remoteEndpoint = "https://memory.example.com"
        let resolved = resolver.resolve(settings: settings)
        #expect(resolved?.backend == .localMarkdown)
        #expect(resolved?.substitutedReason == .remoteNotConfigured)
    }

    @Test("an unwritable local folder is reported rather than swallowed")
    func unwritableLocalFolderIsReported() {
        let resolved = resolver(writable: false).resolve(settings: MemorySettings())
        #expect(resolved?.backend == .localMarkdown)
        #expect(resolved?.substitutedReason == .localDirectoryUnavailable("Memory"))
        #expect(resolved?.substitutedReason?.explanation.contains("Memory") == true)
    }

    @Test("every problem explains itself in product language")
    func problemsExplainThemselves() {
        let problems: [MemoryBackendProblem] = [
            .remoteNotConfigured,
            .remoteMissingCredential,
            .localDirectoryUnavailable("记忆")
        ]
        for problem in problems {
            let text = problem.explanation
            #expect(!text.isEmpty)
            #expect(text.count > 20, "a bare enum name is not an explanation")
            #expect(!text.contains("backend"), "user-facing text, not type names")
            #expect(!text.contains("nil"))
        }
    }

    @Test("both backends describe what picking them costs")
    func backendsDescribeThemselves() {
        let local = MemoryBackendResolver.description(for: .localMarkdown)
        #expect(local.title.contains("本地"))
        #expect(local.detail.contains("不用配置") || local.detail.contains("不需要配置"))

        let remote = MemoryBackendResolver.description(for: .remoteService)
        #expect(remote.title.contains("云端"))
        #expect(remote.detail.contains("密钥"), "the cost must be stated up front")
        #expect(remote.detail.contains("离开") || remote.detail.contains("联网"),
                "that memory leaves the machine is the part a user must know")
    }

    @Test("resolution is nil only when there is no provider at all")
    func noProvidersResolvesToNil() {
        let empty = MemoryBackendResolver(providers: [])
        #expect(empty.resolve(settings: MemorySettings()) == nil)
    }

    @Test("the resolved value compares on identity, not on provider instance")
    func resolutionComparesOnSlug() {
        let resolved = resolver().resolve(settings: MemorySettings())
        let other = resolver().resolve(settings: MemorySettings())
        #expect(resolved == other, "two resolutions of the same selection are equal")
    }
}