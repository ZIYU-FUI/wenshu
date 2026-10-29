import Foundation
import SwiftUI

// The screen a chapter opens in.
//
// The body is Markdown, and the renderer is the system's own:
// `Text(AttributedString(markdown:))`, so no Markdown library joins the
// app. The revision the Mac reported travels with the body, so a copy
// that is behind the Mac is visible instead of silent.
//
// A failure here is a failure of ONE chapter: the library is there, so
// the screen names the chapter that failed and never shows an empty
// library.

/// The chapter the reader opens.
@MainActor
struct ChapterReaderView: View {
    /// The chapter the reader asked for.
    let chapterID: ChapterID
    /// The store the body comes from.
    let store: any LibraryStore

    /// What the screen shows right now.
    @State private var state: ChapterReaderState = .loading

    var body: some View {
        content
            .navigationTitle(title)
            .task { await load() }
    }

    /// The screen for the state it is in.
    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
        case .loaded(let read):
            chapterBody(read)
        case .failed(let failure):
            failureRow(failure)
        }
    }

    /// The chapter's body, with the revision it was read at.
    private func chapterBody(_ read: ChapterRead) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMedium) {
                Text(Self.markdown(read.body))
                    .font(DesignTokens.bodyFont)
                metadata(read)
            }
            .padding(DesignTokens.spacingLarge)
        }
    }

    /// The lines that say where the chapter sits and which revision it
    /// was read at.
    ///
    /// The order is the order the outline gave, so a reader knows which
    /// chapter of the book this is.
    @ViewBuilder
    private func metadata(_ read: ChapterRead) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSmall) {
            if let placement = placement {
                Text("Chapter \(placement.number) of \(placement.total)")
            }
            Text("Revision \(read.revision)")
        }
        .font(DesignTokens.captionFont)
        .foregroundStyle(DesignTokens.secondaryTextColor)
    }

    /// The row that says the chapter could not be read.
    ///
    /// The library is there and this one chapter is not readable yet,
    /// so the row says so and stops there.
    private func failureRow(_ failure: ChapterReadFailure) -> some View {
        ContentUnavailableView {
            Label("Chapter Unavailable", systemImage: SFIcon.stateError.rawValue)
        } description: {
            // The copy travels as a localized key, the way every other
            // string in this app does, so it resolves against a
            // Localizable table once this target has one.
            Text(LocalizedStringKey(failure.message))
        }
    }

    /// Asks the store for the chapter's body.
    private func load() async {
        do {
            state = .loaded(try await store.read(chapter: chapterID))
        } catch let failure as ChapterReadFailure {
            state = Self.state(for: failure)
        } catch {
            state = Self.state(for: .unreadable)
        }
    }

    /// The chapter's title, as the Mac spells it.
    private var title: String {
        placement?.title ?? chapterID.id
    }

    /// Where the chapter sits in the outline the Mac sent.
    private var placement: ChapterPlacement? {
        store.state.chapter(chapterID)
    }

    /// The body as Markdown, the way the system renders it.
    ///
    /// The renderer is Apple's own, so a heading, a list and emphasis
    /// come out as the Mac wrote them, with no Markdown library in the
    /// app.
    nonisolated static func markdown(_ body: String) -> AttributedString {
        (try? AttributedString(markdown: body)) ?? AttributedString(body)
    }

    /// The state the screen shows for a chapter that could not be read.
    ///
    /// A failed read is a failure of that one chapter, so the state
    /// carries the reason and nothing about the library.
    nonisolated static func state(for failure: ChapterReadFailure) -> ChapterReaderState {
        .failed(failure)
    }
}

/// What the chapter screen shows.
enum ChapterReaderState: Equatable {
    /// The body is on its way from the Mac.
    case loading
    /// The body, and the revision it was read at.
    case loaded(ChapterRead)
    /// The read failed; the reason says what failed.
    case failed(ChapterReadFailure)
}

extension ChapterReadFailure {
    /// The line the reader shows when a chapter cannot be read.
    ///
    /// The library is there and this one chapter is not readable yet,
    /// so the line names the chapter and never the library.
    var message: String {
        switch self {
        case .macUnreachable:
            "The Mac is not reachable, so this chapter could not be read."
        case .unreadable:
            "This chapter could not be read from the Mac."
        }
    }
}

#if DEBUG
#Preview("Chapter") {
    NavigationStack {
        ChapterReaderView(
            chapterID: ChapterID(id: "chapter-harbour"),
            store: FixtureLibraryStore()
        )
    }
}
#endif
