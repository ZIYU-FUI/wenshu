//
//  Sources/WenshuApp/Views/Windows/AttachmentsWindow.swift
//
//  Independent Attachments window (= the entry surface for the
//  WSAttachment SwiftData @Model). Lists every WSAttachment via
//  FetchDescriptor so the toolbar entry is a real usable surface
//  (= not a placeholder). The shape mirrors ForeshadowingGraphWindow
//  (= per the v2.9b independent-window pattern).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        + Apple HIG `.windowResizability(.contentSize)`. Same shape
//        as kanban + todo + canvas + composer + foreshadowing-graph
//        + cron windows.
//    S3 (single source of truth): reads WSAttachment via
//        `WSPersistenceContainer.shared.mainContext` (= the canonical
//        container; = no sidecar persistence).
//

import SwiftUI
import SwiftData

/// Independent Attachments window (= MVP per (see OOB.md #2026-10-03) OOB:
/// "新增入口，在工具栏加三个圆的单独的按钮，打开独立的 windows 像看板一样").
@MainActor
struct AttachmentsWindow: View {

    @State private var attachments: [WSAttachment] = []
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLoose) {
            header
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if attachments.isEmpty {
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
            SFIcon("paperclip", style: .inlineSmall, color: IconColor.tint)
            Text(WenshuI18n.t("window.attachments.title"))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text("\(attachments.count)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: DesignTokens.spacingStandard) {
            SFIcon("tray", style: .emptyStateHero, color: IconColor.secondary)
            Text(WenshuI18n.t("window.attachments.empty"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(attachments, id: \.id) { attachment in
                    attachmentRow(attachment)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentRow(_ attachment: WSAttachment) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.spacingStandard) {
            SFIcon("paperclip", style: .inlineSmall, color: IconColor.tint)
            VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
                Text(attachment.filename)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Text("\(attachment.mimeType) · \(attachment.sizeBytes) bytes · \(attachment.parentKind)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(attachment.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DesignTokens.spacingCaption)
    }

    private func reload() async {
        do {
            let context = WSPersistenceContainer.shared.mainContext
            let descriptor = FetchDescriptor<WSAttachment>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            attachments = try context.fetch(descriptor)
            errorText = nil
        } catch {
            errorText = String(describing: error)
        }
    }
}