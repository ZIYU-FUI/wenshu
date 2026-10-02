//
//  BackgroundReviewView.swift · Wenshu · v2.9a ticket T23 (boss 2026-09-28 OOB A3)
//
//  Manual surface for BackgroundReview (= boss 2026-09-28 OOB
//  inventory A3). The v2.8c agent surface (= BackgroundReviewTool
//  + WenshuConductor wire + ConversationLoop step 9 auto-call) is
//  wired; = the manual approve / reject surface was missing.
//
//  v2.9a adds the inspector tab: lists pending BackgroundProposal
//  rows + an Approve button (= calls BackgroundReviewOps.approve)
//  + a Reject button (= calls BackgroundReviewOps.reject).
//
//  Uses BackgroundReviewOps (= @MainActor enum with 4 static funcs:
//  submit / approve / reject / listPending) as the canonical entry
//  surface (= the agent path goes through the same ops via
//  BackgroundReviewTool).
//
//  Pattern follows BookmarkView / v2.8a specialized-tool body
//  modifier + EmptyStateView pattern (= canonical Apple HIG).
//
//  Per boss 2026-09-28 OOB: '用户体验第一' = no placeholder/stub;
//  = the v2.9a BackgroundReview tab must show real proposals
//  (= loaded via BackgroundReviewOps.listPending), not a
//  placeholder text.

import SwiftUI
import WenshuApp

struct BackgroundReviewView: View {
    @Environment(AppState.self) private var appState

    @State private var proposals: [BackgroundProposal] = []
    @State private var status: SpecializedToolLoadStatus = .idle
    @State private var errorText: String?

    init() {}

    var body: some View {
        specializedToolBody(
            activeBookId: appState.openTabs.first(where: { $0.id == appState.activeTabId })?.id,
            emptyContent: { emptyState },
            mainContent: { contentBody }
        )
        .task { await reload() }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "checkmark.circle",
            title: WenshuI18n.t("background_review.empty.title"),
            body: WenshuI18n.t("background_review.empty.body")
        )
    }

    private var contentBody: some View {
        List(proposals) { proposal in
            HStack(alignment: .top, spacing: 8) {
                SFIcon(
                    proposalIcon(for: proposal.kind),
                    style: .inlineSmall,
                    color: proposalColor(for: proposal.kind)
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(proposal.title)
                        .font(.headline)
                    if !proposal.proposedChanges.isEmpty {
                        Text(proposal.proposedChanges.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                Spacer()
                VStack(spacing: 4) {
                    Button(WenshuI18n.t("background_review.approve")) {
                        Task { await approve(proposal.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button(WenshuI18n.t("background_review.reject")) {
                        Task { await reject(proposal.id) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, DesignTokens.spacingIconic)
        }
    }

    private func proposalIcon(for kind: ProposalKind) -> String {
        switch kind {
        case .turnSummary: return "text.alignleft"
        case .entityCreation: return "person.crop.circle.badge.plus"
        case .entityUpdate: return "person.text.rectangle"
        case .entityDeletion: return "person.crop.circle.badge.minus"
        case .fileEdit: return "pencil.and.list.clipboard"
        case .memoryWrite: return "brain"
        case .skillInvocation: return "sparkles"
        case .other: return "ellipsis.circle"
        }
    }

    private func proposalColor(for kind: ProposalKind) -> Color {
        switch kind {
        case .turnSummary, .memoryWrite: return .blue
        case .entityCreation: return .purple
        case .entityUpdate, .fileEdit: return .orange
        case .entityDeletion: return .red
        case .skillInvocation: return .pink
        case .other: return .gray
        }
    }

    private func reload() async {
        status = .loading
        errorText = nil
        proposals = await BackgroundReviewOps.listPending()
        status = .loaded
    }

    private func approve(_ id: UUID) async {
        do {
            try await BackgroundReviewOps.approve(id)
            proposals.removeAll { $0.id == id }
        } catch {
            errorText = String(describing: error)
        }
    }

    private func reject(_ id: UUID) async {
        do {
            try await BackgroundReviewOps.reject(id)
            proposals.removeAll { $0.id == id }
        } catch {
            errorText = String(describing: error)
        }
    }
}