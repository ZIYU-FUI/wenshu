//
//  SkillRegistry.swift · Wenshu · v0.18 ticket 02 (hermes replica)
//
// local Skills load (hermes skills_hub + GitHub).
// 2026-08-19 "" — hermes skills_hub, wenshu skill registry.
//
// hermes (skills_hub.py 35 do_*):
// - list() → [Skill]: Sources/WenshuCore/Skills/<name>/SKILL.md
// - load(name) → Skill?: SKILL.md + parse frontmatter
// - invoke(name, input) → String: skill (read only frontmatter + body, 35 do_* hub)
//
// SKILL.md format (frontmatter + body):
//  ---
//  name: skill-name
//  description: ...
//  ---
//
//  # body markdown
//

import Foundation

/// Skill frontmatter (YAML: SKILL.md file)
public struct SkillFrontmatter: Equatable, Sendable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

/// Skill: name + frontmatter + body + files (linked_files)
public struct Skill: Equatable, Sendable {
    public let name: String
    public let path: URL
    public let frontmatter: SkillFrontmatter
    public let body: String
    public let linkedFiles: [URL]

    public init(name: String, path: URL, frontmatter: SkillFrontmatter, body: String, linkedFiles: [URL]) {
        self.name = name
        self.path = path
        self.frontmatter = frontmatter
        self.body = body
        self.linkedFiles = linkedFiles
    }
}

/// SkillRegistry: + local SKILL.md file
public actor SkillRegistry {
    /// skill directory (default wenshu Sources/WenshuCore/Skills/, override testdirectory)
    private let rootDir: URL

    public init(rootDir: URL? = nil) {
        if let rootDir = rootDir {
            self.rootDir = rootDir
        } else {
            // default wenshu Skills directory. WENSHU_ROOT env (test), fallback cwd/Sources/WenshuCore/Skills
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let defaultPath = cwd.appendingPathComponent("Sources/WenshuCore/Skills", isDirectory: true)
            if let envRoot = ProcessInfo.processInfo.environment["WENSHU_ROOT"] {
                self.rootDir = URL(fileURLWithPath: envRoot).appendingPathComponent("Sources/WenshuCore/Skills", isDirectory: true)
            } else {
                self.rootDir = defaultPath
            }
        }
    }

    /// list: rootDir SKILL.md, return skill names
    public func list() throws -> [String] {
        guard FileManager.default.fileExists(atPath: rootDir.path) else { return [] }
        let contents = try FileManager.default.contentsOfDirectory(at: rootDir, includingPropertiesForKeys: [.isDirectoryKey])
        return contents.compactMap { entry -> String? in
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { return nil }
            let skillFile = entry.appendingPathComponent("SKILL.md")
            guard FileManager.default.fileExists(atPath: skillFile.path) else { return nil }
            return entry.lastPathComponent
        }.sorted()
    }

    /// load: 1 skill, parse frontmatter + body
    public func load(name: String) throws -> Skill? {
        let skillDir = rootDir.appendingPathComponent(name, isDirectory: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillFile.path) else { return nil }
        let raw = try String(contentsOf: skillFile, encoding: .utf8)
        let (frontmatter, body) = parseFrontmatter(raw)
        let linked = listLinkedFiles(skillDir: skillDir)
        return Skill(name: name, path: skillFile, frontmatter: frontmatter, body: body, linkedFiles: linked)
    }

    /// invoke: invoke (frontmatter + body, 35 do_* hub)
    public func invoke(name: String, input: String = "") throws -> String {
        guard let skill = try load(name: name) else {
            throw SkillRegistryError.notFound(name: name)
        }
        return """
        # Skill: \(skill.name)
        # Description: \(skill.frontmatter.description)

        \(skill.body)

        # Input: \(input)
        """
    }

    /// YAML frontmatter (: name + description, Yams)
    private func parseFrontmatter(_ raw: String) -> (SkillFrontmatter, String) {
        let lines = raw.components(separatedBy: "\n")
        guard let firstLine = lines.first, firstLine.hasPrefix("---") else {
            // frontmatter, fallback
            return (SkillFrontmatter(name: "unknown", description: ""), raw)
        }
        var inFrontmatter = true
        var frontmatterLines: [String] = []
        var bodyLines: [String] = []
        var foundEnd = false
        for (idx, line) in lines.enumerated() {
            if idx == 0 { continue }  // skip first ---
            if inFrontmatter {
                if line.hasPrefix("---") {
                    inFrontmatter = false
                    foundEnd = true
                    continue
                }
                frontmatterLines.append(line)
            } else {
                bodyLines.append(line)
            }
        }
        if !foundEnd {
            // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
            // ---, fileyes body
            return (SkillFrontmatter(name: "unknown", description: ""), raw)
        }
        // frontmatter (key: value)
        var name = "unknown"
        var description = ""
        for line in frontmatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") {
                name = trimmed.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("description:") {
                description = trimmed.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (SkillFrontmatter(name: name, description: description), body)
    }

    /// skill directory linked files (references/ templates/ scripts/)
    private func listLinkedFiles(skillDir: URL) -> [URL] {
        let linkedSubdirs = ["references", "templates", "scripts", "assets"]
        var results: [URL] = []
        let fm = FileManager.default
        for subdir in linkedSubdirs {
            let dir = skillDir.appendingPathComponent(subdir, isDirectory: true)
            guard fm.fileExists(atPath: dir.path) else { continue }
            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                results.append(contentsOf: contents)
            }
        }
        return results
    }
}

/// SkillRegistry error
public enum SkillRegistryError: Error {
    case notFound(name: String)
}