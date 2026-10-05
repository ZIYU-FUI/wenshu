//
//  Sources/WenshuApp/Views/Windows/AttachmentsWindow.swift
//
//  Independent Attachments window (= the entry surface for the
//  WSAttachment SwiftData @Model). Lists every WSAttachment via
//  FetchDescriptor so the toolbar entry is a real usable surface
//  (= not a placeholder). The shape mirrors ForeshadowingGraphWindow
//  (= per the v2.9b independent-window pattern).
//
//  Migrated from a custom List + ForEach + ScrollView shape to
//  Apple HIG canonical `Table` (macOS 12+; = the same
//  multi-column native control Finder / Mail / Notes use for
//  tabular data). Apple canonical gives column-header sorting,
//  native row selection, and Apple-styled table chrome for
//  free. Each TableColumn is bound to a KeyPath (= Apple HIG
//  idiomatic; = no custom SortDescriptor plumbing).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI `Table` primitive +
//        SF Symbols 6 + Apple HIG `.windowResizability(.contentSize)`.
//        Same shape as kanban + todo + canvas + composer +
//        foreshadowing-graph + cron windows.
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
    /// Apple HIG canonical table selection (= a single row at a time
    /// for Attachments; = multi-select for Apple Mail's table). The
    /// bound Set stores the persistent IDs of selected rows (= the
    /// String id from the @Model; = Set<String> via Identifiable.ID).
    @State private var selection: Set<WSAttachment.ID> = []
    /// Apple HIG canonical sort order (= the user clicks a column
    /// header to toggle ascending / descending).
    @State private var sortOrder: [KeyPathComparator<WSAttachment>] = [
        KeyPathComparator(\.createdAt, order: .reverse)
    ]

    /// Apple HIG canonical byte formatter (= ByteCountFormatter; =
    /// automatic unit selection per locale + content size; = e.g.
    /// "1.2 KB" for small files, "3.4 MB" for large). Shared static
    /// (= cheap across table rows; = Foundation thread-safe).
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useAll]
        return f
    }()

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
                // Apple HIG canonical Table (= macOS 12+; = the
                // multi-column native control Finder / Mail / Notes
                // use for tabular data; = column-header click sorts;
                // = native row selection chrome). Uses TableRow
                // + ForEach rows: because WSAttachment's id is
                // String (= not a UUID; = Table(of:) with explicit
                // TableRowForEach gives us KeyPath sorting on String
                // id; = no need to retrofit WSAttachment to
                // Identifiable; = the type stays
                // SwiftData-@Model-agnostic).
                Table(of: WSAttachment.self, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn("Filename", value: \.filename) { attachment in
                        HStack(spacing: DesignTokens.spacingStandard) {
                            SFIcon("paperclip", style: .inlineSmall, color: IconColor.tint)
                            Text(attachment.filename)
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .width(min: 160, ideal: 240)
                    TableColumn("Type", value: \.mimeType) { attachment in
                        Text(attachment.mimeType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 120)
                    TableColumn("Size", value: \.sizeBytes) { attachment in
                        // Apple HIG canonical byte formatter
                        // (= ByteCountFormatter; = automatic unit
                        // selection per locale + content size).
                        // Declared static (= cheap to share across
                        // table rows; = Foundation's
                        // ByteCountFormatter thread-safe).
                        Text(AttachmentsWindow.byteFormatter.string(fromByteCount: Int64(attachment.sizeBytes)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 100)
                    TableColumn("Parent", value: \.parentKind) { attachment in
                        Text(attachment.parentKind)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 100, ideal: 140)
                    TableColumn("Created", value: \.createdAt) { attachment in
                        Text(attachment.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .width(min: 80, ideal: 100)
                } rows: {
                        ForEach(attachments) { attachment in
                            TableRow(attachment)
                        }
                }
                .onChange(of: sortOrder) { _, newOrder in
                    attachments.sort(using: newOrder)
                }
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
            Text(String(localized: "window.attachments.title"))
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
            Text(String(localized: "window.attachments.empty"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity)
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
