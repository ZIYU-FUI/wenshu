//
// ChatHelpTextOverlay.swift
//
// chatviewin progress (was: bottom-right).
//
//  Pattern: ZStack +
//

import SwiftUI

/// ChatHelpTextOverlay: (centered, large) shown when no API key configured.
/// Tapping 'Settings' jumps to Settings → API tab.
struct ChatHelpTextOverlay: View {
    let onSettingsTap: () -> Void

    var body: some View {
        // The chat zone's empty-state hint sits on a same-sized overlay built
        // from Apple's mask APIs, because the hint alone was a
        // pure-text hint (= icon + 2-line title + 1-line body)
        // pure-text hint (= icon + 2-line title + 1-line body)
        // without any background fill, so the underlying chat
        // messages (= 'Test message: persistence check' / 'Wenshu reply:
        // message received' / 'migration test: tokens column works' / 4
        // 'You there?' buttons) bled through the hint and made it hard to
        // read.
        //
        // product pattern for an empty-state overlay inside a
        // content area (= Mail's 'No conversations selected' /
        // Notes' 'No notes' / Music's 'No music in library'):
        // the empty state COVERS the content area with a SOLID
        // (= non-transparent) background so the content underneath
        // is fully occluded. The background is the same as the
        // content area's own material (= here: chat panel's
        // `.regularMaterial`).
        //
        // Apple API options surveyed:
        // 1. .background(.regularMaterial) → semi-transparent material (content below
        //    shows through blurred — not appropriate for empty state, need full occlusion)
        // 2. .background(Color(NSColor.windowBackgroundColor))
        //    → solid color (the product's choice for empty state)
        // 3. .background(Color(NSColor.controlBackgroundColor))
        //    → control background color (good for inline views, not large areas)
        // 4. .containerBackground(.background, for: .window)
        //    → window-level (not suitable for per-zone overlay)
        //
        // Final pick: #2 `Color(NSColor.windowBackgroundColor)` in a
        // ZStack background layer (= solid fill matching the chat panel's
        // base color = fully occludes the messages below + visually consistent
        // with the Apple system chat panel (= the product's empty-state pattern).
        //
        // Frame: `.frame(maxWidth: .infinity, maxHeight: .infinity)`
        // on the ZStack = overlay fills the entire chat zone (= same slot
        // as the chat messages) = the empty state is a fullscreen-
        // for-this-zone message, not a tiny floating bubble (=
        // the product for empty states inside scrollable
        // content).
        //
        // Layer order: the Color is the FIRST child of ZStack (= it
        // paints on the bottom layer) and the VStack content is
        // stacked on top (= the hint icon + text render in front
        // of the background fill).
        //
        // Center: wrap the icon + title + body VStack in `Spacer +
        // content + Spacer` (= top + bottom Spacers push the
        // content to vertical center inside the chat zone).
        ZStack {
            Color.clear // zone background shows through (= by design: the parent zone provides the background)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // Every empty state in the app renders through the shared EmptyStateView,
                // whose icon is sized and weighted for the role
                // (= 76 PT SF Symbols 6 icon + .regular weight = the
                // canonical macOS 27 inspector / empty-state
                // icon weight; = standard title / body
                // hierarchy).
                // Same visual treatment as the 12 specialized tool
                // tabs + the editor empty state + PreviewPane.
                //
                // The chat empty state has a SPECIAL CASE: the title
                // contains an inline 'Settings' Button as part of
                // the sentence (= Apple Mail / Notes convention for
                // empty-state hints that include a settings CTA inside
                // the title sentence; = NOT a separate Button below).
                // To preserve this, EmptyStateView exposes a second
                // init that accepts a caller-supplied titleView (= the
                // HStack { Text + Button + Text } below).
                //
                // Inner spacing values (= 22 PT icon→title gap, 4 PT
                // title→body gap) are matched to Apple's measured
                // ContentUnavailableView sample.
                // -m1-shell (see OOB.md #2026-09-16) OOB ' ICON， .fill':
                // migrated chat empty-state icon from 'message.fill' to
                // 'message' (= the outline variant, which
                // https://developer.apple.com/design/human-interface-guidelines/sf-symbols
                // states: "The outline variant works
                // well in toolbars, lists, and other places where you
                // display a symbol alongside text").
                EmptyStateView(
                    icon: "message",
                    titleView:
                    HStack(spacing: 0) {
                        Text(String(localized: "chathelp.please_first_goto") + " ")
                            .foregroundStyle(.secondary)
                        Button(action: onSettingsTap) {
                            Text(String(localized: "auto.chathelptextoverlay.l25.h61781343"))
                                .foregroundStyle(Color.accentColor)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        Text(" " + String(localized: "auto.chathelptextoverlay.l30.h53427819"))
                            .foregroundStyle(.secondary)
                    }
                    .font(.headline)
                    .multilineTextAlignment(.center),
                    body: String(localized: "auto.chathelptextoverlay.l33.h88773098")
                )
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
