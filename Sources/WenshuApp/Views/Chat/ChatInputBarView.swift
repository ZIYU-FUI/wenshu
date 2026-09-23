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
    VStack(alignment: .leading, spacing: 4) {
        if let imagePath = vm.attachedImagePath {
            // Attachment preview chip: small thumbnail + a
            // ✕ button to clear the draft. Sized to fit the
            // chat input row width (= bounded by outer
            // horizontal padding via the parent's
            // .padding(.horizontal, ...) below).
            ChatAttachmentPreviewChip(imagePath: imagePath) {
                vm.clearAttachedImage()
            }
        }
    // v1.70 boss 2026-09-18 "the 3 buttons don't sit on
    // the same row as the textfield, looks ugly" +
    // "default 2-3 lines height": split the chat input
    // into a 2-row layout (= Apple Messages / Slack
    // pattern; = TextField on its own row that auto-
    // grows from a 72 PT baseline up to 4 lines via
    // .lineLimit(1...4); = the 3 buttons attach / send
    // / goal on a fixed 30 PT bottom row below it
    // that stays put while the textfield expands).
    VStack(alignment: .leading, spacing: 6) {
        // TextField row (= the expanding editor surface;
        // = defaults to 72 PT = ~3 lines of 13 PT font
        // before the user types; = grows up to 4 lines
        // via .lineLimit(1...4); = Apple Messages /
        // Slack pattern).
        // v0.24 boss acceptance fix (2026-08-24): placeholder shows different text based on key state.
        // Boss 8/24 (out-of-band): 'please set up a large-model provider in Settings first'.
        // v0.25.1 (= ticket 030 chat send button Lucide icon + 8 PT textfield padding):
        // owner 2026-08-26 OOB 'chat zone chatbutton
        // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
        // send chat 8 PT ' =
        // 1) replace SF paperplane.fill (= Apple Send ICON) with
        //    Lucide .send (= paper plane icon, same visual
        //    metaphor as SF paperplane but Lucide outline style
        //    for consistency with the rest of the project per
        //    ticket 005+).
        // 2) add 8 PT horizontal padding to the textfield (= text
        //    has 8 PT of breathing room from the rounded border,
        //    = Apple HIG TextField default padding is 4 PT, owner
        //    wants 12 PT effective = 4 + 8).
        // 3) increase HStack(spacing: 8) to HStack(spacing: 16)
        //    per owner spec 'add 8 PT spacing above the chat text field' = add 8 PT
        //    additional gap between textfield and send button
        //    (= boss wants more visual breathing room between
        //    textfield and send button than current 8 PT).
        TextField(WenshuI18n.t("auto2.chatview.l858.h59940148"),
                  text: $vm.inputText, axis: .vertical)
            .lineLimit(1...4)
            // v1.71 boss 2026-09-18 'textfield needs to be 3 lines
            // tall by default'. Place .frame(minHeight: 64) AFTER
            // .lineLimit(1...4) so SwiftUI honors the minimum
            // (= the empty-state default height = 64 PT = ~2
            // lines of 13 PT font + padding = comfortable
            // multi-line default). The previous v1.71 first
            // attempt set .frame(minHeight: 96) (= ~3 lines)
            // but boss said it was 'a bit too tall' and asked
            // for 64 PT (= the canonical Apple Messages empty-
            // state chat input height per WWDC 2023). The
            // .lineLimit(1...4) range stays (= auto-grow
            // ceiling at 4 lines = 128 PT).
            .frame(minHeight: 64)
            // v0.40 boss 9/7 OOB ', shouldchat zonedialog
            // . hint, should /help ': the slash-
            // command hint (= "/create-book My new novel")
            // lives here as the .help() tooltip (= macOS
            // NSHelpManager on hover; = Apple HIG canonical
            // "explainer tooltip" pattern). Previously was a
            // top banner above the workspace (= visual noise,
            // = boss wants the chat zone to be the SOLE
            // input surface for slash commands; = hint
            // moved to non-intrusive tooltip here).
            .help(WenshuI18n.t("chat.input.help"))
            // v0.28 followup Boss UX round 27 (Boss 2026-08-29
            // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
            // .multilineTextAlignment(.leading) + the default
            // .leading-to-trailing text flow makes the text
            // top-aligned by default (= text sits at the top
            // of the 30 PT frame, not centered). To match the
            // Send button's centered visual position (= button
            // label is centered within the 30 PT capsule),
            // use no special alignment (= SwiftUI TextField
            // axis: .vertical centers content by default
            // within the .frame(minHeight: 72)  // v1.70 default 2-3 lines: 72 PT = ~3 lines of 13 PT font bounds).
            // v0.24 boss acceptance fix: disable when no key configured.
            .disabled(!hasUsableKey)
            .focused(inputFocused)
            .onSubmit { Task { await vm.routeInput() } }
            // T18-SLASH-AUTOCOMPLETE (2026-09-18): inline slash
            // command popup (= Hermes-style autocomplete). Appears
            // above the TextField when the user types `/`. Filter
            // rows = commands whose name starts with the typed
            // prefix (= case-insensitive). Tap a row -> fill
            // vm.inputText with `/commandName ` (= trailing space
            // = user can immediately type the remainder).
            //
            // The overlay uses .topLeading alignment (= sits
            // flush against the TextField top edge with 8 PT
            // inset = the standard autocomplete popup pattern).
            // The popup is bound to vm.inputText via the engine
            // (= re-evaluates on every keystroke).
            //
            // Hidden when no slash prefix OR no matching rows.
            // Apple HIG: no custom chrome; = uses .regularMaterial
            // + .quaternary border (= same as the chat input panel).
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
            // v1.54 chat-input-disabled-key-check: removed the
            // `.onChange(of: vm.currentModel)` blur/focus dance.
            // The old code toggled `inputFocused` based on
            // whether `wenshu.llm.model` had a value (= which
            // was the same broken signal as `hasUsableKey`
            // pre-fix; = a user who saved a key but had not
            // picked a specific model would lose focus on the
            // input even though the LLM was reachable). Now
            // `hasUsableKey` reads the keychain directly, so
            // model selection no longer drives input focus.
            // User focus is preserved across model picks.
            // v0.25.1 (= ticket 034 chat textfield 1 PT focus
            // ring): owner 2026-08-26 OOB 'when the text field is focused this
            // blue outline is too thick — change to 1PT and try' = SwiftUI
            // TextField .roundedBorder style has a default
            // focus ring ~2-3 PT thick. Boss wants the focus
            // ring thinned to 1 PT. Fix = override the default
            // .roundedBorder style with a custom rounded
            // border using .textFieldStyle(.plain) (= removes
            // system focus ring) + add a conditional
            // RoundedRectangle stroke (lineWidth: 1) on focus.
            // v0.25.1 (= ticket 035 chat textfield placeholder
            // color + position): owner 2026-08-26 OOB 'input
            // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
            // message... hint defaultyes
            // color ' = the placeholder text
            // 'inputmessage...' currently looks too bright (= high
            // contrast, = looks like real text) and is in
            // the wrong position (= too far left, no left
            // padding). Per Apple HIG (developer.apple.com/
            // design/human-interface-guidelines/color +
            // developer.apple.com/design/human-interface-
            // guidelines/components/selection-and-input/
            // text-fields), the placeholder text color
            // should be `placeholderTextColor` (= semantic
            // = .gray in SwiftUI = systemGray), and the
            // position should be left-aligned with 12 PT
            // horizontal padding (= Apple HIG text field
            // default). Fix = add .padding(.horizontal, DesignTokens.chromePaddingMedium)
            // to the TextField (= Apple HIG default 12 PT
            // horizontal padding), and add a subtle
            // Color.gray.opacity(0.1) background (= so the
            // textfield is visually a 'control' surface, not
            // a transparent overlay, = the placeholder text
            // naturally appears in the secondary color
            // without being too bright). The 1 PT focus
            // ring (ticket 034) + 8 PT outer top margin
            // (ticket 034 final 3) preserved.
            .textFieldStyle(.plain)
            // v0.28 followup Boss UX round 25 (Boss 2026-08-29
            // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
            // the textfield now has 2 height modes:
            //
            // 1. EMPTY STATE (= no text): .frame(minHeight: 72)  // v1.70 default 2-3 lines: 72 PT = ~3 lines of 13 PT font
            //    (= matches the Send button at 30 PT so the
            //    two controls look like the same height when
            //    there's no text — per Apple HIG canonical
            //    chat input row in Messages / Mail). Without
            //    this, the textfield's natural height (= ~22
            //    PT = font 13 PT + auto-padding) is visually
            //    shorter than the button (= 24 PT controlSize
            //    regular + 30 PT frame = 30 PT visual).
            //
            // 2. TYPING STATE (= text growing past 1 line):
            //    no max height pin so the textfield auto-
            //    grows from 30 PT (1 line) up to 4 lines via
            //    .lineLimit(1...4). The Send button stays
            //    bottom-anchored via HStack(alignment: .bottom).
            //
            // Why .frame(minHeight: 72)  // v1.70 default 2-3 lines: 72 PT = ~3 lines of 13 PT font and not .frame(height: LayoutTokens.chromeControlHeight):
            // - .frame(height: LayoutTokens.chromeControlHeight) PIN the textfield to 30 PT
            //   (= LayoutTokens value = 30 PT per v0.28 Apple HIG basis; DesignTokens canonical toolbarBandHeight = 32 PT is the newer canonical).
            //   regardless of content (= would block the auto-grow
            //   from round 25).
            // - .frame(minHeight: 72)  // v1.70 default 2-3 lines: 72 PT = ~3 lines of 13 PT font ONLY enforces a minimum
            //   (= textfield starts at 30 PT when empty, but
            //   can grow larger when content is multi-line).
            //
            // v0.28 followup Boss UX round 27 (Boss 2026-08-29
            // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
            // unified both empty-state heights at 30 PT
            // (= matches kZoneToolbarHeight = canonical chrome
            // height across the app).
            //
            // v0.25.1 (= ticket 037): was pinned to 24 PT per
            // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
            // boss OOB 'is the text field not 32 now, no matter what
            // change to match the text field height' = at the time, the textfield
            // visual was 24 PT (= 1 line) so boss wanted to
            // match the button height.
            // v1.64 boss 2026-09-20 'place current code in wenshu':
            // Apple Messages Liquid Glass chat input pattern.
            // 1. Drop the .padding(.horizontal, DesignTokens.chromePaddingMedium)
            //    (= was padding the textfield inside the panel
            //    chrome = the old panel-style chat input). Apple
            //    Messages renders the textfield as a self-contained
            //    capsule with internal padding = the .glassEffect
            //    capsule provides the visible boundary.
            // 2. Drop the .overlay RoundedRectangle focus ring (=
            //    Apple Messages has no focus ring = the glass
            //    capsule is the only chrome).
            // 3. Add .glassEffect(.regular.interactive(), in: Capsule())
            //    (= the Apple macOS 27 Liquid Glass capsule = blurs
            //    + refracts the content underneath = the canonical
            //    Apple Messages chrome).
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            // v1.64 Apple macOS 27 Liquid Glass: turns the
            // textfield into a real glass capsule that blurs
            // + refracts the chat history underneath. The
            // glass IS the visible boundary (= no border, no
            // focus ring). Function unchanged: textfield
            // auto-grow, placeholder, slash-command
            // autocomplete, disabled state — all preserved.
            .glassEffect(.regular.interactive(), in: Capsule())
        // v1.28 C3.4.7: extract leaked Send button modifiers (.buttonStyle
        // + .controlSize + .frame + .disabled + v0.28/v0.61 boss OOB comments)
        // from ChatView into ChatSendButton.swift (= the C3.4.4 commit
        // missed these modifiers, = they were still chained off the
        // ChatSendButton(vm: vm) call site; = per boss '做好清理' principle,
        // this amendment closes the gap).

        // Button row (= fixed 30 PT height; = 3 buttons
        // spread across the row width; = Attach on
        // the left, Send + Goal on the right; =
        // HStack(alignment: .center) so buttons stay
        // vertically centered regardless of the
        // textfield's current height).
// T0-PATH-VISIBLE (2026-09-18): new indicator button placed immediately
        // after ChatAttachButton (= per boss OOB '加按钮就在附件上传
        // 按钮后面先加'). HStack layout otherwise unchanged (= Spacer,
        // Send, Goal all stay in place).
        //
        // T3-MULTI-TURN-LOOP (2026-09-18): turn counter button
        // placed immediately after ChatAgentPathIndicator (= the
        // order matches worktree commit history: T0 -> T3).
        // HStack layout otherwise unchanged.
        HStack(alignment: .center, spacing: 8) {
            // v1.64f boss 2026-09-20 'apply the prototype to
            // wenshu directly': replace the v1.64 6-button
            // chat input HStack with the canonical Apple macOS 27
            // NSButton(bezelStyle: .glass) buttons via the new
            // GlassIconButton NSViewRepresentable (= the same
            // chrome Apple's NSToolbar uses for its toolbar items
            // per developer.apple.com/documentation/appkit/nsbutton/
            // bezelstyle-swift.enum/glass).
            //
            // Order per boss 2026-09-20 '3 buttons + textfield +
            // 2 buttons' (= the canonical Apple Messages chat
            // input layout). No Spacer (= buttons + textfield
            // pack flush into a single HStack row).
            //
            // SubAgentTag is rendered conditionally (= empty view
            // when no sub-agent is running = HStack spacing absorbs
            // it = no visible orphan gap).
            //
            // Stub action closures = real wiring lives in follow-
            // up tickets (= each button's original SwiftUI helper
            // file ChatAttachButton.swift / ChatSendButton.swift /
            // etc. will be migrated to wire to GlassIconButton
            // actions in v1.64f-ticket-3+).
            //
            // LEFT: 3 state indicators
            GlassIconButton(systemName: "paperclip", help: "附件") {
                // ChatAttachButton action (file picker)
                showingImageImporter = true
            }
            GlassIconButton(systemName: "sparkles", help: "Agent path") {
                // ChatAgentPathIndicator action
            }
            GlassIconButton(systemName: "arrow.triangle.2.circlepath", help: "Turn counter") {
                // ChatTurnProgress action (display-only)
            }
            // Sub-agent tag = conditional (hidden when no sub-agent)
            if vm.activeSubAgentName != nil {
                GlassIconButton(systemName: "person.crop.circle", help: vm.activeSubAgentName ?? "Sub-agent") {
                    // ChatSubAgentTag action
                }
            }

            Spacer(minLength: 8)

            // RIGHT: 2 action buttons
            GlassIconButton(systemName: "paperplane", help: "发送") {
                Task { await vm.routeInput() }
            }
            GlassIconButton(systemName: "scope", help: "目标 (⌘⇧G)") {
                Task { await vm.startLongRunningGoal() }
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        }
        .frame(minHeight: 30)
    }
    }   // CHATIMG-001 (2026-09-07): close inner VStack (preview chip + HStack)
    }
}
