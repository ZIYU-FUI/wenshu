// PromptCacheRecorder.swift
//
// The prompt cache, measured.
//
// Three things live here:
//   1. The policy: which route and model can carry a cache marker, and
//      which TTL tier the marker asks for.
//   2. The recorder: a running total per conversation of the tokens the
//      provider served from its cache, the tokens it wrote into it, and
//      the input those cached tokens kept out of the bill.
//   3. The stream collector: the counters a provider sends inside its
//      stream events, gathered while the stream is being decoded.
//
// The recorder is fed from the running turn, so the number is available
// while the conversation runs and without a restart.

import Foundation

/// Cache policy: who can carry a marker, and for how long.
public enum PromptCachePolicy {

    /// The TTL tiers a provider accepts for a cache marker.
    public enum TTL: String, Sendable, CaseIterable {
        case short = "5m"
        case long = "1h"
        /// Resolved by the caller: a human-paced session keeps the prefix
        /// alive long enough to be read again, a machine-paced one does not.
        case auto
    }

    /// Who paces the session. The tier follows the pace: a person typing
    /// into the app comes back after minutes, a sub-agent or a batch job
    /// comes back after milliseconds.
    public enum Source: Sendable, Equatable {
        case interactive
        case machinePaced
    }

    /// The tier the setting resolves to for a given source.
    ///
    /// An unknown value keeps the short tier: the provider holds the
    /// prefix for five minutes either way, and the short tier is the
    /// cheaper write.
    public static func effectiveTTL(_ requested: TTL, source: Source) -> String {
        switch requested {
        case .short: return TTL.short.rawValue
        case .long: return TTL.long.rawValue
        case .auto: return source == .interactive ? TTL.long.rawValue : TTL.short.rawValue
        }
    }

    /// The cache_control marker for a TTL tier.
    ///
    /// The shape matches the one the Anthropic and MiniMax builders
    /// already send: an ephemeral marker, plus the tier key when the
    /// provider is asked to hold the prefix for the long tier.
    public static func marker(ttl: String) -> [String: String] {
        var dict: [String: String] = ["type": "ephemeral"]
        if ttl == TTL.long.rawValue {
            dict["ttl"] = TTL.long.rawValue
        }
        return dict
    }

    /// Whether the OpenAI-compatible wire of this route can carry a cache
    /// marker.
    ///
    /// The marker rides on the message envelope, and two facts decide
    /// whether it is sent. Neither is the provider's name:
    ///   - The route must be one whose wire accepts the Anthropic-style
    ///     envelope marker: a router that fronts several upstreams.
    ///   - The model must be one whose family honours the marker. The
    ///     same router serves a model that caches and a model that does
    ///     not, so the model decides.
    public static func carriesEnvelopeMarker(providerSlug: String, model: String) -> Bool {
        guard isEnvelopeMarkerRoute(providerSlug) else { return false }
        return isCacheCapableFamily(model)
    }

    /// The marker for a route and model, or nil when the wire cannot
    /// carry one.
    ///
    /// A provider whose wire has no cache field gets no marker, so it
    /// never pretends to cache.
    public static func marker(
        providerSlug: String,
        model: String,
        ttl: String
    ) -> [String: String]? {
        guard carriesEnvelopeMarker(providerSlug: providerSlug, model: model) else { return nil }
        var dict: [String: String] = ["type": "ephemeral"]
        if ttl == TTL.long.rawValue {
            dict["ttl"] = TTL.long.rawValue
        }
        return dict
    }

    /// The routes whose OpenAI-compatible wire accepts the Anthropic-style
    /// envelope marker.
    ///
    /// A router accepts it because it forwards to an upstream that speaks
    /// it. A first-party endpoint does not: it either has no cache field
    /// or caches on its own terms, and a local model caches by its own
    /// key-value reuse rather than by a marker on the wire.
    private static func isEnvelopeMarkerRoute(_ providerSlug: String) -> Bool {
        let slug = providerSlug.lowercased()
        return slug == "openrouter" || slug == "nous"
    }

    /// Whether the model is one whose family honours the marker.
    ///
    /// The model decides, not the provider: the same router serves a
    /// model that caches and a model that does not.
    private static func isCacheCapableFamily(_ model: String) -> Bool {
        let name = model.lowercased()
        return name.contains("claude") || name.contains("kimi") || name.contains("moonshot")
    }
}

/// The TTL setting the markers ask for.
///
/// The tier is the USER's choice and lives in the app's own defaults
/// (= the same store the other `wenshu.llm.*` settings use), so changing
/// it takes effect on the next request without a restart. The pace is a
/// property of the session being run (= a human at the app, or a
/// sub-agent), not of the user, so it is held in memory.
public final class PromptCacheTTLSetting: @unchecked Sendable {
    /// The defaults key that carries the tier (= "5m" / "1h" / "auto").
    ///
    /// The same key the app's settings surface writes, so the tier
    /// survives a restart and a change is picked up by the next request.
    public static let defaultsKey = "wenshu.llm.promptCacheTTL"

    private let lock = NSLock()
    private var storedSource: PromptCachePolicy.Source

    public init(source: PromptCachePolicy.Source = .interactive) {
        self.storedSource = source
    }

    /// The tier the user chose (= the stored tier, or `auto` when the
    /// user has not chosen one).
    public var ttl: PromptCachePolicy.TTL {
        lock.lock()
        defer { lock.unlock() }
        return Self.storedTier()
    }

    /// The tier as it is stored in the app's defaults.
    ///
    /// An absent or unrecognised value reads as `auto` (= the tier
    /// follows the pace of the session), so a defaults file written by a
    /// newer or older build never leaves the markers tierless.
    private static func storedTier() -> PromptCachePolicy.TTL {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else {
            return .auto
        }
        return PromptCachePolicy.TTL(rawValue: raw) ?? .auto
    }

    /// The pace of the session the tier is resolved against.
    public var source: PromptCachePolicy.Source {
        lock.lock()
        defer { lock.unlock() }
        return storedSource
    }

    /// The TTL tier this setting resolves to right now.
    ///
    /// The tier is read from the app's defaults at the moment the
    /// request is built, so a tier the user changes is picked up by the
    /// next request without a restart.
    public var effectiveTTL: String {
        lock.lock()
        defer { lock.unlock() }
        return PromptCachePolicy.effectiveTTL(Self.storedTier(), source: storedSource)
    }

    /// Set the tier (= the user's choice) and, optionally, the pace.
    ///
    /// The tier is written to the app's defaults, so it survives a
    /// restart and the app's settings surface can show it.
    public func set(_ newValue: PromptCachePolicy.TTL, source: PromptCachePolicy.Source? = nil) {
        UserDefaults.standard.set(newValue.rawValue, forKey: Self.defaultsKey)
        lock.lock()
        defer { lock.unlock() }
        if let source { storedSource = source }
    }
}

/// The TTL setting the request path reads.
public enum PromptCacheSettings {
    public static let ttl = PromptCacheTTLSetting()
}

/// The cache numbers for one conversation.
public struct PromptCacheTotals: Sendable, Equatable {
    /// Tokens the provider served from its cache.
    public var cacheReadTokens: Int
    /// Tokens the provider wrote into its cache.
    public var cacheCreationTokens: Int
    /// The input the cache kept out of the bill.
    ///
    /// A cached prefix is billed at roughly a quarter of the input rate,
    /// so the tokens read from the cache stand for the input that did not
    /// have to be paid for at full price.
    public var savedInputTokens: Int
    /// How many calls the totals cover.
    public var callCount: Int

    public init(
        cacheReadTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        savedInputTokens: Int = 0,
        callCount: Int = 0
    ) {
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.savedInputTokens = savedInputTokens
        self.callCount = callCount
    }
}

/// The running cache total, per conversation.
///
/// Fed from the turn path, so a long conversation reports what its cache
/// saved while it is still running.
public actor PromptCacheRecorder {
    public static let shared = PromptCacheRecorder()

    private var totalsByConversation: [String: PromptCacheTotals] = [:]
    /// The conversation that recorded last (= the one just spent tokens).
    private var mostRecentConversationId: String?

    public init() {}

    /// Fold one call's usage into the conversation's total.
    public func record(conversationId: String, usage: LLMUsage) {
        var totals = totalsByConversation[conversationId] ?? PromptCacheTotals()
        totals.cacheReadTokens += usage.cacheReadTokens
        totals.cacheCreationTokens += usage.cacheCreationTokens
        totals.savedInputTokens += usage.cacheReadTokens
        totals.callCount += 1
        totalsByConversation[conversationId] = totals
        mostRecentConversationId = conversationId
    }

    /// The total for one conversation (= zero when nothing was recorded).
    public func totals(conversationId: String) -> PromptCacheTotals {
        totalsByConversation[conversationId] ?? PromptCacheTotals()
    }

    /// The total of the most recently used conversation.
    ///
    /// The panel that shows the saving does not know which conversation
    /// the user is in (= the settings pane is not the chat), and the
    /// conversation that just spent the tokens is the one whose saving
    /// the user is asking about.
    public func mostRecentTotals() -> PromptCacheTotals {
        guard let last = mostRecentConversationId else { return PromptCacheTotals() }
        return totalsByConversation[last] ?? PromptCacheTotals()
    }
}

/// The counters a provider sent inside its stream events.
///
/// Providers split the counters across events: the input count and the
/// cache counts arrive first, the output count last. Each field keeps the
/// latest non-zero value it was given.
public final class StreamUsageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var latest = LLMUsage(inputTokens: 0, outputTokens: 0)

    public init() {}

    /// Merge the counters from one stream event.
    public func merge(_ incoming: LLMUsage) {
        lock.lock()
        defer { lock.unlock() }
        latest = LLMUsage(
            inputTokens: incoming.inputTokens > 0 ? incoming.inputTokens : latest.inputTokens,
            outputTokens: incoming.outputTokens > 0 ? incoming.outputTokens : latest.outputTokens,
            cacheReadTokens: incoming.cacheReadTokens > 0 ? incoming.cacheReadTokens : latest.cacheReadTokens,
            cacheCreationTokens: incoming.cacheCreationTokens > 0 ? incoming.cacheCreationTokens : latest.cacheCreationTokens
        )
    }

    /// The counters seen so far.
    public var usage: LLMUsage {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }
}

/// The collector the running turn reads its usage from.
///
/// The streaming decoders run inside their own tasks, so the collector
/// travels with the turn rather than with the caller.
public enum StreamUsageScope {
    @TaskLocal public static var collector: StreamUsageCollector?
}
