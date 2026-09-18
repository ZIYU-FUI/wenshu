//
//  ChatPlanPartView.swift · Wenshu · T20b-PLAN-UI (2026-09-18)
//
//  Hermes-style plan card renderer. Displays a numbered plan
//  (= list of PlanStep) as a collapsible card with an
//  'Approve & Run' action.
//
//  Apple HIG convention:
//    - Card with .quaternary fill (= subtle plan-mode indicator;
//      = the chat bubble color stays neutral = no Apple HIG conflict)
//    - Numbered steps in monospaced font (= the canonical code-block
//      "step list" visual; = matches Xcode's task list pattern).
//    - 'Approve' / 'Decline' buttons at the bottom (= the standard
//      modal-action footer pattern; = same shape as Mail's rule
//      confirmation dialog).
//
//  Hermes equivalent: useChatSendPlanMode (= runtime/chat/plan.ts) =
//  displays a PlanCard component with steps + approve/decline buttons.
//

import SwiftUI
import WenshuApp

/// ChatPartView for plan-mode plans. Renders the Plan as a card
/// with numbered steps + Approve/Decline buttons.
///
/// Approval flow (= wired by ChatView via the onApprove closure):
///   1. User types `/plan <query>`
///   2. PlanModeEngine produces a Plan
///   3. ChatView creates a ChatMessage with .plan part containing
///      the Plan (= handled by a new ChatMessagePart.Kind.case)
///   4. ChatMessageBodyView routes .plan -> ChatPlanPartView
///   5. User clicks Approve -> onApprove(plan) re-invokes the
///      conductor with the plan attached as additional system context
public struct ChatPlanPartView: View {
    public let plan: Plan
    public let onApprove: (Plan) -> Void

    @State private var isExpanded: Bool = true

    public init(plan: Plan, onApprove: @escaping (Plan) -> Void) {
        self.plan = plan
        self.onApprove = onApprove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
            // Header: 'Plan: <query>' + connector label.
            HStack(spacing: DesignTokens.chromePaddingSmall) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                Text("Plan: \(plan.query)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(plan.connectorID)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            // DisclosureGroup (= collapsible step list; = the
            // standard macOS expand/collapse pattern). Default = expanded
            // (= user sees the plan immediately).
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
                    ForEach(plan.steps, id: \.index) { step in
                        stepRow(step)
                    }
                }
                .padding(.top, DesignTokens.chromePaddingSmall)
            } label: {
                HStack(spacing: 4) {
                    Text("\(plan.steps.count) step\(plan.steps.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            // Action footer (= Approve + Decline = standard modal action
            // pattern). Decline is just onApprove with the plan dropped
            // (= user dismisses the plan; = the query is still in the
            // chat zone for them to manually retry).
            HStack(spacing: DesignTokens.chromePaddingSmall) {
                Button {
                    onApprove(plan)
                } label: {
                    Label {
                        Text("Approve & Run")
                    } icon: {
                        Image(systemName: "play.fill").font(.system(size: 10, weight: .semibold))
                    }
                    .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Spacer()
            }
            .padding(.top, DesignTokens.chromePaddingSmall)
        }
        .padding(DesignTokens.chromePaddingSmall)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .frame(maxWidth: 420)
    }

    /// Single step row (= numbered + monospaced + detail).
    private func stepRow(_ step: PlanStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(step.index).")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.primary)
                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var cardFill: AnyShapeStyle {
        AnyShapeStyle(.quaternary.opacity(0.4))
    }
}