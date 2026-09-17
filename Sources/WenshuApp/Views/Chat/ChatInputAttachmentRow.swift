//
//  ChatInputAttachmentRow.swift · Wenshu · v1.28 C3.4.2
//
//  v1.28 C3.4.2: split ChatInputAttachmentRow out of ChatView (= god-view
//  split step 2 = the CHATIMG-001 attachment-preview chip row that
//  sits above the HStack inside the chat input VStack).
//
//  Originally at ChatView.swift:1303-1313:
//      VStack(alignment: .leading, spacing: 4) {
//          if let imagePath = vm.attachedImagePath {
//              ChatAttachmentPreviewChip(imagePath: imagePath) {
//                  vm.clearAttachedImage()
//              }
//          }
//      HStack(alignment: .bottom, spacing: 8) {
//          // ... (the rest of the input row: paperclip + TextField + Send + Goal)
//      }
//
//  The extraction moves the `if let imagePath = vm.attachedImagePath { ChatAttachmentPreviewChip }`
//  block (= 9 LOC inside the VStack) into a standalone view. The HStack
//  (= paperclip + TextField + Send button + Goal button) stays in
//  ChatView.swift (= that block is large and tangled with many v0.61
//  boss OOB comments; = future C3.4.3 ticket will extract it into
//  ChatInputRow.swift).
//
//  Behavior preserved (= the chip shows only when `vm.attachedImagePath != nil`,
//  and the ✕ button calls `vm.clearAttachedImage()`).
//

import SwiftUI

struct ChatInputAttachmentRow: View {
    var vm: ChatViewModel

    var body: some View {
        if let imagePath = vm.attachedImagePath {
            ChatAttachmentPreviewChip(imagePath: imagePath) {
                vm.clearAttachedImage()
            }
        }
    }
}
