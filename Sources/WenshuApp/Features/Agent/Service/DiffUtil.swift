//
//  DiffUtil.swift
//
//  LCS-based unified diff utility (= DiffEntry + lcsTable + backtrackDiff
//  + computeUnifiedDiff) consolidated from 2 duplicate definitions in
//  A117 (= the same 4 declarations were inline in both
//  EditChapterActor.swift + BookChapterTool.swift; = a real duplicate
//  flagged by the §6.2 4-slot file-shape audit).
//
//  Why a separate file (= and not in either of the 2 callers): both
//  EditChapterActor and BookChapterTool are large actors (= 700+
//  LOC each = 1.5x the §6.6 600-LOC cap); = they share 1 algorithmic
//  concern (= line-level unified diff = the standard "--- old /
//  +++ new / @@" format). Putting the utility in its own file = 1
//  source of truth for the diff algorithm = changing the LCS
//  implementation now happens in 1 place (= not 2).
//
//  Per the §6.2 4-slot spec: this is a pure algorithm = belongs in
//  Service/ (= already is; = sibling of the 2 callers in the same
//  Service/ dir).
//
//  Per the §6.5 file-naming rule: <X>Util.swift is the project's
//  actual suffix for pure utility namespaces (= matches the Apple
//  Backyard Birds `SampleUtil.swift` pattern).
//
//  Privacy: the original `private enum DiffEntry` and `private
//  static func X` were private to the actor (= file-scoped). They
//  are now internal (= default) on `DiffEntry` so both actors can
//  reference it (= the function bodies were already using
//  `DiffEntry` in the actor's return types; = the diff return
//  type now lives here).
//

import Foundation

/// Unified-diff result (= the standard "--- old\n+++ new\n@@\n" text
/// + summary stats = added/removed line count + char count).
struct UnifiedDiff: Equatable, Sendable {
    let text: String
    let addedLines: Int
    let removedLines: Int
    let addedChars: Int
    let removedChars: Int
}

/// Line-level diff entry (= 1 added / removed / context line).
enum DiffEntry: Equatable, Sendable {
    case added(String)
    case removed(String)
    case context(String)
}

/// Build the LCS table for the standard longest-common-subsequence
/// algorithm. Returns an `(a.count + 1) x (b.count + 1)` matrix where
/// `table[i][j]` = LCS length of `a[0..<i]` and `b[0..<j]`.
func lcsTable(_ a: [String], _ b: [String]) -> [[Int]] {
    var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in 1...a.count {
        for j in 1...b.count {
            if a[i - 1] == b[j - 1] {
                table[i][j] = table[i - 1][j - 1] + 1
            } else {
                table[i][j] = max(table[i - 1][j], table[i][j - 1])
            }
        }
    }
    return table
}

/// Backtrack through the LCS table to produce a sequence of diff
/// entries (= the diff result in chronological order = additions
/// / removals / context lines).
func backtrackDiff(
    old: [String],
    new: [String],
    lcs: [[Int]]
) -> [DiffEntry] {
    var entries: [DiffEntry] = []
    var i = old.count
    var j = new.count
    while i > 0 || j > 0 {
        if i > 0 && j > 0 && old[i - 1] == new[j - 1] {
            entries.append(.context(old[i - 1]))
            i -= 1
            j -= 1
        } else if j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j]) {
            entries.append(.added(new[j - 1]))
            j -= 1
        } else if i > 0 {
            entries.append(.removed(old[i - 1]))
            i -= 1
        }
    }
    return entries.reversed()
}

/// Compute the standard unified-diff text (= "--- old\n+++ new\n@@\n"
/// + the line-by-line additions / removals / context) plus summary
/// stats (= added/removed line count + added/removed char count).
func computeUnifiedDiff(old: String, new: String) -> UnifiedDiff {
    let oldLines = old.components(separatedBy: "\n")
    let newLines = new.components(separatedBy: "\n")
    var oldSplit = oldLines
    var newSplit = newLines
    if old.hasSuffix("\n") && oldSplit.last == "" { oldSplit.removeLast() }
    if new.hasSuffix("\n") && newSplit.last == "" { newSplit.removeLast() }
    let lcs = lcsTable(oldSplit, newSplit)
    let lines = backtrackDiff(old: oldSplit, new: newSplit, lcs: lcs)
    var addedLines = 0
    var removedLines = 0
    var addedChars = 0
    var removedChars = 0
    for entry in lines {
        switch entry {
        case .added(let body):
            addedLines += 1
            addedChars += body.count
        case .removed(let body):
            removedLines += 1
            removedChars += body.count
        case .context: continue
        }
    }
    var text = "--- old\n+++ new\n@@\n"
    for entry in lines {
        switch entry {
        case .added(let body): text += "+\(body)\n"
        case .removed(let body): text += "-\(body)\n"
        case .context(let body): text += " \(body)\n"
        }
    }
    return UnifiedDiff(
        text: text,
        addedLines: addedLines,
        removedLines: removedLines,
        addedChars: addedChars,
        removedChars: removedChars
    )
}
