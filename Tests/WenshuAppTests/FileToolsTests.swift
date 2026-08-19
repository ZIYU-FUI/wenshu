//
//  FileToolsTests.swift · Wenshu · v0.18 ticket 07 (file tools)
//
//  单元测试 FileTools. cwd 下临时文件, 测试后清理.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("FileTools (hermes replica)")
struct FileToolsTests {
    private static func tempPath(name: String = "test") -> String {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".test-\(name)-\(UUID().uuidString.prefix(8)).txt")
            .path
    }

    @Test("write + read round-trip")
    func testWriteRead() throws {
        let tools = FileTools()
        let path = Self.tempPath()
        try tools.write(path: path, content: "hello wenshu")
        let read = try tools.read(path: path)
        #expect(read == "hello wenshu")
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("patch 1 处替换")
    func testPatch() throws {
        let tools = FileTools()
        let path = Self.tempPath()
        try tools.write(path: path, content: "old text content")
        try tools.patch(path: path, hunk: PatchHunk(oldText: "old", newText: "new"))
        let patched = try tools.read(path: path)
        #expect(patched == "new text content")
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("patch 找不到 old text 抛错")
    func testPatchNotFound() async throws {
        let tools = FileTools()
        let path = Self.tempPath()
        try tools.write(path: path, content: "actual content")
        await #expect(throws: FileToolsError.self) {
            try tools.patch(path: path, hunk: PatchHunk(oldText: "missing", newText: "replacement"))
        }
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("search 找包含 pattern 的文件")
    func testSearch() throws {
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".test-search-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file1 = dir.appendingPathComponent("a.txt").path
        let file2 = dir.appendingPathComponent("b.txt").path
        let file3 = dir.appendingPathComponent("c.md").path
        let tools = FileTools()
        try tools.write(path: file1, content: "contains WENSHU_PATTERN here")
        try tools.write(path: file2, content: "no match")
        try tools.write(path: file3, content: "WENSHU_PATTERN also here")
        let results = try tools.search(rootDir: dir.path, pattern: "WENSHU_PATTERN")
        #expect(results.count == 2)
        #expect(results.contains(file1))
        #expect(results.contains(file3))
        try? FileManager.default.removeItem(atPath: dir.path)
    }

    @Test("list 列目录")
    func testList() throws {
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".test-list-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "x".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "y".write(to: dir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let tools = FileTools()
        let entries = try tools.list(path: dir.path)
        #expect(entries.count == 2)
        let names = entries.map { $0.name }.sorted()
        #expect(names == ["a.txt", "b.txt"])
        try? FileManager.default.removeItem(atPath: dir.path)
    }
}