//
//  ChapterFocusLockBadge.swift · wenshu · chapter-dialog 2026-09-28 T3
//
//  Visual badge surfaced in the editor when the LLM holds the
//  chapter cursor (= the focus-lock wrapper cleared
//  AppState.focusedChapterPath and is mid-edit). Apple HIG
//  canonical "editing" affordance: a small label + spinner
//  above the editor content (= same shape as Pages / Numbers'
//  'Saving...' badge next to the document title).
//
//  The badge is rendered by EditorView when
//  focusedChapterPath == currentTab.documentPath AND
//  !shellState.chatVisible (= the user is looking at the editor,
//  not the chat column). When the LLM's edit completes, the
//  wrapper restores the snapshot (= focusedChapterPath goes back
//  to its prior value, the badge disappears, and the editor
//  reloads with the LLM's changes).
//

import SwiftUI

/// chapter-dialog 2026-09-28 T3: small inline banner shown when
/// the LLM holds the chapter cursor. Pure rendering view (= no
/// business logic; = the host decides when to render it).
struct ChapterFocusLockBadge: View {
    var body: some View {
        HStack(spacing: DesignTokens.spacingIconic) {
            // Apple HIG spinner (= ProgressView infinite) signals
            // ongoing activity without stealing focus from the
            // editor's read-only text view.
            ProgressView()
                .controlSize(.small)
            SFIcon("pencil.and.outline", style: .inlineSmall, color: IconColor.tertiary)
            Text(WenshuI18n.t("chatview.focus_lock.badge"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.spacingTight)
        .padding(.vertical, DesignTokens.spacingIconic)
        .background(.quinary.opacity(0.4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WenshuI18n.t("chatview.focus_lock.badge"))
    }
}