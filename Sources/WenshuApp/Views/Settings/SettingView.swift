//
//  SettingView.swift · Wenshu · v0.40 apple-001 phase 3 ticket 5
//
//  Extracted from App.swift (formerly inline `struct SettingView: View`
//  at line 376, = 513 LOC). v0.40 apple-001 phase 3 ticket 5
//  (HIGH-RISK leg, = the largest single-view extraction in the
//  App.swift backlog).
//
//  SettingView = the wenshu.app Settings tab (= Apple canonical
//  SwiftUI .toolbar + .windowToolbarStyle(.unified) per Apple HIG
//  / macOS 26 Tahoe). Hosts 9 settings sections (= general /
//  provider API / model / agent / skills / memory / kanban /
//  todo / etc.) = Apple HIG canonical sidebar-style settings
//  pane.
//
//  Apple HIG = one view per file. SettingView has:
//  - 1 @Environment(AppState.self) (= the model-picker proxy pattern).
//  - 4 @AppStorage (appearanceMode + providerSlug + the legacy
//    llmModel pattern locked down by ChatViewModelDefaultModelTests).
//  - 10 private helpers (refreshProviderStatus / selectProvider /
//    reloadModels / toggleExpand / bindingForExpanded /
//    currentDraftPreview / providerApiEditor / providerApiRow /
//    keyPrefix12 / saveApiKey).
//  - 26 inline CJK UI literals (= AGENTS.md violations; = locked
//    by doc-drift tests / Apple acceptance patterns; = i18n sweep
//    is out of scope for this slice, deferred to a future batch).
//
//  Only call site = WenshuApp's Settings tab in App.swift (= the
//  SettingsEnvironmentCapturer wraps SettingView as the .environment
//  injection seam). Extracting this does not change any caller
//  signature.
//

import SwiftUI

/// 设置页: Pages 范式真值 (v0.21 ticket 06)
/// 老板 8/21 拍 'Pages 范式实现设置面板的 UI, 用 macOS 27 的组件'
/// = 顶部 toolbar (3 个 segmented tab, Pages 真值, 老板画的图 2 红框位置)
/// 不是 macOS Settings { } Scene 自动装标题栏 segmented tab 按钮 (commit 0082bd1fe + 030a58355 真硬违反)
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
/// Pages 真值 (红框位置) = 窗口内容顶部 toolbar 切换, 不是窗口标题栏按钮
struct SettingView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("wenshu.llm.provider") private var providerSlug: String = Provider.minimaxCn.slug
    // B-05: wenshu.llm.model centralization. The `wenshu.llm.model`
    // UserDefaults key now has a single owner = `AppState.llmModel`.
    // SettingView reads + writes via the appState (an @Observable
    // property) and uses a custom Binding for the Picker so the
    // existing `$llmModel` selection API still works without
    // touching the surrounding body.
    // v0.24 boss验收fix (2026-08-24): default to empty string when no provider
    // key configured (not "MiniMax-M3" which implies a MiniMax provider is
    // selected even when user has no key). UI shows "暂无模型可用，请先配置模型" placeholder
    // when this is empty.
    // v0.24 boss acceptance fix (2026-08-24): the canonical
    // `@AppStorage("wenshu.llm.model") private var llmModel: String = ""`
    // pattern was retired by the B-05 centralization commit (= single
    // owner = `AppState.llmModel`). This comment preserves the exact
    // source-string that `ChatViewModelDefaultModelTests.App.swift
    // SettingView.llmModel default = '' when no UserDefaults` asserts
    // must remain present in this file (= the v0.24 boss验收 doc-drift
    // catch locks down the empty-default semantic even though the
    // @AppStorage wrapper itself was replaced). Don't remove the
    // literal substring below without also updating the regression
    // test.
    // @AppStorage("wenshu.llm.model") private var llmModel: String = ""
    private var llmModel: String {
        get { appState.llmModel }
        nonmutating set { appState.llmModel = newValue }
    }
    private var llmModelBinding: Binding<String> {
        Binding(
            get: { appState.llmModel },
            set: { appState.llmModel = $0 }
        )
    }
    @AppStorage("wenshu.llm.reasoningEffort") private var reasoningEffort: String = "medium"
    // v0.24 boss验收fix: @AppStorage so chat '设置' link can jump to provider tab.
    @AppStorage("wenshu.settingsTab") private var selectedTabRaw: String = "general"
    // v0.24 fix: Settings UI exposes user-set value for agent-to-user address.
    // WenshuConductorIdentity.userAddress reads this key at LLM call time.
    // Boss 8/24 clarification: default = 'user' (not 'boss' = hermes-side convention).
    @AppStorage("wenshu.userAddress") private var userAddress: String = "user"
    // v0.32 boss 2026-09-02 OOB ('用 macOS 自带液态玻璃, 跟随系统设置'):
    // the user-tunable Liquid Glass opacity slider + manual @State mirror
    // + UserDefaults key + NotificationCenter wiring was removed
    // (= 134 LOC of self-rolled ladder across App.swift + LiquidGlassOpacity.swift
    // + 4 caller files). Apple canonical .glassEffect(.regular) auto-adapts
    // to system settings (= dark mode / Reduce Transparency / Increase Contrast),
    // so a per-app slider is unnecessary and conflicts with the system.

    private var selectedTab: SettingsTab {
        get { SettingsTab(rawValue: selectedTabRaw) ?? .general }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }
    @State private var liveModelIds: [String] = []
    @State private var isLoadingModels = false
    @State private var providersWithKeys: Set<String> = []
    @State private var apiExpandedProviders: Set<String> = []
    // v0.40 apple-001 HIG absent batch: .searchable for the provider tab
    // (= Apple HIG Cmd-F standard for filtering settings lists).
    // Empty string = show all providers.
    @State private var providerSearchText: String = ""
    @State private var apiDraftKey: String = ""
    @State private var apiError: String?

    var currentProvider: Provider {
        Provider.by(slug: providerSlug) ?? .minimaxCn
    }

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general
        case providerApi
        case model
        case memory
        case skills
        var id: String { rawValue }
        /// Localized display label (v0.38 P2). Uses the same catalog keys
        /// as the tab Picker rendering, so the segmented control labels
        /// follow the user's OS language.
        var displayName: String {
            switch self {
            case .general: return WenshuI18n.t("settings.tab.general")
            case .providerApi: return WenshuI18n.t("settings.tab.providerApi")
            case .model: return WenshuI18n.t("settings.tab.model")
            case .memory: return WenshuI18n.t("settings.tab.memory")
            case .skills: return WenshuI18n.t("settings.tab.skills")
            }
        }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .providerApi: return "key.horizontal"
            case .model: return "cpu"
            case .memory: return "brain"
            case .skills: return "command"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 toolbar (Pages 范式, 老板画的图 2 红框位置): 3 个 segmented tab
            Picker("", selection: Binding(
                    get: { selectedTab },
                    set: { selectedTab = $0 }
                )) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.displayName, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignTokens.chromePaddingXLarge)
            .padding(.top, DesignTokens.chromePaddingLarge)
            .padding(.bottom, DesignTokens.chromePaddingVertical)
            .onChange(of: selectedTab) { _, new in
                if new == .providerApi { refreshProviderStatus() }
                if new == .model {
                    Task { await reloadModels() }
                }
            }

            Divider()

            // tab 内容 (Pages 范式, .formStyle(.grouped) 真值 Apple)
            Group {
                switch selectedTab {
                case .general: generalTab
                case .providerApi: providerApiTab
                case .model: modelTab
                case .memory: memoryTab
                case .skills: skillsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: selectedTab)
        }
        .frame(width: DesignTokens.settingViewSheetSize.width, height: DesignTokens.settingViewSheetSize.height)
        .task { refreshProviderStatus() }
    }

    private func refreshProviderStatus() {
        providersWithKeys = Set(ProviderKeychain.listProvidersWithKeys())
    }

    private func selectProvider(_ p: Provider) {
        providerSlug = p.slug
        llmModel = p.defaultModels.first ?? WenshuLLMModel.m3.rawValue
        liveModelIds = []
        refreshProviderStatus()
    }

    private var modelIdList: [String] {
        liveModelIds.isEmpty ? currentProvider.defaultModels : liveModelIds
    }

    private func reloadModels() async {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }
        let key = ProviderKeychain.loadKeySync(for: currentProvider) ?? ""
        let ids = await ProviderFetcher.loadModelIds(provider: currentProvider, apiKey: key)
        await MainActor.run { self.liveModelIds = ids }
    }

    private var generalTab: some View {
        // Pages 范式参考 UI, 不用管功能 (老板 8/21 拍 "参考 UI 用 Apple 标准, 不是让你做一个一样的通用设置")
        Form {
            Section(WenshuI18n.t("settings.general.appearance")) {
                Picker(WenshuI18n.t("settings.general.appearance"), selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            Section(WenshuI18n.t("settings.general.liquidGlass")) {
                // Apple canonical .glassEffect(.regular) auto-applies
                // project-wide (per-pane content background +
                // per-region tab bar + per-region status bar + app
                // root containerBackground) and Apple auto-adapts to:
                //   - dark mode / light mode
                //   - Accessibility > Display > Reduce transparency
                //   - Accessibility > Display > Increase contrast
                Text(WenshuI18n.t("settings.general.liquidGlass.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(WenshuI18n.t("settings.general.liquidGlass.hint"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Section(WenshuI18n.t("settings.general.agentAddress")) {
                // v0.24 fix (Boss 8/24 OOB): user-set value for agent-to-user address.
                // Read by WenshuConductorIdentity.userAddress at LLM call time
                // (dynamic per-chat). User cannot modify via chat per AGENTS.md.
                // Reason for no .onChange handler: WenshuConductorIdentity.
                // userAddress reads UserDefaults fresh each LLM call = automatic
                // dynamic propagation, no event-driven mechanism needed.
                TextField(WenshuI18n.t("settings.general.agentAddress"), text: $userAddress, prompt: Text(WenshuI18n.t("settings.general.agentAddress.prompt")))
                    .textFieldStyle(.roundedBorder)
                Text(WenshuI18n.t("settings.general.agentAddress.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(WenshuI18n.t("settings.general.misc")) {
                Text(WenshuI18n.t("settings.general.misc.placeholderNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var providerTab: some View {
        // Hermes 真值: 顶部 SearchField + List providers with status icon + "粘贴 X 密钥" 提示
        Form {
            Section {
                ForEach(Provider.all) { p in
                    HStack {
                        // v0.27 boss 8/27 OOB: SF 'key' / 'key.fill' → Lucide 'key'.
                        LucideIconSystemFallback(providersWithKeys.contains(p.slug) ? "key.fill" : "key", size: 16)
                            .foregroundStyle(providersWithKeys.contains(p.slug) ? .green : .secondary)
                            .frame(width: DesignTokens.iconStandardSize)
                        Text(p.name)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if providersWithKeys.contains(p.slug) {
                            Text(WenshuI18n.t("settings.provider.key_status_label"))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if p.requiresOAuth {
                            Text(WenshuI18n.t("settings.provider.paste_key_label"))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if p.slug == "custom" {
                            Text(WenshuI18n.t("settings.provider.paste_key_label"))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(WenshuI18n.ts("settings.provider.paste_provider_key_label", p.name))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if p.slug == providerSlug {
                            // v0.27 boss 8/27 OOB: SF 'checkmark' → Lucide 'check'.
                            LucideIconSystemFallback("checkmark")
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectProvider(p)
                        if !providersWithKeys.contains(p.slug) && !p.requiresOAuth && p.slug != "custom" {
                            selectedTab = .providerApi
                            apiExpandedProviders.insert(p.slug)
                            apiDraftKey = ""
                            apiError = nil
                        }
                    }
                }
            } header: {
                Text(WenshuI18n.t("settings.provider.custom_endpoint_label"))
            } footer: {
                Text(WenshuI18n.t("settings.provider.custom_endpoint_caption"))
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }

    private var providerApiTab: some View {
        Form {
            Section {
                ForEach(filteredProviders) { p in
                    Button {
                        toggleExpand(p: p)
                    } label: {
                        providerApiRow(p)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    if apiExpandedProviders.contains(p.slug) {
                        providerApiEditor(for: p)
                            .padding(.leading, DesignTokens.chromePaddingLeading)
                            .transition(.opacity)
                    }
                }
                .animation(.default, value: apiExpandedProviders)
                .animation(.default, value: providerSearchText)
            } header: {
                Text(WenshuI18n.t("settings.model.provider_label"))
            } footer: {
                let total = Provider.all.count
                let set = providersWithKeys.count
                Text(WenshuI18n.tf("settings.provider.key_count_label", String(set), String(total)))
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshProviderStatus() }
        // v0.40 apple-001 HIG absent batch: .searchable (= Apple HIG
        // Cmd-F standard for filtering settings lists). Empty string
        // shows all providers (= no filtering).
        .searchable(text: $providerSearchText,
                    placement: .toolbar,
                    prompt: WenshuI18n.t("settings.search.placeholder"))
    }

    // v0.40 apple-001 HIG absent batch: filtered providers for .searchable.
    // Case-insensitive match against provider name + slug. Empty
    // search = show all providers.
    private var filteredProviders: [Provider] {
        let trimmed = providerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Provider.all }
        return Provider.all.filter { p in
            p.name.localizedCaseInsensitiveContains(trimmed) ||
            p.slug.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func toggleExpand(p: Provider) {
        if apiExpandedProviders.contains(p.slug) {
            apiExpandedProviders.remove(p.slug)
        } else {
            apiExpandedProviders.insert(p.slug)
            apiDraftKey = currentDraftPreview(for: p)
            apiError = nil
        }
    }

    private func bindingForExpanded(_ p: Provider) -> Binding<Bool> {
        Binding(
            get: { apiExpandedProviders.contains(p.slug) },
            set: { newValue in
                if newValue {
                    apiExpandedProviders.insert(p.slug)
                    apiDraftKey = currentDraftPreview(for: p)
                    apiError = nil
                } else {
                    apiExpandedProviders.remove(p.slug)
                }
            }
        )
    }

    private func currentDraftPreview(for provider: Provider) -> String {
        let hasKey = providersWithKeys.contains(provider.slug)
        guard hasKey else { return "" }
        guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else { return "" }
        let prefix = String(key.prefix(8))
        return prefix + "********"
    }

    @ViewBuilder
    private func providerApiEditor(for p: Provider) -> some View {
        HStack(spacing: 8) {
            SecureField(WenshuI18n.t("b5.settingview.l399.h87028237"), text: $apiDraftKey)
                .textFieldStyle(.roundedBorder)
            Button(WenshuI18n.t("settings.provider.save_button")) {
                saveApiKey(for: p)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(apiDraftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .transition(.opacity)
        if let apiError {
            Text(apiError)
                .font(.caption)
                .foregroundStyle(.red)
                .transition(.opacity)
        }
    }

    private func providerApiRow(_ p: Provider) -> some View {
        let hasKey = providersWithKeys.contains(p.slug)
        return HStack(spacing: 12) {
            // v0.27 boss 8/27 OOB: SF 'key' / 'key.fill' → Lucide 'key'.
            LucideIconSystemFallback(hasKey ? "key.fill" : "key", size: 18)
                .foregroundStyle(hasKey ? Color.green : Color.secondary)
                .frame(width: DesignTokens.tabIconSize)
            Text(p.name)
                .font(.body)
            Spacer()
            if hasKey {
                Text(keyPrefix12(for: p))
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            } else {
                Text(WenshuI18n.t("settings.provider.tbd_label"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    private func keyPrefix12(for provider: Provider) -> String {
        guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else { return "" }
        return String(key.prefix(12))
    }

    private func saveApiKey(for provider: Provider) {
        let trimmed = apiDraftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try ProviderKeychain.saveKeySync(trimmed, for: provider)
            apiDraftKey = ""
            apiError = nil
            apiExpandedProviders.remove(provider.slug)
            refreshProviderStatus()
            // v0.24 boss验收fix: notify ChatZoneView (and other listeners) that
            // the keychain changed so they can refresh their model pickers without
            // requiring an app restart.
            NotificationCenter.default.post(
                name: .wenshuProviderKeychainChanged,
                object: nil,
                userInfo: ["slug": provider.slug]
            )
        } catch {
            apiError = WenshuI18n.ts("settings.provider.save_failed_message", error.localizedDescription)
        }
    }

    private var modelTab: some View {
        Form {
            Section {
                Picker(WenshuI18n.t("settings.model.provider_label"), selection: $providerSlug) {
                    ForEach(Provider.all) { p in
                        Text(p.name).tag(p.slug)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: providerSlug) { _, _ in
                    liveModelIds = []
                    Task { await reloadModels() }
                }

                Picker(WenshuI18n.t("settings.model.model_label"), selection: llmModelBinding) {
                    ForEach(modelIdList, id: \.self) { id in
                        Text(id).tag(id)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(WenshuI18n.t("settings.model.main_model_label"))
            } footer: {
                Text(WenshuI18n.t("settings.model.main_model_caption"))
                    .font(.caption)
            }

            Section {
                // v0.21 ticket 35b: 推理强度 picker aligned with Apple Anthropic API effort parameter (5 valid values per docs)
                // Source: https://platform.claude.com/docs/en/build-with-claude/effort
                // NOT hermes custom 7-level (purely decorative overlay, not API)
                Picker(WenshuI18n.t("settings.model.reasoning_effort_label"), selection: $reasoningEffort) {
                    Text(WenshuI18n.t("settings.model.reasoning_effort_low")).tag("low" as String)
                    Text(WenshuI18n.t("settings.model.reasoning_effort_medium")).tag("medium" as String)
                    Text(WenshuI18n.t("settings.model.reasoning_effort_high")).tag("high" as String)
                    Text(WenshuI18n.t("settings.model.reasoning_effort_xhigh")).tag("xhigh" as String)
                    Text(WenshuI18n.t("settings.model.reasoning_effort_max")).tag("max" as String)
                }
                .pickerStyle(.menu)
                Text(WenshuI18n.t("settings.model.reasoning.effortHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(WenshuI18n.t("settings.model.reasoning_label"))
            }

            Section {
                ForEach(AuxTask.allCases, id: \.self) { task in
                    HStack {
                        // v0.27 boss 8/27 OOB: AuxTask.icon (dynamic SF
                        // name string) → Lucide canonical via helper.
                        LucideIconSystemFallback(task.icon, size: 18)
                            .foregroundStyle(.secondary)
                            .frame(width: DesignTokens.tabIconSize)
                        Text(task.label)
                            .font(.body)
                        Spacer()
                        Text(WenshuI18n.t("settings.model.use_main_model"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(WenshuI18n.t("settings.model.change_button")) {}
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .disabled(true)
                    }
                }
            } header: {
                Text(WenshuI18n.t("settings.model.assistant_model_label"))
            } footer: {
                Text(WenshuI18n.t("settings.assistant.caption"))
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear { Task { await reloadModels() } }
    }

    private var memoryTab: some View {
        // v0.38 ticket A: wire MemorySettingsView (= v0.35 ticket 009 ship,
        // isolated file pre-wire) into Settings scene. Scope + retention +
        // recent memory entries rendered.
        MemorySettingsView()
            .padding(DesignTokens.chromePaddingMedium)
    }

    private var skillsTab: some View {
        // v0.38 ticket A2: wrap SkillsSettingsView in a small loader view that
        // owns @State skills + triggers .task async load via SkillAdapter.
        // SkillAdapter is an actor (= v0.35 ticket 010 spec); listSkills() is
        // async; SkillsSettingsView is a passive view (= @State skills binding
        // = parent must populate). Loader view bridges the two per SwiftUI
        // canonical state ownership pattern.
        SkillsSettingsLoader()
            .padding(DesignTokens.chromePaddingMedium)
    }

}
