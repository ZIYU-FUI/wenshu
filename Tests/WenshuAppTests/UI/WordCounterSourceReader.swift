//
//  WordCounterSourceReader.swift · WenshuAppTests
//
//  The reader the editor's word-count path is guarded by.
//
//  THE QUESTION IT ANSWERS: = = for every production file, = = WHICH
//  MEMBER of the editor's word-count type does this file call, = = and
//  does that member REACH the linguistic segmentation?
//
//  ⇒ ⇒ AND THE MEMBER SET IS READ, NOT ASSUMED: = = the type's own
//  declaration (= = its body, = = plus every extension of it) says
//  which members exist, = = and their own bodies say which of them
//  reach the segmentation. = = ⇒ So a member the type gains LATER (= =
//  a `wordCount` API, = = a wrapper around the full count) is
//  classified by what its body does, = = and it cannot hide behind a
//  name the reader does not know.
//
//  ⇒ ⇒ AND THE TYPE IS RESOLVED THROUGH ITS ALIASES: = = a
//  `typealias` in the tree names the same type, = = so a call written
//  through the alias is a call to the type's member (= = and the alias
//  is read from the tree, = = not from a list).
//
//  ⇒ ⇒ AND THE ROOT IS THE MECHANISM, NOT A MEMBER NAME: = = the
//  expensive thing is the LINGUISTIC SEGMENTATION (= =
//  `enumerateSubstrings(.byWords)`), = = so the reader's reachability
//  starts at the member that performs it. = = ⇒ Renaming the counter's
//  members does not move the guard, = = and if the segmentation ever
//  leaves the counter's declaration the reader FAILS LOUD (= = it never
//  passes silently on a tree it cannot read).
//
//

import Foundation

/// The reader of the editor's word-count type, = = and of the
/// production files that call it.
enum WordCounterSourceReader {
    // MARK: - What the tree says

    /// What the counter type's own declaration says.
    struct CounterType {
        /// Every member the type declares (= = its own body, = = plus
        /// every extension of it), = = sorted.
        let members: [String]

        /// The members that REACH the linguistic segmentation (= = the
        /// members a production file may not call).
        let expensive: Set<String>

        /// The names that DENOTE the type (= = the type's own name, = =
        /// plus every module-wide alias of it in the tree).
        let typeNames: Set<String>

        /// The members another file may call that do NOT reach the
        /// segmentation (= = the fast path).
        let cheap: Set<String>
    }

    /// The whole production tree, = = read.
    struct Tree {
        /// The counter type's declaration.
        let counter: CounterType

        /// Per production file, = = the counter members the file
        /// mentions (= = the members whose names follow the type's name
        /// or one of its aliases).
        let mentions: [String: Set<String>]
    }

    /// Why the reader could not read the tree.
    enum ReaderError: Error, CustomStringConvertible {
        /// The counter type's declaration is not in the tree.
        case noDeclaration

        /// No member of the counter type performs the linguistic
        /// segmentation (= = the reader's root moved, = = so the guard
        /// cannot certify anything).
        case noSegmentationRoot

        /// A file names a member the counter type does not declare.
        case unknownMember(String)

        var description: String {
            switch self {
            case .noDeclaration:
                return "the counter type's declaration is not in the production tree"
            case .noSegmentationRoot:
                return "no member of the counter type performs the linguistic segmentation (= the reader's root moved)"
            case let .unknownMember(name):
                return "the counter type declares no member named \(name)"
            }
        }
    }

    /// One member of the counter type, = = with the text of its own
    /// declaration (= = the lines from its declaration to the next
    /// member's).
    private struct Member {
        let name: String
        let region: String
        let isPrivate: Bool
    }

    /// One `typealias` the tree carries.
    private struct Alias {
        let name: String
        let target: String
        /// The file that declares it (= = a private alias is visible
        /// there only).
        let scope: String
        /// Whether the alias is private (= = and so visible in its own
        /// file only).
        let isPrivate: Bool
    }

    // MARK: - The tree

    /// The production tree, = = read once (= = the counter type's
    /// members, = = the aliases, = = and the mentions).
    static func readTree() throws -> Tree {
        let paths = try SourceLocator.swiftFilesUnderSources()

        var maskedFiles: [String: String] = [:]
        var aliases: [Alias] = []
        var declarations: [Member] = []
        for path in paths {
            let masked = try SourceCodeMask.code(of: SourceLocator.read(path))
            maskedFiles[path] = masked
            aliases += typeAliases(in: masked, scopedTo: path)
            declarations += members(ofTheCounterTypeIn: masked)
        }

        let typeNames = resolvedTypeNames(aliases: aliases, scopedTo: nil)
        let memberNames = Array(Set(declarations.map(\.name))).sorted()
        let expensive = expensiveMembers(declarations)

        // ⇒ ⇒ THE READER FAILS LOUD, = = and it never passes silently
        // = = on a tree it could not read.
        guard !declarations.isEmpty else { throw ReaderError.noDeclaration }
        guard !expensive.isEmpty else { throw ReaderError.noSegmentationRoot }

        let declaredNames = Set(memberNames)
        let cheap = Set(declarations.filter { !$0.isPrivate }.map(\.name)).subtracting(expensive)

        var mentions: [String: Set<String>] = [:]
        for (path, masked) in maskedFiles {
            let names = typeNames.union(resolvedTypeNames(aliases: aliases, scopedTo: path))
            mentions[path] = try membersMentioned(
                in: masked,
                typeNames: names,
                memberNames: declaredNames
            )
        }

        return Tree(
            counter: CounterType(
                members: memberNames,
                expensive: expensive,
                typeNames: typeNames,
                cheap: cheap
            ),
            mentions: mentions
        )
    }

    // MARK: - The counter type's own declaration

    /// The counter type's members, = = read from its declaration and
    /// from every extension of it.
    private static func members(ofTheCounterTypeIn masked: String) -> [Member] {
        guard masked.contains("WordCounter") else { return [] }
        var found: [Member] = []
        for region in declaringRegions(ofTheCounterTypeIn: masked) {
            found += members(inDeclaringRegion: region)
        }
        return found
    }

    /// The bodies of the counter type's declaration, = = one per
    /// declaration (= = its own body, = = and each extension's).
    private static func declaringRegions(ofTheCounterTypeIn masked: String) -> [String] {
        let pattern = #"(?:enum|struct|class|extension)\s+WordCounter\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(masked.startIndex..., in: masked)
        var regions: [String] = []
        for match in regex.matches(in: masked, range: range) {
            let after = masked.index(masked.startIndex, offsetBy: match.range.upperBound)
            guard let open = masked.range(of: "{", range: after ..< masked.endIndex),
                  let close = matchingBrace(in: masked, from: open.lowerBound)
            else { continue }
            regions.append(String(masked[open.upperBound ..< close]))
        }
        return regions
    }

    /// The members one declaring region holds, = = each with the text
    /// of its own declaration.
    private static func members(inDeclaringRegion region: String) -> [Member] {
        let lines = region.components(separatedBy: "\n")

        // ⇒ ⇒ AND THE MEMBERS ARE THE DECLARATIONS AT THE TYPE'S OWN
        // = = LEVEL: = = a local inside a member's body sits deeper, = =
        // = = and it is not a member. = ⇒ ⇒ AND THE DEPTH IS COUNTED ON
        // = = EVERY LINE, = = = because the line that CLOSES a body is
        // = = = the line that takes the depth back down.
        var depth = 0
        var found: [(name: String, line: Int, isPrivate: Bool)] = []
        for (index, line) in lines.enumerated() {
            if depth == 0, let declaration = memberDeclaration(in: line) {
                found.append((declaration.name, index, declaration.isPrivate))
            }
            depth += braceDelta(of: line)
        }

        // ⇒ ⇒ AND EACH MEMBER'S REGION IS ITS OWN DECLARATION, = = so
        // = = the reader asks the member what its body does.
        var members: [Member] = []
        for (index, entry) in found.enumerated() {
            let end = index + 1 < found.count ? found[index + 1].line : lines.count
            var text = ""
            for line in entry.line ..< end {
                text += lines[line] + "\n"
            }
            members.append(Member(name: entry.name, region: text, isPrivate: entry.isPrivate))
        }
        return members
    }

    /// The member a line declares, = = or nil when the line declares
    /// no member.
    private static func memberDeclaration(in line: String) -> (name: String, isPrivate: Bool)? {
        let pattern = #"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|private|internal|fileprivate|open|static|final|mutating|nonisolated|override|class|convenience|required|lazy|weak|unowned|prefix|postfix|infix)\s+)*(?:func|var|let)\s+([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let found = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
        else { return nil }
        let nameRange = found.range(at: 1)
        guard nameRange.location != NSNotFound else { return nil }
        let nsLine = line as NSString
        let name = nsLine.substring(with: nameRange)
        let prefix = nsLine.substring(to: nameRange.location).lowercased()
        // ⇒ ⇒ AND THE ACCESS LEVEL IS THE DECLARATION'S OWN: = = a
        // = = `private` member is another file's business nowhere, = =
        // = = and a `fileprivate` one is this file's business only.
        let words = prefix.split(whereSeparator: { $0 == " " || $0 == "\t" })
        let isPrivate = words.contains("private") || words.contains("fileprivate")
        return (name, isPrivate)
    }

    /// How many braces a line opens minus how many it closes.
    private static func braceDelta(of line: String) -> Int {
        var delta = 0
        for character in line {
            if character == "{" {
                delta += 1
            }
            if character == "}" {
                delta -= 1
            }
        }
        return delta
    }

    /// The index of the brace that closes the one at `open`.
    private static func matchingBrace(in masked: String, from open: String.Index) -> String.Index? {
        var depth = 0
        var index = open
        while index < masked.endIndex {
            if masked[index] == "{" {
                depth += 1
            }
            if masked[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            index = masked.index(after: index)
        }
        return nil
    }

    // MARK: - Which members reach the segmentation

    /// The members that reach the linguistic segmentation.
    ///
    /// ⇒ ⇒ AND THE ROOT IS THE MECHANISM: = = the member whose body
    /// = = performs the segmentation, = = and a member that calls it
    /// = = reaches it.
    private static func expensiveMembers(_ declarations: [Member]) -> Set<String> {
        var expensive: Set<String> = []
        for member in declarations
            where member.region.contains("enumerateSubstrings") && member.region.contains(".byWords")
        {
            expensive.insert(member.name)
        }

        // ⇒ ⇒ AND THE REACH CLOSES OVER THE TYPE'S OWN CALLS: = = a
        // = = wrapper around the full count reaches the segmentation, = =
        // = = because the full count performs it.
        var changed = true
        while changed {
            changed = false
            for member in declarations where !expensive.contains(member.name) {
                for sibling in declarations
                    where sibling.name != member.name && expensive.contains(sibling.name)
                {
                    if calls(member.region, sibling.name) {
                        expensive.insert(member.name)
                        changed = true
                        break
                    }
                }
            }
        }
        return expensive
    }

    /// Whether a region CALLS a sibling member (= = the sibling's name
    /// followed by a paren, = = either unqualified or through `Self`).
    ///
    /// ⇒ ⇒ AND A LOCAL SHADOWS THE SIBLING FROM ITS DECLARATION ON: = =
    /// = = a local named like a member is not a call to it (= = = but
    /// = = = only after the local is declared, = = = because the code
    /// = = = before it cannot mean the local).
    private static func calls(_ region: String, _ sibling: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: sibling)
        let pattern = #"(?:^|[^A-Za-z0-9_.])(?:(Self|WordCounter)\s*\.\s*)?"# + escaped + #"\s*\("#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(region.startIndex..., in: region)
        let locals = localNames(in: region)
        for match in regex.matches(in: region, range: range) {
            let qualified = match.range(at: 1).location != NSNotFound
            if !qualified, let shadow = locals[sibling], shadow < match.range.location {
                continue
            }
            return true
        }
        return false
    }

    /// The names a region declares as locals, = = each with where the
    /// declaration sits.
    private static func localNames(in region: String) -> [String: Int] {
        guard let regex = try? NSRegularExpression(pattern: #"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)"#) else {
            return [:]
        }
        var names: [String: Int] = [:]
        for match in regex.matches(in: region, range: NSRange(region.startIndex..., in: region)) {
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound else { continue }
            let name = (region as NSString).substring(with: nameRange)
            let position = names[name] ?? match.range.location
            names[name] = min(position, match.range.location)
        }
        return names
    }

    // MARK: - The aliases

    /// The `typealias` declarations the tree carries.
    ///
    /// ⇒ ⇒ AND THE TARGET IS ITS LAST COMPONENT: = = `typealias W =
    /// = = = WenshuApp.WordCounter` names the counter, = = = and the
    /// = = = reader must see it.
    private static func typeAliases(in masked: String, scopedTo scope: String) -> [Alias] {
        guard masked.contains("typealias") else { return [] }
        let pattern = #"\b((?:public|private|fileprivate|internal)?\s*)typealias\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*((?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var aliases: [Alias] = []
        for match in regex.matches(in: masked, range: NSRange(masked.startIndex..., in: masked)) {
            let modifierRange = match.range(at: 1)
            let nameRange = match.range(at: 2)
            let pathRange = match.range(at: 3)
            guard modifierRange.location != NSNotFound,
                  nameRange.location != NSNotFound,
                  pathRange.location != NSNotFound
            else { continue }
            let nsMasked = masked as NSString
            let target = nsMasked.substring(with: pathRange).split(separator: ".").last.map(String.init) ?? ""
            guard !target.isEmpty else { continue }
            let access = nsMasked.substring(with: modifierRange)
                .trimmingCharacters(in: .whitespaces).lowercased()
            aliases.append(
                Alias(
                    name: nsMasked.substring(with: nameRange),
                    target: target,
                    scope: scope,
                    isPrivate: access == "private" || access == "fileprivate"
                )
            )
        }
        return aliases
    }

    /// The names that denote the counter type: = = its own name, = =
    /// plus every alias that resolves to it.
    ///
    /// ⇒ ⇒ AND A PRIVATE ALIAS IS VISIBLE IN ITS OWN FILE ONLY: = = so
    /// = = the resolution is scoped to the file that declares it.
    private static func resolvedTypeNames(aliases: [Alias], scopedTo scope: String?) -> Set<String> {
        var names: Set = ["WordCounter"]
        var changed = true
        while changed {
            changed = false
            for alias in aliases
                where names.contains(alias.target) && !names.contains(alias.name)
                && (alias.scope == scope || (!alias.isPrivate && scope == nil))
            {
                names.insert(alias.name)
                changed = true
            }
        }
        return names
    }

    // MARK: - The mentions

    /// The counter members a file mentions, = = read from the file's
    /// code (= = its comments and string literals blanked).
    ///
    /// ⇒ ⇒ AND AN UNRESOLVED MEMBER IS AN ERROR, = = not a silence: = =
    /// = = the reader must not pass on a tree whose shape it cannot
    /// = = = read.
    private static func membersMentioned(
        in masked: String,
        typeNames: Set<String>,
        memberNames: Set<String>
    ) throws -> Set<String> {
        var mentioned: Set<String> = []
        for typeName in typeNames {
            guard masked.contains(typeName) else { continue }
            var search = masked.startIndex ..< masked.endIndex
            while let found = masked.range(of: typeName, range: search) {
                search = found.upperBound ..< masked.endIndex
                // ⇒ ⇒ THE NAME MUST STAND ALONE: = = a longer identifier
                // = = that starts with it is a different type.
                if found.lowerBound > masked.startIndex {
                    let previous = masked[masked.index(before: found.lowerBound)]
                    if previous.isLetter || previous.isNumber || previous == "_" {
                        continue
                    }
                }
                var index = skippingWhitespace(in: masked, from: found.upperBound)
                guard index < masked.endIndex, masked[index] == "." else { continue }
                index = skippingWhitespace(in: masked, from: masked.index(after: index))
                // ⇒ ⇒ AND `Type.self.member` IS THE SAME MEMBER: = = the
                // = = reader does not stop at `self`.
                if let self = masked.range(of: "self", range: index ..< masked.endIndex),
                   self.lowerBound == index
                {
                    index = skippingWhitespace(in: masked, from: self.upperBound)
                    guard index < masked.endIndex, masked[index] == "." else { continue }
                    index = skippingWhitespace(in: masked, from: masked.index(after: index))
                }
                guard index < masked.endIndex, masked[index].isLetter || masked[index] == "_" else {
                    continue
                }
                var end = index
                while end < masked.endIndex,
                      masked[end].isLetter || masked[end].isNumber || masked[end] == "_"
                {
                    end = masked.index(after: end)
                }
                let name = String(masked[index ..< end])
                // ⇒ ⇒ A TYPE-LEVEL QUALIFIER IS NOT A MEMBER: = = `self`
                // = = and `Type` name the type, = = not one of its
                // = = members.
                guard name != "self", name != "Type" else { continue }
                guard memberNames.contains(name) else {
                    throw ReaderError.unknownMember(name)
                }
                mentioned.insert(name)
            }
        }
        return mentioned
    }

    /// The first index at or after `index` that carries no whitespace.
    private static func skippingWhitespace(in masked: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < masked.endIndex, masked[cursor].isWhitespace {
            cursor = masked.index(after: cursor)
        }
        return cursor
    }
}
