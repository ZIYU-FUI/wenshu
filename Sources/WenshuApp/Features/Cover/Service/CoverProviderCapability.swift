//
//  Features/Cover/Service/CoverProviderCapability.swift
//
//   : CoverProviderCapability.
//  Which services can actually make a cover.
//
//  The cover feature calls two endpoints, and they speak ONE
//  protocol: the MiniMax image and video protocol (a body of
//  model / prompt / width / height / n / response_format, and an
//  answer of base_resp.status_code with the bytes in
//  data.image_base64). So "can this service make a cover" is not
//  "does this company have an image API" — it is "can we speak to
//  it".
//
//  That is why the answer is a table and not a guess:
//
//  - a route the user configured themselves is THEIRS. The app
//    calls it and reports what it says. The app does not second-guess
//    a service the user pointed at.
//  - an AUTO route means "use the app's current provider". A chat
//    provider cannot make a picture, so for those the cover cannot
//    be made, and the user has to be told why in words they can act
//    on, instead of a cover that silently never appears.
//
//  The facts behind the table (each checked against that provider's
//  own API on 2026-10-23):
//
//  - MiniMax publishes an image endpoint (image-01) and a video
//    endpoint (Hailuo), both on the protocol above. Both of the
//    app's MiniMax slugs point at the same service.
//  - OpenRouter, Gemini and StepFun publish image APIs of their
//    own, and they speak their own protocols. The cover feature
//    cannot call them, so they need a route the user configured.
//  - Anthropic, DeepSeek, Nous, the Codex and Copilot connectors and
//    the xAI OAuth connector are chat services. None of them can
//    make a picture through any route.
//  - Ollama runs locally and has no quota of any kind. It can
//    serve images, but only through a route the user configured.
//  - A custom endpoint is the user's own service: it is called, and
//    whatever it says is reported.
//

import Foundation
import WenshuAgent

/// Which services can make a cover.
enum CoverProviderCapability {

    /// The providers whose own service speaks the cover protocol.
    ///
    /// = the two MiniMax slugs. They are the same service with two
    /// hosts (one for the international account, one for the
    /// mainland one), so they answer to the same rules.
    static let nativeImageProviders: Set<String> = ["minimax", "minimax-cn"]

    /// The providers that are chat services.
    ///
    /// They cannot make a picture or a clip through any route, so a
    /// cover built on one of them cannot be built at all.
    static let chatOnlyProviders: Set<String> = [
        "anthropic",
        "deepseek",
        "nous",
        "openai-codex",
        "copilot",
        "copilot-acp",
        "xai-oauth",
    ]

    /// Whether a provider can serve a kind of cover on its own.
    ///
    /// - Parameters:
    ///   - providerSlug: the provider the route names.
    ///   - kind: the kind of cover (= a picture or a clip).
    static func supports(providerSlug: String, kind: CoverServiceKind) -> Bool {
        let slug = providerSlug.lowercased()
        if nativeImageProviders.contains(slug) {
            return true
        }
        if chatOnlyProviders.contains(slug) {
            return false
        }
        // Everything else (OpenRouter, Gemini, StepFun, Ollama, a
        // custom endpoint) has an image API of its own, but not one
        // the cover feature can speak. A route the user configured
        // for them is the way in, and that route is not this
        // function's business.
        return false
    }

    /// The message the user gets when the cover cannot be made.
    ///
    /// It names the provider, says what is missing, and says where
    /// to put it. A cover that never appears and never says why is
    /// the failure this message exists to prevent.
    static func unsupportedMessage(providerSlug: String, kind: CoverServiceKind) -> String {
        let providerName = Provider.by(slug: providerSlug)?.name ?? providerSlug
        let what = kind == .image ? "a picture" : "a clip"
        return """
            A cover needs a service that generates \(what), and \(providerName) only \
            generates text. Configure a dedicated \(kind == .image ? "image" : "video") service \
            for covers in Settings, or point the app's provider at one that can.
            """
    }

    /// The hosts that serve the cover protocol.
    ///
    /// The cover endpoints are MiniMax's own (= the international
    /// account and the mainland one). A route that names an endpoint
    /// of its own is the user's own service and is called as it is,
    /// but the app still sends it a cover-protocol request, so the
    /// settings say so when the endpoint does not look like a cover
    /// endpoint.
    static let coverProtocolHosts: Set<String> = [
        "api.minimaxi.com",
        "api.minimax.io",
    ]

    /// Whether an endpoint of the user's own looks like a cover
    /// endpoint.
    ///
    /// It is a HOST check and not a block: a proxy of the user's own
    /// can perfectly well speak the cover protocol on another host.
    /// So this answers "is this worth mentioning", not "may we call
    /// it".
    ///
    /// - Parameter baseURL: the endpoint the route names, if any.
    /// - Returns: true when the endpoint is a cover endpoint, or when
    ///   the route names none (= the app's own endpoint is a cover
    ///   one).
    static func speaksCoverProtocol(baseURL: String?) -> Bool {
        guard let baseURL, let host = URL(string: baseURL)?.host else { return true }
        return coverProtocolHosts.contains(host.lowercased())
    }

    /// The message the user gets when no service is configured at all.
    static let noServiceMessage = """
        A cover needs a service that generates pictures. Add an image service in Settings, \
        or use a provider that generates them.
        """
}
