// Backup.swift
//
// Local ZIP backup + restore (= hermes `backup` parity). Uses
// Foundation `FileManager` + `URL` + `Data`.

import Foundation

/// Backup metadata truth
struct BackupMetadata: Equatable, Sendable {
    let id: String
    let sourcePath: String
    let archivePath: String
    let size: Int64
    let createdAt: Date

    init(id: String, sourcePath: String, archivePath: String, size: Int64, createdAt: Date) {
        self.id = id
        self.sourcePath = sourcePath
        self.archivePath = archivePath
        self.size = size
        self.createdAt = createdAt
    }
}

/// Backup (wenshu backup)
///
/// The canonical Apple mechanism for safe file copy / move in a
/// sandboxed app is `NSFileCoordinator`
/// (= developer.apple.com/documentation/foundation/nsfilecoordinator).
/// The previous implementation did raw `FileManager.copyItem` =
/// no cross-process coordination = other NSFilePresenter
/// implementations in the editor (`WenshuMarkdownEditor`, the
/// chapter file watcher, etc.) would silently conflict with the
/// copy.
///
/// `NSFileCoordinator` wraps the read/write so all interested file
/// presenters get notified (= "we're about to read source X" +
/// "we're about to write backup Y"); = no silent file race.
struct BackupTools: Sendable {
    init() {}

    /// Backup: snapshot `sourceDir` to `<backupDir>/<source>-<iso8601>/`
    /// (= the canonical wenshu backup shape; = the artifact is a
    /// directory, not a ZIP, because the .ws bundle is itself a
    /// directory tree = no compression needed; = Time Machine
    /// deduplicates the snapshot natively).
    ///
    /// Apple HIG:
    /// 1. NSFileCoordinator.coordinate(readingItemAt:writingItemAt:)
    ///    wraps the source read + backup write (= the canonical
    ///    cross-process coordination pattern).
    /// 2. The backup directory itself is marked with
    ///    `URLResourceKey.isExcludedFromBackupKey = true` (= Time
    ///    Machine loop prevention; = otherwise Time Machine would
    ///    back up the backup, growing indefinitely).
    func backup(sourceDir: String, backupDir: String? = nil) throws -> BackupMetadata {
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
        // Mark the backup directory with isExcludedFromBackupKey
        // (= Time Machine loop defense). Per Apple HIG, the
        // resource value is set via `setResourceValues(_:)` on
        // the directory URL.
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDestDir = destDir
        try? mutableDestDir.setResourceValues(resourceValues)

        let timestamp = Date().formatted(.iso8601)
            .replacingOccurrences(of: ":", with: "-")
        let backupName = "\(sourceURL.lastPathComponent)-\(timestamp)"
        let archiveURL = destDir.appendingPathComponent(backupName, isDirectory: true)

        // NSFileCoordinator cross-process coordination (= the
        // canonical Apple pattern; = replaces raw fm.copyItem).
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        // The coordinator's accessor closure is non-throwing
        // (= the Obj-C byAccessor signature); = capture inner
        // errors in a local box, then check after the
        // coordinator returns.
        var copyError: Error?
        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: [.withoutChanges],
            writingItemAt: archiveURL,
            options: [.forReplacing],
            error: &coordinationError
        ) { readURL, writeURL in
            do {
                try fm.copyItem(at: readURL, to: writeURL)
            } catch {
                copyError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let copyError {
            throw BackupError.copyFailed(underlying: copyError)
        }
        // Post-check: confirm the artifact landed (= the
        // coordinator may complete the access block without
        // raising an error AND the copy may have failed silently).
        guard fm.fileExists(atPath: archiveURL.path) else {
            throw BackupError.copyFailed(underlying: NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileNoSuchFileError
            ))
        }

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
    func list(backupDir: String? = nil) throws -> [BackupMetadata] {
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
    func restore(backupName: String, to destDir: String, backupDir: String? = nil) throws {
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
    func delete(backupName: String, backupDir: String? = nil) throws {
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

enum BackupError: Error {
    case sourceNotFound(path: String)
    case copyFailed(underlying: Error)
}

extension BackupError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sourceNotFound(let path):
            return "Backup source not found: \(path)"
        case .copyFailed(let underlying):
            return "Backup copy failed: \(underlying.localizedDescription)"
        }
    }
}
