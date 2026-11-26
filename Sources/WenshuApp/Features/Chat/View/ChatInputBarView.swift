//
//  ChatInputBarView.swift
//
// (2026-09-23): the token-usage bottom bar needs a background —
//  `.background(.bar)` (= product sidebar/chrome material; =
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
// (= same style and size as the sidebar's).
//
// (2026-09-23): restored the token-usage bottom bar (the footer is
//  live in this view today).
//  Did NOT restore the manual compress button (= confirmed
//  automatic via ConversationLoop.swift:512).
//
// (2026-09-23): spec = chat column bottom = single input row +
//  divider hairline (= product sidebar-bottom-accessory separator).
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

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Chat input bar = the top layer of the chat zone's 3-layer UI
///
///   1.  (this file) = ChatInputBarView
///   2.  (ChatView body ScrollView) = chat content
///   3.  (NavigationSplitShell + EditorChatNSController) = NSSplitView
///
/// Floats over the chat ScrollView via `.safeAreaInset(edge: .bottom)`.
/// The row's shape is our product spec (= single row; = input controls + text
/// editor on one horizontal axis); = no vendor's layout is claimed for it.
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
    // FOCUS-RETENTION: focus stays in the input after a send. Apple HIG on
    // focus and selection says so (= Apple's own sentence is quoted below,
    // https://developer.apple.com/design/human-interface-guidelines/focus-and-selection);
    // the HIG publishes no page for a chat-input layout, so nothing about
    // this row's shape is attributed to it (= or to any vendor's app).
    // (= "Avoid changing focus without people’s interaction. People rely on the focus system
    // to help them know where they are in your app."). The TextField's
    // `.onSubmit` + the ⌘↩ carrier's `keyboardShortcut(.return)` both
    // drop focus when the send completes. We surface an `onSent` callback
    // (= a thin wrapper around `inputFocused = true`) so ChatView can
    // re-assert focus after each send path. Standing product rule: focus
    // moves only when the user moves it; = the
    // chat input bar is the only surface that auto-claims focus back.
    var onSent: (() -> Void)? = nil

    /// Internal helper: re-assert focus via the `onSent` callback if
    /// the caller provided one. Used by the TextField `.onSubmit` and
    /// the send button action.
    private func reassertFocus() {
        onSent?()
    }

    var body: some View {
        // The context meter lives under the input bar (= the bar stays
        // under the input field). The manual compress button is NOT
        // restored (= ConversationLoop.swift:512 runs
        // ConversationCompression.historyAfterCompression on every turn =
        // automatic compression; = no production caller for
        // manualTrigger, so the bar has no manual trigger of its own.
        //
        //
        // Structure (top to bottom):
        //   1. attachmentPreviewChip (= conditional; = nothing when no image)
        //   2. inputRow              (= single horizontal HStack with
        //                              paperclip + sparkles +  +
        //                              ⌃ + 🎯 + ✈️)
        //   3. Divider               (= sidebar-bottom-accessory separator;
        //                              = matches NewLibraryOutlineView L1776)
        //   4. tokenCountFooter      (= the context meter: a capacity gauge
        //                              beside the reading, and a click on
        //                              the gauge opens the breakdown
        //                              popover)
        //
        // Product error-surfacing rule (= only prompt the user; a
        // model-config error is answered by the toast, nothing more):
        // the previous errorBanner (= the
        // log-reveal affordance shipped with `0f48a3b6a`)
        // was removed (= the user can't act on it; = the
        // user just wants the friendly toast). Failed
        // sends still show the model-config-error toast (shipped UI copy)
        // (= via `vm.lastError` consumed by the chat
        // transcript), but the inline error banner is
        // gone (= no chrome that the user can't act on).
        VStack(alignment: .leading, spacing: 4) {
            attachmentPreviewChip
            inputRow
            tokenCountFooter
        }
    }

    // MARK: - Context meter (= the gauge + its breakdown)

    /// The context meter in the chat zone's bottom bar.
    ///
    /// It carries an Apple capacity gauge (= a level indicator whose fill
    /// stops at the value's place on the path, = the HIG's gauge fill rule:
    /// https://developer.apple.com/design/human-interface-guidelines/gauges)
    /// beside the number, and a click on the gauge opens the breakdown
    /// popover (= the prompt's parts). Clicking opens one popover at a time
    /// (= the HIG's rule:
    /// https://developer.apple.com/design/human-interface-guidelines/popovers).
    ///
    /// The number it shows is the provider's own count of the last
    /// request's prompt, measured against the window the agent
    /// compresses against (= the same number on both sides), so the fill
    /// means the same thing the compression does.
    private var tokenCountFooter: some View {
        // 2026-10-12: spec = match the sidebar's bottom
        // "+ " button style/size verbatim (= the 'style, size copy verbatim'
        // ' = 'just copy the style and size from the sidebar').
        // Reference: the sidebar's bottom "+ " button (= `sidebarBottomNewButton`).
        // Same primitives (= product sidebar-bottom-accessory pattern):
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
        // the compression behavior — always visible
        // (= the user always knows how much room they have; no vendor
        // badge attributed).
        // 2026-10-12: refactored to go through the shared
        // `ChromeBottomFooter` component (= the same shell
        // the editor status bar now uses; = single source of
        // truth for the sidebar-bottom-accessory chrome
        // surface shared with the editor status bar). The outer
        // VStack { Divider; HStack; .padding 8/8 } +
        // .background(.bar) is identical between the chat
        // footer and the editor status bar; the only per-call
        // variation is the inner HStack content (= single Text
        // for the chat footer, 3-chunk Inspector status row
        // for the editor).
        ChromeBottomFooter {
            ChatContextGaugeView(snapshot: vm.contextUsage)
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

    // MARK: - Input row (the actual UI per the spec)

    /// The single input row per the compact-chrome spec: token first, then
    /// even 10 PT gaps between every element of the row.
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
        // The row's own spec (= ours): even 10 PT gaps between every element,
        // 3-left + 2-right layout (= info/options left, action right).
        //
        // Layout (= 5 buttons + 1 fill text field; = all gaps 10 PT):
        //   [📎 attach] [✨ agentPath] [🔄 turnCounter] [TextField fill] [🎯 goal] [✈️ send]
        //    10  10  10  ...auto-fill...  10  10
        // Bottom-aligned chat input bar. 5 buttons + 1 fill text
        // field (= all gaps 10 PT):
        //   [📎 attach] [✨ agentPath] [🔄 turnCounter] [TextField fill] [🎯 goal] [✈️ send]
        //    10  10  10  ...auto-fill...  10  10
        // The HStack alignment is `.bottom` (= the buttons stay
        // visually anchored to the last baseline of the TextField
        // glyph regardless of how many lines the field has grown to).
        HStack(alignment: .bottom, spacing: 10) {
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
            case let .success(urls):
                if let url = urls.first {
                    Task { @MainActor in
                        _ = await vm.attachImage(at: url)
                    }
                }
            case .failure:
                break // user cancelled or sandbox denial; ignore
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
        // One layout leaf on purpose: the input row is an HStack with
        // spacing 10 (the row's own printed spec above, from the
        // 2026-09-23 ordering), and two sibling leaves here would buy
        // a 10 PT gap the spec does not have — the glyph branch and
        // the carrier are therefore contained in one ZStack, the
        // carrier being zero-sized and invisible inside it.
        ZStack {
            // Craft audit O4 (progress honesty + discoverability): the only
            // control that could stop an unbounded reply was the hidden ⌘.
            // carrier below; while a reply streams, this button becomes the
            // stop button visibly (= the standard macOS one-button shape:
            // its glyph follows the operation in flight). The KEY paths do
            // not follow the glyph: ⌘. lives once on the hidden carrier in
            // ChatView+KeyboardShortcuts, and ⌘↩ lives once on the hidden
            // carrier below, mounted unconditionally (= the base registered
            // ⌘↩ in every state, and a shortcut buried in one branch of the
            // glyph swap would leave ⌘↩ dead during a reply while bare
            // Return still sent).
            if isReplyStreaming {
                GlassIconButton(systemName: "stop.fill", help: "停止生成 (⌘.)") {
                    vm.cancelStreaming()
                }
            } else {
                GlassIconButton(systemName: "paperplane", help: "发送 (⌘↩)") {
                    sendNow()
                }
            }
            // The ⌘↩ carrier: state-independent, zero-sized, invisible —
            // the same hidden-Button shape as the ⌘. carrier.
            Button("Send shortcut carrier") {
                sendNow()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    /// The one send path shared by the visible paperplane click and the
    /// hidden ⌘↩ carrier (= one action, two doorways; the glyph swap
    /// during streaming must not fork the key path).
    private func sendNow() {
        Task {
            await vm.routeInput()
            // FOCUS-RETENTION: re-assert focus after the send
            // button is pressed (= the click moves keyboard focus
            // to the button; = the user expects the input to
            // reclaim focus so they can type the next message).
            reassertFocus()
        }
    }

    /// True while an assistant reply is in flight (= a message streams,
    /// or its placeholder has not received its first event yet).
    private var isReplyStreaming: Bool {
        vm.messages.contains { $0.streamState == .streaming || $0.isPlaceholder }
    }

    // MARK: - Text field

    /// Apple macOS 27 Liquid Glass chat input editor.
    /// Single-line (= axis: .horizontal) with `.lineLimit(1)` per
    /// input is a single horizontal row; = multi-line editing
    /// uses ⌘↩ for newline if ever needed).
    /// Auto-grow input field. The TextField starts at the product's stable
    /// chat-input height (= `DesignTokens.controlHeightLarge` = 36 PT; the
    /// old "same row height Apple Messages uses" equivalence was never
    /// measured and is dropped, audit C3) and grows
    /// vertically with content, up to a 5-line cap (= beyond that, the
    /// field scrolls internally; = the input bar does NOT push the
    /// chat transcript off-screen). Switch axis from `.horizontal` to
    /// `.vertical` so ⏎ inserts newlines (= multi-line typing) and
    /// lift the `.lineLimit(1)` constraint to a range, while
    /// preserving `.frame(minHeight:)` so the field stays anchored at
    /// the field's minimum height even when empty.
    private var textField: some View {
        TextField(
            String(localized: "chat.input.placeholder"),
            text: $vm.inputText,
            axis: .vertical
        )
        .lineLimit(1 ... 5)
        .textFieldStyle(.plain)
        // Our spec: the placeholder / typed text starts
        // chromePaddingContentHorizontal (= 10 PT) from the inner-left of the
        // capsule (= the same even 10 PT rhythm as the button gaps).
        .padding(.leading, DesignTokens.spacingModerate)
        .frame(minHeight: DesignTokens.controlHeightLarge)
        .frame(maxWidth: .infinity)
        .disabled(!hasUsableKey)
        .focused(inputFocused)
        .onSubmit {
            // The third doorway to the same action (bare Return; = the
            // one call keeps click, ⌘↩ and Return from fork-drifting).
            sendNow()
        }
        .help(String(localized: "chat.input.help"))
        // Shared chat-surface outline for this field only (= the
        // outgoing message band is not part of it; that band is
        // clipped to a rounded rectangle at the card radius). The
        // radius tracks half the height up to a cap, so a short
        // field reads as a capsule and a grown field stays a rounded
        // rectangle instead of an ellipse the glyphs spill out of.
        .glassEffect(.regular.interactive(), in: ChatSurfaceShape())
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
/// product: no custom chrome (= uses the chat zone's surface tier).
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
            _ = provider.loadObject(ofClass: NSImage.self) { item, _ in
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
