//
//  ChatAttachButton.swift · Wenshu · v1.28 C3.4.3
//
//  v1.28 C3.4.3: split the paperclip attach button out of ChatView
//  (= god-view split step 3 = the CHATIMG-001 attach button that
//  opens the file importer to attach a draft image to the chat
//  message).
//
//  Originally at ChatView.swift:1315-1354 (= 40 lines of comments + 12
//  lines of code). The extraction moves the Button + its modifiers
//  (= .buttonStyle(.bordered) + .help + .disabled) into a standalone
//  view.
//
//  Behavior preserved (= tapping the button toggles the parent's
//  `.fileImporter` binding via the `showingImageImporter` Binding that
//  is passed in; = the picked image goes through ChatViewModel.attachImage(at:);
//  = the .disabled state mirrors vm.isSending so the button is locked
//  while a message is in flight).
//

import SwiftUI

struct ChatAttachButton: View {
    @Binding var showingImageImporter: Bool
    var isSending: Bool

    var body: some View {
        Button {
            showingImageImporter = true
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: DesignTokens.tabIconSize, weight: .regular))
                .aspectRatio(contentMode: .fit)
                .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                .foregroundStyle(.secondary)
        }
        // v0.61 boss 2026-09-10 OOB 'the attach button and the
        // send button should match styles': they are both in the
        // same HStack, so any visual mismatch reads as a bug.
        // Send uses .bordered (= Apple standard Liquid Glass
        // capsule, per boss 8/29 OOB); attach was .borderless
        // (the older CHATIMG-001 default). The two are now the
        // same style, which is also what Apple uses for the
        // paperclip in Messages and the send in every chat app
        // that ships with the platform.
        .buttonStyle(.bordered)
        .help(WenshuI18n.t("chat.input.attach.help"))
        // CHATIMG-001 (2026-09-07): the attach button is
        // intentionally NOT gated on `hasUsableKey` (=
        // LLM model availability). Attaching a draft image
        // is independent of sending (= you can attach + see
        // the preview chip + clear it even when no LLM
        // provider is configured). Send itself still
        // requires `hasUsableKey` via the Send button's own
        // .disabled check; if you try to send with no
        // model, the existing routeInput() guard handles
        // it (= no LLM call = no error message; the
        // message just persists in the in-memory list).
        .disabled(isSending)
    }
}
