import SwiftUI

struct ChapterTreeView: View {
    let projectId: UUID?
    let store: WenshuProjectStore
    @StateObject private var chapterStore: ChapterTreeStore

    init(projectId: UUID?, store: WenshuProjectStore = .shared) {
        self.projectId = projectId
        self.store = store
        _chapterStore = StateObject(wrappedValue: ChapterTreeStore(projectId: projectId ?? UUID(), store: store))
    }

    var body: some View {
        Group {
            if projectId == nil || chapterStore.chapters.isEmpty { emptyState } else {
                List(chapterStore.chapters) { chapter in
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle").font(.system(size: 14)).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) { Text(chapter.title).font(.headline); Text("第 \(chapter.index) 章 · \(chapter.wordCount) 字").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                    }.padding(.vertical, 2)
                }.listStyle(.inset)
            }
        }
        .navigationTitle("章节")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("新建章节", systemImage: "plus") { }.disabled(true).help("v0.04.0 长篇工具 阶段实装") } }
        .task(id: projectId) { if projectId != nil { await chapterStore.load() } }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle").font(.system(size: 56, weight: .light)).foregroundStyle(.secondary)
            Text("暂无章节").font(.title2)
            Text("v0.04.0 接新建章节").font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }
}
