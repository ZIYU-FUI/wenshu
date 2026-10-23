//
//  Features/Cover/Service/CoverRouteResolver.swift
//
//   : CoverRouteResolver.
//  Turns a route into the service the cover feature will call.
//
//  The ladder, in order, stopping at the first hit:
//
//  1. The route is NOT auto: use its provider, and its model if it
//     names one, else the KIND's default model. An explicit route
//     overrides everything.
//  2. The route IS auto: use the app's current PROVIDER (= the key,
//     the host, the quota), and the KIND's default model.
//  3. Nothing is configured at all:
//     - the IMAGE kind falls back to its default model, because the
//       image allowance is large and a cover with no service would
//       mean the feature does nothing;
//     - the VIDEO kind fails with an explicit "not configured" error,
//       because the video allowance is a handful of clips a day and a
//       silent default would spend a scarce quota the user never
//       asked to spend.
//
//  The MODEL always comes from the kind, never from the provider's
//  default model list. The provider profiles in this app describe
//  CHAT models, and an image service cannot be called with one: the
//  image endpoint answers "model not available" for a chat model.
//  So a route inherits the provider and takes the model from the
//  service it is routing to.
//
//  The KEY comes from the route when the route names one (a provider
//  the app does not know about carries its own key), and from the
//  app's current provider otherwise. It is passed IN rather than read
//  from the keychain here, because the resolver is a PURE function
//  of its inputs: no network, no clock, no disk, no keychain.
//
//  The resolver is a PURE function of its inputs: no network, no
//  clock, no disk. The "current provider" is passed IN, so the ladder
//  is testable without an app.
//

import Foundation
import WenshuAgent

/// The service a cover call will use.
struct ResolvedCoverService: Equatable, Sendable {
    /// The provider slug.
    let providerSlug: String
    /// The model id.
    let model: String
    /// The service's endpoint.
    let baseURL: String
    /// The API key.
    let apiKey: String?
}

/// Resolves a cover route into a service.
enum CoverRouteResolver {

    /// Resolves a route.
    ///
    /// - Parameters:
    ///   - route: the route to resolve.
    ///   - currentProviderSlug: the app's active provider slug, or nil
    ///     when the app has no provider configured.
    ///   - currentProviderKey: the key for that provider, or nil when
    ///     the app has no key for it.
    ///   - keyForProvider: reads the key of any provider. It is
    ///     injected so the resolver stays a pure function of its
    ///     inputs: no keychain, no network, no clock, no disk.
    /// - Throws: `CoverRouteError.notConfigured` when the VIDEO kind
    ///   has nothing to resolve to, `CoverRouteError
    ///   .providerCannotMakeCovers` when the route names a provider
    ///   that cannot make covers, and `CoverRouteError.noService`
    ///   when no service can be reached at all.
    static func resolve(
        _ route: CoverServiceRoute,
        currentProviderSlug: String? = nil,
        currentProviderKey: String? = nil,
        keyForProvider: @Sendable (String) -> String? = { slug in
            guard let provider = Provider.by(slug: slug) else { return nil }
            return ProviderKeychain.loadKeySync(for: provider)
        }
    ) throws -> ResolvedCoverService {
        // 1. An explicit route wins: it is the user's own service.
        //
        //    A route that names a provider the app cannot ask for
        //    covers, and does not name a service of its own, would be
        //    sent to the built-in endpoint, which that provider does
        //    not serve. That is refused HERE, with the message that
        //    says what to configure, so the switch does not pretend
        //    to work. A route that names its own base URL is the
        //    user's own service and is called as it is.
        if let providerSlug = route.providerSlug, !providerSlug.isEmpty {
            guard let model = route.model ?? route.kind.defaultModel else {
                throw CoverRouteError.notConfigured(kind: route.kind)
            }
            if route.baseURL == nil,
               !CoverProviderCapability.supports(providerSlug: providerSlug, kind: route.kind) {
                throw CoverRouteError.providerCannotMakeCovers(
                    providerSlug: providerSlug,
                    kind: route.kind
                )
            }
            // The endpoint belongs to the service (= to the
            // dialect), not to the kind: two services have two
            // different video endpoints, and a route that names a
            // provider must reach that provider's own endpoint.
            let baseURL = route.baseURL
                ?? CoverVideoDialectRegistry.dialect(for: route).defaultEndpoint
            let key = route.apiKey ?? keyForProvider(providerSlug)
            return ResolvedCoverService(
                providerSlug: providerSlug,
                model: model,
                baseURL: baseURL,
                apiKey: key
            )
        }

        // 2. An auto route means the built-in service for the kind.
        //
        //    NOT the app's chat provider. The cover endpoints draw
        //    pictures and clips; a chat key cannot pay for a picture,
        //    and a chat provider publishes no picture endpoint in the
        //    cover protocol. So the auto route names the service that
        //    can do the work, and the key comes from that service's
        //    own provider.
        //
        //    The video kind has no default model on purpose (its
        //    allowance is a handful of clips a day), so it never
        //    reaches here: a clip is always the user's own route.
        guard let model = route.kind.defaultModel else {
            throw CoverRouteError.notConfigured(kind: route.kind)
        }
        let providerSlug = route.kind.defaultProviderSlug
        guard let key = keyForProvider(providerSlug), !key.isEmpty else {
            throw CoverRouteError.noService(
                providerSlug: providerSlug,
                kind: route.kind
            )
        }
        return ResolvedCoverService(
            providerSlug: providerSlug,
            model: model,
            baseURL: CoverVideoDialectRegistry.dialect(for: route).defaultEndpoint,
            apiKey: key
        )
    }
}

/// The failures the resolver can raise.
enum CoverRouteError: LocalizedError {
    /// The route names a service that is not configured, and the kind
    /// has no default to fall back to.
    case notConfigured(kind: CoverServiceKind)

    /// The route names a provider that cannot make covers.
    case providerCannotMakeCovers(providerSlug: String, kind: CoverServiceKind)

    /// No service can be reached at all (= no key for the service
    /// that would do the work).
    case noService(providerSlug: String, kind: CoverServiceKind)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let kind):
            switch kind {
            case .image:
                return "The image service is not configured."
            case .video:
                return "The video service is not configured. Choose a video provider and model in Settings before making a moving cover."
            }
        case .providerCannotMakeCovers(let providerSlug, let kind):
            return CoverProviderCapability.unsupportedMessage(
                providerSlug: providerSlug,
                kind: kind
            )
        case .noService:
            return CoverProviderCapability.noServiceMessage
        }
    }
}
