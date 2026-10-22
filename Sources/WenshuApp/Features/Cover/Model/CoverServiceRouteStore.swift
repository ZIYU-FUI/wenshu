//
//  Features/Cover/Model/CoverServiceRouteStore.swift
//
//   : CoverServiceRouteStore.
//  Where the two cover routes live between launches.
//
//  Both routes live in the same store, so the cover feature owns all
//  its settings in one place and the settings pane has a single
//  thing to read.
//
//  The routes are stored as JSON in UserDefaults, the same store and
//  the same shape the neighbouring agent settings use
//  (= Features/Settings/Service/AgentSettingsStore.swift): a
//  defaults suite passed in, so a test never touches the real user
//  defaults, and one JSON payload per key.
//
//  The API key is stored here rather than in the shared provider
//  keychain, because a cover route can name a provider the app does
//  not know about, and the route's key belongs to the route. The
//  key never goes into a SwiftData row and never into a log.
//

import Foundation

/// Persists the two cover service routes.
struct CoverServiceRouteStore {

    /// The defaults suite the store reads and writes. Injectable so a
    /// test never touches the real user defaults.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The defaults key for the image route.
    static let imageKey = "wenshu.cover.route.image"
    /// The defaults key for the video route.
    static let videoKey = "wenshu.cover.route.video"

    /// The route for one service.
    func route(for kind: CoverServiceKind) -> CoverServiceRoute {
        guard let data = defaults.data(forKey: Self.key(for: kind)),
              let decoded = try? JSONDecoder().decode(CoverServiceRoute.self, from: data) else {
            return CoverServiceRoute(kind: kind)
        }
        return decoded
    }

    /// Stores a route.
    func set(_ route: CoverServiceRoute) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        defaults.set(data, forKey: Self.key(for: route.kind))
    }

    /// The image route.
    var imageRoute: CoverServiceRoute {
        get { route(for: .image) }
        nonmutating set { set(newValue) }
    }

    /// The video route.
    var videoRoute: CoverServiceRoute {
        get { route(for: .video) }
        nonmutating set { set(newValue) }
    }

    /// The defaults key for a kind.
    static func key(for kind: CoverServiceKind) -> String {
        switch kind {
        case .image: return imageKey
        case .video: return videoKey
        }
    }
}
