// ToolResultBudget.swift
//
// The ceiling on what one turn's tool output may carry.
//
// A tool result enters the message list and every later request in the
// same turn re-sends that list whole. Without a ceiling the turn's
// prompt grows with every tool call, and the provider refuses the
// request that finally crosses its window. The budget is therefore
// stated in characters (= the unit a result is measured in) and applied
// in two places:
//
//   1. per result   = one oversized result is trimmed to the cap
//   2. per turn     = the turn's accumulated result characters are
//                      capped, and the oldest results give way first
//
// The second rule is the one that stops a turn from growing: trimming
// only the newest result would leave every earlier result in place.

import Foundation

/// The size limits one turn's tool output obeys.
public struct ToolResultBudget: Sendable, Equatable {
    /// The most characters one tool result may carry.
    ///
    /// A result above this is trimmed to a preview plus a marker saying
    /// how much was dropped (= the model reads that the result was cut
    /// rather than believing the cut text is the whole result).
    public var maxResultCharacters: Int

    /// The most characters all of one turn's tool results may carry
    /// together.
    ///
    /// The turn's results are trimmed oldest-first until the sum fits.
    /// The newest results are the ones the model still needs, so they
    /// survive longest.
    public var maxTurnCharacters: Int

    public init(
        maxResultCharacters: Int = ToolResultBudget.defaultResultCharacters,
        maxTurnCharacters: Int = 200_000
    ) {
        self.maxResultCharacters = maxResultCharacters
        self.maxTurnCharacters = maxTurnCharacters
    }

    /// The budget a turn runs with unless its caller says otherwise.
    public static let standard = ToolResultBudget()

    /// The most characters one tool result may carry by default.
    ///
    /// The turn's own cap may be smaller than this (= a small window
    /// leaves less room), so the ledger clamps this value to the turn's
    /// cap: a result the turn could never hold is not admitted whole.
    public static let defaultResultCharacters = 32000

    /// The budget a turn runs with against a window of that many tokens.
    ///
    /// The turn's share of the window is the cap, and the per-result cap
    /// is clamped to it: a result the turn could never hold is not
    /// admitted whole (= the two caps are one budget, so the smaller
    /// window cannot end up with a per-result cap above its own).
    public static func turnBudget(forWindow window: Int) -> ToolResultBudget {
        let turnCap = ToolResultLedger.turnCap(forWindow: window)
        return ToolResultBudget(
            maxResultCharacters: min(defaultResultCharacters, turnCap),
            maxTurnCharacters: turnCap
        )
    }

    /// Trim one result to the per-result cap.
    ///
    /// A result inside the cap is returned unchanged. A result above it
    /// keeps its head and gains a marker naming the dropped size, so
    /// the reader can tell the result was cut.
    public func trim(_ output: String) -> String {
        guard output.count > maxResultCharacters else { return output }
        let dropped = output.count - maxResultCharacters
        let head = String(output.prefix(maxResultCharacters))
        return "\(head)\n[trimmed \(dropped) chars]"
    }

    /// The characters one result contributes to the turn's total.
    ///
    /// The trimmed result's own length is what the turn carries, marker
    /// included, so this counts the text as it will be sent.
    public func charge(_ output: String) -> Int {
        output.count
    }
}

/// The turn's running tool-output accounting.
///
/// One ledger per turn (= the turn's own state, not a global). It
/// answers the only question the executor has to ask: does this result
/// still fit, and if not, which earlier results give way.
public final class ToolResultLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var budgetStorage: ToolResultBudget
    private var spentCharacters: Int = 0

    /// The limits the turn's results obey.
    public var budget: ToolResultBudget {
        lock.lock()
        defer { lock.unlock() }
        return budgetStorage
    }

    public init(budget: ToolResultBudget = .standard) {
        budgetStorage = budget
    }

    /// The characters the turn's results have charged so far.
    public var spent: Int {
        lock.lock()
        defer { lock.unlock() }
        return spentCharacters
    }

    /// Apply the per-result cap and charge the result to the turn.
    ///
    /// Returns the text the model should read (= the capped result).
    ///
    /// The budget is read from its stored value and not through the
    /// `budget` getter: the getter takes the same lock, and a lock that
    /// takes itself is a deadlock.
    public func admit(_ output: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        let trimmed = budgetStorage.trim(output)
        spentCharacters += budgetStorage.charge(trimmed)
        return trimmed
    }

    /// Whether the turn's results are still inside the turn cap.
    public var withinTurnCap: Bool {
        lock.lock()
        defer { lock.unlock() }
        return spentCharacters <= budgetStorage.maxTurnCharacters
    }

    /// How many characters the turn may still charge.
    public var remainingCharacters: Int {
        lock.lock()
        defer { lock.unlock() }
        return max(0, budgetStorage.maxTurnCharacters - spentCharacters)
    }

    /// The turn cap as a share of the window the turn runs against.
    ///
    /// The turn's tool output is part of the prompt, so it is measured
    /// against the same window the prompt is measured against. The window
    /// is counted in TOKENS and the cap is counted in CHARACTERS (= the
    /// unit a result is measured in), so the window is converted first
    /// (= the package's own estimate: a token is four characters). A turn
    /// whose results may take a tenth of the window leaves the rest of
    /// the window to the conversation itself.
    public static func turnCap(forWindow window: Int) -> Int {
        guard window > 0 else { return ToolResultBudget.standard.maxTurnCharacters }
        let windowCharacters = window * ContextUsageMeasure.charactersPerToken
        return max(8000, windowCharacters / 10)
    }
}
