//
//  symlink_walk.swift — what `FileManager.enumerator` does with a symlink, on
//  the three resource keys the import filter actually reads.
//
//  Run:  swift Tools/wenshu-devtool/probes/symlink_walk.swift
//
//  Why this exists in the tree: the import walk's comment says it "skips
//  directories and symlinks pointing outside the source tree", which is narrower
//  than the code. `isRegularFileKey` does not resolve a link, so the walk skips
//  EVERY symlink, and a symlinked directory is never descended into — a folder
//  that happens to be a link therefore imports zero files without a word. Both
//  halves are answers about engine behaviour, so both are printed here rather
//  than argued in a comment; the ledger row in
//  `docs/agents/2026-11-22-session-close-soft-cites-swept-and-landed.md`
//  cites this file as its RE-VERIFY command.
//
//  The probe asserts, so a future macOS or Foundation change that moves either
//  answer fails loudly instead of quietly making the comment untrue again.
//

import Foundation

func values(_ url: URL) -> (regular: Bool?, link: Bool?, dir: Bool?) {
    let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey])
    return (v?.isRegularFile, v?.isSymbolicLink, v?.isDirectory)
}

let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("symlink-walk-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: root) }

// root/top.txt, root/sub/ (a real directory), root/linkdir -> root/real/,
// root/real/a.txt (only reachable through the link).
for dir in ["real", "sub"] {
    try FileManager.default.createDirectory(at: root.appendingPathComponent(dir),
                                            withIntermediateDirectories: true)
}

try "x".write(to: root.appendingPathComponent("top.txt"), atomically: true, encoding: .utf8)
try "y".write(to: root.appendingPathComponent("real/a.txt"), atomically: true, encoding: .utf8)
try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linkdir"),
                                           withDestinationURL: root.appendingPathComponent("real"))

// The enumerator hands back `/private/var/...` for a root that was built as
// `/var/...`, so the display name is cut against the resolved root, and the
// entry itself is never resolved — resolving it would erase the symlink the
// probe is about.
let base = root.resolvingSymlinksInPath().path + "/"
var seen: [String: (regular: Bool?, link: Bool?, dir: Bool?)] = [:]
let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
for case let url as URL in e {
    let rel = url.path.hasPrefix(base) ? String(url.path.dropFirst(base.count)) : url.lastPathComponent
    seen[rel] = values(url)
}

print("walk of a tree holding top.txt, sub/, real/a.txt and linkdir -> real/:")
for name in seen.keys.sorted() {
    let v = seen[name]!
    print(String(format: "  %-12@ regular=%@ symlink=%@ dir=%@", name as NSString,
                 "\(v.regular)" as NSString, "\(v.link)" as NSString, "\(v.dir)" as NSString))
}

let reachedAFile = seen.keys.contains { $0.hasPrefix("linkdir/") }
let linkEntry = seen["linkdir"]
guard let top = seen["top.txt"], top.0 == true else {
    fatalError("PROBE INVALID: a plain file did not read as regular")
}

precondition(reachedAFile == false,
             "the walk descended into a symlinked directory; the comment's \"skips EVERY symlink\" is now false")
precondition(linkEntry?.regular == false && linkEntry?.link == true && linkEntry?.dir == false,
             "a symlinked directory no longer reads as (regular=false, link=true, dir=false): \(String(describing: linkEntry))")
// The same reading as named rows, so `probe-index.md` can point at them and a
// re-run diffs line for line. Run the probe with `git rev-parse HEAD` next to it
// to tie the rows to a tree (= the probe measures Foundation's enumerator, not
// this app's code, so the tree it is tied to is the tree it was run on).
print("entries_total: \(seen.count)")
print("plain_file_is_regular: \(top.0 == true)")
print("symlink_to_regular_file_is_regular: \(seen.values.contains { $0.link == true && $0.regular == true })")
print("symlinked_directory_is_directory: \(linkEntry?.dir == true)")
print("symlinked_directory_is_symlink: \(linkEntry?.link == true)")
print("walk_descends_into_symlinked_directory: \(reachedAFile)")
