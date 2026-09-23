//
//  ChatInputBarView.swift · Wenshu · v1.81
//
//  v1.81 boss 2026-09-23 '聊天区我认为就两层，加上 NSV 框架，也就是三层
//  顶层 = 按钮 对话框 按钮，的那一组和用户交互的控件。
//  中层 = 回显用户和 AI 的对话内容。
//  底层 = NSV 框架':
//
//  Refactor of the chat zone into Apple's canonical 3-layer pattern:
//    1. 顶层 (this file) = ChatInputBarView
//       (= buttons + textfield + attachment preview row + Apple
//       Liquid Glass chrome; = the user-interactive controls).
//    2. 中层 (ChatView body ScrollView) = chat content
//       (= user/AI message bubbles; = the lazy-rendered transcript).
//    3. 底层 (NavigationSplitShell + EditorChatNSController) =
//       the NSSplitView framework (= sidebar / content / chat /
//       inspector column layout; = the window chrome).
//
//  Previously (= v0.x through v1.80) ChatView body was a single
//  `VStack { ScrollView + inner_VStack { attachment + HStack {
//  buttons + TextField } } }` with the input row hard-coded inline
//  (= the input row was NESTED inside the same VStack as the
//  ScrollView; = 2 sibling layers at the SwiftUI body level; = not
//  the canonical 3-layer split). This file extracts the input row
//  into a dedicated top-level SwiftUI view that floats over the
//  ScrollView via `.safeAreaInset(edge: .bottom)` (per Apple HIG
//  chat input pattern = the input bar lives OUTSIDE the scroll
//  viewport; = the scroll content scrolls behind the fixed input bar).
//
//  MVVM compliance per AGENTS.md §11.1 + §11.3 (= boss's hard rule):
//  ChatInputBarView is UI-only (= no FileManager / no UserDefaults
//  reads; = no business logic; = all actions delegate to the
//  injected ChatViewModel; = no StoredChatMessage touched).
//

import SwiftUI

/// Chat input bar = the top-level user-interactive controls row
/// (= buttons + textfield + attachment preview). Floats over the chat
/// ScrollView via `.safeAreaInset(edge: .bottom)` (boss's v1.81
/// '3-layer' refactor: top layer = this view; middle layer = chat
/// content ScrollView; bottom layer = NSSplitView framework).
///
/// UI-only view; all actions delegate to the injected `ChatViewModel`.
struct ChatInputBarView: View {
    /// The chat view model (= business layer; = MVVM pattern).
    @Bindable var vm: ChatViewModel
    /// Focus state binding for the textfield (= propagated from
    /// ChatView so the global `inputFocused` state stays in one place;
    /// = the hidden keyboard-shortcut buttons in ChatView can still
    /// set `inputFocused = true` to focus the textfield).
    var inputFocused: FocusState<Bool>.Binding
    /// Whether a usable API key is configured (= gates the textfield
    /// `.disabled` state; = mirrors ChatView's `hasUsableKey`).
    var hasUsableKey: Bool
    /// File picker visibility (= propagated from ChatView; = tapping
    /// the paperclip button toggles this binding to show NSOpenPanel).
    @Binding var showingImageImporter: Bool

    var body: some View {
        // v1.82 boss 2026-09-23 '聊天区我认为就两层，加上 NSV 框架，也就是三层
        // 顶层 = 按钮 对话框 按钮，的那一组和用户交互的控件' +
        // boss 2026-09-22 '1.token 压缩 2.10PT，按钮、10PT，
        // 按钮、10PT，输入框、10PT，按钮、10PT，按钮、10PT，
        // 按键，10PT 距底，30PT':
        //
        // SINGLE-ROW HStack layout per boss spec:
        //   1. token压缩 (compression indicator pill)
        //   2. 10PT spacing
        //   3. 按钮 (paperclip = attach)
        //   4. 10PT spacing
        //   5. 按钮 (sparkles = agent path)
        //   6. 10PT spacing
        //   7. 输入框 (TextField = middle, fills available space)
        //   8. 10PT spacing
        //   9. 按钮 (arrow.triangle.2.circlepath = turn counter)
        //  10. 10PT spacing
        //  11. 按钮 (scope = goal)
        //  12. 10PT spacing
        //  13. 按钮 (paperplane = send)
        //  + 10PT horizontal padding on both sides
        //  + 30PT bottom margin (= chat input bar距 chat column 底).
        //
        // 改写 from pre-v1.82 2-row VStack (TextField on its own row +
        // buttons on a separate row below) to 1-row HStack per boss
        // spec (= Apple Messages input row + Apple macOS 27 standard
        // chat input pattern: textfield fills available horizontal
        // space; = buttons sit on both sides at fixed sizes; =
        // 10PT gaps between every element).
        //
        // MVVM compliance per AGENTS.md §11.1 + §11.3: ChatInputBarView
        // is UI-only; = all actions delegate to injected ChatViewModel.

        // Attachment preview chip = ABOVE the input row (= optional;
        // = shown when vm.attachedImagePath != nil). Per boss v1.81
        // 'attachment preview stays ABOVE the input row' (= the
        // Apple Messages / Slack pattern; = preview chip never
        // crowds the input controls).
        VStack(alignment: .leading, spacing: 4) {
            if let imagePath = vm.attachedImagePath {
                ChatAttachmentPreviewChip(imagePath: imagePath) {
                    vm.clearAttachedImage()
                }
            }
            // The main input row = SINGLE HStack per boss v1.82 spec.
            HStack(alignment: .center, spacing: 10) {
                // 1. token压缩 (= ChatViewCompressionRow; = context
                // budget indicator; = 上下文使用量 / 压缩状态 pill)
                ChatViewCompressionRow(vm: vm)

                // 2. 附件按钮 (= paperclip; = file picker; = NSOpenPanel)
                GlassIconButton(systemName: "paperclip", help: "附件") {
                    showingImageImporter = true
                }

                // 3. Agent 路径按钮 (= sparkles; = agent path indicator)
                GlassIconButton(systemName: "sparkles", help: "Agent path") {
                    // ChatAgentPathIndicator action
                }

                // 4. 输入框 (= TextField; = middle; = expands to fill
                // available horizontal space via .frame(maxWidth:
                // .infinity)). Apple macOS 27 Liquid Glass capsule
                // (= .glassEffect(.regular.interactive(), in:
                // Capsule()) per boss v1.75 spec).
                TextField(
                    WenshuI18n.t("auto2.chatview.l858.h59940148"),
                    text: $vm.inputText,
                    axis: .horizontal
                )
                .lineLimit(1)
                .frame(minHeight: 44, maxHeight: 44)
                .frame(maxWidth: .infinity)
                .textFieldStyle(.plain)
                .disabled(!hasUsableKey)
                .focused(inputFocused)
                .onSubmit { Task { await vm.routeInput() } }
                .help(WenshuI18n.t("chat.input.help"))
                .glassEffect(.regular.interactive(), in: Capsule())
                // Slash command autocomplete overlay (= inline popup
                // = appears ABOVE the TextField when user types '/').
                .overlay(alignment: .topLeading) {
                    let prefix = ChatSlashCommandAutocompleteEngine.prefixFromInput(vm.inputText)
                    let rows = ChatSlashCommandAutocompleteEngine.filter(
                        prefix: prefix,
                        allCommands: SkillAdapter.hubCommands
                    )
                    if ChatSlashCommandAutocompleteEngine.shouldShow(input: vm.inputText) {
                        ChatSlashCommandAutocomplete(
                            rows: rows,
                            onSelect: { row in
                                vm.inputText = "/\(row.name) "
                            }
                        )
                        .padding(.top, -8)
                        .offset(y: -4)
                    }
                }
                // Paste handler (= .onPasteCommand(of: [.image])).
                // = lives on the TextField (= not on the outer
                // wrapper; = the paste target IS the TextField).
                .onPasteCommand(of: [.image]) { providers in
                    guard let provider = providers.first else { return }
                    _ = provider.loadObject(ofClass: NSImage.self) { item, error in
                        guard let image = item as? NSImage,
                              let tiff = image.tiffRepresentation,
                              let bitmap = NSBitmapImageRep(data: tiff),
                              let pngData = bitmap.representation(using: .png, properties: [:])
                        else { return }
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("wenshu-paste-\(UUID().uuidString).png")
                        do {
                            try pngData.write(to: tempURL)
                            Task { @MainActor in
                                _ = await vm.attachImage(at: tempURL)
                            }
                        } catch {
                            // ignore write failures (= sandbox / disk full)
                        }
                    }
                }

                // 5. Turn counter button (= arrow.triangle.2.circlepath;
                // = display-only; = shows the current turn number)
                GlassIconButton(systemName: "arrow.triangle.2.circlepath", help: "Turn counter") {
                    // ChatTurnProgress action (display-only)
                }

                // 6. Goal button (= scope; = ⌘⇧G long-running goal)
                GlassIconButton(systemName: "scope", help: "目标 (⌘⇧G)") {
                    Task { await vm.startLongRunningGoal() }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                // 7. Send button (= paperplane; = onSubmit equivalent)
                GlassIconButton(systemName: "paperplane", help: "发送") {
                    Task { await vm.routeInput() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
            // 10PT horizontal padding on both sides per boss spec
            // (= the chat input bar's outer HStack padding).
            .padding(.horizontal, 10)
            // 30PT bottom margin per boss spec (= chat input bar距
            // chat column 底 30PT; = DesignTokens.chromePaddingChatBottom).
            .padding(.bottom, DesignTokens.chromePaddingChatBottom)
            // 顶部 = 0PT (= attachment preview chip already provides
            // the gap when present; = when no chip, the input bar sits
            // flush against the chat content above; = Apple Messages
            // pattern).
        }
        // Drop the outer floating panel chrome (= .glassEffect +
        // .overlay(stroke) + .shadow + 12PT padding x3). Pre-v1.82
        // wrapped the entire VStack in .glassEffect(.bar, in:
        // RoundedRectangle(cornerRadius: 14)) (= the 'floating panel'
        // chrome). Per boss v1.81 'the panel was the wrong layer; =
        // the panel IS the input bar itself; = no separate chrome
        // wrapper; = the chat column's NSSplitViewItem content tier
        // IS the panel background; = the Liquid Glass capsule on the
        // TextField is the only chrome).
    }
}
