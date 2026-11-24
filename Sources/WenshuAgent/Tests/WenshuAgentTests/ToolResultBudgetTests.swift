import Foundation
import Testing
@testable import WenshuAgent

/// The tool-output budget, and the turn trim that enforces it.
///
/// These are the rules that stop one turn's tool output from growing the
/// prompt past what the provider accepts. Each test drives the rule that
/// decides, not the numbers that carry it.
@Suite("A turn's tool output stays inside its budget")
struct ToolResultBudgetTests {
    // MARK: - The per-result cap

    @Test("A result inside the cap is passed through unchanged")
    func resultInsideCapUnchanged() {
        let budget = ToolResultBudget(maxResultCharacters: 100, maxTurnCharacters: 1000)
        let output = String(repeating: "a", count: 50)
        #expect(budget.trim(output) == output, "a result inside the cap must not change")
    }

    @Test("A result above the cap is trimmed and says how much was dropped")
    func resultAboveCapTrimmed() {
        let budget = ToolResultBudget(maxResultCharacters: 100, maxTurnCharacters: 1000)
        let output = String(repeating: "a", count: 250)
        let trimmed = budget.trim(output)
        #expect(trimmed != output, "an oversized result must be cut")
        #expect(
            trimmed.hasPrefix(String(repeating: "a", count: 100)),
            "the head of the result must survive the cut"
        )
        #expect(
            trimmed.contains("[trimmed 150 chars]"),
            "the cut must be visible to the reader: \(trimmed)"
        )
    }

    @Test("The ledger charges the turn for what it kept, not what it dropped")
    func ledgerChargesTrimmedSize() {
        let budget = ToolResultBudget(maxResultCharacters: 100, maxTurnCharacters: 1000)
        let ledger = ToolResultLedger(budget: budget)
        let trimmed = ledger.admit(String(repeating: "a", count: 250))
        #expect(
            ledger.spent == trimmed.count,
            "the turn is charged the text as it will be sent: \(ledger.spent) vs \(trimmed.count)"
        )
        #expect(
            ledger.spent < 250,
            "the turn is charged the trimmed size, not the original"
        )
    }

    // MARK: - The turn cap

    @Test("The turn cap is a tenth of the window, in characters")
    func turnCapIsAShareOfTheWindow() {
        // The window is counted in tokens and the cap in characters (= the
        // unit a result is measured in), so the window is converted first
        // (= a token is four characters).
        #expect(
            ToolResultLedger.turnCap(forWindow: 1_000_000) == 400_000,
            "a 1,000,000-token window leaves a tenth of itself (= 400,000 characters) to the tool output"
        )
        #expect(
            ToolResultLedger.turnCap(forWindow: 200_000) == 80000,
            "a 200,000-token window leaves 80,000 characters (= 20,000 tokens)"
        )
        #expect(
            ToolResultLedger.turnCap(forWindow: 64000) == 25600,
            "a 64,000-token window leaves 25,600 characters (= 6,400 tokens)"
        )
        #expect(
            ToolResultLedger.turnCap(forWindow: 0) > 0,
            "a window of zero must still leave the turn a budget"
        )
    }

    @Test("The two caps are one budget: a small window caps the result too")
    func perResultCapIsClampedToTheTurnCap() {
        // A 64,000-token window leaves 25,600 characters to the turn, so
        // a result may not carry 32,000 (= the default): the turn could
        // never hold it.
        let budget = ToolResultBudget.turnBudget(forWindow: 64000)
        #expect(
            budget.maxTurnCharacters == 25600,
            "the turn's cap is its share of the window: \(budget.maxTurnCharacters)"
        )
        #expect(
            budget.maxResultCharacters == 25600,
            "the per-result cap cannot sit above the turn's own cap: \(budget.maxResultCharacters)"
        )

        let big = ToolResultBudget.turnBudget(forWindow: 1_000_000)
        #expect(
            big.maxResultCharacters == ToolResultBudget.defaultResultCharacters,
            "a large window leaves the default per-result cap alone"
        )
    }

    @Test("The ledger knows when the turn is over its cap")
    func ledgerKnowsWhenOverCap() {
        let budget = ToolResultBudget(maxResultCharacters: 100, maxTurnCharacters: 150)
        let ledger = ToolResultLedger(budget: budget)
        #expect(ledger.withinTurnCap, "an empty turn is inside its cap")
        _ = ledger.admit(String(repeating: "a", count: 100))
        #expect(ledger.withinTurnCap, "one result inside the cap keeps the turn inside it")
        _ = ledger.admit(String(repeating: "a", count: 100))
        #expect(!ledger.withinTurnCap, "two results over the cap put the turn over it")
        #expect(ledger.remainingCharacters == 0, "the turn has nothing left to charge")
    }

    // MARK: - The turn trim

    @Test("A turn inside its cap keeps every result whole")
    func turnInsideCapKeepsResults() {
        let messages = [
            toolResult("first", text: String(repeating: "a", count: 100)),
            toolResult("second", text: String(repeating: "b", count: 100)),
        ]
        let trimmed = ConversationLoop.trimTurnToolResults(
            messages,
            budget: ToolResultBudget(maxResultCharacters: 1000, maxTurnCharacters: 1000)
        )
        #expect(trimmed == messages, "a turn inside its cap must not change")
    }

    @Test("A turn over its cap gives way oldest-first")
    func turnOverCapTrimsOldestFirst() {
        let oldResult = String(repeating: "a", count: 400)
        let newResult = String(repeating: "b", count: 400)
        let messages = [
            toolResult("old", text: oldResult),
            toolResult("new", text: newResult),
        ]
        let trimmed = ConversationLoop.trimTurnToolResults(
            messages,
            budget: ToolResultBudget(maxResultCharacters: 10000, maxTurnCharacters: 500)
        )
        let oldOutput = toolOutput(trimmed[0])
        let newOutput = toolOutput(trimmed[1])
        #expect(
            oldOutput != oldResult,
            "the oldest result gives way first"
        )
        #expect(
            newOutput == newResult,
            "the newest result survives: the model still needs it"
        )
    }

    @Test("A trimmed result says how much was dropped")
    func trimmedResultIsMarked() {
        let messages = [
            toolResult("only", text: String(repeating: "a", count: 900)),
        ]
        let trimmed = ConversationLoop.trimTurnToolResults(
            messages,
            budget: ToolResultBudget(maxResultCharacters: 10000, maxTurnCharacters: 100)
        )
        let output = toolOutput(trimmed[0])
        let kept = output.prefix(while: { $0 != "\n" }).count
        #expect(
            output.contains("[trimmed \(900 - kept) chars]"),
            "the marker names what was dropped, not the original size: \(output)"
        )
    }

    @Test("The trim leaves the conversation's own text alone")
    func trimLeavesConversationAlone() {
        let userText = String(repeating: "u", count: 500)
        let messages = [
            LLMMessage(role: .user, blocks: [.text(userText)]),
            toolResult("big", text: String(repeating: "a", count: 900)),
        ]
        let trimmed = ConversationLoop.trimTurnToolResults(
            messages,
            budget: ToolResultBudget(maxResultCharacters: 10000, maxTurnCharacters: 100)
        )
        #expect(
            trimmed[0].blocks.first?.textValue == userText,
            "the writer's own words are never cut"
        )
    }

    @Test("The turn's results fit the cap after the trim")
    func trimmedTurnFitsTheCap() {
        // Five results, each large enough that the turn is over its cap,
        // and the cap small enough that the markers matter.
        let messages = (0 ..< 5).map { index in
            toolResult("r\(index)", text: String(repeating: "\(index)", count: 900))
        }
        let cap = 1000
        let trimmed = ConversationLoop.trimTurnToolResults(
            messages,
            budget: ToolResultBudget(maxResultCharacters: 10000, maxTurnCharacters: cap)
        )
        let total = trimmed.reduce(0) { total, message in
            total + toolOutput(message).count
        }
        #expect(
            total <= cap,
            "the turn's results must fit the cap: \(total) vs \(cap)"
        )
    }

    @Test("The trim's own previews do not grow the turn past its cap")
    func previewsDoNotGrowTheTurn() {
        // One result that is larger than the whole cap: its preview has
        // to be smaller than the cap, marker included.
        let messages = [
            toolResult("huge", text: String(repeating: "a", count: 50000)),
        ]
        let cap = 500
        let trimmed = ConversationLoop.trimTurnToolResults(
            messages,
            budget: ToolResultBudget(maxResultCharacters: 10000, maxTurnCharacters: cap)
        )
        let output = toolOutput(trimmed[0])
        #expect(
            output.count <= cap,
            "the replacement must fit the cap: \(output.count) vs \(cap)"
        )
        let kept = output.prefix(while: { $0 != "\n" }).count
        #expect(
            output.contains("[trimmed \(50000 - kept) chars]"),
            "the marker still names what was dropped: \(output)"
        )
    }

    @Test("A turn against a real window keeps what the window has room for")
    func turnAgainstAWindowKeepsWhatTheWindowHasRoomFor() {
        // A 200,000-token window (= an anthropic-sized one) leaves 80,000
        // characters to the turn's tool output. Four results of 25,000
        // characters do not fit, so the oldest one is cut (= the cut keeps
        // what the cap has room for, not a fixed-size excerpt).
        let budget = ToolResultBudget.turnBudget(forWindow: 200_000)
        let result = String(repeating: "a", count: 25000)
        let messages = (0 ..< 4).map { index in
            toolResult("r\(index)", text: result)
        }
        let trimmed = ConversationLoop.trimTurnToolResults(messages, budget: budget)

        let total = trimmed.reduce(0) { total, message in
            total + toolOutput(message).count
        }
        #expect(
            total <= budget.maxTurnCharacters,
            "the turn must fit its cap: \(total) vs \(budget.maxTurnCharacters)"
        )

        let cutOutput = toolOutput(trimmed[0])
        let kept = cutOutput.prefix(while: { $0 != "\n" }).count
        #expect(
            kept > 200,
            "a cut result keeps what the cap has room for, not a 200-character excerpt: \(kept)"
        )
        #expect(
            cutOutput.contains("[trimmed \(25000 - kept) chars]"),
            "the marker names what was dropped: \(cutOutput)"
        )
        #expect(
            toolOutput(trimmed[1]) == result,
            "the results the turn had room for stay whole"
        )
    }

    // MARK: - Helpers

    private func toolResult(_ id: String, text: String) -> LLMMessage {
        LLMMessage(
            role: .tool,
            blocks: [.toolResult(toolUseID: id, output: text, isError: false)]
        )
    }

    private func toolOutput(_ message: LLMMessage) -> String {
        for block in message.blocks {
            if case let .toolResult(_, output, _) = block {
                return output
            }
        }
        return ""
    }
}
