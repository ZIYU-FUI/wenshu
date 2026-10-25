//
//  ImportServiceBookTree.swift · wenshu
//
//  The book tree's snapshot (= what "unchanged" means for the cancel
//  rollback).
//
//  Why this exists: in the reorganize mode the agent is the only
//  writer (= the orchestrator writes nothing; = see
//  `ImportServiceMainFileWriter`). The agent writes through
//  `WriteBookDocTool`, so the orchestrator's own bookkeeping never
//  learns which files landed. The boss's 2026-10-09 directive is
//  strict: "取消退出时，所有已经导入的内容回退清掉 ... 不留痕" (= cancel
//  = nothing lands on disk).
//
//  So the rollback looks at the tree instead of at a trail: the tree
//  before the run, and the tree after it. A file that is new, or that
//  changed, was written by the run; = it is removed on cancel.
//
//  The stamp is the file's size + its modification date (= a rewrite
//  with the same bytes is not a change the user can see; = a rewrite
//  with different bytes is).
//

import Foundation

/// Reads and diffs a book folder's file tree.
enum ImportServiceBookTree {

    /// One file's stamp.
    struct Stamp: Equatable {
        let size: Int
        let modified: Date
    }

    /// The book tree as it was before a run.
    struct Snapshot: Equatable {
        /// Every file's stamp (= keyed by the file's absolute path).
        var files: [String: Stamp] = [:]
        /// Every directory the tree held (= keyed by the absolute path).
        var directories: Set<String> = []
    }

    /// Read a root's tree.
    static func snapshot(_ root: URL) -> Snapshot {
        var result = Snapshot()
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return result }
        for case let url as URL in walker {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                result.directories.insert(url.standardizedFileURL.path)
                continue
            }
            let values = try? url.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            guard let values else { continue }
            result.files[url.standardizedFileURL.path] = Stamp(
                size: values.fileSize ?? 0,
                modified: values.contentModificationDate ?? .distantPast
            )
        }
        return result
    }

    /// The files the run added or changed (= the paths whose stamp is
    /// missing from the snapshot, or different from it).
    static func changedFiles(
        since snapshot: Snapshot,
        in root: URL
    ) -> [URL] {
        let current = ImportServiceBookTree.snapshot(root)
        return current.files
            .filter { path, stamp in snapshot.files[path] != stamp }
            .keys
            .sorted()
            .map { URL(fileURLWithPath: $0) }
    }

    /// The directories the run created (= the ones the snapshot did not
    /// hold).
    static func createdDirectories(
        since snapshot: Snapshot,
        in root: URL
    ) -> [URL] {
        let current = ImportServiceBookTree.snapshot(root)
        return current.directories
            .subtracting(snapshot.directories)
            .sorted { $0.count > $1.count }  // the deepest first
            .map { URL(fileURLWithPath: $0) }
    }
}
