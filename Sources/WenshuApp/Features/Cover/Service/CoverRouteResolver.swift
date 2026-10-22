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
    /// - Throws: `CoverRouteError.notConfigured` when the VIDEO kind
    ///   has nothing to resolve to.
    static func resolve(
        _ route: CoverServiceRoute,
        currentProviderSlug: String?
    ) throws -> ResolvedCoverService {
        // 1. An explicit route wins: its provider, and its model if
        //    it names one.
        if let providerSlug = route.providerSlug, !providerSlug.isEmpty {
            guard let model = route.model ?? route.kind.defaultModel else {
                throw CoverRouteError.notConfigured(kind: route.kind)
            }
            let baseURL = route.baseURL ?? route.kind.defaultEndpoint
            return ResolvedCoverService(
                providerSlug: providerSlug,
                model: model,
                baseURL: baseURL,
                apiKey: route.apiKey
            )
        }

        // 2. An auto route inherits the app's current provider, and
        //    takes the model from its kind.
        if let currentProviderSlug, !currentProviderSlug.isEmpty {
            guard let model = route.kind.defaultModel else {
                throw CoverRouteError.notConfigured(kind: route.kind)
            }
            return ResolvedCoverService(
                providerSlug: currentProviderSlug,
                model: model,
                baseURL: route.kind.defaultEndpoint,
                apiKey: route.apiKey
            )
        }

        // 3. Nothing is configured. The image kind has a default; the
        //    video kind does not, because its quota is scarce.
        guard let model = route.kind.defaultModel else {
            throw CoverRouteError.notConfigured(kind: route.kind)
        }
        return ResolvedCoverService(
            providerSlug: CoverImageGenerator.providerSlug,
            model: model,
            baseURL: route.kind.defaultEndpoint,
            apiKey: route.apiKey
        )
    }
}

/// The failures the resolver can raise.
enum CoverRouteError: LocalizedError {
    /// The route names a service that is not configured, and the kind
    /// has no default to fall back to.
    case notConfigured(kind: CoverServiceKind)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let kind):
            switch kind {
            case .image:
                return "The image service is not configured."
            case .video:
                return "The video service is not configured. Choose a video provider and model in Settings before making a moving cover."
            }
        }
    }
}
