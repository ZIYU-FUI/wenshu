//
//  ChatMessageAttachmentPreview.swift · Wenshu · refactor chat-mvvm-3layer C-8a
//
//  Apple MVVM canonical leaf view for the image attachment that
//  appears inside a chat message bubble (= the thumbnail chip
//  rendered above the text content when ChatMessage.imagePath is
//  non-nil). Lifted out of ChatMessageView (= previously a 948-line
//  God View) so:
//
//  - ChatMessageView body shrinks (= forwarders from C-2 + this
//    leaf removal shrink the file toward the 200-line target).
//  - The view itself is independently testable + previewable in
//    Xcode preview (= each leaf gets its own SwiftUI Preview).
//  - Future UI variants (= e.g. a video thumbnail, a PDF preview)
//    plug in by adding more leaves next to this one.
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离' (= Apple MVVM canonical):
//  This file is UI-only (= no @Observable classes, no business
//  logic, no FileManager calls). The image bytes are already on
//  disk (= ChatMessage.imagePath points to a file in
//  cache/chat-uploads/, written by LiveChatRepository.copyChatUpload
//  per C-6). The preview is a pure rendering concern.
//
//  Click behavior: NSWorkspace.shared.open(url) (= Reveal in Finder
//  semantics = opens the file with the user's default app). This is
//  Apple HIG canonical for "tap an attachment thumbnail" (= no need
//  to invent a custom viewer).
//
//  Failure mode: when the file is missing (= e.g. cache was cleared
//  after the chat was loaded), render the i18n string
//  "chat.message.imageMissing" instead of an empty box. The
//  ChatMessageView body used to do this inline (= now moved here
//  where the leaf owns it).
//

import SwiftUI

/// Leaf view that renders the image attachment chip inside a chat
/// message bubble. Tap = NSWorkspace.shared.open (= default app).
public struct ChatMessageAttachmentPreview: View {
    /// Absolute path to the image file (= from ChatMessage.imagePath).
    let imagePath: String

    public init(imagePath: String) {
        self.imagePath = imagePath
    }

    public var body: some View {
        // Try to load the image. When the file is gone (= cache
        // cleared after the chat was loaded), show the missing-image
        // placeholder instead.
        if let nsImage = NSImage(contentsOfFile: imagePath) {
            Button {
                let url = URL(fileURLWithPath: imagePath)
                // Apple HIG canonical attachment-open behavior:
                // NSWorkspace.shared.open = "Reveal in default app".
                // No custom viewer (= hermes真值 also uses
                // <a href={url} target="_blank">).
                NSWorkspace.shared.open(url)
            } label: {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.bottom, DesignTokens.chromePaddingMicro)
            }
            .buttonStyle(.plain)
        } else {
            Text(WenshuI18n.t("chat.message.imageMissing"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, DesignTokens.chromePaddingMicro)
        }
    }
}
