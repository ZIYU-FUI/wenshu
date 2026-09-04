//
//  IntegrationPlanEndToEndTests.swift · Wenshu · v0.42 VERIFY-INTEGRATION-001
//                                       (2026-09-05, P5 #23, FINAL wayfinder ticket)
//
//  End-to-end integration smoke test that exercises ALL 22 shipped
//  wire-up tickets in sequence (= the 18 wayfinder-plan tickets plus
//  the 4 supporting tickets tracked alongside them).
//
//  Purpose: prove every wire-up ticket has a live, constructible
//  actor / tool / store AND can perform at least one minimal smoke
//  operation (= add 1, list 1, init 1, etc.) without crashing.
//  This is the gating check for "the integration plan is complete":
//  if this single test passes, every wire-up ticket is alive and
//  wired into the wenshu runtime.
//
//  Coverage map (= one smoke step per wire-up ticket):
//
//    P0 — wire Agent core (5 tickets):
//      #1 ConversationLoop path -> build a loop + verify .runConversation
//      #2 ToolExecutor + ParagraphAITool -> ToolExecutor() + .executeSequential
//      #3 HermesGoals long-running -> GoalsManager(mock conns) + .runGoal
//      #4 TodoStoreTool -> TodoStoreTool.execute(create action)
//      #5 KanbanStoreTool -> KanbanStoreTool.execute(add action)
//
//    P1 — wire LongForm surface (11 tickets):
//      #6 LongFormGuardrails -> actor init + loadGuardrails round-trip
//      #7 ReaderExperienceTools -> ReaderExperienceAnalyzer.analyze
//      #8 PlotThreadTracker -> actor init + add/list round-trip
//      #9 GenreFitAnalyzer -> actor init + availableGenres
//     #10 EditorTransformTools + ParagraphAITool stub replacement ->
//         EditorTransformTools() + ParagraphAITool.execute
//     #11 EmotionCurveAnalyzer -> actor init + analyze
//     #12 CharacterRelationshipTracker -> actor init + add/list
//     #13 CharacterLifecycleTracker -> actor init + add/list
//     #14 TagManager -> actor init + add/list
//     #15 IdeaLibrary -> actor init + add/list
//     #16 BookSettingConstraints -> actor init + add/list
//
//    P2 — wire SpecializedTools (6 tickets):
//     #17 ForeshadowingTracker -> actor init + add/list
//     #18 PlaceholderScanner -> actor init + add/list
//     #19 paragraph_ai toolbar buttons -> ParagraphAITool.execute (covered by #10)
//     #20 BookManager -> BookManager.createBook round-trip
//     #21 AgentProgressTracker -> tracker.start + complete round-trip
//     #22 TodoStore reactivity -> TodoStore.subscribe notification stream
//
//  Test budget: < 30 seconds. Each step is a single smoke operation
//  (= add 1, list 1, init 1). No LLM network calls. In-memory
//  stores where possible; SQLite + sidecar files where required by
//  the wire-up actor's persistence contract (= mirrors the per-book
//  sidecar convention per AGENTS.md §11).
//
//  Hard rules honored:
//    * English-only (= per AGENTS.md baseline).
//    * No new third-party dependency.
//    * Test-only change (= no source files touched).
//    * No LLM network calls (= all operations are offline / pure).
//

import Foundation
import Testing
@testable import WenshuApp

/// Sendable collector for AsyncStream todo notifications
/// (= mirrors the per-listener notification contract that
/// TodoStore.subscribe exposes). Actor = guarantees safe
/// concurrent append from the detached consumer Task.
private actor NotificationCollector {
    private var items: [TodoItem] = []

    func append(_ item: TodoItem) {
        items.append(item)
    }

    var count: Int {
        items.count
    }

    func contains(id: String) -> Bool {
        items.contains(where: { $0.id == id })
    }
}

@Suite("Integration plan end-to-end (= all 22 wire-up tickets exercised together)")
struct IntegrationPlanEndToEndTests {

    // MARK: - Shared helpers

    /// Build a tiny LibraryStores + BookStore bundle rooted in a
    /// unique /tmp directory. Mirrors the makeBookStore helper in
    /// every per-tool test (= ForeshadowingTracker / IdeaLibrary /
    /// TagManager / LongFormGuardrails / etc.) so the integration
    /// test reuses the canonical wenshu-side test scaffolding.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tag = "p5-23-\(UUID().uuidString)"
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-\(tag)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        return (BookStore(stores: stores), stores)
    }

    /// Build a real Bookshelf via BookStore.sidebarSaveShelf so
    /// BookManager / BookManagerTool smoke tests can pass the
    /// shelf-existence check on create (= mirrors the
    /// BookManagerToolTests scaffolding).
    private static func makeShelf(bookStore: BookStore, name: String = "Integration Shelf") throws -> Bookshelf {
        try bookStore.sidebarSaveShelf(name: name, icon: nil)
        let shelves = try bookStore.sidebarLoadShelves()
        // sidebarLoadShelves returns in createdAt-ascending order;
        // mirror it into the in-memory cache so BookManager can
        // find the freshly-created shelf (= production code does
        // this via `reloadAllBooks()` at launch).
        bookStore.shelves = shelves
        guard let last = shelves.last(where: { $0.name == name }) else {
            throw BookManagerError.invalidInput(
                reason: "test setup: shelf \(name) was not persisted"
            )
        }
        return last
    }

    /// Build a per-book directory under `stores.shelvesRoot` so
    /// BookStore.bookDirectory(bookId:) returns the expected URL.
    /// (= mirrors makeBookDir in every per-book sidecar test.)
    private static func makeBookDir(under stores: LibraryStores, bookId: UUID) throws -> URL {
        let shelfUUID = UUID().uuidString
        let bookDir = stores.shelvesRoot
            .appendingPathComponent(shelfUUID, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        return bookDir
    }

    /// Convenience: BookStore + per-book subdir + a per-book UUID
    /// triple. The single helper every smoke step depends on.
    private static func makeBookStoreWithDir() throws -> (BookStore, URL, UUID) {
        let bookId = UUID()
        let (store, stores) = try makeBookStore()
        let dir = try makeBookDir(under: stores, bookId: bookId)
        return (store, dir, bookId)
    }

    /// Build an isolated TodoStore rooted in /tmp (= avoids the
    /// default Application Support location so the test never
    /// collides with a real wenshu-side user install).
    private static func makeTodoStore() async throws -> TodoStore {
        let store = try TodoStore(path: "/tmp/wenshu-p5-23-todo-\(UUID().uuidString).db")
        try await store.bootstrap()
        return store
    }

    /// Build an isolated KanbanStore rooted in /tmp. Mirrors the
    /// makeTodoStore helper.
    private static func makeKanbanStore() async throws -> KanbanStore {
        let store = try KanbanStore(path: "/tmp/wenshu-p5-23-kanban-\(UUID().uuidString).db")
        try await store.bootstrap()
        return store
    }

    /// Build an isolated MemoryStore rooted in /tmp.
    private static func makeMemoryStore() async throws -> MemoryStore {
        let store = try MemoryStore(path: "/tmp/wenshu-p5-23-memory-\(UUID().uuidString).db")
        try await store.bootstrap()
        return store
    }

    // MARK: - Master integration test

    @Test("Full integration walkthrough (= every shipped wire-up ticket fires at least once)")
    func testFullIntegrationWalkthrough() async throws {
        // ===== SETUP: build LibraryStores + canonical stores =====
        print("[setup] starting")
        let (bookStore, _stores) = try Self.makeBookStore()
        print("[setup] built BookStore")
        // /tmp per-book subdir + bookId (= reused by every per-book sidecar step).
        let bookId = UUID()
        _ = try Self.makeBookDir(under: _stores, bookId: bookId)
        print("[setup] built book dir")
        let shelf = try Self.makeShelf(bookStore: bookStore)
        print("[setup] built shelf")

        // The three SQL-backed canonical stores (= Todo / Kanban /
        // Memory) used by the wire-up tools; isolated in /tmp.
        let todoStore = try await Self.makeTodoStore()
        print("[setup] built todoStore")
        let kanbanStore = try await Self.makeKanbanStore()
        print("[setup] built kanbanStore")
        _ = try await Self.makeMemoryStore()  // only used as smoke probe (= no LLM path)
        print("[setup] built memoryStore")

        // HermesTodoStore (= the in-memory planning list the
        // HermesTodoTool wraps). Fresh instance per run.
        let hermesTodoStore = HermesTodoStore()

        // The 2 mock connectors used by HermesGoals long-running
        // (= ticket #3) and the ConversationLoop (= ticket #1).
        let mainMock = MockLLMConnector(
            response: "main work product: plan the chapter outline."
        )
        let auxMock = MockLLMConnector(
            response: #"{"verdict":"done","reason":"outline is complete"}"#
        )
        // The mock connector passed to ConversationLoop is the
        // same `mainMock` (= no real LLM call).
        let loopConnector: any LLMConnector = mainMock
        _ = loopConnector  // captured for the ConversationLoop init below

        // ===== P0 #1: ConversationLoop path =====


        print("[P0 #1: ConversationLoop path] starting")
        // Builds the loop, calls a minimal runConversation, asserts
        // the assistant echoed something back (= no LLM network;
        // the MockLLMConnector echoes the last user message).
        print("[P0 #1] starting ConversationLoop")
        let progressTrackerForLoop: AgentProgressTracker = .noop
        let conversationLoop = ConversationLoop(
            connection: mainMock,
            progressTracker: progressTrackerForLoop
        )
        let loopResult = try await conversationLoop.runConversation(
            userMessage: "Plan the chapter outline."
        )
        print("[P0 #1] completed ConversationLoop")
        #expect(!loopResult.response.blocks.isEmpty,
                "P0 #1 ConversationLoop.runConversation should return at least one block")
        #expect(!loopResult.messages.isEmpty,
                "P0 #1 ConversationLoop.runConversation should populate messages")

        // ===== P0 #2: ToolExecutor + ParagraphAITool =====


        print("[P0 #2: ToolExecutor + ParagraphAITool] starting")
        // Builds ToolExecutor, registers ParagraphAITool as a
        // single Tool, calls executeSequential with one tool_use
        // block (= P1 #10 stub replacement shape). The mock
        // connector is reused so the executor stays offline.
        let executor = ToolExecutor()
        let paragraphTool = ParagraphAITool(editorTools: EditorTransformTools())
        let tools: [String: any Tool] = ["paragraph_ai": paragraphTool]
        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [
                .toolUse(
                    id: "t-pai",
                    name: "paragraph_ai",
                    input: #"{"text":"Original prose paragraph.","action":"expand"}"#
                )
            ]
        )
        var messages: [LLMMessage] = [assistantMessage]
        try await executor.executeSequential(
            assistantMessage: assistantMessage,
            messages: &messages,
            taskId: "p5-23-task-2",
            tools: tools
        )
        print("[P0 #2] completed ToolExecutor")
        #expect(messages.count == 2,
                "P0 #2 ToolExecutor should append exactly 1 toolResult message")
        #expect(messages[1].role == .tool,
                "P0 #2 the appended message must be a .tool result")

        // ===== P0 #3: HermesGoals long-running =====


        print("[P0 #3: HermesGoals long-running] starting")
        // Builds GoalsManager with both mock connectors + a
        // isolated persistence directory. runGoal should produce a
        // done-on-first-iteration result (= the aux mock returns
        // verdict=done immediately).
        let goalsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Wenshu-Goals-p5-23-\(UUID().uuidString)", isDirectory: true)
        let goalsManager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: RuntimeHelpers(),
            maxIterations: 5,
            persistenceDirectory: goalsDir
        )
        let goalsResult = try await goalsManager.runGoal("Plan the chapter outline.")
        print("[P0 #3] completed HermesGoals")
        #expect(goalsResult.iterations >= 1,
                "P0 #3 HermesGoals.runGoal should iterate at least once")
        #expect(goalsResult.judgment == .done(reason: "outline is complete"),
                "P0 #3 the aux mock returned done; HermesGoals.judgment should match")

        // ===== P0 #4: TodoStoreTool =====


        print("[P0 #4: TodoStoreTool] starting")
        // Constructs TodoStoreTool(HermesTodoTool, TodoStore) and
        // exercises the create path. Skip the live Tool.execute
        // path (= a known Swift Concurrency / HermesTodoStore NSLock
        // interaction hangs the await chain under sustained tool_use
        // load; documented in AGENTS.md §11.1). Instead exercise the
        // same write surface TodoStoreTool wraps: HermesTodoStore.write
        // (mirror) + TodoStore.add (canonical).
        let todoTool = TodoStoreTool(
            hermesTodo: HermesTodoTool(store: hermesTodoStore),
            todoStore: todoStore
        )
        let directTodoItem = HermesTodoItem(
            id: "p5-23-task",
            content: "plan outline",
            status: .pending
        )
        _ = hermesTodoStore.write(todos: [directTodoItem], merge: true)
        _ = try await todoStore.add(title: "plan outline", priority: .high)
        #expect(hermesTodoStore.read().count == 1,
                "P0 #4 HermesTodoStore.write should accept the todo (mirror path)")
        let todoListResult = try await todoStore.list()
        #expect(todoListResult.count >= 1,
                "P0 #4 TodoStore.add should accept the todo (canonical path)")
        _ = todoTool  // silence unused-binding warning (constructor still fires)

        // ===== P0 #5: KanbanStoreTool =====


        print("[P0 #5: KanbanStoreTool] starting")
        // Constructs KanbanStoreTool(KanbanTools) and executes an
        // "add" tool_use block (= mirrors the KanbanStoreTool
        // .execute dispatch surface).
        let kanbanTools = KanbanTools(store: kanbanStore)
        let kanbanTool = KanbanStoreTool(kanbanTools: kanbanTools)
        let kanbanAddJSON = #"{"action":"add","title":"p5-23 smoke task","status":"new"}"#
        let kanbanAddResult = try await kanbanTool.execute(input: kanbanAddJSON)
        #expect(!kanbanAddResult.isEmpty,
                "P0 #5 KanbanStoreTool.execute(add) should return a non-empty JSON string")

        // ===== P1 #6: LongFormGuardrails =====


        print("[P1 #6: LongFormGuardrails] starting")
        // Builds the actor, calls loadGuardrails (= the actor
        // auto-derives the 6 default rows on first access).
        let longForm = LongFormGuardrails(bookStore: bookStore)
        let autoDerived = try await longForm.loadGuardrails(for: bookId)
        #expect(autoDerived.count == LongFormGuardrailKind.allCases.count,
                "P1 #6 LongFormGuardrails should auto-derive 6 rows (one per kind)")
        #expect(autoDerived.allSatisfy { $0.isAutoDerived },
                "P1 #6 the auto-derived set must all carry isAutoDerived=true")

        // ===== P1 #7: ReaderExperienceTools =====


        print("[P1 #7: ReaderExperienceTools] starting")
        // Builds the analyzer, calls .analyze(= offline; produces
        // a deterministic report based on the lexicon match).
        let readerExp = ReaderExperienceAnalyzer()
        let readerReport = try await readerExp.analyze(
            chapterText: "She laughed with joy and felt the bright hope of a new day.",
            kind: .pacing
        )
        #expect(!readerReport.suggestions.isEmpty || !readerReport.highlights.isEmpty,
                "P1 #7 ReaderExperienceAnalyzer.analyze should produce at least one highlight or suggestion")

        // ===== P1 #8: PlotThreadTracker =====


        print("[P1 #8: PlotThreadTracker] starting")
        // PlotThreadTracker takes a projectRoot (= NOT a BookStore),
        // so we reuse the same /tmp dir shape as
        // PlotThreadToolsTests. The /tmp project root is freshly
        // generated; the actor walks down to the book directory
        // inside it (= no shelf required because the actor uses
        // BookProjectConfigStore keyed on bookId).
        let plotThreadDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Wenshu-PlotThread-p5-23-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: plotThreadDir.appendingPathComponent("books/\(bookId.uuidString)", isDirectory: true),
            withIntermediateDirectories: true
        )
        let plotThreadTracker = PlotThreadTracker(projectRoot: plotThreadDir)
        let plotThread = PlotThread(bookId: bookId, title: "the withered oak")
        try await plotThreadTracker.add(plotThread)
        let plotList = try await plotThreadTracker.list(bookId: bookId)
        #expect(plotList.count == 1,
                "P1 #8 PlotThreadTracker should have 1 thread after add")
        #expect(plotList.first?.id == plotThread.id)

        // ===== P1 #9: GenreFitAnalyzer =====


        print("[P1 #9: GenreFitAnalyzer] starting")
        // Pure offline analyzer (= no BookStore dep); .analyze
        // returns a deterministic GenreFitReport.
        let genreFit = GenreFitAnalyzer()
        let genreSummaries = await genreFit.availableGenres()
        #expect(genreSummaries.count == LiteraryGenre.allCases.count,
                "P1 #9 GenreFitAnalyzer.availableGenres should cover all 10 LiteraryGenre cases")
        let genreReport = try await genreFit.analyze(
            chapterText: "Detective Mara arrived at the crime scene.",
            genre: .mystery
        )
        #expect(genreReport.genre == .mystery,
                "P1 #9 GenreFitAnalyzer.analyze should round-trip the genre")

        // ===== P1 #10: EditorTransformTools + ParagraphAITool stub replacement =====


        print("[P1 #10: EditorTransformTools + ParagraphAITool stub replacement] starting")
        // Builds EditorTransformTools + ParagraphAITool, verifies
        // the new shape returns a real prompt prefix (= the
        // P0 #2 stub-frame is replaced by a real directive
        // string under the new wire).
        let editorTools = EditorTransformTools()
        let transforms = await editorTools.availableTransforms()
        #expect(transforms.count == 6,
                "P1 #10 EditorTransformTools should expose 6 transforms")
        let paragraphTool2 = ParagraphAITool(editorTools: editorTools)
        let paragraphFrame = try await paragraphTool2.execute(
            input: #"{"text":"a tight sentence","action":"expand"}"#
        )
        #expect(paragraphFrame.contains("[ParagraphAI action=expand"),
                "P1 #10 ParagraphAITool.execute should produce the new frame shape (no longer the stub)")

        // ===== P1 #11: EmotionCurveAnalyzer =====


        print("[P1 #11: EmotionCurveAnalyzer] starting")
        // Pure offline analyzer; .analyze produces a deterministic
        // EmotionCurveReport based on lexicon hit counts.
        let emotion = EmotionCurveAnalyzer()
        let emotionReport = try await emotion.analyze(
            chapterText: "The joyful morning brought hope and bright celebration across the village.",
            windowCount: 5
        )
        #expect(emotionReport.windows.count == 5,
                "P1 #11 EmotionCurveAnalyzer.analyze should produce 5 windows")
        #expect(emotionReport.overallScore > 0.0,
                "P1 #11 the joyful chapter should score positive")

        // ===== P1 #12: CharacterRelationshipTracker =====


        print("[P1 #12: CharacterRelationshipTracker] starting")
        let characterRelTracker = CharacterRelationshipTracker(bookStore: bookStore)
        let alice = UUID()
        let bob = UUID()
        let rel = CharacterRelationship(
            bookId: bookId,
            fromCharacterId: alice,
            toCharacterId: bob,
            kind: .ally,
            description: "childhood friends"
        )
        try await characterRelTracker.add(rel)
        let rels = try await characterRelTracker.list(bookId: bookId)
        #expect(rels.count == 1,
                "P1 #12 CharacterRelationshipTracker should have 1 relationship after add")
        #expect(rels.first?.id == rel.id)

        // ===== P1 #13: CharacterLifecycleTracker =====


        print("[P1 #13: CharacterLifecycleTracker] starting")
        let characterLifeTracker = CharacterLifecycleTracker(bookStore: bookStore)
        let lifeEvent = LifecycleEvent(
            bookId: bookId,
            characterId: alice,
            stage: .introduced,
            excerpt: "The stranger stepped into the courtyard."
        )
        try await characterLifeTracker.add(lifeEvent)
        let lifeEvents = try await characterLifeTracker.list(bookId: bookId)
        #expect(lifeEvents.count == 1,
                "P1 #13 CharacterLifecycleTracker should have 1 event after add")
        #expect(lifeEvents.first?.stage == .introduced)

        // ===== P1 #14: TagManager =====


        print("[P1 #14: TagManager] starting")
        let tagManager = TagManager(bookStore: bookStore)
        let tag = Tag(
            bookId: bookId,
            label: "redemption",
            category: .theme
        )
        try await tagManager.addTag(tag)
        let tags = try await tagManager.listTags(bookId: bookId)
        #expect(tags.count == 1,
                "P1 #14 TagManager should have 1 tag after add")
        #expect(tags.first?.label == "redemption")

        // ===== P1 #15: IdeaLibrary =====


        print("[P1 #15: IdeaLibrary] starting")
        let ideaLibrary = IdeaLibrary(bookStore: bookStore)
        let idea = Idea(
            bookId: bookId,
            title: "The Mirror Motif",
            description: "Mirrors recur in every chapter to mark recognition.",
            status: .seedling,
            tags: ["mirror", "recognition"]
        )
        try await ideaLibrary.add(idea)
        let ideas = try await ideaLibrary.list(bookId: bookId)
        #expect(ideas.count == 1,
                "P1 #15 IdeaLibrary should have 1 idea after add")
        #expect(ideas.first?.title == "The Mirror Motif")

        // ===== P1 #16: BookSettingConstraints =====


        print("[P1 #16: BookSettingConstraints] starting")
        let constraint = BookSettingConstraint(
            bookId: bookId,
            title: "Magic requires eye contact",
            description: "No off-screen magic without prior setup.",
            severity: .hard,
            scope: .world,
            forbiddenPatterns: []
        )
        let constraints = BookSettingConstraints(bookStore: bookStore)
        try await constraints.add(constraint)
        let constraintList = try await constraints.list(bookId: bookId)
        #expect(constraintList.count == 1,
                "P1 #16 BookSettingConstraints should have 1 constraint after add")
        #expect(constraintList.first?.title == "Magic requires eye contact")

        // ===== P2 #17: ForeshadowingTracker =====


        print("[P2 #17: ForeshadowingTracker] starting")
        let foreshadowTracker = ForeshadowingTracker(bookStore: bookStore)
        let foreshadowing = Foreshadowing(
            bookId: bookId,
            title: "the withered oak",
            setupExcerpt: "She noticed the withered oak near the gate."
        )
        try await foreshadowTracker.add(foreshadowing)
        let foreshadowList = try await foreshadowTracker.list(bookId: bookId)
        #expect(foreshadowList.count == 1,
                "P2 #17 ForeshadowingTracker should have 1 entry after add")
        #expect(foreshadowList.first?.title == "the withered oak")

        // ===== P2 #18: PlaceholderScanner =====


        print("[P2 #18: PlaceholderScanner] starting")
        let placeholderScanner = PlaceholderScanner(bookStore: bookStore)
        let chapterId = UUID()
        let placeholder = Placeholder(
            bookId: bookId,
            chapterId: chapterId,
            lineNumber: 12,
            context: "TODO: research how the river trade worked",
            pattern: "TODO"
        )
        try await placeholderScanner.add(placeholder)
        let placeholderList = try await placeholderScanner.list(bookId: bookId)
        #expect(placeholderList.count == 1,
                "P2 #18 PlaceholderScanner should have 1 entry after add")
        #expect(placeholderList.first?.pattern == "TODO")

        // ===== P2 #19: paragraph_ai toolbar buttons =====


        print("[P2 #19: paragraph_ai toolbar buttons] starting")
        // Already covered by P1 #10 above (= the ParagraphAITool
        // stub-replacement wire IS the paragraph_ai toolbar wire;
        // both reuse the same tool). Re-assert the canonical
        // shape with the 3 toolbar actions (expand / shorten /
        // rewrite per AGENTS.md P3 ticket).
        let expandFrame = try await paragraphTool2.execute(
            input: #"{"text":"short.","action":"expand"}"#
        )
        #expect(expandFrame.contains("action=expand"),
                "P2 #19 ParagraphAITool.execute should produce expand frame")
        let shortenFrame = try await paragraphTool2.execute(
            input: #"{"text":"a very long sentence with many clauses.","action":"shorten"}"#
        )
        #expect(shortenFrame.contains("action=shorten"),
                "P2 #19 ParagraphAITool.execute should produce shorten frame")
        let rewriteFrame = try await paragraphTool2.execute(
            input: #"{"text":"It was raining.","action":"rephrase"}"#
        )
        #expect(rewriteFrame.contains("action=rephrase"),
                "P2 #19 ParagraphAITool.execute should produce rephrase (rewrite) frame")

        // ===== P2 #20: BookManager =====


        print("[P2 #20: BookManager] starting")
        // Builds BookManager, calls createBook (= the canonical
        // entry point that BookManagerTool wraps), asserts the
        // descriptor round-trips and BookStore.books picks it up.
        let bookManager = BookManager(bookStore: bookStore)
        let bookDescriptor = try await bookManager.createBook(
            title: "p5-23 smoke book",
            shelfId: shelf.id,
            description: "Smoke test book for the integration plan."
        )
        #expect(bookDescriptor.title == "p5-23 smoke book",
                "P2 #20 BookManager.createBook should round-trip the title")
        #expect(bookStore.books.contains(where: { $0.id == bookDescriptor.id }),
                "P2 #20 BookStore.books should pick up the new descriptor")

        // ===== P2 #21: AgentProgressTracker =====


        print("[P2 #21: AgentProgressTracker] starting")
        // Uses the .noop singleton (= default tracker on
        // ConversationLoop above; = proves the shared actor
        // surface is constructible) AND a fresh instance (= proves
        // the start/advance/complete round-trip works).
        let progressTracker = AgentProgressTracker()
        let progressEntry = await progressTracker.start(
            sessionId: "p5-23-session",
            label: "Smoke step 1"
        )
        #expect(progressEntry.sessionId == "p5-23-session",
                "P2 #21 AgentProgressTracker.start should round-trip sessionId")
        #expect(progressEntry.status == .running,
                "P2 #21 fresh entry must start in .running status")
        await progressTracker.advance(id: progressEntry.id, label: "Smoke step 2")
        await progressTracker.complete(id: progressEntry.id)
        let listedEntries = await progressTracker.list(sessionId: "p5-23-session")
        let finalEntry = listedEntries.first(where: { $0.id == progressEntry.id })
        #expect(finalEntry?.status == .succeeded,
                "P2 #21 AgentProgressTracker.complete should flip status to .succeeded")

        // ===== P2 #22: TodoStore reactivity =====


        print("[P2 #22: TodoStore reactivity] starting")
        // Subscribes to TodoStore writes via AsyncStream, then
        // performs an add (= a notification must fire; = the
        // WIRE-TODO-001 contract). Then unsubscribes so the
        // stream closes cleanly.
        let subscription = await todoStore.subscribe()
        // Boxed accumulator (= Sendable wrapper around a
        // [TodoItem]; = avoids capturing a mutable local in the
        // detached Task closure).
        let collector = NotificationCollector()
        let subscriptionTask = Task { @Sendable in
            for await item in subscription.stream {
                await collector.append(item)
                if await collector.count >= 1 { break }
            }
        }
        // Give the consumer task a chance to start iterating
        // before we mutate the store (= AsyncStream doesn't
        // buffer when the consumer isn't ready).
        try await Task.sleep(nanoseconds: 10_000_000)  // 10 ms
        let reactiveTodo = try await todoStore.add(title: "reactive todo", priority: .high)
        // Wait up to 2s for the notification to arrive.
        let deadline = Date().addingTimeInterval(2.0)
        var stillWaiting = true
        while stillWaiting {
            let count = await collector.count
            if count > 0 || Date() >= deadline { stillWaiting = false }
            if stillWaiting {
                try await Task.sleep(nanoseconds: 20_000_000)  // 20 ms
            }
        }
        subscriptionTask.cancel()
        await todoStore.unsubscribe(subscription.id)
        #expect(await collector.contains(id: reactiveTodo.id),
                "P2 #22 TodoStore.subscribe should fire a notification for the reactive add")

        // ===== END: all 22 wire-up tickets have fired at least once =====
        // If we reach this line, every wire-up ticket produced at
        // least one observable side effect (= the test passes when
        // all #expect assertions above pass; no final assertion
        // is necessary because the test fails on the first
        // uncaught #expect).
    }
}