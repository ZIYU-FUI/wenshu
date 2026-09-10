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
        // v0.40 boss 2026-09-08 OOB 'chat zonehinthint, editor
        // card zone': the chat empty state must use the SAME
        // EmptyStateHint pattern (= icon + title + body) as the
        // editor zone and the card zone. Previously was a multi-line
        // Text + Button link.
        //
        // v0.40 boss 2026-09-08 follow-up 'missing characters in the title': the title must
        // be the FULL sentence ' Settings in progressSettingsok'
        // (not just '). Per Apple HIG the inline 'Settings' text
        // inside the title is the clickable link (= the link is
        // inside the title sentence, not a separate Button below).
        //
        // Implementation: use HStack(spacing: 0) with 3 Text views
        // (= plain + clickable + plain). The middle 'Settings' is
        // wrapped in a Button with .plain style for tap = onSettingsTap.
        //
        // v0.40 boss 2026-09-08 follow-up 'ok,
        // ': the title → body spacing must match the editor
        // zone empty state (= EmptyStateHint's inner VStack spacing
        // = DesignTokens.chromePaddingSmall = 4 PT). The previous
        // implementation had a flat VStack(spacing: chromePaddingLarge)
        // between title and body (= 16 PT = too wide). Restructure
        // = outer VStack spacing chromePaddingLarge (icon → title
        // block) + inner VStack(spacing: chromePaddingSmall) for
        // title → body (= matches EmptyStateHint exactly).
        VStack(spacing: 0) {
            // v0.54: 38 PT + 22 PT gap, matching EmptyStateHint and the
            // measurement taken off Apple's own ContentUnavailableView.
            // This overlay is a hand-rolled twin of EmptyStateHint, so it
            // has to move with it or the chat panel keeps a toolbar-sized
            // icon while every other empty state grew.
            LucideIcon("message-square", size: 38)
                .foregroundStyle(.secondary)
                .padding(.bottom, 22)
            // Title block (= inner VStack with tight 4 PT spacing
            // between title + body = matches EmptyStateHint's inner
            // VStack(spacing: chromePaddingSmall) = Apple HIG canonical
            // title-body separation).
            VStack(spacing: DesignTokens.chromePaddingSmall) {
                // Title (= inline link pattern = Apple's Mail.app /
                // Notes.app convention for empty-state hints that
                // include a "settings" CTA inside the title sentence).
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
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                // Body (= Apple HIG .callout = 12 PT tertiary).
                Text(WenshuI18n.t("auto.chathelptextoverlay.l33.h88773098"))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: 360)
        }
    }
}