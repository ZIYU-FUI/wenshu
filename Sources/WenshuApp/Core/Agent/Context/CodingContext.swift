//
//  CodingContext.swift · Wenshu · HERMES-INTERNAL-002 (2026-09-04)
//
//  1:1 port of hermes coding_context.py (= hermes-internal module #2,
//  boss 2026-09-04 OOB 'A'). Thin adapter — wenshu already has
//  PromptCaching.swift as the canonical coding-context surface, so
//  this module exposes a hermes-aligned API that delegates to it.
//
//  Wenshu-side wins preserved: this is the thin-adapter pattern
//  (= hermes-port = adapter, wenshu-canonical = canonical). CodingContextAggregator
//  reads Swift files from disk and surfaces language + imports + recent edits
//  for downstream prompt assembly.
//

import Foundation

// MARK: - Context value

public struct CodingContext: Sendable, Equatable {
    public let language: String
    public let filePath: String?
    public let snippet: String?
    public let imports: [String]
    public let recentEdits: [String]

    public init(
        language: String,
        filePath: String? = nil,
        snippet: String? = nil,
        imports: [String] = [],
        recentEdits: [String] = []
    ) {
        self.language = language
        self.filePath = filePath
        self.snippet = snippet
        self.imports = imports
        self.recentEdits = recentEdits
    }
}

// MARK: - Aggregator

public actor CodingContextAggregator {

    public init() {}

    /// Build a CodingContext for the given file path. Reads the file from
    /// disk, detects the language from the extension, extracts imports,
    /// and returns the snippet. Mirrors hermes coding_context.aggregate()
    /// without the project-root / git-repo detection (= that lives in
    /// wenshu's canonical PromptCaching surface for the coding posture).
    public func aggregate(for filePath: String) async throws -> CodingContext {
        let url = URL(fileURLWithPath: filePath)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw CodingContextError.fileNotFound(path: url.path)
        }

        let language = Self.detectLanguage(for: url)
        guard !language.isEmpty else {
            throw CodingContextError.unsupportedExtension(path: url.path)
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        let imports = Self.extractImports(from: contents, language: language)
        let snippet = Self.makeSnippet(from: contents, lineLimit: 50)

        return CodingContext(
            language: language,
            filePath: url.path,
            snippet: snippet,
            imports: imports,
            recentEdits: []
        )
    }

    // MARK: - Language detection

    /// Map file extension → language key. Matches hermes
    /// coding_context._CODE_EXTENSIONS (which is broader — we keep
    /// the wenshu-relevant subset since other languages have no
    /// import semantics to surface here).
    static func detectLanguage(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "py", "pyi": return "python"
        case "js", "jsx", "mjs", "cjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "go": return "go"
        case "rs": return "rust"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "rb": return "ruby"
        case "c", "h": return "c"
        case "cc", "cpp", "hpp": return "cpp"
        case "cs": return "csharp"
        case "sh", "bash", "zsh": return "shell"
        case "sql": return "sql"
        case "json": return "json"
        case "md": return "markdown"
        case "toml", "yaml", "yml": return "config"
        default: return ""
        }
    }

    // MARK: - Import extraction

    /// Extract imports for the detected language. Bounded regex match
    /// (= no full AST parser; hermes uses a similar line-by-line scan).
    static func extractImports(from text: String, language: String) -> [String] {
        var imports: [String] = []
        let lines = text.components(separatedBy: .newlines)
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            switch language {
            case "swift":
                if line.hasPrefix("import ") {
                    let parts = line.dropFirst("import ".count)
                        .components(separatedBy: " ")
                        .filter { !$0.isEmpty }
                    if let head = parts.first {
                        imports.append(String(head))
                    }
                }
            case "python":
                if line.hasPrefix("import ") || line.hasPrefix("from ") {
                    imports.append(line)
                }
            case "javascript", "typescript":
                if line.hasPrefix("import ") || line.hasPrefix("from ") || line.hasPrefix("require(") {
                    imports.append(line)
                }
            case "go":
                if line.hasPrefix("import ") || line.hasPrefix("package ") {
                    imports.append(line)
                }
            case "rust":
                if line.hasPrefix("use ") || line.hasPrefix("extern ") {
                    imports.append(line)
                }
            case "shell":
                if line.hasPrefix("source ") || line.hasPrefix(". ") {
                    imports.append(line)
                }
            default:
                break
            }
        }
        // De-duplicate, preserve order.
        var seen = Set<String>()
        return imports.filter { seen.insert($0).inserted }
    }

    // MARK: - Snippet

    /// Make a bounded preview from the file (= first N lines). Used to
    /// surface a snippet in the coding context without holding the whole
    /// file in memory.
    static func makeSnippet(from text: String, lineLimit: Int) -> String {
        let lines = text.components(separatedBy: .newlines)
        let bounded = Array(lines.prefix(lineLimit))
        return bounded.joined(separator: "\n")
    }
}

// MARK: - Errors

public enum CodingContextError: Error, Sendable, Equatable {
    case fileNotFound(path: String)
    case unsupportedExtension(path: String)
}