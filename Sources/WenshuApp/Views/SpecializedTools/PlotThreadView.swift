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
            Text("Plot Threads").font(.headline)
            if let bookId = bookStore.selectedBookId {
                HStack {
                    TextField("Thread title", text: $title)
                    Button("Add") { add(bookId: bookId) }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                TextField("Setup description", text: $details)
                List {
                    Section("Threads") {
                        ForEach(threads) { thread in
                            HStack {
                                VStack(alignment: .leading) { Text(thread.title); Text(thread.status.rawValue).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Button(role: .destructive) { remove(thread.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                            }
                        }
                    }
                    Section("Stale threads") {
                        ForEach(threads.filter { $0.status == .open || $0.status == .developing }) { thread in
                            Label(thread.title, systemImage: "exclamationmark.triangle")
                        }
                    }
                }
            } else { Text("No book selected").foregroundStyle(.secondary) }
            if let errorText { Text(errorText).foregroundStyle(.red).font(.caption) }
        }.padding(12).task(id: bookStore.selectedBookId) { await reload() }
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
