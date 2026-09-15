//
//  PlotThreadView.swift · Wenshu · v0.72 SwiftData migration Phase 5
//
//  Specialized tools pane view (= 1 of 12 tabs; = EmotionCurveView
//  + IdeaLibraryView + BookSettingConstraintsView + CharacterLifecycleView
//  + CharacterRelationshipsView + ForeshadowingTrackerView + PlaceholderScannerView
//  + LongFormGuardrailsView + ReaderExperienceView + TagManagerView + PlotThreadView
//  + GenreFitView = 12 tabs total).
//
//  Renders the plot-thread tracker (= shows running/recalled/abandoned
//  WSForeshadowing entries grouped by chapter).
//
//  Persistence: reads via WSForeshadowingRepository (= SwiftData-backed;
//  = future ticket will introduce a dedicated PlotThreadRepository).
//

import SwiftUI

@MainActor
struct PlotThreadView: View {
    @Environment(BookStore.self) private var bookStore
    @State private var tracker: PlotThreadTracker?
    @State private var threads: [PlotThread] = []
    @State private var title = ""
    @State private var details = ""
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
            Text(WenshuI18n.t("b5.plotthreadview.l14.h19187540")).font(.headline)
            if let bookId = bookStore.selectedBookId {
                HStack {
                    TextField(WenshuI18n.t("b5.plotthreadview.l17.h33003032"), text: $title)
                    Button(WenshuI18n.t("b5.plotthreadview.l18.h79272146")) { add(bookId: bookId) }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                TextField(WenshuI18n.t("b5.plotthreadview.l20.h12597265"), text: $details)
                List {
                    Section(WenshuI18n.t("b5.plotthreadview.l22.h14379348")) {
                        ForEach(threads) { thread in
                            HStack {
                                VStack(alignment: .leading) { Text(thread.title); Text(thread.status.rawValue).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Button(role: .destructive) { remove(thread.id) } label: { Image(systemName: "trash").font(.system(size: 16, weight: .regular)) }.buttonStyle(.borderless)
                            }
                        }
                    }
                    Section(WenshuI18n.t("b5.plotthreadview.l31.h89394691")) {
                        ForEach(threads.filter { $0.status == .open || $0.status == .developing }) { thread in
                            Label { Text(thread.title) } icon: { Image(systemName: "exclamationmark.triangle").font(.system(size: 16, weight: .regular)) }
                        }
                    }
                }
            } else {
                // v1.0.0-m1-shell boss 2026-09-12 OOB 'unify the empty-state style across all of them':
                // use the unified EmptyStateView (= 76 PT Lucide icon
                // + 1 PT stroke via LucideThinIcon + standard
                // title/body hierarchy). Same visual treatment as the
                // other 11 tabs.
                EmptyStateView(
                    icon: "git-branch",
                    title: WenshuI18n.t("b5.plotthreadview.l37.h49866041"),
                    body: WenshuI18n.t("b5.plotthreadview.l17.h33003032")
                )
            }
            if let errorText { Text(errorText).foregroundStyle(.red).font(.caption) }
        }.padding(DesignTokens.chromePaddingMedium).task(id: bookStore.selectedBookId) { await reload() }
    }

    private func reload() async {
        guard let id = bookStore.selectedBookId else { return }
        let instance = tracker ?? PlotThreadTracker(bookStore: bookStore); tracker = instance
        do { threads = try await instance.list(bookId: id) } catch { errorText = error.localizedDescription }
    }
    private func add(bookId: UUID) {
        let instance = tracker ?? PlotThreadTracker(bookStore: bookStore); tracker = instance
        let thread = PlotThread(bookId: bookId, title: title, description: details)
        Task { do { try await instance.add(thread); title = ""; details = ""; await reload() } catch { errorText = error.localizedDescription } }
    }
    private func remove(_ id: UUID) {
        guard let instance = tracker else { return }
        Task { do { try await instance.remove(id: id); await reload() } catch { errorText = error.localizedDescription } }
    }
}
