//
//  Sources/WenshuApp/Views/Windows/SummariesWindow.swift
//
//  Independent Summaries window (= the entry surface for the
//  WSSummary SwiftData @Model). Lists every WSSummary via
//  FetchDescriptor (= 1 row per chat session summary, mapped via
//  WSSession for the chat title). Shape mirrors ForeshadowingGraphWindow
//  (= per the v2.9b independent-window pattern).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        + Apple HIG `.windowResizability(.contentSize)`. Same shape
//        as kanban + todo + canvas + composer + foreshadowing-graph
//        + cron + attachments + manifest windows.
//    S3 (single source of truth): reads WSSummary + WSSession via
//        `WSPersistenceContainer.shared.mainContext` (= the canonical
//        container; = no sidecar persistence).
//

import SwiftUI
import SwiftData

/// Independent Summaries window (= MVP per (see OOB.md #2026-10-03) OOB:
/// "新增入口，在工具栏加三个圆的单独的按钮，打开独立的 windows 像看板一样").
@MainActor
struct SummariesWindow: View {

    @State private var summaries: [WSSummary] = []
    @State private var errorText: String?

    /// Apple HIG canonical table selection (= Set of String ids
    /// via WSSummary's Identifiable conformance; = matches the
    /// @Model's `@Attribute(.unique) var id: String`).
    @State private var selection: Set<WSSummary.ID> = []
    /// Apple HIG canonical sort order (= the user clicks a column
    /// header to toggle ascending / descending).
    @State private var sortOrder: [KeyPathComparator<WSSummary>] = [
        KeyPathComparator(\.updatedAt, order: .reverse)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLoose) {
            header
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if summaries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .padding(DesignTokens.spacingHero)
        .frame(minWidth: DesignTokens.commandPaletteMaxHeight,
               minHeight: DesignTokens.textEditorMediumMinHeight)
        .task { await reload() }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            SFIcon("text.bubble", style: .inlineSmall, color: IconColor.tint)
            Text(String(localized: "window.summaries.title"))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text("\(summaries.count)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: DesignTokens.spacingStandard) {
            SFIcon("text.bubble", style: .emptyStateHero, color: IconColor.secondary)
            Text(String(localized: "window.summaries.empty"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity)
    }

    private var list: some View {
        // Apple HIG canonical Table (= macOS 12+; = multi-column
        // native control Finder / Mail / Notes; = column-header
        // click sorts; = native row selection chrome). Wraps
        // the WSSummary rows with five TableColumns: Session,
        // Model, Summary, Tokens, Updated. Each TableColumn
        // value: KeyPath drives the column-header sort; the
        // closure inside the column body provides the cell
        // content (= Apple HIG idiom; = the column knows its
        // own sort comparator AND its own rendering).
        Table(of: WSSummary.self, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Session", value: \.sessionID) { summary in
                HStack(spacing: DesignTokens.spacingStandard) {
                    SFIcon("text.bubble", style: .inlineSmall, color: IconColor.tint)
                    Text(summary.session?.title ?? summary.sessionID)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .width(min: 140, ideal: 200)
            TableColumn("Model", value: \.modelUsed) { summary in
                Text(summary.modelUsed)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 120)
            TableColumn("Summary", value: \.summary) { summary in
                Text(summary.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .width(min: 200, ideal: 320)
            TableColumn("Tokens", value: \.coveredTokenCount) { summary in
                // Apple HIG canonical token-format display (= the
                // session's covered → summary token count).
                Text("\(summary.coveredTokenCount) → \(summary.summaryTokenCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .width(min: 100, ideal: 130)
            TableColumn("Updated", value: \.updatedAt) { summary in
                Text(summary.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .width(min: 80, ideal: 100)
        } rows: {
            ForEach(summaries) { summary in
                TableRow(summary)
            }
        }
        .onChange(of: sortOrder) { _, newOrder in
            summaries.sort(using: newOrder)
        }
    }

    private func reload() async {
        do {
            let context = WSPersistenceContainer.shared.mainContext
            let descriptor = FetchDescriptor<WSSummary>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            summaries = try context.fetch(descriptor)
            errorText = nil
        } catch {
            errorText = String(describing: error)
        }
    }
}