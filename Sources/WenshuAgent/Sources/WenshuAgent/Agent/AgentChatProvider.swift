//
//  AgentChatProvider.swift · Wenshu · agent runtime boundary
//
//  The seam that lets the runtime call the app's canonical chat
//  entry point without naming an app type.
//
//  The verifier probes the agent the way the app's own chat surface
//  does: one message in, one reply out. The app owns the wiring
//  (= the installed conductor, the provider key, the model), so the
//  runtime declares the contract and the app fills it.
//

/// What one chat call produced.
public struct AgentChatOutcome: Sendable {
    /// The assistant's reply text.
    public let reply: String
    /// The tokens the provider counted for the call.
    public let totalTokens: Int
    /// The model's reasoning trace, when the provider returned one.
    public let thinking: String?

    public init(reply: String, totalTokens: Int, thinking: String?) {
        self.reply = reply
        self.totalTokens = totalTokens
        self.thinking = thinking
    }
}

/// The chat entry point the runtime probes.
///
/// The app installs the implementation. The runtime never names an
/// app type, so the conductor, the provider key and the model choice
/// stay on the app side of the boundary.
public protocol AgentChatProvider: Sendable {
    /// The model identifier this provider routes with.
    var modelIdentifier: String { get }

    /// Runs one chat turn.
    ///
    /// Returns nil when no agent is installed (= the caller surfaces
    /// that as a failure instead of faking a reply).
    func chat(userMessage: String, sessionId: String, model: String) async -> AgentChatOutcome?
}

/// The installed provider slot.
///
/// The app fills this once at launch; the runtime reads it when the
/// verifier probes the agent.
public enum AgentChatProviders {
    public nonisolated(unsafe) static var current: (any AgentChatProvider)?
}
