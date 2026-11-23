//
//  ChatScrollToBottomButton.swift
//
//  The floating "back to the newest content" control.
//
//  WHY
//  ===
//  A writer scrolls up to re-read an earlier paragraph while the reply
//  is still arriving. The transcript then holds its place (the follow
//  is gated on the reader being at the bottom), so the reader is not
//  yanked away -- but the viewport is now parked in the middle of the
//  conversation with no way back except dragging the scrollbar.
//
//  The upstream reference (Hermes desktop) floats a pill
//  above the composer for exactly this state, and the pill carries the
//  number of messages below the viewport. This card builds the control
//  and its state; the count is deliberately NOT built here (= = the
//  viewport-to-row mapping it needs is a separate piece of work, and
//  the rule is that a control earns its place by what it does,
//  not by what it counts).
//
//  WHAT IT IS
//  =========
//  A capsule-shaped glass control, centered above the composer, that
//  appears only while the reader is away from the bottom. Its icon
//  comes from the app's own icon factory (= = SFIcon), its size from
//  the IconStyle ladder, and its color from the IconColor enum (= = the
//  app's own rules for icons).
//
//  While it is hidden it takes no room and takes no clicks: the
//  control is removed from the layout (not merely made transparent),
//  so it cannot swallow a click meant for the transcript.
//

import SwiftUI

/// The floating control that takes the reader back to the newest content.
///
/// The control is shown by its parent (the transcript's overlay) and
/// reports the click. It carries no state of its own: what "away from
/// the bottom" means belongs to the transcript, which is the only
/// thing that can measure it.
struct ChatScrollToBottomButton: View {
    /// What the control does when it is clicked.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingTight) {
                SFIcon("chevron.down", style: .inlineSmall, color: IconColor.secondary)
                Text(String(localized: "chat.scroll.toBottom"))
                    .font(.callout)
                    .foregroundStyle(IconColor.primary.style)
            }
            .padding(.horizontal, DesignTokens.spacingStandard)
            .padding(.vertical, DesignTokens.spacingTight)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .help(String(localized: "chat.scroll.toBottom.help"))
        .accessibilityLabel(String(localized: "chat.scroll.toBottom"))
    }
}
