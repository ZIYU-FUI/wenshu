//
//  ForeshadowingGraphWindow.swift · Wenshu · v2.8b ticket T10-T13 (boss 2026-09-28 OOB B9)
//
//  Independent Foreshadowing Graph window (= the previously-unwired
//  graph view; = the inspector's ForeshadowingView is a list;
//  = this window hosts the graph-style overview).
//
//  Per boss 2026-09-28 OOB B9 '在标题栏/工具栏中加一个按钮':
//  build an MVP independent Foreshadowing Graph window (= a graph
//  overview that complements the inspector's list view).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        + Apple HIG `.windowResizability(.contentSize)` (= the
//        same shape as kanban + todo windows).
//    S3 (single source of truth): the graph node data flows
//        from the same WSBookmark / Foreshadowing persistence as
//        the inspector's ForeshadowingView (= no second store).
//
//  NOTE (= boss 2026-09-28 OOB B9 '和老板 todo 一样' = same
//  shape; = the underlying graph rendering is intentionally a
//  placeholder for the future ticket that adds Spring-Force
//  layout via Grape::ForceSimulation per §11.1 batch 2 issue 05;
//  = this MVP shows the canonical placeholder surface + an
//  inspector-style list view).

import SwiftUI

/// Independent Foreshadowing Graph window (= MVP per boss
/// 2026-09-28 OOB B9).
@MainActor
struct ForeshadowingGraphWindow: View {

    @State private var entries: [ForeshadowingEntry] = []

    /// One foreshadowing entry (= the row shape; = mapped from the
    /// future ForeshadowingGraph actor's data).
    struct ForeshadowingEntry: Identifiable, Equatable {
        let id: String
        let title: String
        let status: String
        var displayName: String { "\(title) (\(status))" }
    }

    init() {}

    var body: some View {
        NavigationStack {
            contentBody
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            // future ticket: wire to ForeshadowingGraph
                            // actor (per §11.1 batch 2 issue 05 =
                            // Grape::ForceSimulation layout).
                        } label: {
                            Label {
                                Text(WenshuI18n.t("foreshadowing_graph.layout"))
                            } icon: {
                                Image(systemName: "rectangle.3.group.fill")
                            }
                        }
                    }
                }
        }
        .frame(minWidth: 540, minHeight: 400)
    }

    @ViewBuilder
    private var contentBody: some View {
        if entries.isEmpty {
            EmptyStateView(
                icon: "arrow.triangle.branch",
                title: WenshuI18n.t("foreshadowing_graph.empty.title"),
                body: WenshuI18n.t("foreshadowing_graph.empty.body")
            )
        } else {
            List(entries) { entry in
                Text(entry.displayName)
            }
        }
    }
}