//
//  ProviderEndpointOverrides.swift · Wenshu
//
//  The custom endpoint a user typed for a provider.
//
//  The provider list is a curated enum whose endpoints are compile-time
//  constants (= `Provider.defaultBaseURL`). A user whose gateway lives at
//  their own address had no way to point Wenshu at it: the endpoint was
//  chosen in one factory and the factory had no input for it.
//
//  This holder is that input. The app installs the user's values here; the
//  connector credentials factory reads them. It lives in the package (= the
//  package owns the values, the app owns where they are stored), and it
//  follows the same install-at-the-edge pattern as `ProviderKeychain.backend`.
//
//  Why a holder and not a parameter: the credentials factory is called from
//  every connector's send and stream path, so a parameter would have to
//  reach fifteen call sites in seven files. A holder reaches one.
//

import Foundation

/// Per-provider custom endpoints, installed by the app.
///
/// Thread-safe by construction: the map is replaced wholesale, never
/// mutated in place, so a reader always sees a consistent snapshot.
public enum ProviderEndpointOverrides {

    /// The user's custom endpoints, keyed by provider slug.
    ///
    /// An entry is either absent or empty (= the provider's own default
    /// endpoint applies). Never read `UserDefaults` from here (= the app
    /// installs the values; = the package owns no storage).
    public nonisolated(unsafe) static var baseURLs: [String: String] = [:]

    /// The endpoint to use for a provider.
    ///
    /// The override wins when it is a usable URL; otherwise the provider's
    /// own default applies. A stored value that cannot be parsed, or that
    /// names no host, is ignored rather than handed to a connector (= a
    /// broken endpoint would fail every call, and the provider default
    /// still works).
    public static func baseURL(for provider: Provider) -> String {
        let stored = baseURLs[provider.slug]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stored, !stored.isEmpty else { return provider.defaultBaseURL }
        guard let url = URL(string: stored), let host = url.host, !host.isEmpty else {
            return provider.defaultBaseURL
        }
        return stored
    }
}
