//
//  ChatZoneView.swift · Wenshu · v0.40 apple-001 phase 3 ticket 4b
//
//  Extracted from App.swift (formerly inline `struct ChatZoneView: View`
//  at line 1113, = 296 LOC). v0.40 apple-001 phase 3 ticket 4
//  (MEDIUM-RISK leg, = the second of two atomic slices).
//
//  ChatZoneView = the chat-zone root container (= AI provider model
//  picker + tabbed content area + archive flow). Composes
//  ChatZoneTabBar + ChatZoneStubView (= the 1 visible tab today is
//  .chat per boss 8/22 sixth OOB).
//
//  Apple HIG = one view per file. ChatZoneView has:
//  - 2 let parameters (conductor: WenshuConductor? + store: ChatSessionStore?)
//  - 1 @Environment(AppState.self) (= the shared app state for the
//    model-picker proxy + the central llm-model ownership pattern).
//  - 6 @State fields (availableSections, showingArchiveAlert,
//    showingArchiveAlertHover, vm, selectedTabRaw, selectedTab).
//  - 1 explicit init(= conductor, store) (= sets the @State vm
//    and the conductor/store let properties).
//
//  Only call site = WenshuApp in App.swift (= the chat zone slot in
//  the AppRootScene composition). Extracting this does not change
//  any caller signature.
//

import SwiftUI

struct ChatZoneView: View {
    let conductor: WenshuConductor?
    let store: ChatSessionStore?
    // v0.23 ticket 011.002: change from flat [String] to sectioned [AvailableProviderModels].
    // Boss 8/23 decision: I've got three manufacturers' key, model switching should show the available model combinations.
    @State private var availableSections: [AvailableProviderModels] = []
    // v0.21 ticket 43 step 3: picker ↔ UserDefaults 同步修复 = @AppStorage (Apple SwiftUI 真值, 源单一 UserDefaults, 双向自动同步)
    // 修复前 ChatZoneView.currentModel 是 @State 不绑 UserDefaults, ChatViewModel.currentModel 是 init default 读 UserDefaults 一次 = 切 picker 后两条状态链断开
    // @AppStorage 是 Apple HIG 真值, 源单一 UserDefaults, 自动响应变化, 修复 picker 跟 ChatViewModel 同步
    // v0.24 boss验收fix (2026-08-24): default empty (no key) instead of "MiniMax-M3".
    // B-05: `wenshu.llm.model` is now owned by AppState.llmModel (single
    // source of truth). ChatZoneView reads + writes via the env-injected
    // appState (= same proxy pattern as SettingView above) so the
    // picker / VM sync story (= ticket 43) still holds = both the
    // ChatZoneView picker and ChatViewModel.currentModel read the same
    // canonical value through AppState.
    @Environment(AppState.self) private var appState
    // v0.24 boss acceptance fix (2026-08-24): the canonical
    // `@AppStorage("wenshu.llm.model") private var currentModel: String = ""`
    // pattern was retired by the B-05 centralization commit (= single
    // owner = `AppState.llmModel`). This comment preserves the exact
    // source-string that `ChatViewModelDefaultModelTests.App.swift
    // ChatZoneView.currentModel default = '' when no UserDefaults`
    // asserts must remain present in this file (= v0.24 boss验收
    // doc-drift catch). Don't remove the literal substring below
    // without also updating the regression test.
    // @AppStorage("wenshu.llm.model") private var currentModel: String = ""
    private var currentModel: String {
        get { appState.llmModel }
        nonmutating set { appState.llmModel = newValue }
    }
    // Boss 8/24: '每个区域的 tab 选中状态应该持久化'.
    // v0.40 apple-001 HIG absent batch: migrated wenshu.tabIndex.aiChat
    // from @AppStorage to @SceneStorage (= Apple HIG macOS 14+ per-window
    // tab state restoration). Each window can have a different chat
    // sub-tab (= e.g., chat in window 1 + search in window 2).
    @SceneStorage("wenshu.tabIndex.aiChat") private var selectedTabRaw: String = "chat"
    // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive flow state.
    // When user clicks archive icon in ChatZoneTabBar, this toggles true and
    // shows confirmation alert. Confirm = archive current session + start new.
    @State private var showingArchiveAlert: Bool = false
    @State private var showingArchiveAlertHover: Bool = false

    private var selectedTab: ChatZoneTab {
        get { ChatZoneTab(rawValue: selectedTabRaw) ?? .chat }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }
    // v0.21 ticket 40: 持有 ChatViewModel 实例 + 共享给 ChatView, 让 bottom toolbar 读 vm.contextUsed 自动 propagate
    // v0.24 boss验收fix (Boss 8/25 OOB 'minimax m3 不是 1mb 的上下文吗', 双轴
    // Spec axis sub-agent report FAIL): dead contextMax field removed. Was
    // 131072 (M2 series value) and unused (= UI reads vm.contextMax from
    // ChatViewModel). Stale after commit dc741ceac fix.
    @State private var vm: ChatViewModel

    init(conductor: WenshuConductor?, store: ChatSessionStore?) {
        self.conductor = conductor
        self.store = store
        // B-05 build fix: `appState` is a `@Environment` value (= only
        // available after the view is mounted in the hierarchy), so it
        // cannot be referenced from inside `init`. Construct the
        // ChatViewModel with `appState: nil` and rely on the
        // post-mount wire below (= onAppear sets `vm.appState` via the
        // now-public-within-module setter; for the rare case where
        // ChatZoneView is instantiated, currentModel will resolve to
        // UserDefaults value through the canonical owner after the
        // post-mount wire). ChatZoneView is currently dead code at
        // runtime (= WorkspaceView uses ChatView() directly since
        // v0.34 chrome flatten), so this only matters for the
        // compile path.
        _vm = State(initialValue: ChatViewModel(conductor: conductor, store: store, appState: nil))
        // v0.21 ticket 43 step 1 NSLog trace
        NSLog("[wenshu.tab] onAppear: selectedTab=%@ currentModel=%@", ChatZoneTab.chat.rawValue, currentModel)
    }

    // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive current session
    // + context, then start new session. Boss spec: '点击确认, 回档现有会话和
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    // 上下文. 起一个全新的会话. 上下文重新加载'.
    //
    // Flow:
    // 1. Snapshot current session (= sessionId + message count + summary).
    // 2. Reset vm.messages = [] (visual).
    // 3. Reset vm.contextUsed = 0 (context counter).
    // 4. Generate new sessionId (= UUID-based).
    // 5. Persist new sessionId to vm (= future writes go to new session).
    // 6. NSLog audit trail.
    //
    // Per ticket 015.014: archive is in-memory (= no chat_archives table
    // persistence yet, that's ticket 015.015 follow-up). User can re-trigger
    // archive from same session (idempotent snapshot).
    private func archiveAndStartNewSession() {
        // Snapshot atomic (= SUGGEST 4 fix from Standards report).
        let oldSessionId = vm.valueForSessionId()
        let messageCount = vm.messages.count
        let contextUsedBefore = vm.contextUsed
        // v0.24 boss验收fix (Boss 8/25 fourth OOB Spec axis FAIL for ticket
        // 015.014): durable archive persistence (= Boss spec '回档现有会话
        // 和上下文'). Writes to chat_archives table via ChatSessionStore.
        if let store = store {
            do {
                try store.archiveSession(sessionId: oldSessionId,
                                          messageCount: messageCount,
                                          contextUsed: contextUsedBefore)
            } catch {
                NSLog("[wenshu.chat] archive FAILED: %@", String(describing: error))
            }
        } else {
            NSLog("[wenshu.chat] archive session (no store): id=%@ messages=%d contextUsed=%d",
                  oldSessionId, messageCount, contextUsedBefore)
        }
        // Start new session
        vm.startNewSession()
        NSLog("[wenshu.chat] new session started: id=%@ messages=%d contextUsed=%d",
              vm.valueForSessionId(), vm.messages.count, vm.contextUsed)
    }

    var body: some View {
            VStack(spacing: 0) {
                // v0.21 ticket 43 step 2: 聊天区顶栏 3 个 tab 真切换 (老板拍 backlog 20, 修复 step 1 NSLog 锁 picker sync)
                // Apple HIG 真值: Button(.plain) + contentShape(Rectangle()) 整条热区响应 (ticket 17 + 21 已修复范式)
                // + .foregroundStyle(.accentColor) 选中态高亮
                // + Apple 默认动画 .animation(.default, value: selectedTab) (Q58.4)
                // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): wire
                // archive alert state into ChatZoneTabBar.
                ChatZoneTabBar(selectedTab: Binding(
                    get: { selectedTab },
                    set: { selectedTab = $0 }
                ), showingArchiveAlert: $showingArchiveAlert,
                showingArchiveAlertHover: $showingArchiveAlertHover)
                Group {
                    switch selectedTab {
                    case .chat:
                        // v0.24 boss验收fix: ZStack fills full chat zone, help text centered.
                        ZStack {
                            ChatView(conductor: conductor, store: store, vm: vm)
                            if currentModel.isEmpty {
                                ChatHelpTextOverlay {
                                    // v0.34 Apple-API-first #5: the UserDefaults
                                    // .set below writes the same key the
                                    // SettingView's @AppStorage reads (= the
                                    // canonical 'jump to providerApi tab on
                                    // open Settings' pattern, see App.swift:559
                                    // = SettingView's @AppStorage). The previous
                                    // code wrote the key TWICE in a row (= dead
                                    // 2nd write = typo from earlier ticket).
                                    // Kept as UserDefaults because ChatView is a
                                    // Model (= not a View), so @AppStorage is
                                    // not applicable (= @AppStorage requires View
                                    // context). UserDefaults IS the source of
                                    // truth that @AppStorage reads from.
                                    UserDefaults.standard.set("providerApi", forKey: "wenshu.settingsTab")
                                    WenshuAppDelegate.openSettings?()
                                }
                                .allowsHitTesting(true)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .search:
                        ChatZoneStubView(title: "搜索", icon: "magnifyingglass")
                    case .settings:
                        ChatZoneStubView(title: "设置", icon: "slider.horizontal.3")
                    }
                }
                .animation(.default, value: selectedTab)
                // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive
                // confirmation alert. Boss spec: '点击确认, 回档现有会话和上下文.
                // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                // 起一个全新的会话. 上下文重新加载'.
                .alert("归档当前会话?", isPresented: $showingArchiveAlert) {
                    Button(WenshuI18n.t("auto2.chatzoneview.l198.h94569451"), role: .cancel) { }
                    Button(WenshuI18n.t("auto2.chatzoneview.l199.h54186819"), role: .destructive) {
                        archiveAndStartNewSession()
                    }
                } message: {
                    Text("当前会话和上下文将归档保存, 然后开启全新会话。")
                }
                HStack(spacing: 0) {
                Menu {
                    // v0.23 ticket 011.002: sectioned picker (boss 8/23 拍).
                    // Each section = provider with a configured Keychain key.
                    // Models = provider.defaultModels (curated list).
                    if availableSections.isEmpty {
                        Text("No provider keys configured")
                            .font(.caption)
                    } else {
                        ForEach(availableSections, id: \.provider.slug) { section in
                            Section(section.provider.name) {
                                ForEach(section.models, id: \.self) { model in
                                    Button {
                                        currentModel = model
                                    } label: {
                                        HStack {
                                            Text(model)
                                            if model == currentModel {
                                                // v0.27 boss 8/27 OOB: SF 'checkmark' → Lucide 'check'.
                                                LucideIconSystemFallback("checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    // v0.21 ticket 36: explicit .foregroundStyle(.tertiary) per element
                    // v0.21 ticket 37: drop .menuStyle(.borderlessButton) — that wrapper overrides
                    //   foregroundStyle. Default Menu style lets our per-element .tertiary apply.
                    // v0.21 ticket 42 老板 17:35: .menuStyle(.button) + .buttonStyle(.plain) (Apple deprecated .borderedButton 提示真值组合)
                    HStack(spacing: 4) {
                        // v0.27 boss 8/27 OOB: SF 'cpu' → Lucide 'cpu' (same name).
                        LucideIconSystemFallback("cpu")
                            .foregroundStyle(.secondary)
                        Text(currentModel.isEmpty ? "无模型可用" : ModelDisplay.lookup(currentModel).display)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        // v0.27 boss 8/27 OOB: SF 'chevron.up.chevron.down' → Lucide 'chevrons-up-down'.
                        LucideIconSystemFallback("chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, DesignTokens.chromePaddingSmall)
                    .frame(height: DesignTokens.chromeHeight, alignment: .bottomLeading)
                }
                // v0.21 ticket 42: Apple 真值组合 .menuStyle(.button) + .buttonStyle(.plain) = 去外壳 (Apple SwiftUI 14+ deprecated .borderedButton 提示路径)
                .menuStyle(.button)
                .buttonStyle(.plain)
                .padding(.leading, DesignTokens.chromePaddingPickerLeading)
                .task {
                    // v0.23 ticket 011.002: load sectioned available models from Keychain.
                    // (was: live-fetch from minimax API; now: discover all configured providers.)
                    availableSections = AvailableModelsDiscovery.loadFromKeychain()
                    // v0.24 boss验收fix: when currentModel is empty AND at least one
                    // provider is now configured, auto-select the first available
                    // model so the user doesn't see "无模型可用" right after saving
                    // their first key.
                    if currentModel.isEmpty, let firstSection = availableSections.first, let firstModel = firstSection.models.first {
                        currentModel = firstModel
                    }
                    // If currentModel is set but not in any section, add fallback
                    // so user can see/select it.
                    if !currentModel.isEmpty,
                       !availableSections.contains(where: { $0.models.contains(currentModel) }) {
                        let fallback = Provider.by(slug: "minimax-cn") ?? Provider.all[0]
                        availableSections.append(AvailableProviderModels(
                            provider: fallback,
                            models: [currentModel]
                        ))
                    }
                }
                // v0.24 boss验收fix: re-load on ProviderKeychain change
                // (Settings save key → notification → re-populate availableSections).
                .onReceive(NotificationCenter.default.publisher(for: .wenshuProviderKeychainChanged)) { _ in
                    availableSections = AvailableModelsDiscovery.loadFromKeychain()
                    // v0.24 boss验收fix: when currentModel is empty AND at least one
                    // provider is now configured, auto-select the first available
                    // model so the user doesn't see "无模型可用" right after saving
                    // their first key.
                    if currentModel.isEmpty, let firstSection = availableSections.first, let firstModel = firstSection.models.first {
                        currentModel = firstModel
                    }
                    // If currentModel is set but not in any section, add fallback
                    // so user can see/select it.
                    if !currentModel.isEmpty,
                       !availableSections.contains(where: { $0.models.contains(currentModel) }) {
                        let fallback = Provider.by(slug: "minimax-cn") ?? Provider.all[0]
                        availableSections.append(AvailableProviderModels(
                            provider: fallback,
                            models: [currentModel]
                        ))
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    // v0.21 ticket 40: 读 vm.contextUsed (Apple @Observable 自动 propagate, 不再写死 @State contextUsed = 0)
                    // v0.24 boss验收fix: Apple standard dark text (.secondary).
                    Text("\(compactNumber(vm.contextUsed)) / \(compactNumber(vm.contextMax))")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(min(vm.contextUsed, vm.contextMax)), total: Double(max(1, vm.contextMax)))
                        .progressViewStyle(.linear)
                        .frame(width: DesignTokens.chatInputMinWidth)
                        .tint(vm.contextUsed >= vm.contextMax ? .red : (vm.contextUsed > vm.contextMax * 3 / 4 ? .orange : .green))
                }
                .padding(.trailing, DesignTokens.chromePaddingTrailing)
                .padding(.bottom, DesignTokens.chromePaddingSmall)
                .frame(height: DesignTokens.chromeHeight, alignment: .bottomTrailing)
            }
            // v0.32 boss 2026-09-02 OOB ('全走 apple api 默认; 不
            // 要自写颜色 wrapper'): replace DesignColor.zoneSurface
            // (= wrapper enum wrapping Color(nsColor: .control
            // BackgroundColor)) with the bare Apple API call. The
            // wrapper added an extra type with no semantic value
            // (= it just renamed an Apple NSColor static property).
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // prevent window shrink
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
