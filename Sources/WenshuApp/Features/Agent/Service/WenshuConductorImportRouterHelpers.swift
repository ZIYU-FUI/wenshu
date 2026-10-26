// 
// … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

enum WCIRHelpers {

        // (webSearchToolSchema extracted to WCIRToolSchema.swift in A89; = see that file)
        // … (= 38 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // MARK: - shouldSkip
    static func shouldSkip(
        result: ContentSameResult
    ) -> Bool {
        return result.isContentSame
            && result.confidence >= ImportDocumentTemplate.contentSameConfidenceThreshold
}


        // MARK: - parseAndMap

    static func parseAndMap(
        raw: String,
        body: String,
        fallbackTitle: String,
        filePath: String
    ) -> ImportRoutingResult {
        // 1. Extract the JSON object. The LLM is instructed to reply with one line of
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // emit before the JSON).
        guard let json = extractFirstJSONObject(raw) else {
            // LLM returned no parseable JSON. Fall back to a safe default (= drafts is
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // orchestrator's downstream consumers don't crash).
            return ImportRoutingResult(
                destination: .bookFolder(.drafts),
                title: fallbackTitle,
                summary: "LLM 未返回可解析的 JSON；归类为草稿。",
                tags: [],
                entityType: "other",
                category: nil,
                confidence: 0.0,
                rewrittenBody: nil,
                extraFiles: [],
            )
    }
        // 2. Parse the JSON.
        let parsed = parseImportDecision(json)
        // 3. Map the destination. The orchestrator accepts a closed enum; = we coerce the
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // so we never write a string into the destination field).
        let destination: ImportDestination
        switch parsed.destination {
        case "referenceLibrary":
            destination = .referenceLibrary
        case "bookFolder":
            destination = .bookFolder(parsed.bookFolder ?? .drafts)
        default:
            // Unknown destination string from the LLM (= the model invented a value not
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // chat override).
            destination = .bookFolder(.drafts)
    }
        // 4. Final envelope. The LLM-supplied title is the canonical title (= the
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // from the source).
        return ImportRoutingResult(
            destination: destination,
            // (= boss "不能用 提示词控制" directive): the title is run through `acceptTitle` (=
            // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // filename-stem fallback").
            title: Self.acceptTitle(parsed: parsed, filePath: filePath),
            summary: parsed.summary,
            tags: Set(parsed.tags),
            entityType: "other",
            category: nil,
            confidence: parsed.tags.isEmpty ? 0.3 : 0.9,
            // the optional rewritten body (= the LLM's .ws-format body in
            // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // the mode-aware body selection).
            rewrittenBody: parsed.rewrittenBody,
            // extraFiles parsed by `parseImportDecision` (= see ticket 02). Empty array
            // when LLM doesn't return any (= most common case).
            extraFiles: parsed.extraFiles,
        )
}

    // / Fallback title (= the basename without the source-file extension; = used
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // MARK: - fallbackTitle
    static func fallbackTitle(from filePath: String) -> String {
        let fileName = (filePath as NSString).lastPathComponent
        let stem = (fileName as NSString).deletingPathExtension
        return stem.isEmpty ? "未命名" : stem
}

    // / (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). Programmatic
    // … (= 24 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // MARK: - sanitizeTitle
    static func sanitizeTitle(
        _ candidate: String,
        from filePath: String
    ) -> String? {
        // 1. Empty / whitespace-only.
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        // 2. Path separator (= "/" or "\") in the title.
        if candidate.contains("/") || candidate.contains("\\") {
            return nil
    }
        // 3. File extension at the end (= .md / .txt / .markdown / .docx ...). The LLM
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // the entity, not the filename).
        let knownExtensions: Set<String> = [
            "md", "markdown", "txt", "text",
            "docx", "doc", "pdf", "rtf",
            "html", "htm"
        ]
        let lower = candidate.lowercased()
        for ext in knownExtensions {
            if lower.hasSuffix("." + ext) {
                return nil
        }
    }
        // 4. Title equals the full source path (= LLM copied `input.filePath`).
        if candidate == filePath { return nil }
        // 5. Title equals the source file's lastPathComponent (= the LLM copied the
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // stripped form).
        let fileName = (filePath as NSString).lastPathComponent
        if candidate == fileName { return nil }
        // 6. Title too long (= not a real title).
        if candidate.count > 50 { return nil }
        // 7. Mostly digits / spaces / punctuation (= gibberish).
        let alnumCount = candidate.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }.count
        if Double(alnumCount) / Double(max(candidate.count, 1)) < 0.3 {
            return nil
    }
        // 8. Path-prefix match (= the title starts with the user's home directory path or
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // enough characters to be a giveaway).
        let homeDir = NSHomeDirectory()
        if !homeDir.isEmpty, candidate.hasPrefix(homeDir) {
            return nil
    }
        // All checks pass; = return the trimmed candidate (= the surrounding whitespace,
        // if any, is stripped).
        return trimmed
}

    // / (= boss 2026-10-09 (see OOB.md #2026-10-09) (= the sidebar's linkgraph =
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // MARK: - stripObsidianBacklinks
    static func stripObsidianBacklinks(_ body: String) -> String {
        var stripped: [String] = []
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)
            let trimmed = lineStr.trimmingCharacters(in: .whitespaces)
            // Drop any line containing a relative upward path (= "../" or "/../"; =
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // the Obsidian relative-link family).
            if lineStr.contains("../") { continue }
            // Drop any line containing a wikilink fragment (= "[[...]]"; = the Obsidian
            // autolink form).
            if lineStr.contains("[[") { continue }
            // Drop Obsidian-era metadata markers (= boss 2026-10-09 (see OOB.md
            // #2026-10-09) by prefix on the trimmed line).
            if Self.isUselessMetadataLine(trimmed) {
                continue
        }
            // Drop the "反链:" / "反链 :" header line too (= once we've stripped all the
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // this line is the Obsidian-era marker).
            if trimmed == "反链" || trimmed == "反链:" || trimmed == "反链 :" {
                continue
        }
            stripped.append(lineStr)
    }
        return stripped.joined(separator: "\n")
}

    // / (= boss 2026-10-09 (see OOB.md #2026-10-09) (= boss 2026-10-09 (see
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // MARK: - isUselessMetadataLine
    static func isUselessMetadataLine(_ trimmed: String) -> Bool {
        let prefixes: [String] = [
            // The old previous template (= 老板 2026-10-09 [archived-round] "不要参考 MD 的格式，而是盘点文枢的功
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // uses 实体类型/标签/摘 要 only).
            "类型:",
            "类型 :",
            "状态:",
            "状态 :",
            "核心信息:",
            "核心信息 :",
            "核心:",
            "核心 :",
            "详细描述:",
            "详细描述 :",
            "实体化:",
            "实体化 :",
            // Timestamps (= entities.json has createdAt / updatedAt already).
            "上次更新:",
            "上次更新 :",
            "更新于",
            "创建时间:",
            "创建时间 :",
            "创建于",
            "updated:",
            "updated :",
            "created:",
            "created :",
            "modified:",
            "modified :",
            // Tags (= tags are a separate field in the Reference struct).
            "tags:",
            "tags :",
            "tag:",
            "tag :",
            "标签:",
            "标签 :",
            "tags",
            "tag",
            "标签",
            // Author / source markers (= the .ws Reference struct has a `source` field; =
            // author markers are duplicated if they appear in the body).
            "作者:",
            "作者 :",
            "author:",
            "author :",
            "来源:",
            "来源 :",
            "source:",
            "source :",
        ]
        let lower = trimmed.lowercased()
        for p in prefixes {
            if lower.hasPrefix(p.lowercased()) { return true }
    }
        return false
}

        // MARK: - acceptTitle

    static func acceptTitle(parsed: ImportDecision, filePath: String) -> String {
        if let sanitized = Self.sanitizeTitle(parsed.title, from: filePath) {
            return sanitized
    }
        return Self.fallbackTitle(from: filePath)
}

    // MARK: - Private parsing

    /// Decoded subset of the LLM's JSON output.
    struct ImportDecision {
        var title: String
        var summary: String
        var tags: [String]
        var destination: String
        var bookFolder: BookFolder?
        // / (= boss 2026-10-09 (see OOB.md #2026-10-09) "重写同时搜索校对"). The LLM's
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / mode OR when the LLM returned an empty string).
        var rewrittenBody: String?
        // / (= boss 2026-10-10 (see OOB.md #2026-10-10) 去" 反馈). The LLM's
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / on top of the LLM-prompt cap).
        var extraFiles: [ExtraFile] = []
}

    // / Extract the first balanced `{...}` JSON object from the LLM's response.
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // MARK: - extractFirstJSONObject
    static func extractFirstJSONObject(_ raw: String) -> String? {
        guard let firstBrace = raw.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        var sanitized = ""
        for i in raw[firstBrace...].indices {
            let c = raw[i]
            if escape { escape = false; sanitized.append(c); continue }
            if c == "\\" { escape = true; sanitized.append(c); continue }
            if c == "\"" { inString.toggle(); sanitized.append(c); continue }
            if inString {
                // The LLM may have inserted literal newlines inside a string value (= the
                // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // escaped `\n` so the rest of the parse can succeed.
                if c == "\n" {
                    sanitized.append("\\n")
                } else if c == "\r" {
                    // Skip CR; = the \n already handled the line break.
                } else {
                    sanitized.append(c)
            }
                continue
        }
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 {
                    sanitized.append(c)
                    return sanitized
            }
        }
            sanitized.append(c)
    }
        return nil
}

    // / Parse the JSON envelope into an `ImportDecision`. Defensive: any field
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // MARK: - parseImportDecision
    static func parseImportDecision(_ json: String) -> ImportDecision {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ImportDecision(
                title: "", summary: "", tags: [],
                destination: "bookFolder", bookFolder: .drafts,
                rewrittenBody: nil
            )
    }
        let title = (parsed["title"] as? String) ?? ""
        let summary = (parsed["summary"] as? String) ?? ""
        let tags = (parsed["tags"] as? [String]) ?? []
        let destination = (parsed["destination"] as? String) ?? "bookFolder"
        // The model does not name a folder (= the folder is the user's
        // choice; = the sheet's two-level folder picker owns it; = the
        // model guessing a folder is what made the write land somewhere
        // the user did not pick).
        let bookFolder: BookFolder? = nil
        // (= only set in `searchAndRewrite` mode; = empty string from the LLM = the user
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // orchestrator falls back to the original body).
        let rawRewritten = (parsed["rewrittenBody"] as? String) ?? ""
        let rewrittenBody: String? = rawRewritten.isEmpty ? nil : Self.stripObsidianBacklinks(rawRewritten)
        // The library's tag rule (= the boss 2026-10-09): = the title
        // is not a tag, = at most three tags, = at least one.
        let titleNorm = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let dedupedTags = ImportTagPolicy.tags(
            tags,
            title: titleNorm,
            fallback: []
        )
        // ticket 02: parse `extraFiles` (= LLM's optional array of split-out files).
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // import).
        let extraFiles = Self.parseExtraFiles(from: parsed)
        return ImportDecision(
            title: title,
            summary: summary,
            tags: dedupedTags,
            destination: destination,
            bookFolder: bookFolder,
            rewrittenBody: rewrittenBody,
            extraFiles: extraFiles
        )
}


        // MARK: - parseExtraFiles
        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / doesn't include `extraFiles` at all.
    static func parseExtraFiles(from json: [String: Any]) -> [ExtraFile] {
        guard let rawArray = json["extraFiles"] as? [[String: Any]] else {
            return []
    }
        // (= boss 2026-10-10 (see OOB.md #2026-10-10) 自定义 cap" chosen). = 6 mandatory
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // overwrite).
        var result: [ExtraFile] = []
        var requiredCount = 0
        var customCount = 0
        for element in rawArray {
            // cap = 6 必填 + 5 自定义 = 11 total. The mandatory 6 always get priority; = the
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // to 5 custom.)
            let isRequired = (element["required"] as? Bool) ?? false
            if isRequired {
                if requiredCount >= 6 { continue }
            } else {
                if customCount >= 5 { continue }
        }
            // Parse folder (= one of 6 BookFolder cases).
            guard let folderStr = element["folder"] as? String,
                  let folder = Self.bookFolder(from: folderStr)
            else {
                NSLog(
                    "[wenshu.import] extraFiles element has unknown folder; skipping: %@",
                    element.description
                )
                continue
        }
            // Title must be non-empty (= after trim).
            let title = (element["title"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty {
                NSLog(
                    "[wenshu.import] extraFiles element has empty title; skipping: %@",
                    element.description
                )
                continue
        }
            // the boss explicitly said "不要 备注标题的文档" (= no fixed "备注.md" file). If the LLM
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // the user's wishes).
            if title == "备注" {
                NSLog(
                    "[wenshu.import] extraFiles element is '备注' (= boss banned 2026-10-10); dropping"
                )
                continue
        }
            // Body must be non-empty (= the LLM is supposed to put real content here; =
            // empty body = no point in creating a blank .md).
            let body = element["body"] as? String ?? ""
            if body.isEmpty {
                NSLog(
                    "[wenshu.import] extraFiles element has empty body; skipping: %@",
                    element.description
                )
                continue
        }
            // Un-escape JSON `\\n` to real newlines (= the LLM-prompt told it to use \n
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // as rewrittenBody above).
            let unescapedBody = body
                .replacingOccurrences(of: "\\n", with: "\n")
            result.append(ExtraFile(
                folder: folder,
                title: title,
                body: unescapedBody,
                required: isRequired
            ))
            if isRequired { requiredCount += 1 } else { customCount += 1 }
    }
        return result
}

    // / ticket 02: map a string to a `BookFolder` (= the same mapping as the
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // MARK: - bookFolder
    static func bookFolder(from string: String) -> BookFolder? {
        switch string {
        case "world": return .world
        case "characters": return .characters
        case "outlines": return .outlines
        case "chapters": return .chapters
        case "drafts": return .drafts
        case "ideas": return .ideas
        default: return nil
    }
}

        // MARK: - tagContainsPunctuation

    static func tagContainsPunctuation(_ tag: String) -> Bool {
        // Pre-resolve the underscore scalar (= the `Unicode.Scalar == String` overload
        // doesn't exist; = the comparison is scalar-to-scalar).
        let underscore: Unicode.Scalar = "_"
        for scalar in tag.unicodeScalars {
            // ASCII letters / digits: keep (= use the scalar's `properties` set; =
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // directly; = those members live on `Character`).
            if scalar.isASCII {
                let p = scalar.properties
                if p.isASCIIHexDigit || (scalar.value >= 0x41 && scalar.value <= 0x5A)
                    || (scalar.value >= 0x61 && scalar.value <= 0x7A)
                    || (scalar.value >= 0x30 && scalar.value <= 0x39) {
                    continue
            }
        }
            // ASCII underscore: drop (= the user wouldn't navigate to a tag with an
            // underscore in it).
            if scalar == underscore { return true }
            // CJK Unified Ideographs and extensions: keep. CJK Compatibility Ideographs
            // (U+F900..U+FAFF): keep.
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v)       // CJK Unified
                || (0x3400...0x4DBF).contains(v)   // CJK Ext A
                || (0x20000...0x2A6DF).contains(v) // CJK Ext B
                || (0x2A700...0x2B73F).contains(v) // CJK Ext C
                || (0x2B740...0x2B81F).contains(v) // CJK Ext D
                || (0xF900...0xFAFF).contains(v)   // CJK Compat
                || (0x2F800...0x2FA1F).contains(v) // CJK Compat Suppl
            {
                continue
        }
            // Everything else (= ASCII punctuation, CJK punctuation, whitespace, control
            // chars, emoji, symbols) is rejected.
            return true
    }
        return false
}

}


// MARK: - The agent's own reply

/// The metadata the import agent reports back.
///
/// The procedure asks for one JSON object at the end of the agent's
/// reply (= the title, the tags and the one-line summary; = the same
/// fields the sheet's per-file row shows). The model is asked for these
/// fields once, in the procedure, so there is no separate classification
/// call whose answer is thrown away.
struct WCIRAgentMetadata: Sendable, Equatable {
    var title: String = ""
    var summary: String = ""
    var tags: [String] = []
    var entityType: String = "other"
    var category: String?
    var confidence: Double = 0.0
}

extension WCIRHelpers {

    /// Read the metadata out of the agent's reply.
    ///
    /// A reply that carries no parseable object yields empty metadata
    /// (= the caller falls back to the file's name for the title).
    static func parseAgentMetadata(_ reply: String) -> WCIRAgentMetadata {
        guard let json = extractFirstJSONObject(reply),
              let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return WCIRAgentMetadata()
        }
        let title = (parsed["title"] as? String) ?? ""
        let summary = (parsed["summary"] as? String) ?? ""
        let tags = (parsed["tags"] as? [String]) ?? []
        let entityType = (parsed["entityType"] as? String)
            ?? (parsed["entity_type"] as? String)
            ?? "other"
        let category = (parsed["category"] as? String)
        let confidence = (parsed["confidence"] as? Double) ?? 0.0
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = category.flatMap {
            EntityCategory(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return WCIRAgentMetadata(
            title: cleanTitle,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            // The library's tag rule (= the title is not a tag, = one
            // to three tags, = never none).
            tags: ImportTagPolicy.tags(
                tags,
                title: cleanTitle,
                fallback: cleanCategory.map { [$0.displayName] } ?? []
            ),
            entityType: entityType,
            category: category,
            confidence: confidence
        )
    }
}
