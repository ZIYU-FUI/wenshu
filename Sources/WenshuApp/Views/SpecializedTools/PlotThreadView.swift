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
        VStack(alignment: .leading, spacing: 12) {
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
                                Button(role: .destructive) { remove(thread.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                            }
                        }
                    }
                    Section(WenshuI18n.t("b5.plotthreadview.l31.h89394691")) {
                        ForEach(threads.filter { $0.status == .open || $0.status == .developing }) { thread in
                            Label(thread.title, systemImage: "exclamationmark.triangle")
                        }
                    }
                }
            } else { Text(WenshuI18n.t("b5.plotthreadview.l37.h49866041")).foregroundStyle(.secondary) }
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
