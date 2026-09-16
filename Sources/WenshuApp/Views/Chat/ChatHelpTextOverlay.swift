//
// ChatHelpTextOverlay.swift · Wenshu · v0.24 bossverification
//
// Boss 2026-08-24: chatviewin progress (was: bottom-right).
//
//  Pattern: ZStack +
//

import SwiftUI

/// ChatHelpTextOverlay: (centered, large) shown when no API key configured.
/// Tapping 'Settings' jumps to Settings → API tab.
public struct ChatHelpTextOverlay: View {
    let onSettingsTap: () -> Void

    public var body: some View {
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'the chat zone's empty-state hint has no background,
        // add a same-sized overlay using Apple APIs — find the mask-related
        // APIs'. The previous ChatHelpTextOverlay rendered as a
        // pure-text hint (= icon + 2-line title + 1-line body)
        // without any background fill, so the underlying chat
        // messages (= 'Boss test message: persistence check' / 'Wenshu reply:
        // message received' / 'migration test: tokens column works' / 4
        // 'You there?' buttons) bled through the hint and made it hard to
        // read.
        //
        // Apple HIG pattern for an empty-state overlay inside a
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
        //    → solid color (Apple HIG recommended for empty state)
        // 3. .background(Color(NSColor.controlBackgroundColor))
        //    → control background color (good for inline views, not large areas)
        // 4. .containerBackground(.background, for: .window)
        //    → window-level (not suitable for per-zone overlay)
        //
        // Final pick: #2 `Color(NSColor.windowBackgroundColor)` in a
        // ZStack background layer (= solid fill matching the chat panel's
        // base color = fully occludes the messages below + visually consistent
        // with the Apple system chat panel = Apple HIG canonical empty-state pattern).
        //
        // Frame: `.frame(maxWidth: .infinity, maxHeight: .infinity)`
        // on the ZStack = overlay fills the entire chat zone (= same slot
        // as the chat messages) = the empty state is a fullscreen-
        // for-this-zone message, not a tiny floating bubble (=
        // Apple HIG canonical for empty states inside scrollable
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
            Color.clear  // zone background shows through (= Apple canonical: parent ZoneContentView provides background)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // v1.0.0-m1-shell boss 2026-09-12 OOB 'the current empty state isn't
                // a single component — can you abstract a UI component? While you're at it, on the
                // empty-state icon: double the size and use the thinnest strokes. The goal is to unify all
                // empty-state styles. The right column has 12 tabs and many are missing an empty state':
                // migrate to the unified EmptyStateView component
                // (= 76 PT Lucide icon + 1 PT stroke via
                // LucideThinIcon + standard title / body hierarchy).
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
                EmptyStateView(
                    icon: "message.fill",
                    titleView:
                        HStack(spacing: 0) {
                            Text(WenshuI18n.t("chathelp.please_first_goto") + " ")
                                .foregroundStyle(.secondary)
                            Button(action: onSettingsTap) {
                                Text(WenshuI18n.t("auto.chathelptextoverlay.l25.h61781343"))
                                    .foregroundStyle(Color.accentColor)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            Text(" " + WenshuI18n.t("auto.chathelptextoverlay.l30.h53427819"))
                                .foregroundStyle(.secondary)
                        }
                        .font(.headline)
                        .multilineTextAlignment(.center),
                    body: WenshuI18n.t("auto.chathelptextoverlay.l33.h88773098")
                )
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}