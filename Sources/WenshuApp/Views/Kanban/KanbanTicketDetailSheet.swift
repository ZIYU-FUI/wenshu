//
//  KanbanTicketDetailSheet.swift · Wenshu · kanban-detail-sheet 2026-09-28
//
//  Phase 2 of the kanban-markdown arc. Opens a sheet (= modal) for a
//  single KanbanTicket so the user can read the full agent-written
//  body (= markdown = `**Goal:**`, lists, inline code, links) past
//  the card's `.lineLimit(6)` truncation.
//
//  Apple HIG components used (= no custom chrome):
//    - .sheet(isPresented:)
//    - NavigationStack (Apple-default sheet chrome = title row + close)
//    - ScrollView + Text(AttributedString) for the body
//    - HStack(status badge) mirrors the card's status pill (= no layout drift)
//    - .frame(width:height:) per DesignTokens settyIOsheet size (= 600×400
//      reused for any read-only body sheet; = boss hasn't asked for a
//      dedicated kanban-size token yet).
//
//  1 markdown pipeline = the body parses via the same
//  `ChatTextPartView.parseMarkdown` the card body uses (= 1:1 with
//  hermes 0.21.5 reusing MessageTextContent across kanban + chat).
//
//  i18n: status labels reuse the existing `label(for:)` style from
//  `KanbanCard`; = no new strings here beyond a "Body" header (= the
//  body is the only new visible chrome).
//

import SwiftUI

struct KanbanTicketDetailSheet: View {
    let ticket: KanbanTicket
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
                statusBadge
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
                        Text(ticket.title)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)
                        if let body = ticket.body, !body.isEmpty {
                            Text(ChatTextPartView.parseMarkdown(body))
                                .font(.body)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("No body set.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, DesignTokens.chromePaddingMedium)
                    .padding(.vertical, DesignTokens.chromePaddingSmall)
                }
            }
            .frame(idealWidth: DesignTokens.settingIOsheetSize.width,
                   idealHeight: DesignTokens.settingIOsheetSize.height)
            .navigationTitle("Ticket")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(statusLabel(ticket.status))
            .font(.caption.weight(.medium))
            .padding(.horizontal, DesignTokens.chromePaddingSmall)
            .padding(.vertical, DesignTokens.chromePaddingNano)
            .background(.tint.opacity(0.18), in: Capsule())
            .padding(.horizontal, DesignTokens.chromePaddingMedium)
            .padding(.top, DesignTokens.chromePaddingSmall)
    }

    private func statusLabel(_ status: KanbanStatus) -> String {
        switch status {
        case .new: return "新"
        case .triage: return "分流"
        case .ready: return "就绪"
        case .running: return "进行"
        case .blocked: return "阻塞"
        case .review: return "复核"
        case .done: return "完成"
        case .failed: return "失败"
        }
    }
}
