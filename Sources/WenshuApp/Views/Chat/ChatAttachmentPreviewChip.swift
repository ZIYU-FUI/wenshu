import SwiftUI
import Lucide

/// CHATIMG-001 (2026-09-07): the small attachment preview chip that
/// sits above the chat input HStack when an image is pending
/// (= ChatViewModel.attachedImagePath is set). Renders a 48 PT
/// rounded thumbnail of the attached image + a ✕ button to clear
/// the draft. Sibling-by-design to ChatMessageView (= both render
/// chat attachment state but at different lifecycle points:
/// ChatAttachmentPreviewChip = draft state; ChatMessageView =
/// committed-message state).
///
/// Visual: Apple Messages / Slack attachment preview pattern. 48 PT
/// square thumbnail on the leading side, 8 PT gap, then a small
/// ✕ button (Lucide "x") that calls the `onClear` closure. The
/// whole chip is wrapped in `.regularMaterial` (= macOS 27 Liquid
/// Glass translucency) + a 1 PT separator border = matches the
/// TextField below for visual continuity (= Apple HIG canonical
/// "chat input row" container styling).
struct ChatAttachmentPreviewChip: View {
    let imagePath: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // 48 PT rounded thumbnail of the attached image. Uses
            // SwiftUI `Image` (= no Nuke; Nuke was retired by
            // DEAD-PIN-CLEANUP-001 per §13 v0.10 ship packet).
            // `Image(nsImage:)` initializer requires AppKit; on
            // macOS 27 the canonical Apple API is `Image(nsImage:)`
            // (= macOS-only).
            thumbnail
            Button {
                onClear()
            } label: {
                if let lucide = Lucide("x") {
                    lucide
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                } else {
                    LucideIconSystemFallback("xmark.circle.fill", size: 14)
                }
            }
            .buttonStyle(.borderless)
            .help(WenshuI18n.t("chat.input.attach.clear"))
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let nsImage = NSImage(contentsOfFile: imagePath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            // Fallback: empty 48 PT rounded rect (file missing or
            // unreadable). Still shows the clear button so the user
            // can dismiss.
            RoundedRectangle(cornerRadius: 6)
                .fill(.clear)
                .frame(width: 48, height: 48)
        }
    }
}
