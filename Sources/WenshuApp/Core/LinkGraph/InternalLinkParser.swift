//
// InternalLinkParser.swift · Wenshu · v0.19 ticket 12 (Obsidian replica, do first)
// 2026-08-19 evening Obsidian A + ', '.
//
// Markdown `[[name]]` . SilverBullet page ref / Obsidian wikilink, .
// Apple HIG: Foundation NSRegularExpression +, Markdown .
//

import Foundation

/// 1 Internal Link = Parsing Results
public struct InternalLink: Equatable, Sendable {
    public let text: String           // show ([[name|alias]] yes alias)
    public let target: String         // ref ([[name]] [[name|alias]] yes name)
    public let line: Int              // source markdown ok (0-indexed)
    public let offset: Int            // source markdown offset

    public init(text: String, target: String, line: Int, offset: Int) {
        self.text = text
        self.target = target
        self.line = line
        self.offset = offset
    }
}

/// InternalLinkParser: Markdown `[[name]]` / `[[name|alias]]`
/// Obsidian wikilink format 1:1, SilverBullet page ref
public enum InternalLinkParser {
    /// ok `[[name]]` `[[name|alias]]`
    ///: `[[` + `]` + `]]`, in progress `|` target / alias
    /// Apple HIG: NSRegularExpression Markdown
    private static let pattern: NSRegularExpression = {
        // \[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\] — group 1 = target, group 2 = optional alias
        guard let re = try? NSRegularExpression(pattern: #"\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]"#) else {
            fatalError("InternalLinkParser pattern compile failed")
        }
        return re
    }()

    /// 1 markdown content, link
    public static func parse(_ content: String) -> [InternalLink] {
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
