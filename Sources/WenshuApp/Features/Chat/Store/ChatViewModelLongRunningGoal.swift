//
//  ChatViewModelLongRunningGoal.swift
//
//  Long-running goal starter extracted from ChatSessionViewModel.swift
//  in A110 (= §6.6 60-LOC function-level cap; = `startLongRunningGoal`
//  was 88 LOC = 1.47x the cap).
//
//  Why a separate file (= and not in ChatSessionViewModel.swift): the
//  function is the "user typed a goal they want to keep working on
//  for many turns" starter (= 1 single concern = 4-stage async
//  pipeline: create goal message + create LLM message + wire
//  streaming + mark goal-bound); = putting it in its own file lets
//  the next reader find the long-running-goal entry point by name.
//  Also shrinks ChatSessionViewModel.swift from 1150 LOC (= 1.92x
//  the file-level cap) to ~1060 LOC.
//
//  Per the §6.2 4-slot spec: this is the @Observable state + business
//  logic = belongs in Store/ (= already is; = sibling of
//  ChatSessionViewModel.swift).
//
//  The function uses many stored properties (= messages + isSending +
//  inputText + attachedImagePath + etc.); = all those properties
//  must be internal (= not `private var`) for the cross-file
//  extension to reach them; = same pattern as A82-A83-A100-A108.
//

import Foundation
import WenshuAgent
import os

extension ChatViewModel {

    func startLongRunningGoal() async {
        let goal = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else { return }

        // Main + auxiliary connector. Both fallback to AnthropicConnector
        // (= a real LLMConnector that errors with .missingAPIKey when no
        // key is configured; the user sees the failure in the system
        // message). The AppState.activeConnector wiring is a separate
        // ticket — out of allowlist for this one.
        // AUDIT.md §2.2 partial (2026-10-16 boss "只做把之前的
        // 调用方式改成调用包" arc): resolve the active
        // connector through the public facade (= the
        // canonical source of truth; = no direct
        // `AnthropicConnector()` construction here).
        let mainConnector: any LLMConnector = WenshuAgent.shared.activeLLMConnector()
        let auxiliaryConnector: any LLMConnector = mainConnector

        // Runtime with default sinks + no mock-time (= test seam left
        // open for future GoalsManager-runtime-tests; runGoal only
        // reads runtime.now() between iterations).
        let runtime = RuntimeHelpers()

        // Per-session persistence directory under NSTemporaryDirectory.
        // HermesGoals.swift's GoalsManager.persistGoal requires the
        // directory to be writable (= tests use the same temp-scoped
        // pattern; see `HermesGoalsTests.makeTempPersistenceDir`).
        // Business layer must not touch infrastructure directly (=
        // the canonical separation rule). The
        // `FileManager.default.temporaryDirectory` call moves into
        // `HermesGoals.swift`'s `temporaryGoalsDirectory(prefix:)`
        // helper (= data-layer concern). Here we call the helper
        // instead of `FileManager` directly.
        let persistenceDirectory = GoalsManager.temporaryGoalsDirectory(
            prefix: "WenshuGoals"
        )

        let manager = GoalsManager(
            mainConnector: mainConnector,
            auxiliaryConnector: auxiliaryConnector,
            runtime: runtime,
            maxIterations: 10,
            persistenceDirectory: persistenceDirectory
        )

        // Initial persistence: record the goal's starting state so
        // the JSON file is visible in the persistence directory even
        // before runGoal produces any work. HermesGoals.swift does
        // not auto-persist; persistGoal is the explicit hook.
        let goalId = UUID()
        do {
            try await manager.persistGoal(
                goalId,
                work: GoalsWork(goal: goal, work: "", iterations: 0, context: [])
            )
        } catch {
            Self.logSwallowedPersistenceFailure(operation: "persistGoal", error: error)
        }

        let shortHandle = String(goalId.uuidString.prefix(8))
        messages.append(ChatMessage(
            role: .system,
            source: .system,
            content: "Long-running goal started: \(goal) (handle \(shortHandle))"
        ))

        // Clear the draft (= mirrors the routeInput() end-state so the
        // user can keep typing while the Ralph loop runs in background).
        inputText = ""

        // Detached background Task: GoalsManager.runGoal does its own
        // actor-isolated loop (= no @MainActor coupling), so we can
        // safely detach and bounce back to MainActor for chat updates.
        let capturedGoal = goal
        Task.detached(priority: .background) { [manager] in
            do {
                let result = try await manager.runGoal(capturedGoal)
                await MainActor.run {
                    self.messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: "Goal completed: \(capturedGoal) (iterations: \(result.iterations))"
                    ))
                }
            } catch {
                await MainActor.run {
                    self.messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: "Goal failed: \(capturedGoal) (\(error.localizedDescription))"
                    ))
                }
            }
        }
    }
}
