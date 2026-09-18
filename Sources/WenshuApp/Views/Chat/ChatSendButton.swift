//
//  ChatSendButton.swift · Wenshu · v1.28 C3.4.4
//
//  v1.28 C3.4.4: split the Send button out of ChatView (= god-view
//  split step 4 = the v1.0.0-m1-shell boss 2026-09-15 OOB "use SF
//  Symbols 6 paperplane" send button at the right of the input row).
//
//  Originally at ChatView.swift:1524-1553 (= 30 lines: Button + icon
//  + isSending state-driven ProgressView swap + .bordered style +
//  .frame height + v0.61 boss OOB comments).
//
//  Behavior preserved:
//  - Tapping → spawn Task that calls `vm.routeInput()` (= the v0.39
//    ChatBox front-door entry point)
//  - While `isSending` is true: swap the icon for ProgressView +
//    dim the icon to 50% opacity + scale down to 92% (= the v0.55
//    "pulse while reply is streaming" pattern)
//  - Otherwise: SF Symbols 6 `paperplane` (= boss 2026-09-15 OOB
//    reversal of the v0.25.1 "Lucide .send" choice)
//  - .bordered button style + .frame height 32 PT (= matches Apple's
//    canonical chat input control height per Liquid Glass HIG)
//

import SwiftUI

struct ChatSendButton: View {
    var vm: ChatViewModel

    var body: some View {
        Button {
            Task { await vm.routeInput() }
        } label: {
            if vm.isSending {
                ProgressView()
                    .controlSize(.small)
            } else {
                // v1.0.0-m1-shell boss 2026-09-15 OOB 'remove Lucide,
                // use SF Symbols 6 (3rd gen) with palette rendering':
                // canonical send-button icon = SF Symbols 6 `paperplane`.
                // Replaces the v0.25.1 'Lucide .send' choice per
                // boss 2026-08-26 OOB (= which has since been
                // superseded by the 2026-09-15 'use SF Symbols 6'
                // reversal).
                Image(systemName: "paperplane")
                    .font(.system(size: DesignTokens.tabIconSize, weight: .regular))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                    // v0.55: pulse the glyph while a reply is streaming
                    .opacity(vm.isSending ? 0.5 : 1)
                    .scaleEffect(vm.isSending ? 0.92 : 1)
                }
                }
                // v0.61 boss 2026-09-10 OOB 'the attach button and the
                // send button should match styles': both buttons are in
                // the same HStack, so any visual mismatch reads as a bug.
                // Use .bordered = the standard macOS Liquid Glass secondary
                // button style (= Apple's canonical "default button" look
                // in macOS 26 Tahoe). Per Apple developer.apple.com/
                // documentation/SwiftUI/PrimitiveButtonStyle, .bordered
                // renders a translucent rounded capsule (= Liquid Glass
                // material in macOS 26+) with a 1 PT separator border +
                // tint-on-hover effect. The icon shrinks to 18 PT
                // (= matches Apple's canonical glyph size for secondary
                // toolbar buttons per Liquid Glass HIG).
                //
                // v0.25.1 ticket 033 chat send button 30 PT height:
                // .controlSize(.regular) button default ≈ 24 PT glyph;
                // .frame(height: 30 PT) keeps the button at Apple's
                // standard control height (= same as the TextField so they
                // align flush). Previously the TextField was visually
                // ~22 PT (= font 13 PT + auto-padding = shorter than the
                // button's 24 PT controlSize regular).
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(height: LayoutTokens.chromeControlHeight)
                .disabled(vm.inputText.isEmpty || vm.isSending)
                .help(WenshuI18n.t("chat.input.send.help"))
                }
                }
