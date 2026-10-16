//
//  ChatInputBarView.swift
//
// (2026-09-23): the token-usage bottom bar needs a background
//  ，，，'. Add
//  `.background(.bar)` (= Apple HIG sidebar/chrome material; =
//  translucent + Light/Dark auto-adapts; = same primitive the sidebar
//  inherits).
//
// (2026-09-23): divider co-located with tokenCountFooter (=
//  same VStack(spacing: 0) { Divider(); label } pattern as sidebar
//  L1760 `sidebarBottomNewButton`; = the divider sits higher than the bottom bar = the
//  divider used to sit directly below inputRow = visually disconnected
//  from the footer; = moved into the footer group).
//
// (2026-09-23): spec = match the sidebar's bottom "+ "
//  button style/size verbatim. Reference: NewLibraryOutlineView.swift
//  L1760 `sidebarBottomNewButton`. Changes to the tokenCountFooter:
//    - .footnote → .callout        (= sidebar's exact text size)
//    - .padding(.horizontal, 10) → 8 (= sidebar's exact padding)
//    - +.padding(.vertical, 8)     (= sidebar's exact vertical padding)
//    - Spacer() → .frame(maxWidth: .infinity, alignment: .leading)
//                                 (= sidebar's exact alignment primitive)
//    - HStack spacing 8 → 6        (= sidebar's exact icon-text gap)
// (= 'just copy the style and
//  size from the sidebar').
//
// (2026-09-23): restored the token-usage bottom bar (= the
//  2026-09-23 ' token ，，。
//  '). Did NOT restore the manual compress button (= confirmed
//  automatic via ConversationLoop.swift:512; = (see OOB.md #2026-09-23) '
//  ，').
//
// (2026-09-23): spec = chat column bottom = single input row +
//  divider hairline (= Apple HIG sidebar-bottom-accessory separator).
// = clean rewrite. v1.82 = single-row HStack. v1.81 = 3-layer split.
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
///
///   1.  (this file) = ChatInputBarView
///   2.  (ChatView body ScrollView) = chat content
///   3.  (NavigationSplitShell + EditorChatNSController) = NSSplitView
///
/// Floats over the chat ScrollView via `.safeAreaInset(edge: .bottom)`.
/// Apple Messages / Slack chat input pattern (= single row; = input
/// controls + text editor on one horizontal axis).
///
/// UI-only view per AGENTS.md §11.1 + §11.3 (= the MVVM hard rule):
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
        // 2026-09-23: restored the token-usage bottom bar
        // (= (see OOB.md #2026-09-23) ' token ，，
        // 。'). Manual compress button is NOT restored
        // (= ConversationLoop.swift:512 runs ConversationCompression.
        // historyAfterCompression on every turn = automatic compression;
        // = no production caller for manualTrigger anymore; = the
        // 2026-09-23 '，，，。
        // ，').
        //
        // Structure (top to bottom):
        //   1. attachmentPreviewChip (= conditional; = nothing when no image)
        //   2. errorBanner           (= conditional; = shown only when
        //                              `vm.lastError != nil` after a
        //                              failed send; = per boss
        //                              2026-10-16 OOB "开可以查看
        //                              详细的 LOG, 错在哪")
        //   3. inputRow              (= single horizontal HStack with
        //                              paperclip + sparkles +  +
        //                              ⌃ + 🎯 + ✈️)
        //   4. Divider               (= sidebar-bottom-accessory separator;
        //                              = matches NewLibraryOutlineView L1776)
        //   5. tokenCountFooter      (= "0 tokens used" / "N tokens used" /
        //                              orange warning when over threshold;
        //                              = visual only; = no action button)
        VStack(alignment: .leading, spacing: 4) {
            attachmentPreviewChip
            errorBanner
            inputRow
            tokenCountFooter
        }
    }

    // MARK: - Error banner (= 查看详细 LOG affordance)

    /// Per boss 2026-10-16 OOB "开可以查看详细的 LOG, 错
    /// 在哪": when the last send failed (= `vm.lastError` set),
    /// show a small banner above the input row with a
    /// "查看详细 LOG" button. The banner reads the
    /// `vm.lastRawErrorDescription` (= the technical detail
    /// like "Error Domain=SSEClient Code=400 HTTP 400") into
    /// a sheet where the user can copy the text to the
    /// clipboard (= for bug reports / provider escalation)
    /// OR open Console.app pre-filtered to the wenshu
    /// subsystem (= the dev surface for the same error).
    ///
    /// Only renders when `vm.lastError != nil` (= no
    /// visual cost in the success path). The banner
    /// dismisses itself when the user starts a new send
    /// (= `vm.clear()` resets both `lastError` and
    /// `lastRawErrorDescription`; = the new send's
    /// placeholder replaces the banner).
    @State private var showingLogSheet = false
    private var errorBanner: some View {
        Group {
            if let errMsg = vm.lastError {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(errMsg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button {
                        showingLogSheet = true
                    } label: {
                        Label("查看详细 LOG", systemImage: "doc.text.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                    .help("查看真实技术错误 (= 开发者日志)，可复制或打开 Console.app")
                }
                .padding(.horizontal, DesignTokens.spacingModerate)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
                .sheet(isPresented: $showingLogSheet) {
                    LogDetailSheet(
                        userMessage: errMsg,
                        rawErrorDescription: vm.lastRawErrorDescription
                    )
                }
            }
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
    ///   1. No messages        → not rendered (= only show when there's
    ///                              something to count; = the empty state
    ///                              is silence not a confusing "0 tokens")
    ///   2. Below threshold   → "N tokens used" in `.secondary` tone
    ///   3. Over threshold    → "N / M tokens (P%)" in `.orange` tone
    private var tokenCountFooter: some View {
        // 2026-10-12: spec = match the sidebar's bottom
        // "+ " button style/size verbatim (= the 'style, size copy verbatim'
        // ' = 'just copy the style and size from the sidebar').
        // Reference: NewLibraryOutlineView.swift L1760 `sidebarBottomNewButton`.
        // Same primitives (= Apple HIG sidebar-bottom-accessory pattern):
        //   - Divider above
        //   - HStack(spacing: DesignTokens.spacingTight) for label (= just the Text here; = the
        //     "+ " button has `Image + Text`; = we have no action
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
        // T33-ALWAYS-SHOW-COMPRESSION behavior — always visible
        // (= matches Apple Mail attachment-size badge = the user always
        // knows how much room they have).
        // 2026-10-12: refactored to go through the shared
        // `ChromeBottomFooter` component (= the same shell
        // the editor status bar now uses; = single source of
        // truth for the canonical Apple HIG
        // sidebar-bottom-accessory chrome surface). The outer
        // VStack { Divider; HStack; .padding 8/8 } +
        // .background(.bar) is identical between the chat
        // footer and the editor status bar; the only per-call
        // variation is the inner HStack content (= single Text
        // for the chat footer, 3-chunk Inspector status row
        // for the editor).
        ChromeBottomFooter {
            HStack(spacing: DesignTokens.spacingTight) {
                if vm.contextUsed >= tokenCompressionContextThreshold {
                    // Over-threshold warning (orange).
                    // (2026-09-23): localized.
                    // en: "%d / %d tokens (%d%%)" / zh-Hans: " %d / %d tokens（%d%%）".
                    Text(String.localizedStringWithFormat(NSLocalizedString("chat.input.tokens_used.over_threshold", comment: ""), vm.contextUsed,
                                       tokenCompressionContextThreshold,
                                       percentOfThreshold))
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else {
                    // Below threshold (quiet secondary).
                    // 2026-09-23: 'change the context-usage text to Chinese'.
                    // en: "%d tokens used" / zh-Hans: " %d tokens".
                    Text(String.localizedStringWithFormat(NSLocalizedString("chat.input.tokens_used", comment: ""), vm.contextUsed))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// 30,000 token compression threshold (= the budget at
    /// which ConversationCompression kicks in for summarization).
    private let tokenCompressionContextThreshold: Int = 30_000

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

    // MARK: - Input row (the actual UI per the spec)

    /// The single input row per the v1.82 spec:
    /// `1.token  2.10PT，、10PT，、10PT，、10PT，
    ///  、10PT，、10PT，，10PT ，30PT`
    ///
    /// Elements (left → right):
    ///   1. token (compression indicator pill)
    ///   2.  (paperclip = file picker)
    ///   3.  (sparkles = agent path indicator, display-only)
    ///   4.  (TextField = middle, fills available space)
    ///   5.  (turn counter = display-only)
    ///   6.  (scope = long-running goal, ⌘⇧G)
    ///   7.  (paperplane = send, ⌘↩)
    private var inputRow: some View {
        // 2026-09-23: '10PT | button | 10PT | button | 10PT | button | 10PT | chat box
        // （）｜10PT｜｜10PT｜｜10PT' OOB. Apple Messages
        // 3-left + 2-right layout (= info/options left, action right;
        // = the canonical chat input row spec).
        //
        // Layout (= 5 buttons + 1 fill text field; = all gaps 10 PT):
        //   [📎 attach] [✨ agentPath] [🔄 turnCounter] [TextField fill] [🎯 goal] [✈️ send]
        //    10  10  10  ...auto-fill...  10  10
        HStack(alignment: .center, spacing: 10) {
            attachButton
            agentPathButton
            turnCounterButton

            textField
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            goalButton
            sendButton
        }
        .padding(.horizontal, DesignTokens.spacingModerate)
        .padding(.bottom, DesignTokens.spacingModerate)
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
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusCard)
                    .strokeBorder(Color.accentColor, lineWidth: DesignTokens.separatorThicknessEmphasis)
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
            // (2026-09-23): display-only indicator (= no action).
            // Code-review finding #14 flagged a stale comment that
            // referenced a non-existent `vm.activeAgentPath` property
            // (= no such field on ChatViewModel). Replace with the
            // honest statement (= the button is decorative; = no
            // current reactive value to bind).
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
    /// input is a single horizontal row; = multi-line editing
    /// uses ⌘↩ for newline if ever needed).
    private var textField: some View {
        TextField(
            String(localized: "chat.input.placeholder"),
            text: $vm.inputText,
            axis: .horizontal
        )
        .lineLimit(1)
        .textFieldStyle(.plain)
        // 2026-09-23: 'input message... needs 10PT left padding from the chat box'.
        // Apple Messages chat input pattern: the placeholder /
        // typed text starts chromePaddingContentHorizontal (= 10 PT)
        // from the inner-left of the capsule (= the SF Symbol icons
        // in macOS Messages chat input are followed by the same
        // padding to the text).
        .padding(.leading, DesignTokens.spacingModerate)
        .frame(minHeight: DesignTokens.controlHeightLarge, maxHeight: DesignTokens.controlHeightLarge)
        .frame(maxWidth: .infinity)
        .disabled(!hasUsableKey)
        .focused(inputFocused)
        .onSubmit { Task { await vm.routeInput() } }
        .help(String(localized: "chat.input.help"))
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
                allCommands: ChatHubCommands.all
            )
            if ChatSlashCommandAutocompleteEngine.shouldShow(input: inputText) {
                ChatSlashCommandAutocomplete(
                    rows: rows,
                    onSelect: { row in
                        inputText = "/\(row.name) "
                    }
                )
                .padding(.top, -DesignTokens.spacingStandard)
                .offset(y: -DesignTokens.spacingIconic)
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
