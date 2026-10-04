//
//  Sources/WenshuApp/Views/Windows/ManifestWindow.swift
//
//  Independent Manifest window (= the entry surface for the
//  WSManifest SwiftData @Model). Shows the workspace manifest
//  record (= schema version, migration timestamp, etc.) since
//  the @Model is a singleton. Shape mirrors ForeshadowingGraphWindow
//  (= per the v2.9b independent-window pattern).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        + Apple HIG `.windowResizability(.contentSize)`. Same shape
//        as kanban + todo + canvas + composer + foreshadowing-graph
//        + cron windows.
//    S3 (single source of truth): reads WSManifest via
//        `WSPersistenceContainer.shared.mainContext` (= the canonical
//        container; = no sidecar persistence).
//

import SwiftUI
import SwiftData

/// Independent Manifest window (= MVP per (see OOB.md #2026-10-03) OOB:
/// "新增入口，在工具栏加三个圆的单独的按钮，打开独立的 windows 像看板一样").
@MainActor
struct ManifestWindow: View {

    @State private var manifest: WSManifest?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLoose) {
            header
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let manifest {
                details(manifest)
            } else {
                emptyState
            }
        }
        .padding(DesignTokens.spacingHero)
        .frame(minWidth: DesignTokens.commandPaletteMaxHeight,
               minHeight: DesignTokens.textEditorMediumMinHeight)
        .task { await reload() }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            SFIcon("doc.text.below.ecg", style: .inlineSmall, color: IconColor.tint)
            Text(WenshuI18n.t("window.manifest.title"))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: DesignTokens.spacingStandard) {
            SFIcon("questionmark.folder", style: .emptyStateHero, color: IconColor.secondary)
            Text(WenshuI18n.t("window.manifest.empty"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func details(_ manifest: WSManifest) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
                detailRow(label: WenshuI18n.t("window.manifest.workspace_uuid"),
                          value: manifest.workspaceUUID.uuidString)
                detailRow(label: WenshuI18n.t("window.manifest.schema_version"),
                          value: "\(manifest.schemaVersion)")
                detailRow(label: WenshuI18n.t("window.manifest.wenshu_version"),
                          value: manifest.wenshuVersion)
                detailRow(label: WenshuI18n.t("window.manifest.created_at"),
                          value: manifest.createdAt.formatted(date: .abbreviated, time: .shortened))
                detailRow(label: WenshuI18n.t("window.manifest.updated_at"),
                          value: manifest.updatedAt.formatted(date: .abbreviated, time: .shortened))
                if let checksum = manifest.checksum {
                    detailRow(label: WenshuI18n.t("window.manifest.checksum"),
                              value: checksum)
                }
                if let migratedAt = manifest.migratedFromRawSqliteAt {
                    detailRow(label: WenshuI18n.t("window.manifest.migrated_at"),
                              value: migratedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding(DesignTokens.spacingLoose)
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingStandard) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: DesignTokens.metadataPanelMaxWidth, alignment: .leading)
            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func reload() async {
        do {
            let context = WSPersistenceContainer.shared.mainContext
            let descriptor = FetchDescriptor<WSManifest>()
            manifest = try context.fetch(descriptor).first
            errorText = nil
        } catch {
            errorText = String(describing: error)
        }
    }
}