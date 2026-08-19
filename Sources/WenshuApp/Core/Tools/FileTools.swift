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

/// FileTools: 本地 file ops 工具
public struct FileTools: Sendable {
    public init() {}

    /// read: 读文件真值
    public func read(path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    /// write: 写文件真值 (原子写, Apple 真值: .atomicWrite)
    public func write(path: String, content: String) throws {
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// patch: 1 处替换真值 (hermes patch 1 处简化)
    public func patch(path: String, hunk: PatchHunk) throws {
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