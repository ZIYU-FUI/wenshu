//
//  InspectorTodoPageView.swift
//  wenshu
//
//  The todo page of the trailing inspector column.
//
//  The page owns the list of todos the assistant wrote. The list
//  itself lands in the sibling card that owns the todo store; this
//  file is the seam the column's page switcher routes to, so the
//  sibling fills the page in without touching the column.
//
//

import SwiftUI

/// The trailing inspector column's todo page.
///
/// The body states the page's subject in one line until the todo
/// list arrives.
struct InspectorTodoPageView: View {
    var body: some View {
        Text(InspectorPage.todo.localizedTitle)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
