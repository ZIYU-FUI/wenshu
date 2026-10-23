import Foundation
import Testing
@testable import WenshuAgent

/// The tool-safety rules, driven through the runtime consumer.
///
/// Each test exercises the rule that decides, not the values that carry
/// it: a settings value proves nothing, because a value does not know
/// what the executor does with it.
@Suite("Tool safety refuses what it should")
@MainActor
struct ToolSafetyPolicyTests {

    // MARK: - Helpers

    private func policy(
        denied: [String] = ToolSafetyPolicy.Values.defaultDeniedToolPatterns,
        mutating: Set<String> = ["book_chapter"],
        unbounded: Set<String> = ["web_search"],
        autoApprove: Bool = false,
        maxIdenticalMutating: Int = 2,
        maxIdenticalFailures: Int = 2,
        maxUnbounded: Int = 3
    ) -> ToolSafetyPolicy.Values {
        ToolSafetyPolicy.Values(
            deniedToolPatterns: denied,
            mutatingToolNames: mutating,
            unboundedToolNames: unbounded,
            autoApprove: autoApprove,
            maxIdenticalMutatingCalls: maxIdenticalMutating,
            maxIdenticalFailures: maxIdenticalFailures,
            maxUnboundedCallsPerTurn: maxUnbounded
        )
    }

    // MARK: - The hazard class

    @Test("A tool in the hazard class is refused by default")
    func hazardClassRefusedByDefault() {
        let values = policy()
        let refusal = ToolSafetyPolicy.refusal(toolName: "process", values: values)
        #expect(refusal != nil, "a process runner must not run unapproved")
        #expect(
            refusal?.contains("process") == true,
            "the refusal must name the tool: \(refusal ?? "nil")"
        )
    }

    @Test("The refusal names the rule that fired")
    func refusalNamesTheRule() {
        let refusal = ToolSafetyPolicy.refusal(
            toolName: "process",
            values: policy()
        )
        #expect(
            refusal?.contains("hazard") == true || refusal?.contains("approved") == true,
            "the refusal must say which rule fired: \(refusal ?? "nil")"
        )
    }

    @Test("Approving the hazard class lets it through")
    func approvalLetsTheHazardClassThrough() {
        let values = policy(autoApprove: true)
        #expect(
            ToolSafetyPolicy.refusal(toolName: "process", values: values) == nil,
            "an approved hazard class must run"
        )
    }

    @Test("A tool outside the hazard class is never refused by the policy")
    func ordinaryToolNotRefused() {
        let values = policy()
        for tool in ["book_chapter", "ReadFile", "web_search", "llm_wiki"] {
            #expect(
                ToolSafetyPolicy.refusal(toolName: tool, values: values) == nil,
                "\(tool) is not in the hazard class and must not be refused"
            )
        }
    }

    @Test("A pattern matches a tool name case-insensitively")
    func patternMatching() {
        #expect(ToolSafetyPolicy.matches(pattern: "process", toolName: "process"))
        #expect(ToolSafetyPolicy.matches(pattern: "PROCESS", toolName: "process"))
        #expect(ToolSafetyPolicy.matches(pattern: "*shell*", toolName: "run_shell"))
        #expect(ToolSafetyPolicy.matches(pattern: "*bash*", toolName: "bash_exec"))
        #expect(!ToolSafetyPolicy.matches(pattern: "process", toolName: "WriteFile"))
        #expect(!ToolSafetyPolicy.matches(pattern: "process", toolName: "processes"))
    }

    // MARK: - The repeated mutating call

    @Test("A repeated identical mutating call is refused")
    func repeatedMutatingCallRefused() {
        let ledger = ToolSafetyLedger(policy: policy(maxIdenticalMutating: 2))
        #expect(ledger.evaluate(toolName: "book_chapter", input: "{\"a\":1}") == nil)
        #expect(ledger.evaluate(toolName: "book_chapter", input: "{\"a\":1}") == nil)
        let refusal = ledger.evaluate(toolName: "book_chapter", input: "{\"a\":1}")
        #expect(refusal != nil, "the third identical mutating call must be refused")
    }

    @Test("A repeated read is not refused")
    func repeatedReadNotRefused() {
        let ledger = ToolSafetyLedger(policy: policy(maxIdenticalMutating: 2))
        for _ in 0..<6 {
            #expect(
                ledger.evaluate(toolName: "ReadFile", input: "{\"path\":\"a\"}") == nil,
                "repeating a read is normal and must not be refused"
            )
        }
    }

    @Test("A mutating call with a different input is not a repeat")
    func differentInputIsNotARepeat() {
        let ledger = ToolSafetyLedger(policy: policy(maxIdenticalMutating: 2))
        #expect(ledger.evaluate(toolName: "book_chapter", input: "{\"a\":1}") == nil)
        #expect(ledger.evaluate(toolName: "book_chapter", input: "{\"a\":2}") == nil)
        #expect(ledger.evaluate(toolName: "book_chapter", input: "{\"a\":3}") == nil)
    }

    // MARK: - The repeated failure

    @Test("A repeated exact failure is refused")
    func repeatedFailureRefused() {
        let ledger = ToolSafetyLedger(policy: policy(maxIdenticalFailures: 2))
        ledger.recordFailure(toolName: "ReadFile", input: "{\"path\":\"x\"}", text: "boom")
        ledger.recordFailure(toolName: "ReadFile", input: "{\"path\":\"x\"}", text: "boom")
        let refusal = ledger.evaluate(toolName: "ReadFile", input: "{\"path\":\"x\"}")
        #expect(refusal != nil, "a call that already failed twice must be refused")
    }

    @Test("A failure rule counts reads too")
    func failureRuleCountsReads() {
        let ledger = ToolSafetyLedger(policy: policy(maxIdenticalFailures: 1))
        ledger.recordFailure(toolName: "ReadFile", input: "{\"path\":\"x\"}", text: "boom")
        #expect(
            ledger.evaluate(toolName: "ReadFile", input: "{\"path\":\"x\"}") != nil,
            "a broken read is not one that needs a third try"
        )
    }

    @Test("A failure with a different input is not a repeat")
    func differentFailureIsNotARepeat() {
        let ledger = ToolSafetyLedger(policy: policy(maxIdenticalFailures: 2))
        ledger.recordFailure(toolName: "ReadFile", input: "{\"path\":\"x\"}", text: "boom")
        ledger.recordFailure(toolName: "ReadFile", input: "{\"path\":\"y\"}", text: "boom")
        #expect(
            ledger.evaluate(toolName: "ReadFile", input: "{\"path\":\"x\"}") == nil,
            "a different call is not the same broken call"
        )
    }

    // MARK: - The per-turn cap

    @Test("An unbounded tool is capped per turn")
    func unboundedToolCapped() {
        let ledger = ToolSafetyLedger(policy: policy(maxUnbounded: 3))
        for _ in 0..<3 {
            #expect(ledger.evaluate(toolName: "web_search", input: "{\"q\":\"a\"}") == nil)
        }
        let refusal = ledger.evaluate(toolName: "web_search", input: "{\"q\":\"b\"}")
        #expect(refusal != nil, "the fourth search in one turn must be refused")
    }

    @Test("A capped tool does not count the other tools' calls")
    func capCountsOnlyItsOwnTool() {
        let ledger = ToolSafetyLedger(policy: policy(maxUnbounded: 2))
        _ = ledger.evaluate(toolName: "web_search", input: "{\"q\":\"a\"}")
        _ = ledger.evaluate(toolName: "book_chapter", input: "{\"a\":1}")
        #expect(
            ledger.evaluate(toolName: "web_search", input: "{\"q\":\"b\"}") == nil,
            "another tool's call must not consume the search's budget"
        )
    }

    // MARK: - The ledger is per turn

    @Test("A fresh ledger has no history")
    func freshLedgerHasNoHistory() {
        let values = policy(maxIdenticalMutating: 2)
        let first = ToolSafetyLedger(policy: values)
        _ = first.evaluate(toolName: "book_chapter", input: "{\"a\":1}")
        _ = first.evaluate(toolName: "book_chapter", input: "{\"a\":1}")

        let second = ToolSafetyLedger(policy: values)
        #expect(
            second.evaluate(toolName: "book_chapter", input: "{\"a\":1}") == nil,
            "a new turn must start with a clean ledger"
        )
    }

    @Test("The ledger decides the loop rules, not the hazard class")
    func ledgerDecidesTheLoopRulesOnly() {
        // The hazard class belongs to the permission gate (= the caller
        // may inject its own gate; = a ledger that always answered
        // first would make an injected gate unable to allow anything).
        let ledger = ToolSafetyLedger(policy: policy())
        #expect(
            ledger.evaluate(toolName: "process", input: "{}") == nil,
            "the ledger must not decide the hazard class"
        )
        #expect(
            ToolSafetyPolicy.refusal(
                toolName: "process",
                values: ToolSafetyPolicy.values
            ) != nil,
            "the gate still refuses the hazard class"
        )
    }

    @Test("The ledger reads the policy it was given")
    func ledgerReadsItsOwnPolicy() {
        // One identical mutating call is allowed, the second is not (= a
        // ledger built with a cap of one).
        let ledger = ToolSafetyLedger(policy: policy(maxIdenticalMutating: 1))
        #expect(ledger.evaluate(toolName: "book_chapter", input: "{\"a\":1}") == nil)
        #expect(
            ledger.evaluate(toolName: "book_chapter", input: "{\"a\":1}") != nil,
            "the ledger must read the policy it was given"
        )
    }
}
