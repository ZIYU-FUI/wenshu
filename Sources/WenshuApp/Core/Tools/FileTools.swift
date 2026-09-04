//
//  FileTools.swift · Wenshu · v0.18 ticket 07 (hermes replica)
//
//  本地 file tools (复刻 hermes file tool 真值).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现" + "不符合文枢定位的可以复刻".
//
//  wenshu 定位 = SwiftUI 桌面写作 app. FileTools 写作用 (read / write / patch / search / list).
//  Apple HIG 真值: FileManager + URL + Data + String.
//

import Foundation

/// File entry 真值 (hermes list 真值)
public struct FileEntry: Equatable, Sendable {
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public let modifiedAt: Date?

    public init(path: String, name: String, isDirectory: Bool, size: Int64, modifiedAt: Date?) {
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

/// Patch 1 处真值 (hermes patch 真值)
public struct PatchHunk: Sendable {
    public let oldText: String
    public let newText: String
    public init(oldText: String, newText: String) {
        self.oldText = oldText
        self.newText = newText
    }
}

/// FileToolError: errors thrown by FileTools (v0.23 ticket 008: path guard).
public enum FileToolError: Error, LocalizedError {
    case pathDenied(path: String)

    public var errorDescription: String? {
        switch self {
        case .pathDenied(let path):
            return "path denied (boss 8/23 拍: 用户不可通过聊天改系统): \(path)"
        }
    }
}

/// FileTools: 本地 file ops 工具
public struct FileTools: Sendable {
    public init() {}

    /// pathDenied: 路径 deny-list check (boss 8/23 拍: 用户不可通过聊天改代码 / 改配置).
    /// Returns true if the path matches project code / config / scratch / system files.
    /// Uses (path as NSString).standardizingPath to normalize symlinks / . / ..
    /// v0.23 ticket 013.002: hermes _is_blocked_device parity.
    /// Also blocks /dev/* + /proc/* (memory/environ leaks) + symlink hops.
    public func pathDenied(_ path: String) -> Bool {
        let std = (path as NSString).standardizingPath

        // v0.23 ticket 013.002: hermes _is_blocked_device_path parity.
        // Block /dev/* (can hang reads) and /proc/* secrets (environ/maps/mem).
        if isBlockedDevice(std) { return true }

        // v0.23 ticket 013.002: hermes symlink-hop defense.
        // Follow symlinks and re-check each hop's parent + final resolved path.
        if pathHasBlockedSymlink(std) { return true }

        let denyPrefixes = [
            "Sources/",
            "Tests/",
            "Package.swift",
            ".scratch/",
            "Tools/wenshu-devtool/",
            "/.wenshu/",
            "/.hermes/",
            "/etc/",
            "/System/",
            "/usr/",
        ]
        let denySuffixes = [".zshrc", ".bashrc", ".profile", ".bash_profile"]
        for prefix in denyPrefixes where std.contains(prefix) { return true }
        for suffix in denySuffixes where std.hasSuffix(suffix) { return true }
        return false
    }

    /// isBlockedDevice: hermes `_is_blocked_device_path` parity.
    /// Block /dev/stdin + /proc/* secrets (can leak env / memory layout).
    public func isBlockedDevice(_ path: String) -> Bool {
        // /dev/stdin, /dev/zero, /dev/random, etc. — can hang reads or expose data.
        if path.hasPrefix("/dev/") {
            return true
        }
        // /proc/self/environ → env vars (incl. API keys)
        // /proc/self/maps → memory layout (ASLR bypass)
        // /proc/self/cmdline → process args (might contain secrets)
        // /proc/self/mem → raw memory
        // /proc/self/auxv → AT_RANDOM seed (ASLR oracle)
        // /proc/self/pagemap → virtual→physical translation
        let procSensitiveSuffixes = [
            "/environ", "/cmdline", "/maps", "/smaps",
            "/smaps_rollup", "/numa_maps", "/mem", "/auxv", "/pagemap",
            "/fd/0", "/fd/1", "/fd/2",  // stdio (hangs reads)
        ]
        if path.hasPrefix("/proc/") {
            for suffix in procSensitiveSuffixes where path.hasSuffix(suffix) {
                return true
            }
        }
        return false
    }

    /// pathHasBlockedSymlink: hermes symlink-hop defense (boss 8/23 security).
    /// Resolves symlinks and verifies no hop leads to a blocked device.
    /// Returns true if ANY hop in the chain points to /dev/* or /proc/*.
    public func pathHasBlockedSymlink(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        // Resolve symlinks iteratively. macOS realpath equivalent.
        var current = url
        var hops = 0
        let maxHops = 40  // symlink cycle limit (matches POSIX MAXSYMLINKS)
        while hops < maxHops {
            let resolved = current.resolvingSymlinksInPath()
            if resolved == current { break }  // no more symlinks to resolve
            if isBlockedDevice(resolved.path) { return true }
            current = resolved
            hops += 1
        }
        return false
    }

    /// read: 读文件真值
    public func read(path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    /// write: 写文件真值 (原子写, Apple 真值: .atomicWrite)
    /// v0.23 ticket 008: path guard rejects deny-list paths.
    public func write(path: String, content: String) throws {
        if pathDenied(path) { throw FileToolError.pathDenied(path: path) }
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// patch: 1 处替换真值 (hermes patch 1 处简化)
    /// v0.23 ticket 008: path guard rejects deny-list paths.
    public func patch(path: String, hunk: PatchHunk) throws {
        if pathDenied(path) { throw FileToolError.pathDenied(path: path) }
        let original = try read(path: path)
        guard original.contains(hunk.oldText) else {
            throw FileToolsError.patchNotFound(path: path, oldText: hunk.oldText)
        }
        let patched = original.replacingOccurrences(of: hunk.oldText, with: hunk.newText)
        try write(path: path, content: patched)
    }

    /// search: 目录递归搜索真值
    public func search(rootDir: String, pattern: String, fileExtension: String? = nil) throws -> [String] {
        var results: [String] = []
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: rootDir, isDirectory: true)
        guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return results
        }
        for case let fileURL as URL in enumerator {
            let isFile = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            guard isFile else { continue }
            if let ext = fileExtension, !fileURL.pathExtension.isEmpty && fileURL.pathExtension != ext {
                continue
            }
            if let content = try? String(contentsOf: fileURL, encoding: .utf8),
               content.contains(pattern) {
                results.append(fileURL.path)
            }
        }
        return results
    }

    /// list: 列目录真值
    public func list(path: String) throws -> [FileEntry] {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        return contents.compactMap { fileURL in
            let name = fileURL.lastPathComponent
            let resources = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            let isDir = resources?.isDirectory ?? false
            let size = Int64(resources?.fileSize ?? 0)
            let modified = resources?.contentModificationDate
            return FileEntry(path: fileURL.path, name: name, isDirectory: isDir, size: size, modifiedAt: modified)
        }.sorted { $0.name < $1.name }
    }
}

public enum FileToolsError: Error {
    case patchNotFound(path: String, oldText: String)
}