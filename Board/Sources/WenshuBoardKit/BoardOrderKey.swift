//
//  BoardOrderKey.swift
//  WenshuBoard
//
//  The one mechanism the reference teaches that Wenshu needs and does not
//  have: a list order that an insert does not have to renumber.
//
//  Milanote's measured scheme (Board/docs/milanote-card-model.md §4.1): every list child carries a `score`, the step between neighbouring
//  scores is 65536, and an item placed above the head takes a negative
//  multiple. The score alone totally orders the list, so the ordinal is
//  redundant and a card can be inserted between two neighbours by writing one
//  row.
//
//  The step is 65536 rather than 1 so that the head ladder can grow: a head
//  insertion takes the next negative multiple, and the gap between the head
//  and the first positive score leaves room for many of them before a
//  rebalance is needed.
//

/// The fractional order key: one number that totally orders a list of cards.
public enum BoardOrderKey {

    /// The distance between two neighbouring order keys.
    public static let step: Int64 = 65_536

    /// The key of the card that sits at ordinal `index` in a list.
    public static func key(forIndex index: Int) -> Int64 {
        Int64(index) * step
    }

    /// The key for a card inserted at `index` among siblings already keyed by
    /// `existing`.
    ///
    /// - Returns: the new key, or `nil` when the two neighbours are one apart
    ///   and there is no integer between them. The caller then rebalances
    ///   (§`rebalance`) and retries.
    public static func insertKey(at index: Int, among existing: [Int64]) -> Int64? {
        let sorted = existing.sorted()
        guard let head = sorted.first else {
            // The first card of an empty list sits at the origin.
            return 0
        }
        if index <= 0 {
            // Above the head: take the next rung of the negative ladder.
            return head - step
        }
        if index >= sorted.count {
            // Below the tail.
            return sorted[sorted.count - 1] + step
        }
        let lower = sorted[index - 1]
        let upper = sorted[index]
        guard upper - lower > 1 else {
            return nil
        }
        return lower + (upper - lower) / 2
    }

    /// The keys for `count` cards inserted at `index` among siblings already
    /// keyed by `existing`.
    ///
    /// The reference's rule for a batch: the gap between the two neighbours is
    /// divided into (count + 1) parts, so ONE gap holds the whole batch and
    /// the list is never renumbered. For one card this is the midpoint, which
    /// is what `insertKey(at:among:)` returns.
    ///
    /// - Returns: the new keys in list order, or `nil` when the gap has no
    ///   room for the batch. The caller then rebalances (§`rebalance`) and
    ///   retries.
    public static func insertKeys(at index: Int, among existing: [Int64], count: Int) -> [Int64]? {
        guard count > 0 else { return [] }
        let sorted = existing.sorted()
        guard let head = sorted.first else {
            // An empty list has no gap to split: the batch takes the ladder.
            return (0..<count).map { key(forIndex: $0) }
        }
        if index <= 0 {
            // Above the head: the next rungs of the negative ladder, the first
            // card of the batch closest to the head.
            return (1...count).map { head - Int64($0) * step }
        }
        if index >= sorted.count {
            // Below the tail.
            let tail = sorted[sorted.count - 1]
            return (1...count).map { tail + Int64($0) * step }
        }
        let lower = sorted[index - 1]
        let upper = sorted[index]
        guard upper - lower > Int64(count) else {
            return nil
        }
        let part = (upper - lower) / Int64(count + 1)
        return (1...count).map { lower + Int64($0) * part }
    }

    /// The new keys for a list whose keys are given IN LIST ORDER.
    ///
    /// The negative head rungs are gone: the first card sits at the origin
    /// again and the rest sit on the ladder. The input is taken in the order
    /// it is given, so the n-th returned key belongs to the n-th card = the
    /// caller pairs them positionally, after sorting its cards by key.
    ///
    /// This is what the caller writes back after a failed
    /// §`insertKey(at:among:)` or §`insertKeys(at:among:count:)`.
    public static func rebalance(_ keysInListOrder: [Int64]) -> [Int64] {
        keysInListOrder.enumerated().map { key(forIndex: $0.offset) }
    }

    /// The order the cards appear in, given their keys.
    public static func ordered<T>(_ cards: [T], key: (T) -> Int64) -> [T] {
        cards.sorted { key($0) < key($1) }
    }
}
