//
//  HermesGoalsTests.swift · Wenshu · HERMES-SUBSYSTEM-5 (ticket 026 step 5)
//
//  Eight round-trip tests for the 1:1 port of hermes goals.py to
//  HermesGoals.swift. Tests verify the parity surface (= runGoal loop,
//  auxiliary judgment, filesystem persistence, cross-turn reload, and
//  per-book scope directory).
//
//  Test inventory (= per ticket 026 step 5 §File 3):
//
//    1. testRunGoal_doneImmediately  — auxiliary says "done" on iter 1
//                                      → result.iterations == 1, .done
//    2. testRunGoal_iteratesUntilDone — auxiliary says "continue" 3×
//                                      then "done" → result.iterations == 4
//    3. testRunGoal_maxIterations    — auxiliary says "continue" forever
//                                      → result.iterations == maxIterations,
//                                        .failed("Maximum goal iterations...")
//    4. testJudge                    — GoalsManager.judge(work:goal:) calls
//                                      auxiliary once and returns its verdict
//    5. testPersistGoal              — persistGoal writes the expected JSON
//                                      file under the persistence directory
//    6. testLoadGoal                 — loadGoal reads the JSON file back
//                                      and returns the GoalsWork
//    7. testCrossTurnContext         — a fresh GoalsManager that shares the
//                                      persistence directory can read goals
//                                      written by a prior manager instance
//    8. testPerBookScope             — passing a per-book persistence
//                                      directory writes the JSON file under
//                                      THAT directory, NOT the global scope
//
//  Test fixtures use the shared MockLLMConnector (= defined in
//  MockLLMConnector.swift) with `scriptedResponses` to script canned
//  main-model work outputs and auxiliary-model verdict JSON blocks.
//  Each iteration of runGoal alternates one main send + one auxiliary
//  send, so the scripted response arrays must be sized accordingly.
//
//  Persistence tests use FileManager.default.temporaryDirectory scoped
//  by a unique UUID subdirectory per test, which is cleaned up via
//  `defer` after the test finishes.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("HermesGoals (HERMES-SUBSYSTEM-5)")
struct HermesGoalsTests {

    // MARK: - Shared helpers

    /// Build a canned `LLMResponse` for the main connector (= a single text
    /// block containing the supplied work string).
    private static func mainResponse(_ text: String) -> LLMResponse {
        LLMResponse(
            id: "main-\(UUID().uuidString)",
            model: "main-mock",
            blocks: [.text(text)],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 10, outputTokens: 20)
        )
    }

    /// Build a canned auxiliary response. The text block carries the JSON
    /// verdict that GoalsManager.parseJudgment will decode (= either
    /// `{"verdict":"done",...}` or `{"verdict":"continue",...}`).
    private static func auxiliaryVerdict(_ verdict: String, reason: String) -> LLMResponse {
        let escapedReason = reason
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let json = "{\"verdict\":\"\(verdict)\",\"reason\":\"\(escapedReason)\"}"
        return LLMResponse(
            id: "aux-\(UUID().uuidString)",
            model: "aux-mock",
            blocks: [.text(json)],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 5, outputTokens: 5)
        )
    }

    /// Build a `RuntimeHelpers` actor with all sinks stubbed and no mock-time.
    /// runGoal only calls `runtime.now()` (= a no-op for behavior beyond the
    /// mock-time gate), so a bare RuntimeHelpers() is sufficient.
    private static func makeRuntime() -> RuntimeHelpers {
        RuntimeHelpers()
    }

    /// Build a fresh isolated temp directory for a single persistence test.
    /// Returns the URL and an idempotent cleanup closure (= safe to call
    /// even when the directory was never created).
    private static func makeTempPersistenceDir() -> (URL, () -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HermesGoalsTests-\(UUID().uuidString)", isDirectory: true)
        let cleanup: () -> Void = {
            try? FileManager.default.removeItem(at: dir)
        }
        return (dir, cleanup)
    }

    // MARK: - Test 1: runGoal done on first iteration

    @Test("runGoal returns .done with iterations=1 when auxiliary says done immediately")
    func testRunGoal_doneImmediately() async throws {
        // Main produces a work string on iter 1; auxiliary immediately returns done.
        let mainMock = MockLLMConnector(scriptedResponses: [
            Self.mainResponse("First pass work product.")
        ])
        let auxMock = MockLLMConnector(scriptedResponses: [
            Self.auxiliaryVerdict("done", reason: "Goal satisfied in one pass.")
        ])
        let (dir, cleanup) = Self.makeTempPersistenceDir()
        defer { cleanup() }

        let manager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: Self.makeRuntime(),
            maxIterations: 10,
            persistenceDirectory: dir
        )

        let result = try await manager.runGoal("Write the book intro.")

        #expect(result.iterations == 1)
        #expect(result.finalWork == "First pass work product.")
        if case .done(let reason) = result.judgment {
            #expect(reason == "Goal satisfied in one pass.")
        } else {
            Issue.record("Expected .done judgment, got \(result.judgment)")
        }
        #expect(result.mainUsages.count == 1)
    }

    // MARK: - Test 2: runGoal iterates 3× then done

    @Test("runGoal accumulates iterations until auxiliary returns done")
    func testRunGoal_iteratesUntilDone() async throws {
        // 4 iterations total: main→continue, main→continue, main→continue,
        // main→done. Each iteration needs one main response + one auxiliary
        // response (= the manager alternates main.send then judge()).
        var mainScript: [LLMResponse] = []
        var auxScript: [LLMResponse] = []
        for iteration in 1...4 {
            mainScript.append(Self.mainResponse("Work at iteration \(iteration)."))
            let verdict = iteration == 4 ? "done" : "continue"
            let reason = iteration == 4
                ? "Final iteration satisfied the goal."
                : "Iteration \(iteration) made progress but goal not done."
            auxScript.append(Self.auxiliaryVerdict(verdict, reason: reason))
        }
        let mainMock = MockLLMConnector(scriptedResponses: mainScript)
        let auxMock = MockLLMConnector(scriptedResponses: auxScript)
        let (dir, cleanup) = Self.makeTempPersistenceDir()
        defer { cleanup() }

        let manager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: Self.makeRuntime(),
            maxIterations: 10,
            persistenceDirectory: dir
        )

        let result = try await manager.runGoal("Compose three chapters.")

        #expect(result.iterations == 4)
        #expect(result.finalWork == "Work at iteration 4.")
        if case .done(let reason) = result.judgment {
            #expect(reason == "Final iteration satisfied the goal.")
        } else {
            Issue.record("Expected .done judgment, got \(result.judgment)")
        }
        #expect(result.mainUsages.count == 4)
    }

    // MARK: - Test 3: runGoal hits maxIterations and returns .failed

    @Test("runGoal returns .failed(max iterations reached) when auxiliary never says done")
    func testRunGoal_maxIterations() async throws {
        // maxIterations = 10 → loop runs 10 times, each with main→continue.
        let totalIterations = 10
        var mainScript: [LLMResponse] = []
        var auxScript: [LLMResponse] = []
        for iteration in 1...totalIterations {
            mainScript.append(Self.mainResponse("Still working (\(iteration))."))
            auxScript.append(Self.auxiliaryVerdict(
                "continue",
                reason: "Not done yet at iteration \(iteration)."
            ))
        }
        let mainMock = MockLLMConnector(scriptedResponses: mainScript)
        let auxMock = MockLLMConnector(scriptedResponses: auxScript)
        let (dir, cleanup) = Self.makeTempPersistenceDir()
        defer { cleanup() }

        let manager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: Self.makeRuntime(),
            maxIterations: totalIterations,
            persistenceDirectory: dir
        )

        let result = try await manager.runGoal("An unsatisfiable goal.")

        #expect(result.iterations == totalIterations)
        if case .failed(let reason) = result.judgment {
            #expect(reason.contains("Maximum goal iterations reached"))
            #expect(reason.contains("\(totalIterations)"))
        } else {
            Issue.record("Expected .failed(max iterations) judgment, got \(result.judgment)")
        }
        #expect(result.mainUsages.count == totalIterations)
    }

    // MARK: - Test 4: judge(work:goal:) calls auxiliary once and returns its verdict

    @Test("judge calls the auxiliary connector exactly once and returns its parsed verdict")
    func testJudge() async throws {
        let auxMock = MockLLMConnector(scriptedResponses: [
            Self.auxiliaryVerdict("done", reason: "Work meets the stated goal.")
        ])
        let mainMock = MockLLMConnector()  // unused — judge only touches auxiliary
        let (dir, cleanup) = Self.makeTempPersistenceDir()
        defer { cleanup() }

        let manager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: Self.makeRuntime(),
            persistenceDirectory: dir
        )

        let judgment = try await manager.judge(work: "Some work product", goal: "Achieve X")

        if case .done(let reason) = judgment {
            #expect(reason == "Work meets the stated goal.")
        } else {
            Issue.record("Expected .done judgment, got \(judgment)")
        }

        // Confirm the auxiliary mock received exactly one send and the
        // main mock received none (= use the public `receivedOptions` counter
        // exposed by MockLLMConnector — it appends per send() call).
        let auxCalls = await auxMock.receivedOptions.count
        #expect(auxCalls == 1)
        let mainCalls = await mainMock.receivedOptions.count
        #expect(mainCalls == 0)
    }

    // MARK: - Test 5: persistGoal writes JSON to disk

    @Test("persistGoal writes a JSON file under the persistence directory")
    func testPersistGoal() async throws {
        let auxMock = MockLLMConnector()
        let mainMock = MockLLMConnector()
        let (dir, cleanup) = Self.makeTempPersistenceDir()
        defer { cleanup() }

        let manager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: Self.makeRuntime(),
            persistenceDirectory: dir
        )

        let goalId = UUID()
        let work = GoalsWork(
            goal: "Persist this goal.",
            work: "Persisted body text.",
            iterations: 3,
            context: ["note a", "note b"]
        )

        try await manager.persistGoal(goalId, work: work)

        let fileURL = dir.appendingPathComponent("\(goalId.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Read the raw file back and verify the goal/work/iterations round-trip.
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode(GoalsWork.self, from: data)
        #expect(decoded == work)
    }

    // MARK: - Test 6: loadGoal reads JSON from disk

    @Test("loadGoal returns the GoalsWork previously written by persistGoal")
    func testLoadGoal() async throws {
        let auxMock = MockLLMConnector()
        let mainMock = MockLLMConnector()
        let (dir, cleanup) = Self.makeTempPersistenceDir()
        defer { cleanup() }

        let manager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: Self.makeRuntime(),
            persistenceDirectory: dir
        )

        let goalId = UUID()
        let original = GoalsWork(
            goal: "Reload me.",
            work: "Body to reload.",
            iterations: 7,
            context: ["ctx"]
        )
        try await manager.persistGoal(goalId, work: original)

        let loaded = try await manager.loadGoal(goalId)
        #expect(loaded == original)

        // Unknown UUID should return nil (no file on disk, no actor memory).
        let missing = try await manager.loadGoal(UUID())
        #expect(missing == nil)
    }

    // MARK: - Test 7: cross-turn context — a fresh manager reads prior writes

    @Test("a fresh GoalsManager sharing the persistence directory reloads prior writes")
    func testCrossTurnContext() async throws {
        let auxMockA = MockLLMConnector()
        let mainMockA = MockLLMConnector()
        let auxMockB = MockLLMConnector()
        let mainMockB = MockLLMConnector()
        let (dir, cleanup) = Self.makeTempPersistenceDir()
        defer { cleanup() }

        // Turn 1: manager A writes a goal to disk.
        let managerA = GoalsManager(
            mainConnector: mainMockA,
            auxiliaryConnector: auxMockA,
            runtime: Self.makeRuntime(),
            persistenceDirectory: dir
        )
        let goalId = UUID()
        let original = GoalsWork(
            goal: "Cross-turn goal.",
            work: "Cross-turn work.",
            iterations: 5,
            context: ["carryover"]
        )
        try await managerA.persistGoal(goalId, work: original)

        // Turn 2: a brand-new manager (= "next turn") that shares the same
        // persistence directory loads the file manager A wrote. This proves
        // that the persisted state survives actor-instance turnover (= the
        // filesystem is the cross-turn boundary, not the actor's memory).
        let managerB = GoalsManager(
            mainConnector: mainMockB,
            auxiliaryConnector: auxMockB,
            runtime: Self.makeRuntime(),
            persistenceDirectory: dir
        )

        let reloaded = try await managerB.loadGoal(goalId)
        #expect(reloaded == original)

        // Round-trip through disk + back: write again with manager B and
        // read with manager A to confirm bidirectional persistence across the
        // actor-instance boundary (= the full cross-turn contract).
        let secondGoalId = UUID()
        let secondWork = GoalsWork(
            goal: "Manager B goal.",
            work: "Manager B body.",
            iterations: 2,
            context: []
        )
        try await managerB.persistGoal(secondGoalId, work: secondWork)
        let reloadedByA = try await managerA.loadGoal(secondGoalId)
        #expect(reloadedByA == secondWork)
    }

    // MARK: - Test 8: per-book scope — JSON lands under the supplied directory, not global

    @Test("per-book persistence directory isolates goals from the global scope")
    func testPerBookScope() async throws {
        let auxMock = MockLLMConnector()
        let mainMock = MockLLMConnector()
        let (globalDir, globalCleanup) = Self.makeTempPersistenceDir()
        let (bookDir, bookCleanup) = Self.makeTempPersistenceDir()
        defer {
            globalCleanup()
            bookCleanup()
        }

        // Both managers share the runtime mocks but use DIFFERENT persistence
        // directories. Manager A points at the global scope; manager B
        // (= the "book" scope) gets its own per-book subdirectory.
        let globalManager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: Self.makeRuntime(),
            persistenceDirectory: globalDir
        )
        let bookManager = GoalsManager(
            mainConnector: mainMock,
            auxiliaryConnector: auxMock,
            runtime: Self.makeRuntime(),
            persistenceDirectory: bookDir
        )

        let bookGoalId = UUID()
        let bookWork = GoalsWork(goal: "Book-only goal.", work: "Body.", iterations: 1)
        try await bookManager.persistGoal(bookGoalId, work: bookWork)

        // The JSON must exist under bookDir and NOT under globalDir.
        let bookFile = bookDir.appendingPathComponent("\(bookGoalId.uuidString).json")
        let globalFile = globalDir.appendingPathComponent("\(bookGoalId.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: bookFile.path))
        #expect(!FileManager.default.fileExists(atPath: globalFile.path))

        // The book-scoped manager can read it back; the global manager cannot.
        let bookReloaded = try await bookManager.loadGoal(bookGoalId)
        #expect(bookReloaded == bookWork)
        let globalReloaded = try await globalManager.loadGoal(bookGoalId)
        #expect(globalReloaded == nil)
    }
}