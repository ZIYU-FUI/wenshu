//
//  InspectorTaskPageView.swift
//  wenshu
//
//  The task page of the trailing inspector column.
//
//  The page owns the board of long-running work. The board itself
//  lands in the sibling card that owns the board's view; this file is
//  the seam the column's page switcher routes to, so the sibling
//  fills the page in without touching the column.
//
//  The page hands the app's shared workspace state to the board, so
//  the board reads the active book from the same selection the rest
//  of the app reads (= the board no longer lives in a window that
//  resolves a library and a book on its own).
//
//

import SwiftUI

/// The trailing inspector column's task page.
///
/// The body is the board (= the columns of long-running work), read
/// for the book the app's current selection names.
struct InspectorTaskPageView: View {
    /// The app's shared workspace state (= the selection that names
    /// the book the board shows).
    let workspaceUI: WorkspaceUIState

    var body: some View {
        KanbanView(workspaceUI: workspaceUI)
    }
}
