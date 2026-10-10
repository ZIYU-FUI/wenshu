//
//  WriteBookDocTool.swift · wenshu · round-73 (= boss 2026-10-10)
//
//  v2.7 round-73: the wenshu 文档管理员
//  (= wenshu main agent)'s dedicated write
//  tool (= "writeBookDoc"). The agent is
//  told via `ImportWorldPrompt.md` (and
//  future per-folder SOPs) to call this
//  tool once per sub-file (= 1 主索引 + 6
//  必填 + 0-5 自定义 sub-files for the
//  world folder).
//
//  Why a NEW tool (= not the existing
//  `WriteFileTool`):
//
//    - The existing `WriteFileTool` is a
//      generic path-anywhere write (= it
//      operates inside the wenshu library
//      bundle via FileTools.pathDenied
//      guard). = a different scope.
//    - This tool is scoped to the
//      currently-bound book (= the import
//      task's `{bookPath}` root). = no
//      path-arbitrary writes; = always
//      relative to the active book.
//    - This tool also returns structured
//      feedback (= written path + bytes
//      written) so the agent's tool_use
//      loop has unambiguous success/fail
//      signals.
//    - The agent runs inside
//      `ConversationLoop.runTurn` (= the
//      multi-turn agent main loop; = tool
//      use is dispatched by ToolExecutor,
//      which calls back into ImportService
//      to actually persist the file).
//
//  Why NOT a tool (= alternative design):
//
//    - Earlier round-71/72/73 designs
//      used the orchestrator to drive
//      the LLM (= orchestrator called the
//      LLM 1-3 times, parsed JSON, wrote
//      files). That was "the orchestrator
//      IS the agent". The boss's 2026-10-10
//      OOB "走类似看板任务一样, 让一
//      个 agent 跑完" + "LLM 是一次
//      调用一次回复模式" means the LLM
//      cannot drive multi-step work
//      without the agent runtime. Here,
//      the wenshu agent runtime IS the
//      driver (= via ConversationLoop.runTurn);
//      = this tool is the agent's only
//      write surface.
//

import Foundation

/// The agent's write tool for the import
/// flow. Lives next to the rest of the
/// agent toolset (= Sources/WenshuApp/Core/Agent/Tool/)
/// so `ToolRegistry` discovers it via the
/// module-load `_registryBootstrap`.
struct WriteBookDocTool: Tool, Sendable {

    /// Mutable: holds the active book
    /// root (= set by ImportService
    /// before the agent run starts; =
    /// per-run state; = reset on each new
    /// import). The closure form lets the
    /// agent runtime pass the value
    /// through `toolset:` parameter
    /// without exposing a public setter.
    let bookPathProvider: @Sendable () async -> String?

    init(bookPathProvider: @escaping @Sendable () async -> String?) {
        self.bookPathProvider = bookPathProvider
    }

    /// Tool output (= the JSON the agent
    /// sees after each successful write).
    /// Compact: agent only needs to know
    /// success + where it landed + bytes.
    struct WriteResult: Codable, Sendable {
        let path: String
        let bytes: Int
        let success: Bool
    }

    func execute(input: String) async throws -> String {
        let dict = try ToolInputParser.parseDictionary(input: input)
        // Relative path (= within the
        // current book). MUST NOT start
        // with `/` (= absolute paths are
        // rejected; = the tool is
        // book-scoped; = if a future
        // caller wants cross-book write,
        // they pick a different tool).
        let relPath = try ToolInputParser.requireString(dict, "path")
        guard !relPath.hasPrefix("/") else {
            throw ToolExecutorError.invalidInput(
                name: "writeBookDoc",
                reason: "Path must be relative to the active book (no leading '/'): '\(relPath)'"
            )
        }
        let body = try ToolInputParser.requireString(dict, "body")
        // Path-guard (= the tool refuses
        // to escape the book root).
        guard let bookRoot = await bookPathProvider() else {
            throw ToolExecutorError.invalidInput(
                name: "writeBookDoc",
                reason: "No active book (= import not bound to a book). The orchestrator must set the book path before the agent runs."
            )
        }
        let fullPath = (bookRoot as NSString)
            .appendingPathComponent(relPath)
        // Path-guard v2: reject `..`
        // escapes (= canonicalize and
        // verify the resolved path stays
        // inside the book root).
        let canonicalFull = (try? URL(
            fileURLWithPath: fullPath
        ).standardizedFileURL.path) ?? fullPath
        let canonicalRoot = (try? URL(
            fileURLWithPath: bookRoot
        ).standardizedFileURL.path) ?? bookRoot
        guard canonicalFull.hasPrefix(canonicalRoot + "/") else {
            throw ToolExecutorError.pathGuardViolation(
                toolName: "writeBookDoc",
                key: "path",
                underlying: PathGuard.GuardError.invalidPath(
                    reason: "resolved path escapes the book root"
                )
            )
        }
        // v2.7 round-73 (boss 2026-10-10
        // PO 双轴 test failure in worker):
        // create the parent directory
        // (= nested folders like
        // `world/核心设定.md` need the
        // `world/` parent; = a freshly
        // imported book may not yet
        // have any of the per-folder
        // subdirs). Without this,
        // `FileManager` returns
        // `NSPOSIXErrorDomain Code=2`
        // (= "No such file or
        // directory") and the agent's
        // first write call fails.
        // `withIntermediateDirectories:
        // true` is idempotent (= no
        // error if the directory
        // already exists).
        let parentDir = (canonicalFull as NSString)
            .deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(
                atPath: parentDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ToolExecutorError.toolFailed(
                name: "writeBookDoc",
                underlying: String(describing: error)
            )
        }
        // Write the file (= use
        // FileTools.write for the
        // canonical wenshu file-writing
        // path; = shared with the
        // orchestrator's writeFile).
        let tools = FileTools()
        do {
            try tools.write(path: canonicalFull, content: body)
        } catch {
            throw ToolExecutorError.toolFailed(
                name: "writeBookDoc",
                underlying: String(describing: error)
            )
        }
        let bytes = body.utf8.count
        let result = WriteResult(
            path: canonicalFull,
            bytes: bytes,
            success: true
        )
        let data = try JSONEncoder().encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - ToolRegistry bootstrap

extension WriteBookDocTool {
    /// Module-load registration (= fires
    /// once at first type access; = the
    /// underlying Task schedules the
    /// async registerTool() off the init
    /// thread).
    ///
    /// Toolset = `"world"` (= semantic
    /// group; = the ImportService will
    /// filter toolsets for the import
    /// task so the agent only sees the
    /// world-write tool, not the
    /// path-anywhere `WriteFileTool`).
    static let _registryBootstrap: Void = {
        Task {
            // Default bookPathProvider =
            // nil (= no active book). The
            // ImportService replaces this
            // before the agent run starts
            // (= see `ImportAgentDriver`).
            await ToolRegistry.shared.registerTool(
                name: "writeBookDoc",
                toolset: "world",
                schema: ToolRegistrySchema(
                    name: "writeBookDoc",
                    description: """
                    Write 1 .md file inside the active book (= e.g. world/<title>.md). \
                    The path is relative to the book's root; = absolute paths are rejected. \
                    The orchestrator sets the active book before the agent runs.
                    """,
                    inputSchema: [
                        "path": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Relative path inside the active book (= e.g. 'world/核心设定.md'). Must NOT start with '/'."
                        ),
                        "body": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The complete file content (= Markdown)."
                        )
                    ],
                    required: ["path", "body"]
                ),
                handler: WriteBookDocTool(
                    bookPathProvider: { nil }
                ),
                description: "Write 1 .md file to the active book's filesystem (= e.g. world/<title>.md).",
                emoji: "📝"
            )
        }
    }()
}