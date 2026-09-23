// ChatZoneView.swift · Wenshu · v1.91b
//
// v1.91b (2026-09-23): boss '聊天区的，文字回显层，是否可以变成左栏
// 的颜色参数。没有实现，是不是被限制了，是不是 NSV 框架里限制了，
// 你参数加的位置没有生效'. v1.91 added `.background(DesignTokens.
// sidebarBackground)` to ChatView's inner ScrollView; = that only
// paints the ScrollView's content area, NOT the visible chat column
// chrome around it (= the outer VStack + the NSSplitViewItem's AppKit
// container). Move the background to this outer VStack (= the view
// that actually fills the chat column's visible bounds). Same token,
// correct layer.
//
// Extracted from App.swift (formerly inline `struct ChatZoneView: View`)
// per Apple HIG = one view per file.
//
// ChatZoneView = the chat-zone root container (= AI provider model
// selector + ChatView + HelpTextOverlay).
//
// v1.0.0-m1-shell boss 2026-09-10 OOB 'drop the chat zone's top bar entirely, including the archive
// icon button and the tabs — basically the whole top bar. For the zone's internal padding, if the API
// provides one, let the API handle the defaults':
// the chat zone no longer hosts any top-bar chrome (= no
// ChatZoneTabBar, no 3-tab HStack, no archive ICON, no TEB). The
// body of the chat zone = bare ChatView (= the chat history +
// input field). Per Apple HIG TabViews docs 'if you only need
// to show ONE tab, don't show a tab bar at all'. All padding +
// inset inside the chat zone body = Apple API default (= no
// hand-rolled padding/spacing; = the SwiftUI List / NSSplitView
// system defaults decide).
//
// Architecture:
// - chat zone lives inside an `NSSplitViewItem` (= canCollapse
//   = true) in `EditorChatNSController` (= AppKit
//   NSSplitViewController; = the canonical Apple Keynote
//   speaker-notes API).
// - chat zone visibility is controlled by
//   `AppState.chatVisible` (= bound to the View > Show Chat
//   Zone menu item; ⌥⌘K).
// - the chat zone body hosts: ZStack { ChatView;
//   ChatHelpTextOverlay }.

import SwiftUI

struct ChatZoneView: View {
    let conductor: WenshuConductor?
    // Phase 5 ticket 10a: ChatSessionStore deleted. Chat persistence lives
    // in WSChatRepository.shared (= @MainActor SwiftData wrapper).

    @Environment(AppState.self) private var envAppState

    private var appState: AppState { envAppState }

    private var currentModel: String {
        get { appState.llmModel }
        nonmutating set { appState.llmModel = newValue }
    }

    @State private var vm: ChatViewModel

    init(conductor: WenshuConductor?) {
        self.conductor = conductor
        _vm = State(initialValue: ChatViewModel(conductor: conductor, appState: nil))
    }

    var body: some View {
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'chat zone doesn't fill the width':
        // apply `.frame(maxWidth: .infinity, maxHeight: .infinity)` to
        // the outer VStack so the chat zone fills the full width
        // and height of its NSSplitViewItem slot.
        VStack(spacing: 0) {
            ZStack {
                ChatView(conductor: conductor, vm: vm)
                // v1.68 boss 2026-09-18 'chat zone empty state still
                // shows after configuring key': switch the empty
                // state gate from `appState.llmModel.isEmpty` (=
                // checks the SELECTED MODEL ID, not whether a
                // key is configured) to `!ProviderKeychain.
                // listProvidersWithKeys().isEmpty` (= checks the
                // authoritative source of truth for 'is the LLM
                // configured?' = same call SettingView uses to
                // know whether the LLM Connector tab has anything
                // configured). With a key already in the keychain,
                // `listProvidersWithKeys().isEmpty` returns false,
                // so the ChatHelpTextOverlay is dismissed and
                // the chat zone becomes interactive.
                // Per the v1.53 (= 19fa2feb9) reverted commit
                // message (= the same bug was fixed once
                // before; = the revert was due to that v1.53
                // branch being part of the broader v1.55/v1.57
                // chat-input-row work that itself crashed =
                // unrelated to this empty-state gate logic):
                // the ProviderKeychain.listProvidersWithKeys() call
                // is in-memory after first read; = chat zone
                // re-renders are infrequent; = the cost is
                // negligible. Source of truth stays in one place
                // (SettingView + ChatZoneView + ChatView.hasUsableKey
                // = all three call ProviderKeychain.listProvidersWithKeys()).
                if !ProviderKeychain.listProvidersWithKeys().isEmpty {
                    EmptyView()
                } else {
                    ChatHelpTextOverlay {
                        // canonical 'jump to providerApi tab on open
                        // Settings' pattern: UserDefaults IS the source
                        // of truth that @AppStorage reads from.
                        UserDefaults.standard.set("providerApi", forKey: "wenshu.settingsTab")
                        WenshuAppDelegate.openSettings?()
                    }
                    .allowsHitTesting(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // v1.91b (2026-09-23): boss '聊天区的，文字回显层，是否可以变成
        // 左栏的颜色参数。没有实现，是不是被限制了，是不是 NSV 框架
        // 里限制了，你参数加的位置没有生效' (= v1.91 was set on
        // ChatView's ScrollView; = didn't work because the visible
        // chat column background is painted by ChatZoneView's outer
        // VStack + NSSplitViewItem's AppKit container; = ChatView's
        // ScrollView background only paints the scroll content area,
        // NOT the surrounding chat column chrome; = need the bg on
        // THIS outer VStack to actually repaint the visible chat
        // column). Now the entire chat zone fills with
        // DesignTokens.sidebarBackground (= same primitive sidebar
        // uses; = boss's spec satisfied).
        .background(DesignTokens.sidebarBackground)
        .environment(appState)
    }

    /// compactNumber: real token count folded into compact format (Hermes format_token_count_compact canonical).
    /// = 1500 -> "1.5k", 1500000 -> "1.5M", <1000 -> raw number.
    private func compactNumber(_ n: Int) -> String {
        let d = Double(n)
        if d >= 1_000_000 { return String(format: "%.1fM", d / 1_000_000).replacingOccurrences(of: ".0M", with: "M") }
        if d >= 1_000 { return String(format: "%.1fk", d / 1_000).replacingOccurrences(of: ".0k", with: "k") }
        return "\(n)"
    }
}
