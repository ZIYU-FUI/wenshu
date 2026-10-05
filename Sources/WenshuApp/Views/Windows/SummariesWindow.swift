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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(summaries, id: \.id) { summary in
                    summaryRow(summary)
                }
            }
        }
    }

    @ViewBuilder
    private func summaryRow(_ summary: WSSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
            HStack(spacing: DesignTokens.spacingStandard) {
                SFIcon("text.bubble", style: .inlineSmall, color: IconColor.tint)
                Text(summary.session?.title ?? summary.sessionID)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text(summary.modelUsed)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(summary.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: DesignTokens.spacingStandard) {
                Text("\(summary.coveredTokenCount) → \(summary.summaryTokenCount) tokens")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Text(summary.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, DesignTokens.spacingCaption)
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