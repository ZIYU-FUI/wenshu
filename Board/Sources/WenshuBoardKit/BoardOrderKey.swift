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

import Foundation

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

    /// Renumber a list onto the positive ladder, dropping the negative head
    /// rungs. The order is preserved; only the keys change.
    ///
    /// The result is what the caller writes back after a failed
    /// §`insertKey(at:among:)`.
    public static func rebalance(_ keys: [Int64]) -> [Int64] {
        keys.sorted().enumerated().map { key(forIndex: $0.offset) }
    }

    /// The order the cards appear in, given their keys.
    public static func ordered<T>(_ cards: [T], key: (T) -> Int64) -> [T] {
        cards.sorted { key($0) < key($1) }
    }
}
