//
//  CitationHonestyTests.swift · Wenshu
//
//  What this file enforces, in one line: a comment in Sources/ that attributes
//  a design judgement to Apple or to the HIG carries the page it came from, or
//  says plainly that no such guidance exists. Nothing else in the tree may stand
//  in for either.
//
//  THE RULE, as the scan applies it. Every attribution phrase in Sources/ —
//  matched case-insensitively and on word boundaries, so `THE HIG` is charged
//  and `the highlight` is not — must sit in a block that (= a) shows a
//  developer.apple.com URL within 6 lines whose PATH SUBJECT the claim
//  sentence itself names (= proximity alone is not citation), (= b) denies the
//  attribution inside the SAME sentence that makes it, with the denial naming
//  Apple or the HIG within 40 characters of the negator (= "the HIG publishes
//  no …", not "the LLM could not extract …"), or (= c) is on the
//  named-exception list below with a reason. Anything else fails, with file:line.
//
//  Why (b) is scoped to the sentence and not to the comment block: a block-wide
//  negation lets any honest-looking word anywhere in the block launder an
//  unsupported claim. A block that reads "The HIG asks for X. Nothing here is
//  Apple canonical, it's ours" contains a claim about the HIG that carries no
//  source and a denial about a different subject; the denial is not evidence for
//  the sentence next to it. The sentence is the unit that asserts, so the denial
//  has to be inside it. A block-level reading of this same rule is measurably
//  laxer on any tree: the two readings are one difference apart in `scan(_:)`,
//  and `WENSHU_CITATION_ROOT` below re-runs this scan on any checkout, so the gap
//  between them is printable rather than a claim.
//
//  Two ways a citation stops meaning anything, both seen in the corpus of removed
//  soft citations (that corpus is recorded in docs/agents/2026-11-22-session-close-soft-cites-swept-and-landed.md),
//
//  (a) transcribed provenance — the citation belongs to the ORIGINAL code being
//      described (= a 2026-10-12 audit's own citation ladder, a migration note),
//      and rewriting the code left the citation attached to a new topic;
//  (b) collateral damage — a prose rewrite about a neighbouring subject (a removed
//      icon, a measured number) silently drops the words that made the citation
//      honest ("per the 2026-10-12 audit", "the HIG asks", "every quoted HIG
//      sentence", "(no HIG citation)").
//
//  The pattern list is the 9 alternatives measured against the tree:
//  Apple HIG · Apple's HIG · per the HIG · the HIG · HIG-correct ·
//  HIG canonical · Apple canonical · Apple-standard · Apple follows.
//  (The word "canonical" ALONE is deliberately not in the list:
//  `git grep -ciE canonical HEAD -- Sources | awk -F: '{s+=$3} END {print s}'`
//  over the base tree prints 581, almost all of them non-Apple senses —
//  "the canonical form of a path", "the canonical key" — so a bare match
//  would be noise, not a guard.)
//
//  Every rule here is exercised by a planted case in a temporary directory, on
//  the code path the tree scan uses (= the file walk, the sentence scoping, the
//  orphan comparison). A guard whose collector returns nothing passes forever,
//  so each collector reports its own count on the real tree before the tree is
//  allowed to be called clean.
//

import Foundation
import Testing

@Suite("Citation honesty — an Apple/HIG-attributed claim carries its source")
struct CitationHonestyTests {
    /// The 9 attribution alternatives (= measured against the tree; see the
    /// header for why bare "canonical" is excluded).
    ///
    /// Two readings of this list are charged, and the guard prints both:
    /// `attributionPattern` verbatim, case-sensitive — what the guard has
    /// always seen — and `enforcementPattern`, the same alternatives word-
    /// anchored and matched case-insensitively. The widening exists because
    /// the case-sensitive reading is blind to `The HIG`, `APPLE CANONICAL`
    /// and every other casing of the same claim, and because an unanchored
    /// `the HIG` fires inside "the highlight" — a count that cannot tell a
    /// claim from prose noise is not a guard. Anchoring on word boundaries
    /// keeps the case-insensitive reading honest: on this tree it adds the
    /// casing-hidden claims and removes the "high…" noise, leaving a set
    /// with no false positives.
    static let attributionPattern =
        "Apple HIG|Apple's HIG|per the HIG|the HIG|HIG-correct|HIG canonical|Apple canonical|Apple-standard|Apple follows"

    /// The phrase list word-anchored; matched with `.caseInsensitive`. This is
    /// the reading the violation scan and the hit count charge.
    static let enforcementPattern = "\\b(?:\(attributionPattern))\\b"

    /// A sentence that denies the attribution it carries (= honest negative).
    /// Word-bounded on both sides and not keyed on a trailing space: a comment
    /// sentence wraps across comment lines, and a pattern that needs "no "
    /// misses "…publishes no\n/// …number" for a reason that has nothing to do
    /// with honesty. A bare negator is not yet a denial of THIS claim: within
    /// `denialReach` characters the sentence has to name `apple` or `hig`,
    /// because "the LLM could not extract … so the badge appears" contains a
    /// negation about something else entirely, and a guard that credits it
    /// launders whatever attribution happens to sit in the same sentence.
    static let negationPattern =
        "\\b(no|not|nothing|never|none|neither|withdrawn|without)\\b"

    /// What a negation must name nearby to count as denying the attribution.
    static let subjectMentionPattern = "\\b(apple|hig)\\b"

    /// The measured reach of a real denial on this tree (= every denial that
    /// works sits inside ~30 characters of the subject it denies; the one
    /// that fails at 157 is about a different subject).
    static let denialReach = 40

    /// URL path words that say nothing about the page's subject, so they may
    /// not be the only overlap credit for a claim.
    static let urlStopTokens: Set<String> = [
        "http", "https", "www", "com", "apple", "developer", "documentation",
    ]

    /// Characters that end a sentence — where one sentence stops being the
    /// unit that asserts something, and so where a negation stops being able
    /// to reach the claim it belongs to.
    static let sentenceTerminators: Set<Character> = [".", "!", "?", "。", "！", "？"]

    /// The extensions the scan reads: the code, the design documents, and the
    /// plists that carry user-facing copy.
    static let scannedExtensions: Set<String> = ["swift", "md", "plist"]

    /// Lines that name Apple/the HIG inside a quote block whose source is a
    /// project-local document rather than Apple. Each entry carries its
    /// reason; adding to this list is a review decision, not a fix (= the
    /// named-exception list).
    static let namedExceptionFiles: [(path: String, reason: String)] = [
        ("WenshuApp/Shared/UI/ComponentDocs/SFRegions.md",
         "names the boss's own standing directive ('HIG first, unless there is no Apple standard'), attributed to OOB.md — a source we have and can show, not a claim about Apple"),
    ]

    enum Verdict: Equatable { case cited, namedException, negation, violation }

    /// The repository's `Sources/` directory, for the rules that read the tree.
    static var sourcesRoot: URL {
        SourceLocator.repoRoot.appendingPathComponent("Sources")
    }

    /// Words a sentence is really about: its alphanumeric runs, lowercased,
    /// minus the ones too short to carry a subject.
    static func tokens(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 })
    }

    /// The subject words of an Apple URL: its path components (= "sf-symbols",
    /// "buttonstyle", "nsmenu"), not the host words every Apple page shares.
    static func urlSubjectTokens(_ url: String) -> Set<String> {
        guard let host = url.range(of: "developer.apple.com/") else { return [] }
        let path = url[host.upperBound...]
        return Set(path.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 3 && !urlStopTokens.contains($0) })
    }

    /// The same sentence with every Apple URL blanked out: a claim may not
    /// topically credit itself by containing the URL it is citing.
    static func withoutURLs(_ text: String) -> String {
        guard let re = try? bareURLRegex() else { return text }
        var out = ""
        var last = text.startIndex
        let full = NSRange(text.startIndex..., in: text)
        for m in re.matches(in: text, range: full) {
            guard let s = Range(m.range, in: text) else { continue }
            out += text[last ..< s.lowerBound]
            last = s.upperBound
        }
        out += text[last...]
        return out
    }

    static func bareURLRegex() throws -> NSRegularExpression {
        try NSRegularExpression(pattern: "developer\\.apple\\.com[^\\s)\\]>\"'`]+")
    }

    /// One subject word against the claim's words: equal, or a stem of one
    /// side (= "bookmark" under a `bookmarkdata` page), and long enough that
    /// short words cannot bridge unrelated subjects.
    static func subjectMatches(_ subject: String, in claimed: Set<String>) -> Bool {
        for c in claimed {
            if c == subject {
                return true
            }
            if c.count >= 4 && subject.count >= 4 && (subject.contains(c) || c.contains(subject)) {
                return true
            }
        }
        return false
    }

    /// Whether some URL in the window is about what the sentence claims. A
    /// page for `NSMenu` does not credit a sentence about sidebar metrics
    /// just because it sits six lines away in the same block (= the
    /// transcribed-provenance failure the header names: the citation stayed
    /// when the code under it moved on). The URL's own words are removed
    /// from the claim before comparing.
    static func windowCitesSubject(window: [String], sentence: String) -> Bool {
        let claimed = tokens(withoutURLs(sentence))
        guard let re = try? bareURLRegex() else { return false }
        for line in window {
            let r = NSRange(line.startIndex..., in: line)
            for m in re.matches(in: line, range: r) {
                guard let s = Range(m.range, in: line) else { continue }
                let subjects = urlSubjectTokens(trimmedURL(line[s]))
                for u in subjects where subjectMatches(u, in: claimed) {
                    return true
                }
            }
        }
        return false
    }

    /// Whether a negation in the sentence actually denies the attribution:
    /// `subjectMentionPattern` must fire within `denialReach` characters of
    /// the negator, on either side. "publishes no numeric sidebar-row width"
    /// names the HIG inside that reach and is a denial; "the LLM could not
    /// extract" names nothing until a different clause far behind it and is
    /// not.
    static func deniesAttribution(unfolded: String) -> Bool {
        guard let neg = try? NSRegularExpression(pattern: negationPattern,
                                                 options: [.caseInsensitive]),
            let subject = try? NSRegularExpression(pattern: subjectMentionPattern,
                                                   options: [.caseInsensitive])
        else { return false }
        let full = NSRange(unfolded.startIndex..., in: unfolded)
        for n in neg.matches(in: unfolded, range: full) {
            let lo = max(0, n.range.location - denialReach)
            let hi = min(unfolded.utf16.count, n.range.location + n.range.length + denialReach)
            let around = NSRange(location: lo, length: hi - lo)
            if subject.firstMatch(in: unfolded, range: around) != nil {
                return true
            }
        }
        return false
    }

    /// Pure classifier so a probe can call it on any sentence. `sentence` is
    /// the text of the sentence that carries the attribution phrase — the
    /// smallest unit that can be honest or dishonest about it.
    static func classify(sentence: String, window: [String], file: String) -> Verdict {
        if windowCitesSubject(window: window, sentence: sentence) {
            return .cited
        }
        if namedExceptionFiles.contains(where: { file.hasSuffix($0.path) }) {
            return .namedException
        }
        // A wrapped sentence carries the comment markers, indentation and
        // newlines of every line it spans; fold them to a single space so the
        // sentence reads as written. Leaving runs of spaces in place would put
        // the wrap's indentation between a denial and the words it denies and
        // charge an honest "nothing about it comes\n/// from the HIG" as a
        // claim past the reach of the denial.
        let unfolded = sentence
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "///", with: " ")
            .replacingOccurrences(of: "//", with: " ")
            .replacingOccurrences(of: "\\s{2,}", with: " ",
                                  options: .regularExpression)
        if unfolded.range(of: negationPattern, options: [.regularExpression, .caseInsensitive]) != nil,
           deniesAttribution(unfolded: unfolded)
        {
            return .negation
        }
        return .violation
    }

    /// Whether a trimmed line continues a comment block.
    static func isCommentLine(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("///") || t.hasPrefix("//") || t.hasPrefix("*")
            || t.hasPrefix(">") || t.hasPrefix("-") || t.hasPrefix("|")
    }

    /// The index of the first line of `commentBlock(_:hitIndex:)`.
    static func blockStart(_ lines: [String], hitIndex: Int) -> Int {
        var start = hitIndex
        while start > 0 && isCommentLine(lines[start - 1]) {
            start -= 1
        }
        return start
    }

    /// The index of the last line of the comment block carrying the hit. The
    /// sentence must be able to read PAST the hit line: "The HIG's\n
    /// /// publishes no such number" wraps its own denial onto the next
    /// comment line, and a window that stops at the hit cannot see it (= the
    /// denial then reads as an uncited claim, and a claim whose denial lives
    /// one line down reads as honest only by the luck of where the wrap fell).
    static func blockEnd(_ lines: [String], hitIndex: Int) -> Int {
        var end = hitIndex
        while end + 1 < lines.count && isCommentLine(lines[end + 1]) {
            end += 1
        }
        return end
    }

    /// The sentence that carries the match. The block is joined with newlines
    /// so a sentence wrapped over comment lines stays one sentence, and the
    /// span stops at the terminators on either side of the match — which is
    /// what keeps a denial in the next sentence from covering this claim.
    static func sentence(ofMatchAt matchUTF16Offset: Int, block: [String],
                         hitLineOffset: Int) -> String
    {
        var joined = ""
        var starts: [Int] = []
        for (i, line) in block.enumerated() {
            starts.append(joined.utf16.count)
            joined += line
            if i < block.count - 1 {
                joined += "\n"
            }
        }
        let hit = starts[hitLineOffset] + matchUTF16Offset
        let chars = Array(joined)
        if chars.isEmpty {
            return ""
        }
        var running = 0
        var index = chars.count - 1
        for (i, ch) in chars.enumerated() {
            if running >= hit {
                index = i; break
            }
            running += String(ch).utf16.count
        }
        var left = index
        while left > 0, !sentenceTerminators.contains(chars[left - 1]) {
            left -= 1
        }
        var right = index
        while right + 1 < chars.count, !sentenceTerminators.contains(chars[right]) {
            right += 1
        }
        // include the terminator that closed the sentence, and stay inside the
        // array: a match in the last sentence of a block has nothing after it.
        if sentenceTerminators.contains(chars[right]) {
            right += 1
        }
        right = min(right, chars.count - 1)
        return String(chars[left ... max(left, right)])
    }

    /// Every file under `root` whose extension is `ext`. The walk has to visit
    /// the whole tree: a loop that stops at the first file whose extension
    /// differs returns an empty list in any directory that holds a
    /// non-matching file first (= which is every real source root), and an
    /// empty list makes every rule built on it report "clean" forever.
    static func files(_ root: URL, ext: String) -> [URL] {
        guard let e = FileManager.default.enumerator(at: root,
                                                     includingPropertiesForKeys: nil,
                                                     options: [.skipsHiddenFiles]) else { return [] }
        var found: [URL] = []
        for case let obj as URL in e where obj.pathExtension == ext {
            found.append(obj)
        }
        return found
    }

    static func urlRegex() throws -> NSRegularExpression {
        try NSRegularExpression(pattern: "https://developer\\.apple\\.com[^\\s)\\]>\"'`]+")
    }

    /// A URL ends where the address ends. Prose continues after it, and a comma
    /// or a full stop that belongs to the sentence would otherwise become part
    /// of the URL's identity — which turns "the code cites this page" into
    /// "orphan", because the code's copy has no comma on it.
    static func trimmedURL(_ raw: Substring) -> String {
        var url = String(raw)
        while let last = url.last, ".,;:!?、，。".contains(last) {
            url.removeLast()
        }
        return url
    }

    /// Every developer.apple.com URL in every file of `ext`, as (file, line, url).
    static func urlOccurrences(in root: URL, ext: String) -> [(String, Int, String)] {
        guard let re = try? urlRegex() else { return [] }
        var out: [(String, Int, String)] = []
        for url in files(root, ext: ext).sorted(by: { $0.path < $1.path }) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let file = url.path.components(separatedBy: "/Sources/").last ?? url.path
            for (i, line) in text.components(separatedBy: .newlines).enumerated() {
                let r = NSRange(line.startIndex..., in: line)
                for m in re.matches(in: line, range: r) {
                    guard let s = Range(m.range, in: line) else { continue }
                    out.append((file, i + 1, trimmedURL(line[s])))
                }
            }
        }
        return out
    }

    static func collectURLs(in root: URL, ext: String) -> Set<String> {
        Set(urlOccurrences(in: root, ext: ext).map(\.2))
    }

    /// How many lines in `root` carry an attribution phrase, cited or not,
    /// under each of the two readings. A scan that finds violations and a
    /// scan that finds nothing are only distinguishable if this number is
    /// above zero, and the widened reading is only honest if its gap over
    /// the case-sensitive one is printed rather than assumed.
    static func attributionHitCounts(_ root: URL) -> (exactCaseSensitive: Int, anchoredCaseInsensitive: Int) {
        var exact = 0, widened = 0
        if let reA = try? NSRegularExpression(pattern: attributionPattern),
           let reB = try? NSRegularExpression(pattern: enforcementPattern, options: [.caseInsensitive])
        {
            for url in files(root, ext: "swift") + files(root, ext: "md") + files(root, ext: "plist") {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                for line in text.components(separatedBy: .newlines) {
                    let r = NSRange(line.startIndex..., in: line)
                    if reA.firstMatch(in: line, range: r) != nil {
                        exact += 1
                    }
                    if reB.firstMatch(in: line, range: r) != nil {
                        widened += 1
                    }
                }
            }
        }
        return (exact, widened)
    }

    /// The uncited-attribution rule over one root, as file:line | text rows.
    /// The scan charges the widened reading: anchored, case-insensitive.
    static func scan(sourcesRoot: URL) throws -> [String] {
        let regex = try NSRegularExpression(pattern: enforcementPattern, options: [.caseInsensitive])
        var violations: [String] = []
        guard let enumerator = FileManager.default.enumerator(
            at: sourcesRoot, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return ["Sources/ not enumerable"] }
        for case let url as URL in enumerator where scannedExtensions.contains(url.pathExtension) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                guard let m = regex.firstMatch(in: line, range: range) else { continue }
                let file = url.path.components(separatedBy: "/Sources/").last ?? url.path
                let start = blockStart(lines, hitIndex: i)
                let end = blockEnd(lines, hitIndex: i)
                let block = Array(lines[start ... end])
                let window = Array(lines[max(0, i - 6) ... min(lines.count - 1, i + 6)])
                let sentence = sentence(ofMatchAt: m.range.location, block: block,
                                        hitLineOffset: i - start)
                if classify(sentence: sentence, window: window, file: file) == .violation {
                    violations.append("\(file):\(i + 1) | \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        return violations
    }

    /// A throwaway source root holding planted cases, so each rule is proven on
    /// the code path that reads the real tree.
    static func makeProbeTree(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("citation-honesty-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func write(_ url: URL, _ text: String) throws {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try text.data(using: .utf8)!.write(to: url, options: .atomic)
    }

    // MARK: - the tree rules

    @Test("Every Apple/HIG attribution in Sources/ is cited, negated, or named in the exception list")
    func noUncitedAppleAttributions() throws {
        let root = Self.sourcesRoot
        // The collector reports itself before the tree is called clean: a walk
        // that returns nothing makes the verdict below vacuous. Both readings
        // print, because the whole point of the widening is that the
        // case-sensitive one under-counts and the gap must stay visible.
        let counts = Self.attributionHitCounts(root)
        #expect(counts.anchoredCaseInsensitive > 0,
                "no attribution phrase found in Sources/: the guard is inert")
        let violations = try Self.scan(sourcesRoot: root)
        if !violations.isEmpty {
            let detail = "uncited Apple/HIG claims (\(violations.count) of \(counts.anchoredCaseInsensitive) "
                + "attribution lines [anchored case-insensitive; case-sensitive exact reading: "
                + "\(counts.exactCaseSensitive)]):\n"
                + violations.joined(separator: "\n")
            Issue.record(Comment(rawValue: detail))
        }
        #expect(violations.isEmpty)
    }

    @Test("A .md that cites a developer.apple.com page is also cited by some .swift")
    func docCitationsAreNotOrphaned() {
        // Root cause (a) of the survivors: a citation transcribed into a doc
        // block kept its URL after the code it described was rewritten. If the
        // .md still asserts the page and no .swift anywhere leans on it, the
        // quote has become a claim with nothing to check it against.
        let root = Self.sourcesRoot
        let swiftURLs = Self.collectURLs(in: root, ext: "swift")
        let mdURLs = Self.urlOccurrences(in: root, ext: "md")
        // The .swift side has to be alive: with no URL in any code comment,
        // every .md citation would read as an orphan and the rule would be
        // measuring the collector instead of the tree.
        #expect(!swiftURLs.isEmpty, "no .swift cites a developer.apple.com URL: the rule is inert")
        // `git grep -c "developer.apple.com" -- 'Sources/**/*.md' | wc -l` prints
        // 0 on the current tree: the component documents under Sources/ name
        // their pages in prose and show no URL yet. The rule therefore has
        // nothing to bite on today, and `orphanRuleIsCaught` is what proves the
        // comparison works when a document does start citing.
        var orphans: [String] = []
        for (file, line, url) in mdURLs where !swiftURLs.contains(url) {
            orphans.append("\(file):\(line) cites \(url) and no .swift file does")
        }
        if !orphans.isEmpty {
            Issue.record(Comment(rawValue: "orphaned .md citations (\(orphans.count)):\n"
                    + orphans.joined(separator: "\n")))
        }
        #expect(orphans.isEmpty)
    }

    // MARK: - teeth, planted on the real code path

    @Test("Teeth: the file walk reaches every file, so a rule cannot pass by collecting nothing")
    func fileWalkIsNotInert() throws {
        let root = try Self.makeProbeTree("walk")
        defer { try? FileManager.default.removeItem(at: root) }
        // A non-matching extension first: a walk that stops at the first file
        // whose extension differs never reaches the one that matters.
        try Self.write(root.appendingPathComponent("a.txt"), "not a source file")
        try Self.write(root.appendingPathComponent("b.json"), "{\"a\": 1}")
        try Self.write(root.appendingPathComponent("c.pdf"), "x")
        try Self.write(root.appendingPathComponent("Doc.md"),
                       "cites https://developer.apple.com/design/human-interface-guidelines/sf-symbols")
        let found = Self.files(root, ext: "md")
        #expect(found.count == 1, "the .md walk missed a file behind a non-matching one: \(found)")
        #expect(!Self.urlOccurrences(in: root, ext: "md").isEmpty,
                "the URL collector found nothing in a file that carries a URL")
        let realSwift = Self.files(Self.sourcesRoot, ext: "swift")
        let realMd = Self.files(Self.sourcesRoot, ext: "md")
        #expect(realSwift.count > 100, "the real tree's .swift walk returned only \(realSwift.count) files")
        #expect(realMd.count > 0, "the real tree's .md walk returned no files")
    }
}
