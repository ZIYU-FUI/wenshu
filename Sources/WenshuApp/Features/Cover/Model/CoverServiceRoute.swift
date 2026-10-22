//
//  Features/Cover/Model/CoverServiceRoute.swift
//
//   : CoverServiceRoute.
//  Where the cover art is drawn, as ONE unit.
//
//  The four fields (provider, model, base URL, key) are stored and
//  resolved TOGETHER, and that is the whole point of this type. A
//  route that names one provider and another provider's base URL is
//  nonsense, and a type with four independent optionals would let it
//  exist. So the fields are private-ish behind an initializer that
//  takes them all, and every mutation replaces them all.
//
//  The model to copy is the Hermes auxiliary-model routing, whose
//  route keys are likewise an atomic group
//  (= agent/auxiliary_task_config.py, the _AUX_ROUTE_KEYS list) and
//  whose settings UI resets a task back to "auto" as one action.
//
//  "auto" means INHERIT: the route's fields are all nil, and the
//  resolver falls back to whatever the app is currently using. That
//  is the state a user is in before they have configured anything, and
//  it is why the route is nil-shaped rather than a flag.
//
//  The four fields are immutable, so `replacing(...)` is the ONLY way
//  to change one. A settable field would let a caller name a new
//  provider and leave the old endpoint behind, which is exactly the
//  broken route this type exists to make unconstructible.
//

import Foundation

/// Where one cover service draws, as an atomic group of four fields.
struct CoverServiceRoute: Codable, Equatable, Sendable {

    /// The provider slug (= "minimax-cn"), or nil for auto.
    let providerSlug: String?
    /// The model id, or nil for auto.
    let model: String?
    /// The service's base URL, or nil for auto.
    let baseURL: String?
    /// The service's API key, or nil for auto.
    let apiKey: String?

    /// The route that inherits whatever the app is currently using.
    static func auto(for kind: CoverServiceKind) -> CoverServiceRoute {
        CoverServiceRoute(kind: kind)
    }

    /// Whether this route inherits.
    var isAuto: Bool {
        providerSlug == nil && model == nil && baseURL == nil && apiKey == nil
    }

    /// The service this route points at.
    let kind: CoverServiceKind

    init(
        kind: CoverServiceKind,
        providerSlug: String? = nil,
        model: String? = nil,
        baseURL: String? = nil,
        apiKey: String? = nil
    ) {
        self.kind = kind
        self.providerSlug = providerSlug
        self.model = model
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    /// Replaces every field at once.
    ///
    /// There is deliberately no way to change ONE field: a route
    /// whose provider changed but whose base URL did not is a broken
    /// route, and the only way to prevent it is to not offer the
    /// operation. The settings UI calls this with all four values,
    /// so changing the provider clears the model, the base URL and
    /// the key, because they belonged to the old provider.
    func replacing(
        providerSlug: String?,
        model: String?,
        baseURL: String?,
        apiKey: String?
    ) -> CoverServiceRoute {
        CoverServiceRoute(
            kind: kind,
            providerSlug: providerSlug,
            model: model,
            baseURL: baseURL,
            apiKey: apiKey
        )
    }

    /// The route that inherits.
    func resetting() -> CoverServiceRoute {
        CoverServiceRoute(kind: kind)
    }
}
