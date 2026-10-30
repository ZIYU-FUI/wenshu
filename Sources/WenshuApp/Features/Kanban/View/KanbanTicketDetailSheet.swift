//
//  KanbanTicketDetailSheet.swift
//  arc of kanban-markdown work)
//
//  Opens a sheet (= modal) for a single kanban task so the full
//  agent-written body (= markdown = `**Goal:**`, lists, inline code,
//  links) can be read past the card's `.lineLimit(6)` truncation.
//
//  Apple HIG components used (= no custom chrome):
//    - .sheet(isPresented:)
//    - NavigationStack (Apple-default sheet chrome = title row + close)
//    - ScrollView + Text(AttributedString) for the body
//    - the status badge mirrors the card's status pill (= no layout drift)
//    - .frame(width:height:) per DesignTokens settyIOsheet size (= 600×400
//      reused for any read-only body sheet; = no current ask for a
//      dedicated kanban-size token yet).
//
//  1 markdown pipeline = the body parses via the same
//  `ChatTextPartView.parseMarkdown` the card body uses (= 1:1 with
//  hermes 0.21.5 reusing MessageTextContent across kanban + chat).
//
//  i18n: the status label comes from the board's own mapping
//  (= `KanbanStatus.boardLabel`), = so the sheet and the card read
//  the same word in every language.
//

import SwiftUI

struct KanbanTicketDetailSheet: View {
    let task: KanbanTask
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                statusBadge
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        Text(task.title)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)
                        if let body = task.body, !body.isEmpty {
                            Text(ChatTextPartView.parseMarkdown(body))
                                .font(.body)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(String(localized: "kanban.detail.no_body"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingModerate)
                    .padding(.vertical, DesignTokens.spacingTight)
                }
            }
            .frame(idealWidth: DesignTokens.settingIOsheetSize.width,
                   idealHeight: DesignTokens.settingIOsheetSize.height)
            .navigationTitle(String(localized: "kanban.detail.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "kanban.detail.close"), action: onDismiss)
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(task.status.boardLabel)
            .font(.caption.weight(.medium))
            .padding(.horizontal, DesignTokens.spacingTight)
            .padding(.vertical, DesignTokens.spacingCaption)
            .background(.tint.opacity(DesignTokens.accentTintOpacityHero), in: Capsule())
            .padding(.horizontal, DesignTokens.spacingModerate)
            .padding(.top, DesignTokens.spacingTight)
    }

}
