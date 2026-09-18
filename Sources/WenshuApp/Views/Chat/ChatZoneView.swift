// ChatZoneView.swift · Wenshu · v0.40 apple-001 phase 3 ticket 4b
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

    @State private var vm: ChatViewModel

    /// v1.53 chat-empty-state-key-check: empty-state gate =
    /// "any provider has a saved key" (matches SettingView's
    /// `providersWithKeys` logic). Previously this read
    /// `appState.llmModel.isEmpty` — but `llmModel` is the selected
    /// model id, not the key-configured flag. Users who saved a key
    /// in Settings but hadn't yet picked a specific model (the
    /// common onboarding path) saw the empty-state overlay stuck on
    /// top of a fully functional chat zone. Source of truth now =
    /// `ProviderKeychain.listProvidersWithKeys()` — same call
    /// SettingView uses to know whether the LLM Connector tab has
    /// anything configured. Recomputed on every body re-evaluation;
    /// the keychain is fast (in-memory after first read) and the
    /// chat zone re-renders are infrequent.
    private var hasConfiguredProvider: Bool {
        !ProviderKeychain.listProvidersWithKeys().isEmpty
    }

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
                if !hasConfiguredProvider {
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
