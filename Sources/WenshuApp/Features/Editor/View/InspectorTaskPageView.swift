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
//

import SwiftUI

/// The trailing inspector column's task page.
///
/// The body states the page's subject in one line until the board
/// arrives.
struct InspectorTaskPageView: View {
    /// The app's shared workspace state (= the board reads the active
    /// book from the sidebar selection it carries).
    let workspaceUI: WorkspaceUIState

    var body: some View {
        Text(InspectorPage.task.localizedTitle)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
