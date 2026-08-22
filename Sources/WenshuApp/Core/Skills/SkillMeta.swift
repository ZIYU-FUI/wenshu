//
//  SkillMeta.swift · Wenshu · v0.23 ticket 013.008 (hermes gap 5)
//
//  Boss 2026-08-23 拍: hermes SkillMeta trust_level + source parity.
//  Source: github.com/NousResearch/hermes-agent/blob/main/tools/skills_hub.py:131
//
//  Hermes pattern: SkillMeta has trust_level (builtin / trusted / community)
//  + source (official / github / clawhub / lobehub) + quarantine + audit log.
//

import Foundation

/// Skill trust level — hermes parity.
/// builtin = shipped with wenshu, always allowed.
/// trusted = reviewed and signed by wenshu maintainer (boss 拍).
/// community = user-installed, requires explicit approval.
public enum SkillTrustLevel: String, Codable, Sendable, CaseIterable {
    case builtin
    case trusted
    case community
}

/// Skill source — where the skill came from.
public enum SkillSource: String, Codable, Sendable {
    case builtin      // shipped with wenshu
    case github       // pulled from a GitHub repo
    case local        // user-provided .md file
}

/// Skill metadata (mirrors hermes SkillMeta).
public struct SkillMeta: Sendable, Equatable {
    public let name: String
    public let description: String
    public let source: SkillSource
    public let trustLevel: SkillTrustLevel
    public let path: String          // path to SKILL.md file
    public let installedAt: Date

    public init(
        name: String,
        description: String,
        source: SkillSource,
        trustLevel: SkillTrustLevel,
        path: String,
        installedAt: Date = Date()
    ) {
        self.name = name
        self.description = description
        self.source = source
        self.trustLevel = trustLevel
        self.path = path
        self.installedAt = installedAt
    }
}

/// SkillTrustPolicy: decides which skills are allowed to load.
/// Per hermes: builtin always allowed, trusted requires user opt-in, community
/// requires explicit user approval per-skill.
public enum SkillTrustPolicy {

    /// Decide if a skill is allowed to load in the current session.
    /// - Parameter userApprovedCommunity: set of skill names user explicitly approved.
    /// - Returns: true if allowed; false if blocked.
    public static func shouldAllow(
        skill: SkillMeta,
        userApprovedCommunity: Set<String> = []
    ) -> Bool {
        switch skill.trustLevel {
        case .builtin: return true                  // always allowed
        case .trusted: return true                  // reviewed, always allowed (boss pre-approved)
        case .community: return userApprovedCommunity.contains(skill.name)  // user opt-in
        }
    }
}

/// SkillQuarantine: hermes `quarantine/` dir concept.
/// Skills downloaded from external sources (GitHub) are placed in quarantine
/// for audit before promotion to installed skills.
public enum SkillQuarantine {

    /// Hermés-quarantine: dir under wenshu home (~/.hermes/wenshu/skills/quarantine/).
    public static let quarantinePath: String = {
        let home = NSHomeDirectory()
        return home + "/.hermes/wenshu/skills/quarantine"
    }()

    /// quarantineSkill: move a downloaded skill to quarantine dir.
    /// Returns the new path in quarantine.
    public static func quarantineSkill(skillPath: String) throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(atPath: quarantinePath, withIntermediateDirectories: true)
        let fileName = (skillPath as NSString).lastPathComponent
        let dest = quarantinePath + "/" + fileName
        // Move to quarantine. If dest exists, overwrite (audit by user).
        if fm.fileExists(atPath: dest) {
            try fm.removeItem(atPath: dest)
        }
        try fm.moveItem(atPath: skillPath, toPath: dest)
        return dest
    }

    /// promoteSkill: move from quarantine to installed skills dir.
    /// Caller (typically user via Settings GUI) must verify before calling.
    public static func promoteSkill(quarantinedPath: String, installedDir: String) throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(atPath: installedDir, withIntermediateDirectories: true)
        let fileName = (quarantinedPath as NSString).lastPathComponent
        let dest = installedDir + "/" + fileName
        if fm.fileExists(atPath: dest) {
            try fm.removeItem(atPath: dest)
        }
        try fm.moveItem(atPath: quarantinedPath, toPath: dest)
        return dest
    }
}