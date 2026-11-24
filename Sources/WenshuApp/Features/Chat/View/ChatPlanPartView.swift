//
//  ChatPlanPartView.swift
//
//  Hermes-style plan card renderer. Displays a numbered plan
//  (= list of PlanStep) as a collapsible card with an
//  'Approve & Run' action.
//
//  product convention:
//    - Card with .quaternary fill (= subtle plan-mode indicator;
//      = the chat bubble color stays neutral = no product conflict)
//    - Numbered steps in monospaced font (= the canonical code-block
//      "step list" visual; = matches Xcode's task list pattern).
//    - The card's title in the headline style (= a title outranks the
//      caption-scale provenance strip under it; = the rank is the whole
//      of what the header says with size).
//    - 'Approve' / 'Decline' buttons at the bottom (= the standard
//      modal-action footer pattern; = same shape as Mail's rule
//      confirmation dialog).
//
//  Hermes equivalent: useChatSendPlanMode (= runtime/chat/plan.ts) =
//  displays a PlanCard component with steps + approve/decline buttons.
//

import SwiftUI
import WenshuAgent

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
struct ChatPlanPartView: View {
    let plan: Plan
    let onApprove: (Plan) -> Void

    @State private var isExpanded: Bool = true

    init(plan: Plan, onApprove: @escaping (Plan) -> Void) {
        self.plan = plan
        self.onApprove = onApprove
    }

    /// T29-CONNECTOR-ICON (2026-09-18): map a connector slug to a
    /// distinctive SF Symbol. Covers all 14 first-class + custom providers in AGENTS.md
    /// §11.2 + a generic fallback for unknown slugs. The icon
    /// appears next to the connector name in the plan header
    /// (= a quick visual hint of which LLM produced the plan).
    nonisolated static func connectorIcon(_ slug: String) -> String {
        switch slug {
        case "anthropic":     return "brain.head.profile"   // Claude = brain
        case "openai-codex":  return "circle.hexagongrid.fill"  // OpenAI = OpenAI logo-ish
        case "gemini":        return "sparkles"             // Gemini = dual stars
        case "deepseek":      return "water.waves"          // DeepSeek = depth
        case "ollama":        return "laptopcomputer"        // Ollama = local
        case "openrouter":    return "arrow.triangle.branch" // OpenRouter = routing
        case "minimax-cn",
             "minimax":       return "leaf.fill"             // MiniMax = brand-ish
        default:              return "questionmark.circle"  // unknown
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            // The header is two rows: what the plan is, then who made
            // it. A query needs the width the provenance would take, and
            // the model id is not part of the plan's own sentence.
            VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
                HStack(spacing: DesignTokens.spacingTight) {
                    SFIcon("list.bullet.rectangle", style: .inlineSmall, color: Color.accentColor, matchingText: .headline)
                    Text("Plan: \(plan.query)")
                        .font(.headline.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("(N steps)".replacingOccurrences(
                        of: "N", with: "\(plan.steps.count)"
                    ))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, DesignTokens.spacingIconic)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                                .strokeBorder(.quaternary, lineWidth: DesignTokens.separatorThicknessHairline)
                        )
                    Spacer(minLength: 0)
                }
                // The provenance strip: the provider, the exact model id
                // when the plan carries one, and how old the plan is. The
                // connector glyph is the at-a-glance half of this row, so
                // it is read by the row, not by the slug alone.
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon(Self.connectorIcon(plan.connectorID), style: .inlineSmall, color: IconColor.tertiary, matchingText: .caption2)
                    Text(Provider.by(slug: plan.connectorID)?.name ?? plan.connectorID)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let model = plan.model {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                        Text(model)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    Text(plan.createdAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            // DisclosureGroup (= collapsible step list; = the
            // standard macOS expand/collapse pattern). Default = expanded
            // (= user sees the plan immediately).
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                    ForEach(plan.steps, id: \.index) { step in
                        stepRow(step)
                    }
                }
                .padding(.top, DesignTokens.spacingTight)
            } label: {
                HStack(spacing: DesignTokens.spacingIconic) {
                    Text("\(plan.steps.count) step\(plan.steps.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            // Action footer (= Approve + Decline = standard modal action
            // pattern). Decline is just onApprove with the plan dropped
            // (= user dismisses the plan; = the query is still in the
            // chat zone for them to manually retry).
            HStack(spacing: DesignTokens.spacingTight) {
                Button {
                    onApprove(plan)
                } label: {
                    Label {
                        Text("Approve & Run")
                    } icon: {
                        SFIcon("play.fill", style: .inlineSmall, color: IconColor.tint)
                    }
                    .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Spacer()
            }
            .padding(.top, DesignTokens.spacingTight)
        }
        .padding(DesignTokens.spacingTight)
        .background(cardFill, in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusCard)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .frame(maxWidth: DesignTokens.planListMaxWidth)
    }

    /// Single step row (= numbered + monospaced + detail).
    private func stepRow(_ step: PlanStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(step.index).")
                .font(.caption.monospaced().bold())
                .foregroundStyle(Color.accentColor)
                .frame(width: DesignTokens.stepNumberColumnWidth, alignment: .trailing)
            VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
                Text(step.title)
                    .font(.caption.monospaced().bold())
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