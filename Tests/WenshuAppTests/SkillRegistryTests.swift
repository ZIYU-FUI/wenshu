//
//  SkillRegistryTests.swift · Wenshu · v0.18 ticket 02 (hermes replica)
//
//  单元测试本地 SkillRegistry. 直接在 cwd 创建临时 SKILL.md, 测试后清理.
//  测试不用临时目录 (Xcode test sandbox 隔离 temp path 不可靠).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SkillRegistry (hermes replica)")
struct SkillRegistryTests {
    /// cwd 下创建临时 skill 目录, 返回绝对路径
    private static func setupTestSkill(name: String = "test-skill", body: String = "# test body\n") throws -> URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let skillsRoot = cwd.appendingPathComponent(".test-skills-\(UUID().uuidString.prefix(8))", isDirectory: true)
        let skillDir = skillsRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let content = """
        ---
        name: \(name)
        description: 测试 skill \(name)
        ---

        \(body)
        """
        try content.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        return skillsRoot
    }

    @Test("list() 返回 SKILL.md 文件夹名")
    func testList() async throws {
        let dir = try Self.setupTestSkill(name: "alpha")
        let registry = SkillRegistry(rootDir: dir)
        let names = try await registry.list()
        #expect(names == ["alpha"])
    }

    @Test("list() 跳过没 SKILL.md 的文件夹")
    func testListSkipsNoSkill() async throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let skillsRoot = cwd.appendingPathComponent(".test-skills-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: skillsRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: skillsRoot.appendingPathComponent("no-skill-here"), withIntermediateDirectories: true)
        let registry = SkillRegistry(rootDir: skillsRoot)
        let names = try await registry.list()
        #expect(names.isEmpty)
    }

    @Test("load() 解析 frontmatter + body")
    func testLoad() async throws {
        let dir = try Self.setupTestSkill(name: "beta", body: "# beta body\nline 2\nline 3")
        let registry = SkillRegistry(rootDir: dir)
        let skill = try await registry.load(name: "beta")
        #expect(skill?.frontmatter.name == "beta")
        #expect(skill?.frontmatter.description == "测试 skill beta")
        #expect(skill?.body.contains("beta body") == true)
        #expect(skill?.body.contains("line 3") == true)
    }

    @Test("load() 没找到返回 nil")
    func testLoadNotFound() async throws {
        let dir = try Self.setupTestSkill(name: "gamma")
        let registry = SkillRegistry(rootDir: dir)
        let skill = try await registry.load(name: "nonexistent")
        #expect(skill == nil)
    }

    @Test("invoke() 返回 frontmatter + body + input")
    func testInvoke() async throws {
        let dir = try Self.setupTestSkill(name: "delta")
        let registry = SkillRegistry(rootDir: dir)
        let result = try await registry.invoke(name: "delta", input: "test input")
        #expect(result.contains("Skill: delta"))
        #expect(result.contains("测试 skill delta"))
        #expect(result.contains("test input"))
    }

    @Test("invoke() skill 不存在抛错")
    func testInvokeNotFound() async throws {
        let dir = try Self.setupTestSkill(name: "epsilon")
        let registry = SkillRegistry(rootDir: dir)
        await #expect(throws: SkillRegistryError.self) {
            _ = try await registry.invoke(name: "missing")
        }
    }
}