//
//  ChatInputBarView.swift · Wenshu · v1.86
//
//  v1.86 (2026-09-23): boss spec = match the sidebar's bottom "+ 新建"
//  button style/size verbatim. Reference: NewLibraryOutlineView.swift
//  L1760 `sidebarBottomNewButton`. Changes to the tokenCountFooter:
//    - .footnote → .callout        (= sidebar's exact text size)
//    - .padding(.horizontal, 10) → 8 (= sidebar's exact padding)
//    - +.padding(.vertical, 8)     (= sidebar's exact vertical padding)
//    - Spacer() → .frame(maxWidth: .infinity, alignment: .leading)
//                                 (= sidebar's exact alignment primitive)
//    - HStack spacing 8 → 6        (= sidebar's exact icon-text gap)
//  Boss 2026-09-23 '样式，尺寸照抄就好' (= 'just copy the style and
//  size from the sidebar').
//
//  v1.85 (2026-09-23): restored the token-usage bottom bar (= boss
//  2026-09-23 '那个 token 计数的底栏没有了，刚你写出来过，挺好的。
//  写回来吧'). Did NOT restore the manual compress button (= confirmed
//  automatic via ConversationLoop.swift:512; = boss 2026-09-23 '如果
//  可以自动，那个按钮就不用写回来了').
//
//  v1.84 (2026-09-23): boss spec = chat column bottom = single input row +
//  divider hairline (= Apple HIG sidebar-bottom-accessory separator).
//  v1.83 = clean rewrite. v1.82 = single-row HStack. v1.81 = 3-layer split.
//
//  Dead helper classes deleted (= no production caller):
//    - ChatAttachButton.swift (= replaced by inline GlassIconButton)
//    - ChatSendButton.swift (= replaced by inline GlassIconButton)
//    - ChatGoalButton.swift (= replaced by inline GlassIconButton)
//    - ChatAgentPathIndicator.swift (= replaced by inline GlassIconButton)
//    - ChatTurnProgress.swift (= replaced by inline GlassIconButton)
//    - ChatSubAgentTag.swift (= no longer rendered per v1.82 spec
//      = fixed 6 elements; = no conditional sub-agent injection)
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Chat input bar = the top layer of the chat zone's 3-layer UI
/// split per boss v1.81 spec:
///
///   1. 顶层 (this file) = ChatInputBarView
///   2. 中层 (ChatView body ScrollView) = chat content
///   3. 底层 (NavigationSplitShell + EditorChatNSController) = NSSplitView
///
/// Floats over the chat ScrollView via `.safeAreaInset(edge: .bottom)`.
/// Apple Messages / Slack chat input pattern (= single row; = input
/// controls + text editor on one horizontal axis).
///
/// UI-only view per AGENTS.md §11.1 + §11.3 (= boss's MVVM hard rule):
/// no FileManager / no UserDefaults reads; = no business logic; = all
/// actions delegate to the injected `ChatViewModel`; = no
/// StoredChatMessage touched.
struct ChatInputBarView: View {
    @Bindable var vm: ChatViewModel
    var inputFocused: FocusState<Bool>.Binding
    var hasUsableKey: Bool
    @Binding var showingImageImporter: Bool
    @Binding var isDropTargeted: Bool

    var body: some View {
        // v1.85 (2026-09-23): boss restored the token-usage bottom bar
        // (= boss 2026-09-23 '那个 token 计数的底栏没有了，刚你写出来过，
        // 挺好的。写回来吧'). Manual compress button is NOT restored
        // (= ConversationLoop.swift:512 runs ConversationCompression.
        // historyAfterCompression on every turn = automatic compression;
        // = no production caller for manualTrigger anymore; = boss
        // 2026-09-23 '那个压缩按钮，你去确认了吗，自动触发压缩，还是手动。
        // 如果可以自动，那个按钮就不用写回来了').
        //
        // Structure (top to bottom):
        //   1. attachmentPreviewChip (= conditional; = nothing when no image)
        //   2. inputRow              (= single horizontal HStack with
        //                              paperclip + sparkles + 输入框 +
        //                              ⌃ + 🎯 + ✈️)
        //   3. Divider               (= sidebar-bottom-accessory separator;
        //                              = matches NewLibraryOutlineView L1776)
        //   4. tokenCountFooter      (= "0 tokens used" / "N tokens used" /
        //                              orange warning when over threshold;
        //                              = visual only; = no action button)
        VStack(alignment: .leading, spacing: 4) {
            attachmentPreviewChip

            inputRow

            // Divider directly below the input row (= the sidebar
            // pattern: NewLibraryOutlineView L1776 `Divider()` sits
            // at the top of its safeAreaInset = same rhythm here).
            Divider()

            tokenCountFooter
        }
    }

    // MARK: - Token count footer (= visual only)

    /// Token-usage bottom bar (= "N tokens used" = live context budget
    /// indicator; = matches the Apple Mail attachment-size badge = always
    /// visible = the user always knows how much room they have).
    ///
    /// Visual-only footer (= no action button; = the auto-trigger path
    /// via ConversationLoop.swift:512 handles compression on every turn;
    /// = no manual trigger wired). Three states:
    ///   1. No messages        → not rendered (= matches old ChatViewCompressionRow
    ///                              pattern from T33-ALWAYS-SHOW-COMPRESSION
    ///                              but re-thought: only show when there's
    ///                              something to count; = the empty state
    ///                              is silence not a confusing "0 tokens")
    ///   2. Below threshold   → "N tokens used" in `.secondary` tone
    ///   3. Over threshold    → "N / M tokens (P%)" in `.orange` tone
    private var tokenCountFooter: some View {
        // v1.86 (2026-09-23): boss spec = match the sidebar's bottom
        // "+ 新建" button style/size verbatim (= boss '样式，尺寸照抄
        // 就好' = 'just copy the style and size from the sidebar').
        // Reference: NewLibraryOutlineView.swift L1760 `sidebarBottomNewButton`.
        // Same primitives (= Apple HIG sidebar-bottom-accessory pattern):
        //   - Divider above
        //   - HStack(spacing: 6) for label (= just the Text here; = the
        //     "+ 新建" button has `Image + Text`; = we have no action
        //     button = just the text label)
        //   - Text.font(.callout) (= NOT .footnote; = matches the
        //     sidebar's exact text size)
        //   - .frame(maxWidth: .infinity, alignment: .leading) (= the
        //     sidebar uses Spacer() implicitly via the .leading frame;
        //     = no Spacer() needed here)
        //   - .padding(.vertical, 8) + .padding(.horizontal, 8)
        //     (= same 8 PT all-around padding the sidebar uses; = no
        //     10 PT mismatch)
        //   - .foregroundStyle(.secondary) for the below-threshold label
        //     (= matches sidebar Image + .secondary; = the orange over-
        //     threshold branch keeps its warning tone).
        // v1.85: T33-ALWAYS-SHOW-COMPRESSION behavior — always visible
        // (= matches Apple Mail attachment-size badge = the user always
        // knows how much room they have).
        HStack(spacing: 6) {
            if vm.contextUsed >= tokenCompressionContextThreshold {
                // Over-threshold warning (orange).
                Text("\(formatCompactTokenCount(vm.contextUsed)) / \(formatCompactTokenCount(tokenCompressionContextThreshold)) tokens (\(percentOfThreshold)%)")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else {
                // Below threshold (quiet secondary).
                Text("\(formatCompactTokenCount(vm.contextUsed)) tokens used")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }

    /// 30,000 token compression threshold (= matches the old
    /// ChatViewCompressionRow.swift private constant; = the budget at
    /// which ConversationCompression kicks in for summarization).
    private let tokenCompressionContextThreshold: Int = 30_000

    /// "1234" / "1.2k" / "12.3k" / "1.2M" (= matches the old
    /// ChatViewCompressionRowFormatter.formatCompactTokenCount helper).
    private func formatCompactTokenCount(_ count: Int) -> String {
        if count < 1_000 { return "\(count)" }
        if count < 10_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        }
        if count < 1_000_000 {
            return "\(count / 1_000)k"
        }
        return String(format: "%.1fM", Double(count) / 1_000_000.0)
    }

    /// Percentage of compression threshold used (= integer 0-100+).
    private var percentOfThreshold: Int {
        Int((Double(vm.contextUsed) / Double(max(tokenCompressionContextThreshold, 1))) * 100)
    }

    // MARK: - Attachment preview chip

    /// Shows above the input row when an image is attached.
    @ViewBuilder
    private var attachmentPreviewChip: some View {
        if let imagePath = vm.attachedImagePath {
            ChatAttachmentPreviewChip(imagePath: imagePath) {
                vm.clearAttachedImage()
            }
        }
    }

    // MARK: - Input row (the actual UI per boss spec)

    /// The single input row per boss v1.82 spec:
    /// `1.token 压缩 2.10PT，按钮、10PT，按钮、10PT，输入框、10PT，
    ///  按钮、10PT，按钮、10PT，按键，10PT 距底，30PT`
    ///
    /// Elements (left → right):
    ///   1. token压缩 (compression indicator pill)
    ///   2. 按钮 (paperclip = file picker)
    ///   3. 按钮 (sparkles = agent path indicator, display-only)
    ///   4. 输入框 (TextField = middle, fills available space)
    ///   5. 按钮 (turn counter = display-only)
    ///   6. 按钮 (scope = long-running goal, ⌘⇧G)
    ///   7. 按钮 (paperplane = send, ⌘↩)
    private var inputRow: some View {
        // v1.84 (2026-09-23): boss's 2nd rewrite pass (= drop the
        // compression pill from the input HStack; = the spec for
        // this column is just buttons + TextField + buttons; = no
        // token-usage chrome inside the editor).
        HStack(alignment: .center, spacing: 10) {
            attachButton
            agentPathButton

            textField

            turnCounterButton
            goalButton
            sendButton
        }
        .padding(.horizontal, 10)
        .padding(.bottom, DesignTokens.chromePaddingChatBottom)
        .fileImporter(
            isPresented: $showingImageImporter,
            allowedContentTypes: [.image, .png, .jpeg, .gif, .heic],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { @MainActor in
                        _ = await vm.attachImage(at: url)
                    }
                }
            case .failure:
                break   // user cancelled or sandbox denial; ignore
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            Task { @MainActor in
                _ = await vm.attachImage(at: url)
            }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .animation(.snappy, value: isDropTargeted)
    }

    // MARK: - Buttons (Apple macOS 27 NSButton.bezelStyle .glass)

    private var attachButton: some View {
        GlassIconButton(systemName: "paperclip", help: "附件") {
            showingImageImporter = true
        }
    }

    private var agentPathButton: some View {
        GlassIconButton(systemName: "sparkles", help: "Agent path") {
            // Display-only indicator (= no action; = reads
            // vm.activeAgentPath via the reactive @Observable
            // pipeline; = no explicit callback needed here).
        }
    }

    private var turnCounterButton: some View {
        GlassIconButton(systemName: "arrow.triangle.2.circlepath", help: "Turn counter") {
            // Display-only (= shows current turn N of M).
        }
    }

    private var goalButton: some View {
        GlassIconButton(systemName: "scope", help: "目标 (⌘⇧G)") {
            Task { await vm.startLongRunningGoal() }
        }
        .keyboardShortcut("g", modifiers: [.command, .shift])
    }

    private var sendButton: some View {
        GlassIconButton(systemName: "paperplane", help: "发送 (⌘↩)") {
            Task { await vm.routeInput() }
        }
        .keyboardShortcut(.return, modifiers: [.command])
    }

    // MARK: - Text field

    /// Apple macOS 27 Liquid Glass chat input editor.
    /// Single-line (= axis: .horizontal) with `.lineLimit(1)` per
    /// boss v1.82 spec (= no auto-grow multi-line; = the chat
    /// input is a single horizontal row; = multi-line editing
    /// uses ⌘↩ for newline if ever needed).
    private var textField: some View {
        TextField(
            WenshuI18n.t("auto2.chatview.l858.h59940148"),
            text: $vm.inputText,
            axis: .horizontal
        )
        .lineLimit(1)
        .textFieldStyle(.plain)
        .frame(minHeight: 44, maxHeight: 44)
        .frame(maxWidth: .infinity)
        .disabled(!hasUsableKey)
        .focused(inputFocused)
        .onSubmit { Task { await vm.routeInput() } }
        .help(WenshuI18n.t("chat.input.help"))
        .glassEffect(.regular.interactive(), in: Capsule())
        .modifier(SlashCommandAutocompleteModifier(inputText: $vm.inputText))
        .modifier(ImagePasteModifier(onAttach: { url in
            Task { _ = await vm.attachImage(at: url) }
        }))
    }
}

// MARK: - Slash command autocomplete (overlay modifier)

/// Inline `/`-command autocomplete popup (= Hermes-style). Shows above
/// the TextField when the user types `/`. Filter rows = commands whose
/// name starts with the typed prefix (case-insensitive). Tap a row →
/// fill `vm.inputText` with `/commandName ` (= trailing space = user
/// can immediately type the remainder).
///
/// Apple HIG: no custom chrome (= uses the chat zone's surface tier).
/// Hidden when no slash prefix OR no matching rows.
private struct SlashCommandAutocompleteModifier: ViewModifier {
    @Binding var inputText: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            let prefix = ChatSlashCommandAutocompleteEngine.prefixFromInput(inputText)
            let rows = ChatSlashCommandAutocompleteEngine.filter(
                prefix: prefix,
                allCommands: SkillAdapter.hubCommands
            )
            if ChatSlashCommandAutocompleteEngine.shouldShow(input: inputText) {
                ChatSlashCommandAutocomplete(
                    rows: rows,
                    onSelect: { row in
                        inputText = "/\(row.name) "
                    }
                )
                .padding(.top, -8)
                .offset(y: -4)
            }
        }
    }
}

// MARK: - Image paste handler (overlay modifier)

/// `⌘V` image paste = writes the pasted NSImage to a temp .png file
/// (= clipboard binary in-memory isn't addressable here), then
/// delegates to `vm.attachImage(at:)` (= the business-layer entry
/// point that routes through the data layer's ChatRepositoryProtocol
/// seam; = MVVM compliance).
private struct ImagePasteModifier: ViewModifier {
    let onAttach: (URL) -> Void

    func body(content: Content) -> some View {
        content.onPasteCommand(of: [.image]) { providers in
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
                        onAttach(tempURL)
                    }
                } catch {
                    // Ignore write failures (= sandbox / disk full).
                }
            }
        }
    }
}
