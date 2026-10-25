// ImportAgentDriver.swift · wenshu · [archived-round] (= boss 2026-10-10 (see OOB.md #2026-10-10)
// wenshu 文档管理员 (= the wenshu main agent) into the ImportService flow. Flow (= what
// this file implements): 1. Resolve the SOP file (= ImportSOPTrigger looks up by
// target folder; = `world` → `ImportWorldPrompt`). 2. Load the SOP .md from the bundle
// (= ImportSOPLoader.loadRaw). 3. Substitute placeholders (= body, filePath, bookPath,
// bookTitle). 4. Run `ConversationLoop.runTurn` with the SOP as `systemMessage` and
// the `writeBookDoc` tool registered. 5. The agent (= LLM) calls `writeBookDoc` 1+
// times; = each call resolves to a file write on disk. 6. When the agent returns with
// no tool_use (= says "完成" or similar), `runTurn` exits and the orchestrator receives
// `ConversationResult`. The driver is intentionally thin (= it does NOT decide policy;
// = it only composes existing primitives = SOP loader + ConversationLoop + tool
// registry). The orchestrator (= ImportService) handles row state + per-row activity
// logging + task UI.

import Foundation
import WenshuAgent

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

    /// The settings the import turn runs under.
    ///
    /// An import is a mechanical transformation with a fixed procedure, not a
    /// conversation, so the turn reads nothing but its procedure and writes
    /// nothing back. Every guidance switch is off (= no identity, no provider
    /// pointer, no memory pointer, no session recall, no skills, no tool
    /// pointer, no help pointer) and the three include switches are off (= no
    /// project context files, no book context, no environment hints). The
    /// memory subsystem is off, so the turn leaves no trace in the memory
    /// store.
    ///
    /// `visibleTools` stays empty on purpose: an empty set means every
    /// registered tool, so the write tool stays reachable.
    static let importSettings = AgentSettings(
        prompt: PromptSettings(
            identityEnabled: false,
            providerGuidanceEnabled: false,
            memoryGuidanceEnabled: false,
            skillGuidanceEnabled: false,
            toolGuidanceEnabled: false,
            helpGuidanceEnabled: false,
            includeProjectContextFiles: false,
            includeBookContext: false,
            includeEnvironmentHints: false,
            visibleTools: []
        ),
        memory: MemorySettings(enabled: false)
    )

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

        // ── Step 3: substitute placeholders (= body, filePath, bookPath, bookTitle,
        // = the target folder's own name + its mandatory sections). The folder is
        // the one the agent writes into (= the one whose procedure was loaded
        // above; = the procedure names its own folder and its own sections
        // instead of hardcoding them).
        let sop = ImportSOPLoader.substitute(
            sopRaw,
            filePath: input.filePath,
            body: input.body,
            bookPath: input.bookPath,
            bookTitle: input.bookTitle,
            folder: input.targetFolder
        )

        // ── Step 4: build the user message (= short; = the SOP tells the agent how).
        let userMessage = """
        请处理这个文件: \(input.filePath)
        """

        // ── Step 5: bind the active book path (= writeBookDoc needs it). The
        // WriteBookDocTool handler reads `bookPathProvider()` per tool_use (=
        // lazy; = the closure captures the current book path; = resets per
        // driver invocation).
        let toolHandler = WriteBookDocTool(
            bookPathProvider: { [bookContext] in
                await bookContext.bookPath()
            },
            targetFolderName: input.targetFolder.directoryName
        )

        // ── Step 6: build the conversation loop. The connector is wrapped so
        // the turn goes out on the model the user picked: the turn loop
        // resolves the model from the connector (= the provider's first
        // default), so without the wrapper the import would run on a model
        // the user never chose.
        let loop = ConversationLoop(
            connection: ImportModelPinnedConnector(
                base: connector,
                model: modelSlug
            )
        )

        // ── Step 7: run the agent. The tool dispatch loop is inside runTurn (= the
        // wenshu agent main loop; = when the LLM returns a tool_use block,
        // runTurn dispatches the tool (= our writeBookDoc here) and re-prompts
        // the LLM with the tool result; = this loops until the LLM no longer
        // returns tool_use (= "agent finished").
        // The tool declaration travels beside the handler: the handler alone
        // cannot be reached, because the model only emits a tool_use block
        // for a tool the request body advertises.
        // The agent's reply travels back as it is produced (= the sheet
        // shows the reply while the agent is still writing, not only at
        // the end). The blocks are converted with the chat zone's own
        // accumulator, so the sheet's reply and the chat's reply are the
        // same shape.
        let emitter = ImportAgentPartEmitter()
        let result = try await Self.runTurnUntilSomethingLanded(
            loop: loop,
            userMessage: userMessage,
            systemMessage: sop,
            toolHandler: toolHandler,
            emitter: emitter,
            progress: progress
        )

        // ── Step 8: return the outcome.
        await progress?("agent finished (= \(result.messages.count) messages)")
        let lastAssistant = result.messages.last
        // (boss 2026-10-10 (see OOB.md #2026-10-10) PO 双轴 MED finding): count the number
        // of assistant turns that made at least one tool_use call (= 1 turn =
        // 1 task = "wenshu 文档管理员 wrote a book". = the previous double-count
        // was counting the tool_result block of the previous turn as the
        // current turn's tool_use; = the per-row log inflated by N).
        let toolUseCount = Self.writeCallCount(in: result)
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

    /// Run the turn until the agent has actually written a document.
    ///
    /// A model sometimes answers with its plan instead of acting on it
    /// (= it describes the documents it would write, and then stops).
    /// Such a turn writes nothing, and the import must not report
    /// success for it: = the orchestrator's row would say "done" with no
    /// file on disk. So a turn that produced no write is retried (= a
    /// fresh turn, = the same clean context), and a run that never
    /// writes throws (= the row fails, = the user sees it).
    static func runTurnUntilSomethingLanded(
        loop: ConversationLoop,
        userMessage: String,
        systemMessage: String,
        toolHandler: WriteBookDocTool,
        emitter: ImportAgentPartEmitter,
        progress: (@Sendable (String) async -> Void)?,
        attempts: Int = 3
    ) async throws -> ConversationResult {
        var budget = Self.turnTokenBudget
        var thinkingBudget: Int? = Self.thinkingBudget
        var lastReply = ""
        for attempt in 1...attempts {
            // The tally belongs to this attempt (= a previous attempt's
            // writes are not this attempt's).
            let tally = WriteTally()
            let countingTool = CountingWriteTool(base: toolHandler, tally: tally)
            let result: ConversationResult
            do {
                result = try await loop.runTurn(
                    userMessage: userMessage,
                    systemMessage: systemMessage,
                    tools: ["writeBookDoc": countingTool],
                    taskId: UUID().uuidString,
                    settings: Self.importSettings,
                    streamCallback: { block in
                        for part in emitter.consume(block) {
                            await progress?(part.encoded())
                        }
                    },
                    toolSchemas: [WriteBookDocTool.schema],
                    maxTokens: budget,
                    thinkingBudget: thinkingBudget
                )
            } catch {
                // Only a provider's refusal walks the budget ladder. Any
                // other failure (= a tool that threw, = a bad request)
                // is the run's own fault, = and a smaller budget does
                // not fix it, = so it is not a refusal and must not be
                // reported as one.
                guard error is LLMConnectorError else { throw error }
                guard budget > Self.smallestTurnTokenBudget else { throw error }
                budget = max(budget / 2, Self.smallestTurnTokenBudget)
                await progress?(
                    "the provider refused the output budget (= \(budget) now)"
                )
                continue
            }
            if tally.count > 0 { return result }
            // A provider that refuses the request (= a budget it will
            // not take, = a quota, = a model it does not know) says so in
            // the reply; = the stream carries the refusal instead of
            // throwing, = so the reply is where the refusal shows up.
            let refusal = result.messages
                .flatMap(\.blocks)
                .map(\.textValue)
                .joined(separator: "\n")
            if refusal.contains("[stream error]") {
                // The provider refused the request. The exotic knob goes
                // first (= a provider that does not know the thinking
                // budget refuses it outright), = then the output budget
                // halves (= every provider has a cap, = and the cap is
                // not the same everywhere).
                if thinkingBudget != nil {
                    thinkingBudget = nil
                    await progress?(
                        "the provider refused the thinking budget (= off now)"
                    )
                    continue
                }
                if budget > Self.smallestTurnTokenBudget {
                    budget = max(budget / 2, Self.smallestTurnTokenBudget)
                    await progress?(
                        "the provider refused the output budget (= \(budget) now)"
                    )
                    continue
                }
                throw ImportAgentError.providerRefused(reply: String(refusal.prefix(400)))
            }
            // Keep what the model said and how the turn ended (= a
            // failure that says nothing is = a failure nobody can act
            // on).
            let said = result.messages.last
                .map { message in
                    message.blocks.map(\.textValue).joined(separator: "\n")
                } ?? ""
            lastReply = "stop=" + result.response.stopReason.rawValue
                + " out=" + String(result.response.usage.outputTokens)
                + " in=" + String(result.response.usage.inputTokens)
                + " budget=" + String(budget)
                + " said: " + String(said.prefix(400))
            // A turn that ran out of room ends in the middle of the
            // model's reasoning (= it planned the documents and never
            // got to writing them).
            if result.response.stopReason == .maxTokens {
                await progress?(
                    "the agent ran out of room before it wrote (attempt \(attempt)/\(attempts)); = running the procedure again"
                )
            } else {
                await progress?(
                    "the agent planned without writing (attempt \(attempt)/\(attempts)); = running the procedure again"
                )
            }
        }
        throw ImportAgentError.nothingWritten(reply: String(lastReply.prefix(600)))
    }

    /// The import turn's output budget.
    ///
    /// The provider counts the reasoning against the same budget as the
    /// answer, and the world's procedure asks for one index + six
    /// documents with real content. A conversation-sized budget (= 4096)
    /// runs out inside the reasoning, = and the turn ends before a
    /// single document is written.
    static let turnTokenBudget = 16384

    /// The smallest budget the import runs with (= the floor for a
    /// provider whose own cap is low).
    static let smallestTurnTokenBudget = 8192

    /// The import turn's thinking budget.
    ///
    /// The provider counts the reasoning against the same budget as the
    /// answer. The world's procedure asks for one index + six documents
    /// with real content, = and a model that thinks at length spends the
    /// whole budget on the plan and ends the turn before it writes
    /// anything. The budget holds the reasoning down so the answer fits.
    static let thinkingBudget = 8192

    /// The number of write calls the turn made.
    ///
    /// Every tool_use block is one call (= one document written); = the
    /// tool_result block that follows it is the answer, = not a call.
    static func writeCallCount(in result: ConversationResult) -> Int {
        result.messages.reduce(into: 0) { total, message in
            for block in message.blocks {
                if case .toolUse = block { total += 1 }
            }
        }
    }

    /// The number of writes that landed on disk.
    ///
    /// A call is not a write: = the tool refuses a path, = the folder is
    /// missing, = the disk is full, = and then the turn ends with calls
    /// and no files. The tool's own answer says which writes landed, =
    /// so that answer is what the driver reads (= a run that wrote
    /// nothing is a failure, = not a success with a long story).
    ///
    /// The count comes from the handler, = not from the conversation: =
    /// the turn's final messages are the compressed history, = and the
    /// compression drops the tool answers.
    final class WriteTally: @unchecked Sendable {
        private let lock = NSLock()
        private var landed = 0

        /// Records one write's answer.
        func record(_ output: String) {
            guard output.contains("\"success\":true") else { return }
            lock.lock()
            landed += 1
            lock.unlock()
        }

        /// The number of writes that landed.
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return landed
        }
    }

    /// The write tool with the tally behind it.
    struct CountingWriteTool: Tool {
        let base: WriteBookDocTool
        let tally: WriteTally

        func execute(input: String) async throws -> String {
            let output = try await base.execute(input: input)
            tally.record(output)
            return output
        }
    }

    enum ImportAgentError: Error, LocalizedError {
        case noSOPForFolder(BookFolder)
        case sopLoadFailed(underlying: String)
        case nothingWritten(reply: String)
        case providerRefused(reply: String)

        var errorDescription: String? {
            switch self {
            case .noSOPForFolder(let f):
                return "ImportAgentDriver: no SOP defined for folder '\(f.directoryName)' (= future round will add character/outline/etc. SOPs)."
            case .sopLoadFailed(let u):
                return "ImportAgentDriver: SOP load failed: \(u)"
            case .nothingWritten(let reply):
                return "ImportAgentDriver: the agent wrote no document (= the import produced nothing; = run it again). The agent said: \(reply)"
            case .providerRefused(let reply):
                return "ImportAgentDriver: the provider refused the request: \(reply)"
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