// WriteBookDocTool.swift · wenshu · [archived-round] (= boss 2026-10-10 (see OOB.md #2026-10-10)
// (= wenshu main agent)'s dedicated write tool (= "writeBookDoc"). The agent is told
// via `ImportWorldPrompt.md` (and future per-folder SOPs) to call this tool once per
// sub-file (= 1 主索引 + 6 必填 + 0-5 自定义 sub-files for the world folder). Why a NEW tool
// (= not the existing `WriteFileTool`): - The existing `WriteFileTool` is a generic
// path-anywhere write (= it operates inside the wenshu library bundle via
// FileTools.pathDenied guard). = a different scope. - This tool is scoped to the
// currently-bound book (= the import task's `{bookPath}` root). = no path-arbitrary
// writes; = always relative to the active book. - This tool also returns structured
// feedback (= written path + bytes written) so the agent's tool_use loop has
// unambiguous success/fail signals. - The agent runs inside `ConversationLoop.runTurn`
// (= the multi-turn agent main loop; = tool use is dispatched by ToolExecutor, which
// calls back into ImportService to actually persist the file). Why NOT a tool (=
// alternative design): - Earlier [archived-round]/72/73 designs used the orchestrator to drive
// the LLM (= orchestrator called the LLM 1-3 times, parsed JSON, wrote files). That
// was "the orchestrator IS the agent". The boss's 2026-10-10 OOB "走类似看板任务一样, 让一 个
// agent 跑完" + "LLM 是一次 调用一次回复模式" means the LLM cannot drive multi-step work without
// the agent runtime. Here, the wenshu agent runtime IS the driver (= via
// ConversationLoop.runTurn); = this tool is the agent's only write surface.

import Foundation
import WenshuAgent

/// The agent's write tool for the import
/// flow. Lives next to the rest of the
/// agent toolset (= Sources/WenshuApp/Core/Agent/Tool/).
/// The import driver binds it per run (= see
/// `ImportAgentDriver`; = it passes the
/// active book's root as a closure, so the
/// tool always writes relative to that book).
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

    /// The one folder this run may write into (= the folder the user
    /// picked in the import sheet).
    ///
    /// The book root holds six folders, and a run belongs to exactly one
    /// of them. So the tool refuses a path that leaves that folder: the
    /// user's choice is the destination, and a model that writes
    /// elsewhere has not changed it.
    let targetFolderName: String

    init(
        bookPathProvider: @escaping @Sendable () async -> String?,
        targetFolderName: String
    ) {
        self.bookPathProvider = bookPathProvider
        self.targetFolderName = targetFolderName
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

    /// The declaration the model reads.
    /// The agent can only emit a tool_use block
    /// for a tool the request body advertises, so
    /// a turn without this schema never reaches
    /// the write handler.
    ///
    /// The name is the handler key the import
    /// driver passes to the turn (= the model
    /// calls the tool by this name). The tool is
    /// bound to one import run, so it stays out
    /// of the global tool registry.
    static let schema = ToolRegistrySchema(
        name: "writeBookDoc",
        description: """
        Write one document into the active book (= the book the \
        import run is bound to). Call it once per document: \
        each call writes exactly one file. The path is relative \
        to the book root; an absolute path or a path escaping \
        the book root is refused.
        """,
        inputSchema: [
            "path": ToolRegistrySchemaProperty(
                type: "string",
                description: """
                Path of the document relative to the active book \
                root (e.g. 'world/overview.md'). No leading slash.
                """
            ),
            "body": ToolRegistrySchemaProperty(
                type: "string",
                description: "The full UTF-8 content of the document to write."
            )
        ],
        required: ["path", "body"]
    )

    func execute(input: String) async throws -> String {
        let dict = try ToolInputParser.parseDictionary(input: input)
        // Relative path (= within the current book). MUST NOT start with `/` (= absolute
        // paths are rejected; = the tool is book-scoped; = if a future caller
        // wants cross-book write, they pick a different tool).
        let relPath = try ToolInputParser.requireString(dict, "path")
        guard !relPath.hasPrefix("/") else {
            throw ToolExecutorError.invalidInput(
                name: "writeBookDoc",
                reason: "Path must be relative to the active book (no leading '/'): '\(relPath)'"
            )
        }
        let body = try ToolInputParser.requireString(dict, "body")
        // Path-guard (= the tool refuses to escape the book root).
        guard let bookRoot = await bookPathProvider() else {
            throw ToolExecutorError.invalidInput(
                name: "writeBookDoc",
                reason: "No active book (= import not bound to a book). The orchestrator must set the book path before the agent runs."
            )
        }
        let fullPath = (bookRoot as NSString)
            .appendingPathComponent(relPath)
        // Path-guard v2: reject `..` escapes (= canonicalize and verify the resolved path
        // stays inside the book root).
        let canonicalFull = URL(fileURLWithPath: fullPath).standardizedFileURL.path
        let canonicalRoot = URL(fileURLWithPath: bookRoot).standardizedFileURL.path
        guard canonicalFull.hasPrefix(canonicalRoot + "/") else {
            throw ToolExecutorError.pathGuardViolation(
                toolName: "writeBookDoc",
                key: "path",
                underlying: PathGuard.GuardError.invalidPath(
                    reason: "resolved path escapes the book root"
                )
            )
        }
        // Folder-guard (= the tool refuses to leave the folder the user
        // picked). The book's root holds six folders; = a run writes into
        // one of them; = the model's choice of a path never widens that.
        let firstComponent = relPath
            .split(separator: "/")
            .first
            .map(String.init) ?? ""
        guard firstComponent == targetFolderName else {
            throw ToolExecutorError.invalidInput(
                name: "writeBookDoc",
                reason: "Path must stay inside the '\(targetFolderName)' folder (= the folder this import writes into): '\(relPath)'"
            )
        }
        // (boss 2026-10-10 (see OOB.md #2026-10-10) PO 双轴 test failure in worker): create
        // the parent directory (= nested folders like `world/核心设定.md` need the
        // `world/` parent; = a freshly imported book may not yet have any of
        // the per-folder subdirs). Without this, `FileManager` returns
        // `NSPOSIXErrorDomain Code=2` (= "No such file or directory") and the
        // agent's first write call fails. `withIntermediateDirectories: true`
        // is idempotent (= no error if the directory already exists).
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
        // The library's tag rule (= the boss 2026-10-26): = the
        // document's own name is not a tag, = a tag names no sibling
        // document, = there are one to three tags, = and never none.
        // The agent writes the body, = so the app holds the rule.
        let documentTitle = (relPath as NSString).deletingPathExtension
        let siblingNames = ImportTagPolicy.siblingNames(
            inFolderAt: URL(fileURLWithPath: parentDir)
        )
        let folderFallback = BookFolder(rawValue: targetFolderName)?.displayName
        let taggedBody = BookDocumentTagLine.normalized(
            in: body,
            title: documentTitle,
            siblingNames: siblingNames,
            fallback: folderFallback.map { [$0] } ?? []
        )
        // Write the file (= use FileTools.write for the canonical wenshu file-writing
        // path; = shared with the orchestrator's FileTools.write).
        let tools = FileTools()
        do {
            try tools.write(path: canonicalFull, content: taggedBody)
        } catch {
            throw ToolExecutorError.toolFailed(
                name: "writeBookDoc",
                underlying: String(describing: error)
            )
        }
        let bytes = body.utf8.count
        // The book gained a document, so the library says so: the
        // sidebar reloads the tree and the material zone re-reads the
        // documents. A book doc the agent wrote is otherwise invisible
        // until the user clicks something else.
        LibraryChangeNotifier.notifyLibraryChanged(source: .agentBookDoc)
        let result = WriteResult(
            path: canonicalFull,
            bytes: bytes,
            success: true
        )
        let data = try JSONEncoder().encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
