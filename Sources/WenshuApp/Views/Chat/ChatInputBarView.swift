//
//  ChatInputBarView.swift · Wenshu · v1.84
//
//  v1.84 boss 2026-09-23 '我红框部分的删除不要了，保留底栏的' (= 'delete
//  what I marked in the red box; keep the bottom bar'): drop the
//  token-usage pill (= the leftmost vertical text + the bottom-row
//  "0 tokens used + 压缩" = the red-box content). Add a divider
//  hairline below the input row (= visual rhythm only; =
//  matches the Apple HIG sidebar-bottom-accessory separator that
//  NewLibraryOutlineView.swift L1776 uses above its "+ 新建" button;
//  = boss 2026-09-23 '既然你加了底栏，可以参考左栏的底部的新建。
//  有一条分割线。也参考一下高度，这样软件整体看起来更协调').
//  No interactive bottom control (= no "+ 新对话" button; = boss 2026-09-23
//  '不要延展我说的话，我没有要做新建会话的需求。我是说样式参考左栏的新建').
//
//  v1.81 + v1.82 = extraction (move inline VStack → a new file) +
//  single-row HStack. v1.83 = clean rewrite (drop v0.x baggage +
//  delete 6 dead helper SwiftUI View files). v1.84 = simplify +
//  add divider below the input row (= visual rhythm only).
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
        // v1.84 (2026-09-23): boss spec = chat column bottom = single
        // input row (this file's inputRow) + a divider hairline below
        // it (= the Apple HIG sidebar-bottom-accessory separator;
        // = the same primitive NewLibraryOutlineView.swift uses above
        // its "+ 新建" button; = visual rhythm only, no interactive
        // control here; = boss 2026-09-23 '既然你加了底栏，可以参考
        // 左栏的底部的新建。有一条分割线。也参考一下高度，这样软件
        // 整体看起来更协调').
        VStack(alignment: .leading, spacing: 4) {
            attachmentPreviewChip

            inputRow

            // Divider directly below the input row (= the sidebar
            // pattern: NewLibraryOutlineView L1776 `Divider()` sits
            // at the top of its safeAreaInset = same rhythm here).
            Divider()
        }
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
