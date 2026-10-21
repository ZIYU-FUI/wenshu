//  KanbanBoardStyle.swift
//
//  Presentation mapping for the kanban board: one label and one tone per
//  `KanbanStatus`. The board renders these; the labels come from the string
//  catalog so the board reads the same in every language.
//
//  The label wording follows the Hermes board's Simplified Chinese
//  (the triage / to-do / ready / running / blocked / review / done
//  set). Wenshu's status enum has no "scheduled" case, so it has
//  eight columns where Hermes has nine.
//
//  Every case of `KanbanStatus` maps to exactly one column and one tone.
//  A status with no column would make its cards invisible on the board,
//  so the mapping is total by construction.

import SwiftUI

extension KanbanStatus {

    /// User-facing column label. Localized; never a hardcoded literal.
    var boardLabel: String {
        switch self {
        case .new: return String(localized: "kanban.column.new")
        case .triage: return String(localized: "kanban.column.triage")
        case .ready: return String(localized: "kanban.column.ready")
        case .running: return String(localized: "kanban.column.running")
        case .blocked: return String(localized: "kanban.column.blocked")
        case .review: return String(localized: "kanban.column.review")
        case .done: return String(localized: "kanban.column.done")
        case .failed: return String(localized: "kanban.column.failed")
        }
    }

    /// Column tone. The card's left edge and the column's dot both use
    /// it, so a card reads as belonging to its column at a glance.
    ///
    /// Apple semantic colors where the tone has one (= they follow light
    /// and dark mode). The two grays are the system's secondary and
    /// tertiary text tiers (= the same tiers the chrome uses).
    ///
    /// The type is `AnyShapeStyle` because the gray tiers are
    /// `HierarchicalShapeStyle` (= SwiftUI's `.secondary` / `.tertiary`)
    /// and the colored ones are `Color`. One shape style lets both
    /// live in one switch.
    var boardTone: AnyShapeStyle {
        switch self {
        case .new: return AnyShapeStyle(.secondary)
        case .triage: return AnyShapeStyle(.tertiary)
        case .ready: return AnyShapeStyle(Color(nsColor: .systemBlue))
        case .running: return AnyShapeStyle(Color(nsColor: .systemGreen))
        case .blocked: return AnyShapeStyle(Color(nsColor: .systemRed))
        case .review: return AnyShapeStyle(Color(nsColor: .systemOrange))
        case .done: return AnyShapeStyle(.tertiary)
        case .failed: return AnyShapeStyle(Color(nsColor: .systemRed))
        }
    }

    /// Every status, in board order (= the flow a ticket travels).
    ///
    /// The board shows all of them. A status with no column would hide its
    /// cards entirely, because a card is rendered in the column that
    /// matches its status.
    static var boardOrder: [KanbanStatus] {
        [.new, .triage, .ready, .running, .blocked, .review, .done, .failed]
    }
}
