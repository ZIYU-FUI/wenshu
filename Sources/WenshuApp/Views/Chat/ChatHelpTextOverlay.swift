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
        // v1.0.0-m1-shell boss 2026-09-10 OOB '聊天区的空态提示没有背景,
        // 加一个和聊天区同样大小的遮挡, 用 apple api, 找遮罩相关
        // 的 api'. The previous ChatHelpTextOverlay rendered as a
        // pure-text hint (= icon + 2-line title + 1-line body)
        // without any background fill, so the underlying chat
        // messages (= '老板测试消息: 持久化验证' / '文枢回复:
        // 收到消息' / 'migration test: tokens column works' / 4
        // '在?' buttons) bled through the hint and made it hard to
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
        // 1. .background(.regularMaterial) → 半透明 material（下方
        //    内容模糊可见；不适合空态，需要完全遮挡）
        // 2. .background(Color(NSColor.windowBackgroundColor))
        //    → 实色（Apple HIG 推荐 for empty state）
        // 3. .background(Color(NSColor.controlBackgroundColor))
        //    → 控件背景色（适合内嵌 view 不适合大区域）
        // 4. .containerBackground(.background, for: .window)
        //    → window 级（不适合 per-zone overlay）
        //
        // Final pick: #2 `Color(NSColor.windowBackgroundColor)` in a
        // ZStack background layer (= 实色填充 + 与 chat panel 底色
        // 一致 = 完全遮挡下方消息 + 与 Apple 系统 chat panel 视觉
        // 一致 = Apple HIG canonical empty-state pattern).
        //
        // Frame: `.frame(maxWidth: .infinity, maxHeight: .infinity)`
        // on the ZStack = overlay 撑满整个 chat zone (= same slot
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
            Color(NSColor.windowBackgroundColor)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // v0.54: 38 PT + 22 PT gap, matching EmptyStateHint and the
                // measurement taken off Apple's own ContentUnavailableView.
                // This overlay is a hand-rolled twin of EmptyStateHint, so it
                // has to move with it or the chat panel keeps a toolbar-sized
                // icon while every other empty state grew.
                //
                // v0.40 boss 2026-09-08 OOB 'chat zone hint, editor
                // card zone': the chat empty state must use the SAME
                // EmptyStateHint pattern (= icon + title + body) as
                // the editor zone and the card zone.
                //
                // v0.40 boss 2026-09-08 follow-up 'missing characters in the
                // title': the title must be the FULL sentence with the
                // inline 'Settings' link (= the link is inside the
                // title sentence, not a separate Button below).
                //
                // Implementation: HStack(spacing: 0) with 3 Text
                // views (= plain + clickable + plain). The middle
                // 'Settings' is wrapped in a Button with .plain
                // style for tap = onSettingsTap.
                //
                // v0.40 boss 2026-09-08 follow-up: the title → body
                // spacing must match the editor zone empty state (=
                // EmptyStateHint's inner VStack spacing =
                // DesignTokens.chromePaddingSmall = 4 PT). Restructure
                // = outer VStack spacing 0 (icon → title block) +
                // inner VStack(spacing: chromePaddingSmall) for
                // title → body (= matches EmptyStateHint exactly).
                VStack(spacing: 0) {
                    LucideIcon("message-square", size: 38)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 22)
                    // Title block (= inner VStack with tight 4 PT
                    // spacing between title + body = matches
                    // EmptyStateHint's inner VStack(spacing:
                    // chromePaddingSmall) = Apple HIG canonical
                    // title-body separation).
                    VStack(spacing: DesignTokens.chromePaddingSmall) {
                        // Title (= inline link pattern = Apple's
                        // Mail.app / Notes.app convention for
                        // empty-state hints that include a
                        // "settings" CTA inside the title sentence).
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
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}