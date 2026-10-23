//
// ToolSafetyPolicy.swift
//
// What the agent may do, and what it has already tried.
//
// Two questions, one moment: may this tool call run?
//
// - The hazard class. The executor asks before every call. A refusal is
//   a string that becomes the tool result, so the model reads it and the
//   turn continues. Nothing here waits for a user: a session nobody is
//   watching denies rather than blocks, because a blocked call would
//   strand the turn.
//
// - The per-turn ledger. A turn that keeps making the same call is
//   stuck, and every retry costs the user money and, for a write, touches
//   the user's library. The ledger counts what this turn already did and
//   refuses the repeat.
//
// The hazard class is narrower than "mutating". Writing a chapter is the
// product; running a process on the user's machine is the hazard; a file
// write that lands outside the library root is the other half. The
// mutating flag stays the input for the loop rules, where a repeated
// write is the stuck-agent signal.
//
// The facts come from the app: the tool catalogue says which tools
// mutate and which reach outside the library, and the settings say
// whether the user approved the hazard class. The package holds the
// values and reads them at the boundary; the app installs them (= the
// provider-endpoint and context-number precedent, = the package never
// reads the app's storage).
//

import Foundation

// MARK: - Rule names

/// Which rule refused a call.
///
/// The name goes into the refusal message, so a log line says which rule
/// fired rather than only "denied".
public enum ToolSafetyRule: String, Sendable, Equatable, CaseIterable {
    /// The tool is in the hazard class and the user has not approved it.
    case hazardousTool
    /// The same mutating call has already been made in this turn.
    case repeatedMutation
    /// The same call has already failed in this turn.
    case repeatedFailure
    /// An unbounded call has reached this turn's cap.
    case perTurnCallCap
}

/// The refusal a rule produces.
///
/// The text is the tool result the model reads, so it says what happened
/// and what to do next: a refusal that only says "denied" leaves the
/// model guessing and retrying.
public enum ToolSafetyRefusal {

    /// The refusal text for one rule.
    ///
    /// The rule name comes first (= the log line says which rule fired),
    /// then the plain-language reason, then what to do instead.
    public static func message(
        rule: ToolSafetyRule,
        toolName: String,
        reason: String,
        nextStep: String
    ) -> String {
        "Refused by the Wenshu safety policy (rule: \(rule.rawValue)): \(reason) "
            + "Tool: \(toolName). \(nextStep)"
    }

    /// The refusal for a tool in the hazard class.
    public static func hazardousTool(toolName: String, reason: String) -> String {
        message(
            rule: .hazardousTool,
            toolName: toolName,
            reason: reason,
            nextStep: "Use the library tools instead, or ask the user to approve this class in Settings."
        )
    }

    /// The refusal for a repeated identical mutating call.
    public static func repeatedMutation(toolName: String, times: Int) -> String {
        message(
            rule: .repeatedMutation,
            toolName: toolName,
            reason: "this exact call has already been made \(times) times in this turn.",
            nextStep: "Stop retrying it. Change the input, do something else, or answer the user."
        )
    }

    /// The refusal for a repeated failure.
    public static func repeatedFailure(toolName: String, times: Int, lastFailure: String) -> String {
        message(
            rule: .repeatedFailure,
            toolName: toolName,
            reason: "this exact call has already failed \(times) times in this turn (last failure: \(lastFailure)).",
            nextStep: "Stop retrying it. The tool is broken, not the input. Use another tool or answer the user."
        )
    }

    /// The refusal for an unbounded call that hit the turn's cap.
    public static func perTurnCallCap(toolName: String, cap: Int) -> String {
        message(
            rule: .perTurnCallCap,
            toolName: toolName,
            reason: "this turn has already made \(cap) calls to this tool.",
            nextStep: "Stop calling it. Answer the user with what you already have."
        )
    }
}

// MARK: - The installed policy

/// The tool-safety values the app installs, and the rules that read them.
public enum ToolSafetyPolicy {

    /// One snapshot of the safety facts.
    ///
    /// Replaced wholesale rather than mutated in place, so a reader that
    /// asks twice never sees one snapshot from before an install and one
    /// from after it (= the endpoint-override and context-number shape).
    public struct Values: Sendable, Equatable {

        /// Patterns naming the hazard class (= the deny list).
        ///
        /// A pattern matches a tool name case-insensitively, and `*`
        /// stands for any run of characters.
        public var deniedToolPatterns: [String]

        /// The tools that change something (= the catalogue's mutating flag).
        public var mutatingToolNames: Set<String>

        /// The tools a turn may call without bound (= a search, a delegation).
        public var unboundedToolNames: Set<String>

        /// Whether the user approved the hazard class.
        ///
        /// False (= the default) refuses the hazard class. True lets it
        /// through. There is no third state: this card builds no approval
        /// dialog, so an unapproved call is refused, never queued for a
        /// user who is not watching.
        public var autoApprove: Bool

        /// How many identical mutating calls one turn may make.
        public var maxIdenticalMutatingCalls: Int

        /// How many failures one identical call may accumulate in a turn.
        public var maxIdenticalFailures: Int

        /// How many calls an unbounded tool may make in one turn.
        public var maxUnboundedCallsPerTurn: Int

        public init(
            deniedToolPatterns: [String] = Values.defaultDeniedToolPatterns,
            mutatingToolNames: Set<String> = [],
            unboundedToolNames: Set<String> = [],
            autoApprove: Bool = false,
            maxIdenticalMutatingCalls: Int = 2,
            maxIdenticalFailures: Int = 2,
            maxUnboundedCallsPerTurn: Int = 8
        ) {
            self.deniedToolPatterns = deniedToolPatterns
            self.mutatingToolNames = mutatingToolNames
            self.unboundedToolNames = unboundedToolNames
            self.autoApprove = autoApprove
            self.maxIdenticalMutatingCalls = maxIdenticalMutatingCalls
            self.maxIdenticalFailures = maxIdenticalFailures
            self.maxUnboundedCallsPerTurn = maxUnboundedCallsPerTurn
        }

        /// The patterns the package refuses before the app installs any.
        ///
        /// A conservative floor, not the app's list: the package does not
        /// know the app's tool names, so it names the shapes that are
        /// hazardous wherever they appear (= a process runner, a shell).
        /// The app installs the exact list.
        public static let defaultDeniedToolPatterns: [String] = [
            "process",
            "*shell*",
            "*bash*",
            "*exec*",
            "*terminal*"
        ]
    }

    /// The installed values, replaced wholesale by the app.
    public nonisolated(unsafe) static var values = Values()

    /// Install the values.
    public static func install(_ values: Values) {
        self.values = values
    }

    /// Whether a tool name is in the hazard class.
    public static func isHazardous(
        toolName: String,
        patterns: [String] = ToolSafetyPolicy.values.deniedToolPatterns
    ) -> Bool {
        patterns.contains { matches(pattern: $0, toolName: toolName) }
    }

    /// The refusal for a tool in the hazard class, or nil when it may run.
    ///
    /// An approved hazard class returns nil, so the same gate serves both
    /// of the user's choices.
    public static func refusal(
        toolName: String,
        values: Values = ToolSafetyPolicy.values
    ) -> String? {
        guard !values.autoApprove else { return nil }
        guard isHazardous(toolName: toolName, patterns: values.deniedToolPatterns) else { return nil }
        return ToolSafetyRefusal.hazardousTool(
            toolName: toolName,
            reason: "this tool is in the hazardous class (= it runs commands on your machine) and it has not been approved."
        )
    }

    /// Whether a pattern matches a tool name.
    ///
    /// `*` stands for any run of characters; everything else is literal.
    /// The comparison ignores case, because a tool named `WriteFile` and
    /// a pattern named `writefile` are the same tool.
    public static func matches(pattern: String, toolName: String) -> Bool {
        let patternChars = Array(pattern.lowercased())
        let nameChars = Array(toolName.lowercased())
        var patternIndex = 0
        var nameIndex = 0
        var starIndex = -1
        var resumeIndex = 0
        while nameIndex < nameChars.count {
            if patternIndex < patternChars.count, patternChars[patternIndex] == nameChars[nameIndex] {
                patternIndex += 1
                nameIndex += 1
            } else if patternIndex < patternChars.count, patternChars[patternIndex] == "*" {
                starIndex = patternIndex
                resumeIndex = nameIndex
                patternIndex += 1
            } else if starIndex >= 0 {
                patternIndex = starIndex + 1
                resumeIndex += 1
                nameIndex = resumeIndex
            } else {
                return false
            }
        }
        while patternIndex < patternChars.count, patternChars[patternIndex] == "*" {
            patternIndex += 1
        }
        return patternIndex == patternChars.count
    }
}

// MARK: - The per-turn ledger

/// What one turn has already called.
///
/// The ledger lives in the turn's scope, not in the executor: the
/// executor is built fresh inside every round, so a counter there dies
/// with the round. Three counters, three rules, counting three different
/// things:
///
/// - Identical mutating calls. A repeat of a read is normal (= the agent
///   is looking for something); a repeat of the same write with the same
///   input is a stuck agent.
/// - Identical failures. A tool that keeps erroring is broken, not one
///   that needs a third try. This rule counts reads too.
/// - Unbounded calls per turn. A search or a delegation can be asked for
///   as often as the round limit allows, so it gets a cap of its own.
///
/// The mutating rule counts calls; the failure rule counts failures. A
/// call that fails twice with two different errors is one repeated call
/// for the first rule and two failures for the second.
public final class ToolSafetyLedger: @unchecked Sendable {

    /// One call's identity (= the tool and the exact input).
    private struct CallKey: Hashable {
        let tool: String
        let input: String
    }

    private let lock = NSLock()
    private var policy: ToolSafetyPolicy.Values

    /// Identical mutating calls made so far this turn.
    private var mutatingCalls: [CallKey: Int] = [:]

    /// Failures so far this turn.
    private var failures: [CallKey: Int] = [:]

    /// The text of the most recent failure of each call.
    private var lastFailureText: [CallKey: String] = [:]

    /// Calls made so far this turn, per unbounded tool.
    private var unboundedCalls: [String: Int] = [:]

    /// The ledger for one turn, reading the policy as it stands now.
    ///
    /// The policy is copied in, so a turn does not change its rules
    /// halfway through because the settings were reloaded.
    public init(policy: ToolSafetyPolicy.Values = ToolSafetyPolicy.values) {
        self.policy = policy
    }

    /// The loop rules' answer for one call: nil allows, a string refuses.
    ///
    /// The hazard class is NOT decided here (= that is the permission
    /// gate's job, and a caller may inject its own gate; = a ledger that
    /// always answered first would make an injected gate unable to allow
    /// anything). These are the rules that need to see what this turn
    /// already did.
    ///
    /// An allowed call is counted here, so the counters describe the
    /// calls the turn actually made.
    public func evaluate(toolName: String, input: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let key = CallKey(tool: toolName, input: input)
        let isMutating = policy.mutatingToolNames.contains(toolName)

        let failureCount = failures[key] ?? 0
        if failureCount >= policy.maxIdenticalFailures {
            return ToolSafetyRefusal.repeatedFailure(
                toolName: toolName,
                times: failureCount,
                lastFailure: lastFailureText[key] ?? "unknown"
            )
        }

        if isMutating {
            let mutationCount = mutatingCalls[key] ?? 0
            if mutationCount >= policy.maxIdenticalMutatingCalls {
                return ToolSafetyRefusal.repeatedMutation(toolName: toolName, times: mutationCount)
            }
        }

        if policy.unboundedToolNames.contains(toolName) {
            let callCount = unboundedCalls[toolName] ?? 0
            if callCount >= policy.maxUnboundedCallsPerTurn {
                return ToolSafetyRefusal.perTurnCallCap(
                    toolName: toolName,
                    cap: policy.maxUnboundedCallsPerTurn
                )
            }
            unboundedCalls[toolName] = callCount + 1
        }

        if isMutating {
            mutatingCalls[key] = (mutatingCalls[key] ?? 0) + 1
        }
        return nil
    }

    /// Record that a call failed.
    ///
    /// The failure text is kept because the refusal message shows how
    /// many times the call failed and what the last failure was, and
    /// because the same call failing again is the signal the rule fires
    /// on.
    public func recordFailure(toolName: String, input: String, text: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = CallKey(tool: toolName, input: input)
        failures[key] = (failures[key] ?? 0) + 1
        lastFailureText[key] = text
    }
}
