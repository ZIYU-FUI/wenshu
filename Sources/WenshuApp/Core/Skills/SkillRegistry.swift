//
//  SkillRegistry.swift · Wenshu · v0.18 ticket 02 (hermes replica)
//
//  本地 Skills 加载机制 (替代 hermes skills_hub 云 + GitHub).
//  老板 2026-08-19 拍 "底层依赖复刻" — 不依赖 hermes skills_hub, wenshu 自己有 skill registry.
//
//  接口对齐 hermes 真值 (skills_hub.py 35 do_* 函数简化版):
//  - list() → [Skill]: 扫 Sources/WenshuCore/Skills/<name>/SKILL.md
//  - load(name) → Skill?: 拿 SKILL.md 内容 + parse frontmatter
//  - invoke(name, input) → String: 调 skill (简化版只读 frontmatter + body, 不实现 35 do_* 完整 hub)
//
//  SKILL.md 真值格式 (frontmatter + body):
//  ---
//  name: skill-name
//  description: ...
//  ---
//
//  # body markdown
//

import Foundation

/// Skill frontmatter 真值 (YAML 简化版: 跟 SKILL.md 文件一致)
public struct SkillFrontmatter: Equatable, Sendable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

/// Skill: name + frontmatter + body + files (linked_files 真值)
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

/// SkillRegistry: 扫 + 解析本地 SKILL.md 文件
public actor SkillRegistry {
    /// skill 根目录 (默认 wenshu 项目内 Sources/WenshuCore/Skills/, 可 override 测试用临时目录)
    private let rootDir: URL

    public init(rootDir: URL? = nil) {
        if let rootDir = rootDir {
            self.rootDir = rootDir
        } else {
            // 默认 wenshu 项目内 Skills 目录. 优先用 WENSHU_ROOT env (测试可移植), fallback cwd/Sources/WenshuCore/Skills
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let defaultPath = cwd.appendingPathComponent("Sources/WenshuCore/Skills", isDirectory: true)
            if let envRoot = ProcessInfo.processInfo.environment["WENSHU_ROOT"] {
                self.rootDir = URL(fileURLWithPath: envRoot).appendingPathComponent("Sources/WenshuCore/Skills", isDirectory: true)
            } else {
                self.rootDir = defaultPath
            }
        }
    }

    /// list: 扫 rootDir 下所有 SKILL.md, return skill names
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

    /// load: 拿 1 个 skill, parse frontmatter + body
    public func load(name: String) throws -> Skill? {
        let skillDir = rootDir.appendingPathComponent(name, isDirectory: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillFile.path) else { return nil }
        let raw = try String(contentsOf: skillFile, encoding: .utf8)
        let (frontmatter, body) = parseFrontmatter(raw)
        let linked = listLinkedFiles(skillDir: skillDir)
        return Skill(name: name, path: skillFile, frontmatter: frontmatter, body: body, linkedFiles: linked)
    }

    /// invoke: 简化版 invoke (只返回 frontmatter + body, 不实现 35 do_* 完整 hub)
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

    /// 解析 YAML frontmatter (简化版: 只拿 name + description, 不依赖 Yams 第三方)
    private func parseFrontmatter(_ raw: String) -> (SkillFrontmatter, String) {
        let lines = raw.components(separatedBy: "\n")
        guard let firstLine = lines.first, firstLine.hasPrefix("---") else {
            // 没 frontmatter, 用 fallback
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
            // 没找到结束 ---, 整个文件是 body
            return (SkillFrontmatter(name: "unknown", description: ""), raw)
        }
        // 解析 frontmatter 简化版 (key: value)
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

    /// 列 skill 目录下的 linked files (references/ templates/ scripts/)
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

/// SkillRegistry 错误
public enum SkillRegistryError: Error {
    case notFound(name: String)
}