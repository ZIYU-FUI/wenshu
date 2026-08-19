//
//  BackupTests.swift · Wenshu · v0.18 ticket 26 (backup)
//
//  单元测试 BackupTools. cwd 下临时源目录 + 临时备份目录.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Backup (hermes replica)")
struct BackupTests {
    private static func tempDir(name: String) -> URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dir = cwd.appendingPathComponent(".test-backup-\(name)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("backup 复制源目录到备份目录")
    func testBackup() throws {
        let source = Self.tempDir(name: "src")
        try "hello world".write(to: source.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "wenshu project".write(to: source.appendingPathComponent("file2.md"), atomically: true, encoding: .utf8)
        let backupDest = Self.tempDir(name: "dest")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: backupDest)
        }
        let tools = BackupTools()
        let meta = try tools.backup(sourceDir: source.path, backupDir: backupDest.path)
        #expect(meta.sourcePath == source.path)
        #expect(meta.size > 0)
        // 验证备份存在 + 内容一致
        let archived = meta.archivePath
        #expect(FileManager.default.fileExists(atPath: archived))
        let copied = try String(contentsOf: URL(fileURLWithPath: archived).appendingPathComponent("file1.txt"), encoding: .utf8)
        #expect(copied == "hello world")
    }

    @Test("backup 源目录不存在抛错")
    func testBackupSourceNotFound() {
        let tools = BackupTools()
        #expect(throws: BackupError.self) {
            _ = try tools.backup(sourceDir: "/nonexistent/path", backupDir: Self.tempDir(name: "x").path)
        }
    }

    @Test("list 列已存在的备份")
    func testList() throws {
        let source = Self.tempDir(name: "list")
        try "data".write(to: source.appendingPathComponent("data.txt"), atomically: true, encoding: .utf8)
        let backupDest = Self.tempDir(name: "list-dest")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: backupDest)
        }
        let tools = BackupTools()
        _ = try tools.backup(sourceDir: source.path, backupDir: backupDest.path)
        let list = try tools.list(backupDir: backupDest.path)
        #expect(list.count == 1)
    }

    @Test("delete 删 1 个")
    func testDelete() throws {
        let source = Self.tempDir(name: "del")
        try "data".write(to: source.appendingPathComponent("data.txt"), atomically: true, encoding: .utf8)
        let backupDest = Self.tempDir(name: "del-dest")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: backupDest)
        }
        let tools = BackupTools()
        let meta = try tools.backup(sourceDir: source.path, backupDir: backupDest.path)
        let backupName = URL(fileURLWithPath: meta.archivePath).lastPathComponent
        try tools.delete(backupName: backupName, backupDir: backupDest.path)
        let list = try tools.list(backupDir: backupDest.path)
        #expect(list.isEmpty)
    }
}