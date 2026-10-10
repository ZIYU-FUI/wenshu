//
//  ImportAgentDriver.swift · wenshu · round-73 (= boss 2026-10-10)
//
//  v2.7 round-73: the driver that wires the
//  wenshu 文档管理员 (= the wenshu main
//  agent) into the ImportService flow.
//
//  Flow (= what this file implements):
//
//    1. Resolve the SOP file (= ImportSOPTrigger
//       looks up by target folder; = `world` →
//       `ImportWorldPrompt`).
//    2. Load the SOP .md from the bundle
//       (= ImportSOPLoader.loadRaw).
//    3. Substitute placeholders (= body,
//       filePath, bookPath, bookTitle).
//    4. Run `ConversationLoop.runTurn` with
//       the SOP as `systemMessage` and the
//       `writeBookDoc` tool registered.
//    5. The agent (= LLM) calls
//       `writeBookDoc` 1+ times; = each call
//       resolves to a file write on disk.
//    6. When the agent returns with no
//       tool_use (= says "完成" or similar),
//       `runTurn` exits and the orchestrator
//       receives `ConversationResult`.
//
//  The driver is intentionally thin (= it
//  does NOT decide policy; = it only
//  composes existing primitives =
//  SOP loader + ConversationLoop + tool
//  registry). The orchestrator (= ImportService)
//  handles row state + per-row activity
//  logging + task UI.
//

import Foundation

/// Single-call driver. Imports a .md file
/// by handing the task to the wenshu
/// agent (= ConversationLoop.runTurn) with
/// the appropriate SOP injected.
///
/// Returns the agent's final response
/// (= typically "完成"; = the agent says
/// when its tool_use loop finishes). The
/// orchestrator treats any non-tool_use
/// response as "agent finished".
struct ImportAgentDriver: Sendable {

    let connector: any LLMConnector
    let modelSlug: String
    let sopLoader: ImportSOPLoader

    init(
        connector: any LLMConnector,
        modelSlug: String,
        sopLoader: ImportSOPLoader = ImportSOPLoader()
    ) {
        self.connector = connector
        self.modelSlug = modelSlug
        self.sopLoader = sopLoader
    }

    /// Per-task inputs (= bundled by
    /// ImportService before each run).
    struct TaskInput: Sendable {
        let filePath: String
        let body: String
        let bookPath: String
        let bookTitle: String
        let targetFolder: BookFolder
    }

    /// Run the agent end-to-end. Returns
    /// when the agent exits (= no more
    /// tool_use; = either success or
    /// max-turn cap). The orchestrator
    /// then resolves the row state.
    func run(
        input: TaskInput,
        bookContext: ImportAgentBookContext,
        progress: (@Sendable (String) async -> Void)?
    ) async throws -> ImportAgentResult {
        // ── Step 1: resolve the SOP name (= per-folder lookup).
        guard let sopName = ImportSOPTrigger.sopName(for: input.targetFolder) else {
            throw ImportAgentError.noSOPForFolder(input.targetFolder)
        }

        // ── Step 2: load the SOP .md from the bundle.
        let sopRaw: String
        do {
            sopRaw = try sopLoader.loadRaw(named: sopName)
        } catch {
            throw ImportAgentError.sopLoadFailed(underlying: String(describing: error))
        }

        // ── Step 3: substitute placeholders (= body, filePath, bookPath, bookTitle).
        let sop = ImportSOPLoader.substitute(
            sopRaw,
            filePath: input.filePath,
            body: input.body,
            bookPath: input.bookPath,
            bookTitle: input.bookTitle
        )

        // ── Step 4: build the user message (= short; = the SOP tells the agent how).
        let userMessage = """
        请处理这个文件: \(input.filePath)
        """

        // ── Step 5: bind the active book path (= writeBookDoc needs it).
        // The WriteBookDocTool handler reads `bookPathProvider()` per
        // tool_use (= lazy; = the closure captures the current book
        // path; = resets per driver invocation).
        let toolHandler = WriteBookDocTool(
            bookPathProvider: { [bookContext] in
                await bookContext.bookPath()
            }
        )

        // ── Step 6: build the conversation loop.
        let loop = ConversationLoop(
            connection: connector
        )

        // ── Step 7: run the agent. The tool dispatch loop is inside runTurn (= the
        // wenshu agent main loop; = when the LLM returns a tool_use
        // block, runTurn dispatches the tool (= our writeBookDoc here)
        // and re-prompts the LLM with the tool result; = this loops
        // until the LLM no longer returns tool_use (= "agent
        // finished").
        let result = try await loop.runTurn(
            userMessage: userMessage,
            systemMessage: sop,
            tools: ["writeBookDoc": toolHandler],
            taskId: UUID().uuidString,
            streamCallback: nil,
            toolSchemas: []
        )

        // ── Step 8: return the outcome.
        await progress?("agent finished (= \(result.messages.count) messages)")
        let lastAssistant = result.messages.last
        // v2.7 round-73 (boss 2026-10-10
        // PO 双轴 MED finding): count the
        // number of assistant turns that
        // made at least one tool_use call
        // (= 1 turn = 1 task = "wenshu
        // 文档管理员 wrote a book". = the
        // previous double-count was
        // counting the tool_result block
        // of the previous turn as the
        // current turn's tool_use; = the
        // per-row log inflated by N).
        let toolUseCount = result.messages.filter { msg in
            msg.blocks.contains { block in
                if case .toolUse = block { return true } else { return false }
            }
        }.count
        let finalResponse: String = {
        guard let lastAssistant = lastAssistant else { return "" }
        let parts = lastAssistant.blocks.map { $0.textValue }
        return parts.joined(separator: "\n")
    }()
        return ImportAgentResult(
            sopName: sopName,
            toolUseCount: toolUseCount,
            finalResponse: finalResponse
        )
    }

    enum ImportAgentError: Error, LocalizedError {
        case noSOPForFolder(BookFolder)
        case sopLoadFailed(underlying: String)

        var errorDescription: String? {
            switch self {
            case .noSOPForFolder(let f):
                return "ImportAgentDriver: no SOP defined for folder '\(f.directoryName)' (= future round will add character/outline/etc. SOPs)."
            case .sopLoadFailed(let u):
                return "ImportAgentDriver: SOP load failed: \(u)"
            }
        }
    }
}

/// The active book context (= passed in by
/// ImportService; = the driver forwards
/// the closure into the tool so each
/// tool_use re-reads the live book path).
struct ImportAgentBookContext: Sendable {
    let bookPath: @Sendable () async -> String?

    init(bookPath: @escaping @Sendable () async -> String?) {
        self.bookPath = bookPath
    }
}

/// What the driver returns to the
/// orchestrator. `finalResponse` is the
/// agent's last assistant message (= the
/// orchestrator checks if it equals
/// "完成" / "done" to know the agent
/// finished). `toolUseCount` = how many
/// file writes the agent performed (= for
/// the per-row activity log).
struct ImportAgentResult: Sendable {
    let sopName: String
    let toolUseCount: Int
    let finalResponse: String
}