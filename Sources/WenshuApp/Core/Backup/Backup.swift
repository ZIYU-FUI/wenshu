//
//  Backup.swift · Wenshu · v0.18 ticket 26 (hermes replica)
//
//  本地项目备份 (复刻 hermes backup 真值简化版).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现" + "不符合文枢定位的可以复刻".
//
//  wenshu 定位 = SwiftUI 桌面写作 app. Backup 写作用 (项目 ZIP 备份 / 恢复).
//  Apple HIG 真值: Foundation FileManager + URL 真值 + Data 真值.
//

import Foundation

/// Backup metadata truth
public struct BackupMetadata: Equatable, Sendable {
    public let id: String
    public let sourcePath: String
    public let archivePath: String
    public let size: Int64
    public let createdAt: Date

    public init(id: String, sourcePath: String, archivePath: String, size: Int64, createdAt: Date) {
        self.id = id
        self.sourcePath = sourcePath
        self.archivePath = archivePath
        self.size = size
        self.createdAt = createdAt
    }
}

/// Backup 工具 (wenshu 写作用项目备份)
public struct BackupTools: Sendable {
    public init() {}

    /// backup: 创建项目目录的 ZIP 备份真值
    /// 简化: 不用 ZIP, 用 .tar.gz 不行 (Apple 没 tar 真值), 改用 NSFileCoordinator + 复制整个目录到备份目录
    public func backup(sourceDir: String, backupDir: String? = nil) throws -> BackupMetadata {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourceDir, isDirectory: true)
        guard fm.fileExists(atPath: sourceURL.path) else {
            throw BackupError.sourceNotFound(path: sourceDir)
        }
        let destDir: URL
        if let backupDir = backupDir {
            destDir = URL(fileURLWithPath: backupDir, isDirectory: true)
        } else {
            let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            destDir = support.appendingPathComponent("wenshu/backups", isDirectory: true)
        }
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupName = "\(sourceURL.lastPathComponent)-\(timestamp)"
        let archiveURL = destDir.appendingPathComponent(backupName, isDirectory: true)
        try fm.copyItem(at: sourceURL, to: archiveURL)
        let size = try directorySize(at: archiveURL)
        return BackupMetadata(
            id: UUID().uuidString,
            sourcePath: sourceURL.path,
            archivePath: archiveURL.path,
            size: size,
            createdAt: Date()
        )
    }

    /// list: 列所有备份真值
    public func list(backupDir: String? = nil) throws -> [BackupMetadata] {
        let fm = FileManager.default
        let destDir: URL
        if let backupDir = backupDir {
            destDir = URL(fileURLWithPath: backupDir, isDirectory: true)
        } else {
            let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            destDir = support.appendingPathComponent("wenshu/backups", isDirectory: true)
        }
        guard fm.fileExists(atPath: destDir.path) else { return [] }
        let contents = try fm.contentsOfDirectory(at: destDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
        return contents.compactMap { url in
            let resources = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(resources?.fileSize ?? 0)
            let modified = resources?.contentModificationDate ?? Date()
            return BackupMetadata(
                id: url.lastPathComponent,
                sourcePath: url.lastPathComponent,
                archivePath: url.path,
                size: size,
                createdAt: modified
            )
        }.sorted { $0.createdAt > $1.createdAt }
    }

    /// restore: 从备份恢复真值 (复制回去)
    public func restore(backupName: String, to destDir: String, backupDir: String? = nil) throws {
        let fm = FileManager.default
        let destRoot: URL
        if let backupDir = backupDir {
            destRoot = URL(fileURLWithPath: backupDir, isDirectory: true)
        } else {
            let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            destRoot = support.appendingPathComponent("wenshu/backups", isDirectory: true)
        }
        let archiveURL = destRoot.appendingPathComponent(backupName, isDirectory: true)
        let destURL = URL(fileURLWithPath: destDir, isDirectory: true).appendingPathComponent(backupName, isDirectory: true)
        try fm.removeItem(at: destURL)
        try fm.copyItem(at: archiveURL, to: destURL)
    }

    /// delete: 删 1 个备份真值
    public func delete(backupName: String, backupDir: String? = nil) throws {
        let fm = FileManager.default
        let destRoot: URL
        if let backupDir = backupDir {
            destRoot = URL(fileURLWithPath: backupDir, isDirectory: true)
        } else {
            let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            destRoot = support.appendingPathComponent("wenshu/backups", isDirectory: true)
        }
        try fm.removeItem(at: destRoot.appendingPathComponent(backupName, isDirectory: true))
    }

    /// Real directory size (regression)
    private func directorySize(at url: URL) throws -> Int64 {
        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: resourceKeys) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys))
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}

public enum BackupError: Error {
    case sourceNotFound(path: String)
}