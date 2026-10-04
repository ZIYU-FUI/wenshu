//
// Sources/WenshuApp/Views/Windows/_FILE_.swift
//
//  Independent Foreshadowing Graph window (= the previously-unwired
//  graph view; = the inspector's ForeshadowingView is a list;
//  = this window hosts the graph-style overview).
//
// Per the multi-window pattern:
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
// NOTE (= the same shape as the todo pattern:
//  shape; = the underlying graph rendering is intentionally a
//  placeholder for the future ticket that adds Spring-Force
//  layout via Grape::ForceSimulation per §11.1 batch 2 issue 05;
//  = this MVP shows the canonical placeholder surface + an
//  inspector-style list view).

import SwiftUI

/// Independent Foreshadowing Graph window (= MVP per the
/// 2026-09-28 OOB B9).
@MainActor
struct ForeshadowingGraphWindow: View {

    @Environment(BookStore.self) private var bookStore

    @State private var entries: [ForeshadowingEntry] = []
    @State private var errorText: String?

    /// Active book (= mirrors ForeshadowingView's pattern).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// One foreshadowing entry (= the row shape; = mapped from
    /// the ForeshadowingTracker actor's data).
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
                            Task { await reload() }
                        } label: {
                            Label {
                                Text(WenshuI18n.t("foreshadowing_graph.refresh"))
                            } icon: {
                                SFIcon("arrow.clockwise", style: .inlineSmall, color: IconColor.tint)
                            }
                        }
                        .disabled(activeBookId == nil)
                    }
                }
        }
        .frame(minWidth: 540, minHeight: 400)
        .task(id: activeBookId) {
            await reload()
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if entries.isEmpty {
            if activeBookId == nil {
                EmptyStateView(
                    icon: "book.closed",
                    title: WenshuI18n.t("foreshadowing_graph.no_book.title"),
                    body: WenshuI18n.t("foreshadowing_graph.no_book.body")
                )
            } else {
                EmptyStateView(
                    icon: "arrow.triangle.branch",
                    title: WenshuI18n.t("foreshadowing_graph.empty.title"),
                    body: WenshuI18n.t("foreshadowing_graph.empty.body")
                )
            }
        } else {
            List(entries) { entry in
                Text(entry.displayName)
            }
        }
    }

    // Load via the canonical `ForeshadowingTracker` actor (= the
    // view never reads the sidecar directly). Pattern mirrors
    // `ForeshadowingView` (= same actor + same `BookStore`
    // environment).
    private func reload() async {
        guard let bookId = activeBookId else {
            entries = []
            return
        }
        do {
            let tracker = ForeshadowingTracker(bookStore: bookStore)
            let rows = try await tracker.list(bookId: bookId)
            entries = rows.map { row in
                ForeshadowingEntry(
                    id: row.id.uuidString,
                    title: row.title,
                    status: row.status.rawValue
                )
            }
            errorText = nil
        } catch {
            errorText = String(describing: error)
            entries = []
        }
    }
}