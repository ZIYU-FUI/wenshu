//
//  Persistence/WSSkill.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 6 of 21 @Model classes: WSSkill.
//  Mirrors `skills` table from WenshuWorkspace.swift (= v0.18 ticket 02
//  local Skills loader, replica of hermes skills_hub).
//
//  Trust levels (hermes-port parity):
//    - "trusted"        = bundled with wenshu or approved by user
//    - "experimental"  = installed from user-supplied source, not yet audited
//    - "blocked"        = explicitly disabled by user

import Foundation
import SwiftData

@Model
final class WSSkill {
    @Attribute(.unique) var name: String
    var skillDescription: String
    var source: String
    /// Trust level (= matches hermes skill_trust_level enum values)
    var trustLevel: String
    var path: String
    var installedAt: Date

    init(name: String, description: String, source: String, trustLevel: String, path: String) {
        self.name = name
        self.skillDescription = description
        self.source = source
        self.trustLevel = trustLevel
        self.path = path
        self.installedAt = Date()
    }
}
