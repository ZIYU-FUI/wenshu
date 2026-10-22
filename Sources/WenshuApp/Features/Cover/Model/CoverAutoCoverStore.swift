//
//  Features/Cover/Model/CoverAutoCoverStore.swift
//
//   : CoverAutoCoverStore.
//  Where the automatic-cover switch and its timestamp live.
//
//  The switch and the timestamp belong together: the timestamp is the
//  moment the switch was turned on, and it is what separates the
//  documents that were already in the library from the ones that
//  arrive later.
//
//  The store sits beside the route store, so the cover feature owns
//  all of its settings in one place.
//

import Foundation

/// Persists the automatic-cover switch and the moment it was turned
/// on.
struct CoverAutoCoverStore {

    /// The defaults suite the store reads and writes.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The defaults key for the switch.
    static let enabledKey = "wenshu.cover.auto.enabled"
    /// The defaults key for the moment the switch was turned on.
    static let enabledAtKey = "wenshu.cover.auto.enabledAt"

    /// The stored policy.
    var policy: CoverAutoCoverPolicy {
        get {
            let isEnabled = defaults.bool(forKey: Self.enabledKey)
            let enabledAt = defaults.object(forKey: Self.enabledAtKey) as? Date
            return CoverAutoCoverPolicy(isEnabled: isEnabled, enabledAt: enabledAt)
        }
        nonmutating set {
            defaults.set(newValue.isEnabled, forKey: Self.enabledKey)
            if let enabledAt = newValue.enabledAt {
                defaults.set(enabledAt, forKey: Self.enabledAtKey)
            } else {
                defaults.removeObject(forKey: Self.enabledAtKey)
            }
        }
    }

    /// Turns the switch on, stamped now.
    func enable(at now: Date = .now) {
        policy = .enabling(at: now)
    }

    /// Turns the switch off.
    func disable() {
        policy = .disabled
    }
}
