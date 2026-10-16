//
//  ImportServiceTitleOnlyHelpers.swift
//
//  2 title-only retry helpers extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: titleOnlyBody +
//  siblingContextMap = 68 LOC moved out of the main file into this
//  dedicated module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1599 LOC = 2.7x the 600-LOC cap. The 2
//  title-only retry helpers are a single concern (= "build the
//  synthesized body when the original .md is unreadable" + "build
//  the sibling-context map for the LLM"). Putting them in a
//  dedicated file named after the concern (= ImportServiceTitleOnlyHelpers.swift)
//  lets the next reader find these helpers by name.
//
//  These 2 funcs are static (= no instance state; = safe to call
//  from any context).
//

import Foundation

/// Namespace container for the 2 title-only retry helpers.
enum ImportServiceTitleOnlyHelpers {

    /// Construct a "title-only" body for the LLM (= the source file is
    /// unreadable; = the body is the minimum context the LLM needs to produce
    /// metadata + a `.ws`-format body). The body follows the same structure as
    /// the `userPrompt` expects (= the LLM's prompt is "read this body +
    /// produce title / summary / tags + rewrittenBody" = the title-only body is
    /// a short synthesized markdown with the title as the H1 + a brief context
    /// block).
    static func titleOnlyBody(
        fileName: String,
        siblingContext: String
    ) -> String {
        let titleStem = (fileName as NSString).deletingPathExtension
        return """
        # \(titleStem)

        <!-- title-only retry.
             The original .md file at the same path
             failed to read on disk (= malformed utf-8
             or unsupported format). The orchestrator
             constructed this body from the filename
             + the sibling .md names in the same
             source directory. The LLM should use
             web_search to fill in the canonical
             content for "\(titleStem)" and produce
             the standard .ws-format body (3 必填 + 2
             可选 frontmatter + 自由 markdown 正文). -->
        \(siblingContext.isEmpty ? "" : siblingContext)
        """
    }


    /// Build a map from each task's source path to a sibling-context string (=
    /// the names of the other `.md` files in the same source directory). One
    /// walk per unique parent directory (= the wenshu user's import directories
    /// typically hold hundreds of files; = the walk is the only I/O = we
    /// amortize it across the failed set).
    static func siblingContextMap(for tasks: [ImportTask]) -> [String: String] {
        let fm = FileManager.default
        // 1. Group task paths by parent directory.
        var byDir: [String: [String]] = [:]
        for task in tasks {
            let path = task.sourcePath
            let dir = (path as NSString).deletingLastPathComponent
            byDir[dir, default: []].append(path)
        }
        // 2. For each unique parent, enumerate the directory and build a per-path context
        // string (= all the other .md names in the same folder).
        var out: [String: String] = [:]
        for (dir, paths) in byDir {
            // 3. Sibling .md names (= every .md file in the directory; = the failed
            // file's own name is excluded from its own context; = the list
            // is "what other entities are nearby").
            let siblingNames: [String]
            if let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                siblingNames = enumerator.compactMap { url in
                    guard let url = url as? URL,
                          (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                          url.pathExtension.lowercased() == "md"
                    else { return nil }
                    return url.lastPathComponent
                }
            } else {
                siblingNames = []
            }
            // 4. Build the per-path context (= the failed file's own name is filtered
            // out; = the list is the "neighbors in the same folder").
            for path in paths {
                let myName = (path as NSString).lastPathComponent
                let others = siblingNames.filter { $0 != myName }
                let context = others.isEmpty
                    ? ""
                    : "## 同目录其他文件 (= entity neighbors in this folder)\n\n" +
                      others.sorted().prefix(20).map { "- \($0)" }.joined(separator: "\n") + "\n"
                out[path] = context
            }
        }
        return out
    }


}
