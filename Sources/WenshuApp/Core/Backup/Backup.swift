//
//  Backup.swift · Wenshu · v0.18 ticket 26 (hermes replica)
//
// localbackup (hermes backup).
// 2026-08-19 ", Apple " + "can".
//
// wenshu = SwiftUI app. Backup (ZIP backup / restore).
// Apple HIG: Foundation FileManager + URL + Data .
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

/// Backup (wenshu backup)
public struct BackupTools: Sendable {
    public init() {}

    /// backup: createdirectory ZIP backup
    ///: ZIP, .tar.gz not ok (Apple tar), change NSFileCoordinator + copydirectorybackupdirectory
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

    /// list: backup
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

    /// restore: backuprestore (copy)
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

    /// delete: 1 backup
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