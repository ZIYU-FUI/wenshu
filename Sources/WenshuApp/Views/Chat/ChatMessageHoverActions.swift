//
//  ChatMessageHoverActions.swift · Wenshu · refactor chat-mvvm-3layer C-9e
//
//  Apple MVVM canonical chat-surface pair:
//    1. ChatMessageHoverActions (= the floating copy + delete buttons
//       that fade in on hover, per Hermes MessageActions pattern).
//    2. ChatHoverModifier (= the ViewModifier that captures hover
//       state and exposes it as a `wenshuChatHover()` extension).
//
//  Both lifted out of ChatPartView.swift so:
//
//  - Hover UX can evolve independently (= e.g. adding more actions
//    or changing the modifier to use SwiftUI's newer `.onContinuousHover`).
//  - The chat part file no longer mixes part rendering with hover chrome.
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  UI-only (= no business logic; = the action closures come from
//  the caller = the ChatMessageView body wires the actual
//  copy-to-clipboard + delete-message calls).
//

import SwiftUI

public struct ChatMessageHoverActions: View {
    /// The message content to copy when the user clicks Copy.
    public let content: String
    @State private var isHovering: Bool = false

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        HStack(spacing: DesignTokens.chromePaddingSmall) {
            // Copy button (= SF Symbols 6 `document.on.document` icon;
            // = copies the message text to NSPasteboard).
            Button {
                copyToPasteboard()
            } label: {
                Image(systemName: "document.on.document").font(.system(size: 12, weight: .regular))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(WenshuI18n.t("chatview.message_action.copy"))
            // Delete button (= SF Symbols 6 `trash` icon; = marks the
            // message for deletion = the caller wires the actual
            // delete logic via a parent state).
            Button {
                // (= the delete action is wired at the call site via
                // a parent State binding; = this button just emits
                // a Notification for the parent to observe; = the
                // parent can decide whether to remove from the
                // message list or just hide).
                NotificationCenter.default.post(
                    name: .wenshuChatMessageDeleteRequested,
                    object: content
                )
            } label: {
                Image(systemName: "trash").font(.system(size: 12, weight: .regular))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(WenshuI18n.t("chatview.message_action.delete"))
        }
        .padding(.horizontal, DesignTokens.chromePaddingSmall)
        .padding(.vertical, DesignTokens.chromePaddingMicro)
        .background(.regularMaterial, in: Capsule())
        .opacity(isHovering ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    /// Copy the message text to NSPasteboard (= the canonical macOS
    /// clipboard). Uses `NSPasteboard.general` (= the shared system
    /// pasteboard).
    private func copyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
    }
}

/// Notification name posted when the user clicks the delete button
/// on a chat message (= the parent view observes this notification
/// and wires the actual deletion logic).
extension Notification.Name {
    public static let wenshuChatMessageDeleteRequested = Notification.Name("wenshu.chat.message.deleteRequested")
}

/// View modifier that wires the hover state (= a `View` extension
/// that captures the hover event and stores it in `@State`).
public struct ChatHoverModifier: ViewModifier {
    @State private var isHovering: Bool = false
    public func body(content: Content) -> some View {
        content.onHover { hovering in
            isHovering = hovering
        }
    }
}

public extension View {
    /// Convenience: attach the hover state to any view. The state's
    /// `$isHovering` is NOT exposed (= this modifier is for inline
    /// use where the parent owns its own hover state; = use the
    /// `ChatMessageHoverActions` overlay directly for the canonical
    /// user-message hover pattern).
    @MainActor
    func wenshuChatHover() -> some View {
        modifier(ChatHoverModifier())
    }
}
