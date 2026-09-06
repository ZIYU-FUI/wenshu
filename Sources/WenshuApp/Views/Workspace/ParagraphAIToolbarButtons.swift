//
//  ParagraphAIToolbarButtons.swift · Wenshu · v0.40 apple-001 Q2 slice 3
//
//  Extracted from WorkspaceView.swift (formerly inline private
//  struct at line 2097). Q2 boss拍 split WorkspaceView; after
//  slice 2 (= FormatToolbarButtons extracted) this slice pulls
//  the next self-contained view = the paragraph AI toolbar
//  (= 3 primary transform buttons + 1 dropdown Menu for 3 more).
//
//  Apple HIG = one view per file. ParagraphAIToolbarButtons
//  has 0 @State / 0 @Environment (= fully stateless = 3 let
//  parameters: selectedText, isApplying, onApply callback).
//  The EditorTransform enum (= the 6 transform cases) lives
//  in Sources/WenshuApp/Core/Agent/Specialized/EditorTools.swift
//  and is public, so this file just imports it.
//
//  Only call site = WorkspaceView's editor toolbar HStack, invoked
//  as `ParagraphAIToolbarButtons(selectedText:, isApplying:,
//  onApply: applyParagraphAI)`. Extracting this does not change
//  any caller signature.
//

import SwiftUI

struct ParagraphAIToolbarButtons: View {
    let selectedText: String
    let isApplying: Bool
    let onApply: (EditorTransform) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.chromePaddingMicro) {
            // Expand (= ⌘⇧E). SF Symbol:
            // `arrow.up.left.and.arrow.down.right` = Apple's
            // built-in expand icon (= "up-left arrow + down-right
            // arrow"; = visually says "make bigger"). Matches the
            // boss spec's exact `Image(systemName:)` line.
            Button {
                onApply(.expand)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(DesignTokens.hotkeyComboFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("paragraph.expand"))
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(selectedText.isEmpty || isApplying)

            // Shorten (= ⌘⇧H). SF Symbol:
            // `arrow.down.right.and.arrow.up.left` = Apple's
            // built-in condense icon (= "down-right arrow +
            // up-left arrow"; = visually says "make smaller").
            // Matches the boss spec's exact `Image(systemName:)`
            // line.
            Button {
                onApply(.shorten)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(DesignTokens.hotkeyComboFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("paragraph.shorten"))
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(selectedText.isEmpty || isApplying)

            // Rephrase (= ⌘⇧R). SF Symbol:
            // `arrow.triangle.2.circlepath` = Apple's built-in
            // refresh icon (= 2 triangles around a circle path; =
            // visually says "say it differently"). Matches the
            // boss spec's exact `Image(systemName:)` line.
            Button {
                onApply(.rephrase)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(DesignTokens.hotkeyComboFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("paragraph.rephrase"))
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(selectedText.isEmpty || isApplying)

            // Menu: shiftTone / simplify / dramatize (= no
            // shortcut per boss spec; = dropdown next to the 3
            // primary buttons). Uses Apple's native `Menu` (= the
            // SwiftUI macOS 13+ API; = no third-party menu lib
            // needed). Each item is a Button so it integrates with
            // the same `onApply` callback (= consistent code
            // path with the 3 primary buttons; = no special
            // menu-only branch in `applyParagraphAI`).
            Menu {
                Button("Shift tone") { onApply(.shiftTone) }
                    .disabled(selectedText.isEmpty || isApplying)
                Button("Simplify") { onApply(.simplify) }
                    .disabled(selectedText.isEmpty || isApplying)
                Button("Dramatize") { onApply(.dramatize) }
                    .disabled(selectedText.isEmpty || isApplying)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(DesignTokens.hotkeyComboFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignTokens.chromePaddingSmall)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help(WenshuI18n.t("workspace.transforms.moreHelp"))
            .disabled(selectedText.isEmpty || isApplying)
        }
    }
}
