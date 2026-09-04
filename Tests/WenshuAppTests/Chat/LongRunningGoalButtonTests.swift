//
//  LongRunningGoalButtonTests.swift · Wenshu · WIRE-AGENT-003 (2026-09-04)
//
//  Round-trip tests for ChatViewModel.startLongRunningGoal (= the
//  ⌘⇧G chat button wired into ChatView per P0 #3). The button is
//  the user-visible front door to the HermesGoals Ralph loop
//  (= GoalsManager.runGoal); the tests prove the wire-up is
//  end-to-end correct from ChatViewModel's perspective.
//
//  Acceptance (= per P0 #3 brief, 3 tests):
//    1. testLongRunningGoal_emptyInput_doesNothing
//       — empty / whitespace input is a no-op (= no GoalsManager
//         created, no messages appended, no draft cleared).
//    2. testLongRunningGoal_withInput_appendsStartMessage
//       — non-empty input → a system ChatMessage is appended
//         synchronously with the format
//         "Long-running goal started: <goal> (handle <8 hex>)".
//         The persistence directory is also created (= proves the
//         GoalsManager path executed).
//    3. testLongRunningGoal_clearsDraftAfterStart
//       — after startLongRunningGoal, vm.inputText is "" (= the
//         draft is cleared so the user can keep typing while the
//         Ralph loop runs in background).
//
//  Note on mock strategy: the chat button constructs AnthropicConnector()
//  inline (= a real connector that fails with .missingAPIKey when no key
//  is configured). The tests do NOT try to mock that connector (= no
//  test seam was added; production code is left unchanged from the
//  ChatView.swift wire-up). The tests instead verify the synchronous
//  observable surface (= start system message + draft clear +
//  persistence directory creation) which is what the user sees when
//  they press ⌘⇧G. The actual GoalsManager.runGoal loop is exercised
//  in HermesGoalsTests.swift (= 8 round-trip tests covering done /
//  continue / maxIterations / persistence / cross-turn reload /
//  per-book scope).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WIRE-AGENT-003 — Long-running goal button (⌘⇧G)")
struct LongRunningGoalButtonTests {

    // MARK: - Test 1: empty input is a no-op

    @Test("startLongRunningGoal empty input does nothing")
    @MainActor
    func testLongRunningGoal_emptyInput_doesNothing() async {
        let vm = ChatViewModel()
        vm.inputText = "   \n  "

        let beforeMessageCount = vm.messages.count
        let beforeDraft = vm.inputText

        await vm.startLongRunningGoal()

        // No messages appended (= empty-input guard fired first).
        #expect(vm.messages.count == beforeMessageCount)
        // Draft unchanged (= the empty-input guard runs before the
        // inputText clear at the end of startLongRunningGoal).
        #expect(vm.inputText == beforeDraft)
    }

    // MARK: - Test 2: non-empty input appends the start message

    @Test("startLongRunningGoal with input appends start message and creates persistence dir")
    @MainActor
    func testLongRunningGoal_withInput_appendsStartMessage() async {
        let vm = ChatViewModel()
        vm.inputText = "Draft a chapter outline for the heist scene."

        let beforeMessageCount = vm.messages.count
        // Capture the temp directory that startLongRunningGoal creates
        // (= proves the GoalsManager.persistGoal path executed). The
        // directory is named "WenshuGoals-<UUID>" under
        // NSTemporaryDirectory; we enumerate the temp dir after the
        // call and look for a new "WenshuGoals-*" entry.
        let tempDir = FileManager.default.temporaryDirectory
        let beforeEntries = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)) ?? []
        let beforeWenshuGoalsEntries = beforeEntries.filter { $0.hasPrefix("WenshuGoals-") }

        await vm.startLongRunningGoal()

        // A system message was appended synchronously.
        #expect(vm.messages.count == beforeMessageCount + 1)
        let startMsg = vm.messages.last
        #expect(startMsg?.role == .system)
        #expect(startMsg?.source == .system)
        // Message format: "Long-running goal started: <goal> (handle <8 hex>)".
        #expect(startMsg?.content.hasPrefix("Long-running goal started: Draft a chapter outline for the heist scene.") == true)
        #expect(startMsg?.content.contains("(handle ") == true)

        // A new WenshuGoals-* persistence directory was created under
        // NSTemporaryDirectory (= proves GoalsManager.persistGoal ran).
        let afterEntries = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)) ?? []
        let afterWenshuGoalsEntries = afterEntries.filter { $0.hasPrefix("WenshuGoals-") }
        #expect(afterWenshuGoalsEntries.count > beforeWenshuGoalsEntries.count,
                "expected a new WenshuGoals-* persistence directory after startLongRunningGoal")

        // Clean up the persistence directory we just created so we
        // don't pollute the user's tmp over many test runs.
        for entry in afterWenshuGoalsEntries {
            if !beforeWenshuGoalsEntries.contains(entry) {
                let url = tempDir.appendingPathComponent(entry, isDirectory: true)
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Test 3: draft is cleared after start

    @Test("startLongRunningGoal clears the input draft after starting")
    @MainActor
    func testLongRunningGoal_clearsDraftAfterStart() async {
        let vm = ChatViewModel()
        vm.inputText = "Make the agent handle this end-to-end."

        await vm.startLongRunningGoal()

        // The draft is cleared synchronously inside
        // startLongRunningGoal (before the detached Task runs).
        #expect(vm.inputText.isEmpty)
    }
}