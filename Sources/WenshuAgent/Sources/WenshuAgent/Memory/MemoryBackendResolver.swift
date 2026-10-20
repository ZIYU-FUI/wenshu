// MemoryBackendResolver.swift
//
// Choosing between the two memory backends a user can pick from (= the
// MemoryBackend case added in AgentSettings, see OOB.md #2026-10-20).
//
// The choice is a user decision, not ours, and the two options answer
// different questions:
//
//   localMarkdown  memory lives in the user's library as plain text. They can
//                  read it, edit it, grep it, and it never leaves the machine.
//                  Nothing to configure.
//   remoteService  memory is hosted elsewhere with stronger semantic
//                  retrieval. It needs an endpoint and a key, and the user
//                  should know that before they pick it.
//
// The resolver exists because picking a backend and having it work are
// different problems. A selection that cannot be honoured has to say so
// rather than silently falling back: a user who chose the service because it
// retrieves better must not silently get local files.
//
// Local is the default because it needs nothing. That is a default, not a
// preference (= AgentSettings.MemorySettings).

import Foundation

/// Why the selected backend could not be used.
public enum MemoryBackendProblem: Sendable, Equatable {
    /// The chosen service has no endpoint.
    case remoteNotConfigured
    /// The chosen service has an endpoint but no credential.
    case remoteMissingCredential
    /// The chosen local folder does not exist and cannot be created.
    case localDirectoryUnavailable(String)

    /// User-facing explanation. Written for someone who did not choose the
    /// word "backend".
    public var explanation: String {
        switch self {
        case .remoteNotConfigured:
            return """
            选了云端记忆，但还没有填地址。到「设置 - 记忆」里填上服务地址就能用。
            在那之前先用本地的 Markdown 记忆，它不需要任何配置。
            """
        case .remoteMissingCredential:
            return """
            选了云端记忆，但还没有填密钥。到「设置 - 记忆」里填上就能用。
            在那之前先用本地的 Markdown 记忆，它不需要任何配置。
            """
        case .localDirectoryUnavailable(let folder):
            return """
            本地记忆要用「\(folder)」这个文件夹，但它建不出来。
            检查一下资料库的写入权限，或者在「设置 - 记忆」里换一个文件夹名。
            """
        }
    }
}

/// The backend actually in use, plus why if it is not the chosen one.
public struct ResolvedMemoryBackend: Sendable, Equatable {
    public let backend: MemoryBackend
    public let provider: any MemoryProvider
    /// Set when the resolved backend differs from the chosen one.
    public let substitutedReason: MemoryBackendProblem?

    public init(
        backend: MemoryBackend,
        provider: any MemoryProvider,
        substitutedReason: MemoryBackendProblem? = nil
    ) {
        self.backend = backend
        self.provider = provider
        self.substitutedReason = substitutedReason
    }

    /// Whether the user got what they picked.
    public var matchesSelection: Bool { substitutedReason == nil }

    /// The provider chosen in settings is honoured when this holds.
    public static func == (lhs: ResolvedMemoryBackend, rhs: ResolvedMemoryBackend) -> Bool {
        lhs.backend == rhs.backend
            && lhs.provider.slug == rhs.provider.slug
            && lhs.substitutedReason == rhs.substitutedReason
    }
}

/// Turns a selection plus the available providers into one usable provider.
public struct MemoryBackendResolver: Sendable {
    /// Every backend the app can construct.
    public var providers: [any MemoryProvider]
    /// Whether the local folder can be written.
    public var localDirectoryWritable: @Sendable (String) -> Bool

    public init(
        providers: [any MemoryProvider],
        localDirectoryWritable: @escaping @Sendable (String) -> Bool = { _ in true }
    ) {
        self.providers = providers
        self.localDirectoryWritable = localDirectoryWritable
    }

    /// Resolve the user's choice.
    ///
    /// The fallback is deliberate and loud: a backend that cannot run is
    /// replaced by local memory and the reason travels with the result, so
    /// the settings screen can explain it. The alternative, honouring the
    /// selection and failing at the first turn, is worse for the user than
    /// working memory plus an explanation.
    public func resolve(settings: MemorySettings) -> ResolvedMemoryBackend? {
        let local = providers.first { $0.slug == MemoryBackendResolver.localSlug }
        guard let local else { return nil }

        switch settings.backend {
        case .localMarkdown:
            guard localDirectoryWritable(settings.localDirectory) else {
                // No usable backend at all: still hand back local so the turn
                // can run, but record why it may not persist.
                return ResolvedMemoryBackend(
                    backend: .localMarkdown,
                    provider: local,
                    substitutedReason: .localDirectoryUnavailable(settings.localDirectory)
                )
            }
            return ResolvedMemoryBackend(backend: .localMarkdown, provider: local)

        case .remoteService:
            let remote = providers.first { $0.slug == MemoryBackendResolver.remoteSlug }
            guard let remote else {
                return ResolvedMemoryBackend(
                    backend: .localMarkdown,
                    provider: local,
                    substitutedReason: .remoteNotConfigured
                )
            }
            guard !settings.remoteEndpoint.isEmpty else {
                return ResolvedMemoryBackend(
                    backend: .localMarkdown,
                    provider: local,
                    substitutedReason: .remoteNotConfigured
                )
            }
            return ResolvedMemoryBackend(backend: .remoteService, provider: remote)
        }
    }

    /// Slug for the local backend. Stable because it is stored in settings and
    /// in the keychain.
    public static let localSlug = "swiftdata-memory"

    /// Slug for a hosted backend.
    public static let remoteSlug = "remote-memory"

    /// What to show for a backend in settings: title plus the line that tells
    /// a user what picking it costs them.
    public static func description(for backend: MemoryBackend) -> (title: String, detail: String) {
        switch backend {
        case .localMarkdown:
            return (
                "本地 Markdown",
                "记忆存在你的资料库里，纯文本。不用配置，不联网，你能自己打开看、自己改。"
            )
        case .remoteService:
            return (
                "云端记忆",
                "记忆交给外部服务托管，找回来的东西更贴近意思。需要填服务地址和密钥，记忆会离开这台电脑。"
            )
        }
    }
}