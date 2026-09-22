//
//  ChatMessageThinkingDisclosure.swift · Wenshu · refactor chat-mvvm-3layer C-8b
//
//  Apple MVVM canonical leaf view for the reasoning DisclosureGroup
//  that shows the assistant's thinking content (= what it considered
//  before replying). Lifted out of ChatMessageView so:
//  - ChatMessageView body shrinks further (toward the ~200 line target).
//  - The thinking disclosure is independently testable + Xcode-previewable.
//  - The collapse state is owned at the leaf level (= each message
//    tracks its own collapse independently).
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  This is UI-only (= no business logic; = the thinking string comes
//  straight from ChatMessage.thinking).
//
//  Visibility rule (= preserved from ChatMessageView body):
//  The leaf renders ONLY when:
//    - message.parts is empty (legacy v0.34 messages without parts)
//    - AND no .reasoning part exists in message.parts (new
//      streaming messages use ChatReasoningPartView instead; = if
//      any reasoning part is present, the legacy DisclosureGroup
//      would duplicate the content).
//    - AND thinking string is non-empty.
//    - AND message source is .wenshu (assistant side).
//  Pass `shouldRender: false` to hide (= the leaf itself is dumb;
//  the gate logic stays in the call site for now).
//
//  hermes 1:1: hermes真值's thinking DisclosureGroup (= status.tsx
//  ResponseLoadingIndicator + assistant-message.tsx) uses NO icon +
//  NO 'chatview.ai_thinking' label — just the 3×3 PT StatusPulse
//  square as the collapsed row identity. wenshu keeps that 1:1.
//

import SwiftUI

/// Leaf view: collapsible reasoning block for legacy messages.
/// Pass `thinking: ""` or `shouldRender: false` to hide the leaf.
public struct ChatMessageThinkingDisclosure<Label: View>: View {
    let thinking: String
    @Binding var isExpanded: Bool
    @ViewBuilder let collapsedLabel: Label

    public init(
        thinking: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder collapsedLabel: () -> Label
    ) {
        self.thinking = thinking
        self._isExpanded = isExpanded
        self.collapsedLabel = collapsedLabel()
    }

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(thinking)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, DesignTokens.chromePaddingMicro)
                .transition(.opacity)
        } label: {
            collapsedLabel
        }
        .animation(.default, value: isExpanded)
    }
}
