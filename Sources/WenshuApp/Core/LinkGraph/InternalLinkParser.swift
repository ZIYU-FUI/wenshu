// InternalLinkParser.swift
//
// Parses Markdown `[[name]]` (= SilverBullet page ref / Obsidian
// wikilink) using Foundation `NSRegularExpression`.

import Foundation
import os.log

/// 1 Internal Link = Parsing Results
struct InternalLink: Equatable, Sendable {
    let text: String           // show ([[name|alias]] yes alias)
    let target: String         // ref ([[name]] [[name|alias]] yes name)
    let line: Int              // source markdown ok (0-indexed)
    let offset: Int            // source markdown offset

    init(text: String, target: String, line: Int, offset: Int) {
        self.text = text
        self.target = target
        self.line = line
        self.offset = offset
    }
}

/// InternalLinkParser: Markdown `[[name]]` / `[[name|alias]]`
/// Obsidian wikilink format 1:1, SilverBullet page ref
enum InternalLinkParser {
    /// ok `[[name]]` `[[name|alias]]`
    ///: `[[` + `]` + `]]`, in progress `|` target / alias
    /// Apple HIG: NSRegularExpression Markdown
    private static let pattern: NSRegularExpression = {
        // \[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\] — group 1 = target, group 2 = optional alias
        // Per Apple HIG + 12 standard P2-01 fatalError 收口: the
        // NSRegularExpression literal is non-rare (= the regex is
        // statically embedded in this file; = an edit to the literal
        // is the only way this `try?` can fail). Treat the failure as
        // a programmer error (= logger.error + return empty matches)
        // rather than a runtime crash.
        guard let re = try? NSRegularExpression(pattern: #"\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]"#) else {
            os.Logger(subsystem: "com.wenshu.app", category: "linkgraph")
                .error("[wenshu.linkgraph] InternalLinkParser pattern compile failed (= editor bug; = all internal links silently disabled)")
            return NSRegularExpression()
        }
        return re
    }()

    /// 1 markdown content, link
    static func parse(_ content: String) -> [InternalLink] {
        var results: [InternalLink] = []
        let nsContent = content as NSString
        let fullRange = NSRange(location: 0, length: nsContent.length)
        let matches = pattern.matches(in: content, range: fullRange)
        for match in matches {
            // group 1: target ()
            let targetRange = match.range(at: 1)
            guard targetRange.location != NSNotFound,
                  let targetSwiftRange = Range(targetRange, in: content)
            else { continue }
            let target = String(content[targetSwiftRange])

            // group 2: alias ()
            var text = target
            let aliasRange = match.range(at: 2)
            if aliasRange.location != NSNotFound,
               let aliasSwiftRange = Range(aliasRange, in: content) {
                text = String(content[aliasSwiftRange])
            }

            // line: \n match.location
            let line = lineNumber(in: content, at: match.range.location)
            results.append(InternalLink(text: text, target: target, line: line, offset: match.range.location))
        }
        return results
    }

    /// content offset, 0-indexed ok
    private static func lineNumber(in content: String, at offset: Int) -> Int {
        let prefix = (content as NSString).substring(to: min(offset, (content as NSString).length))
        var count = 0
        for char in prefix {
            if char == "\n" { count += 1 }
        }
        return count
    }
}
