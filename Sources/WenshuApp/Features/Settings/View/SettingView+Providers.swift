//
//  SettingView+Providers.swift
//
//  The provider pane, the model pane and the SettingsOps plumbing they
//  call.
//
//  Why: the panes that talk to a provider and to the LLM are a cluster
//  of their own, and the view's file was over the file-size cap.
//
import SwiftUI
import WenshuAgent

extension SettingView {
    // MARK: - 提供方 pane

    var providersPane: some View {
        Form {
            Section {
                Toggle(isOn: $useKeychainForProviderKeys) {
                    Text("使用系统钥匙串保存 key")
                }
                .onChange(of: useKeychainForProviderKeys) { _, _ in
                    // Per boss 2026-10-16 OOB "如果用户在配好
                    // key 后关闭钥匙串功能, 应该立刻把 key
                    // 放在不走钥匙串的路径中": re-resolve
                    // the backend (= swap the read primary)
                    // AND actively migrate any keys that
                    // currently live only in the OTHER
                    // store (= the previous primary). The
                    // self-heal path on `loadKeySync`
                    // already covers this lazily, but the
                    // boss wants the migration to be
                    // visible at the moment the toggle
                    // flips (= the chat empty-state should
                    // not flash).
                    let previousBackend = ProviderKeychain.backend
                    ProviderKeychain.backend = ProviderKeychain.resolveBackend()
                    if let mirrored = ProviderKeychain.backend as? MirroredKeychainStore {
                        mirrored.migrateToCurrentPrimary()
                    } else if let mirrored = previousBackend as? MirroredKeychainStore {
                        // = the new backend is something
                        // other than MirroredKeychainStore
                        // (= e.g., a test override) but the
                        // old backend was Mirrored; = the
                        // keys are still in the old
                        // MirroredKeychainStore's inner
                        // stores, so run the migration on
                        // the old mirror to copy them to
                        // whatever the new primary is.
                        mirrored.migrateToCurrentPrimary()
                    }
                    // RATIONALE: re-fill the
                    // WenshuAgent.shared cached
                    // provider-with-keys snapshot so the
                    // chat input field re-enables
                    // immediately after the toggle flip
                    // (= the cache is otherwise
                    // populated only by the next
                    // `providersWithKeys()` await; = the
                    // migration above doesn't write to
                    // the cache; = without this re-await
                    // the chat input stays disabled).
                    Task { await WenshuAgent.shared.providersWithKeys() }
                    NotificationCenter.default.post(
                        name: .wenshuProviderKeychainChanged,
                        object: nil
                    )
                }
            } header: {
                Text("钥匙串")
            } footer: {
                Text("开启 = 存到 macOS 钥匙串; 关闭 = 存到本地文件.")
            }
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
                            .padding(.leading, 16)
                            .transition(.opacity)
                    }
                }
                .animation(.default, value: apiExpandedProviders)
                .animation(.default, value: globalSearchQuery)
            } header: {
                Text(String(localized: "settings.providers.section_header"))
            } footer: {
                let total = Provider.all.count
                let set = providersWithKeys.count
                Text(String.localizedStringWithFormat(NSLocalizedString("settings.provider.key_count_label", comment: ""),
                                                      String(set), String(total)))
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshProviderStatus() }
    }

    private var filteredProviders: [Provider] {
        // The previous per-pane `.searchable` toolbar field is gone; the sidebar-top
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // providers row list narrows as the user types.
        let trimmed = globalSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Provider.all }
        return Provider.all.filter { p in
            p.name.localizedCaseInsensitiveContains(trimmed) ||
                p.slug.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func toggleExpand(p: Provider) {
        let wasExpanded = apiExpandedProviders.contains(p.slug)
        apiExpandedProviders = SettingsOps.toggleExpansion(provider: p, in: apiExpandedProviders)
        if !wasExpanded {
            apiDraftKey = currentDraftPreview(for: p)
            apiError = nil
        }
    }

    private func currentDraftPreview(for provider: Provider) -> String {
        let hasKey = providersWithKeys.contains(provider.slug)
        guard hasKey else { return "" }
        // AUDIT.md §2.2 partial (2026-10-16): route through
        // WenshuAgent.shared (= the public facade; =
        // `loadKeyPreview(for:)` is the sync forwarder to
        // `ProviderKeychain.loadKeySync(for:)`; = the call
        // site is `var` (= non-async) and cannot `await`).
        // The same `var` cannot `await providersWithKeys()`;
        // = the `providersWithKeys` set above (= the
        // view's @State) is the local cache that the
        // WenshuAgent.shared hasProvidersWithKeysCached
        // // path also serves (= 2 caches, both refreshed
        // // on keychain change notification).
        let preview = WenshuAgent.shared.loadKeyPreview(for: provider)
        guard !preview.isEmpty else { return "" }
        let prefix = String(preview.prefix(8))
        return prefix + "********"
    }

    @ViewBuilder
    private func providerApiEditor(for p: Provider) -> some View {
        HStack {
            SecureField(String(localized: "settings.providers.key.placeholder"), text: $apiDraftKey)
                .textFieldStyle(.roundedBorder)
            Button(String(localized: "settings.provider.save_button")) {
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
        return HStack {
            SFIcon("key", style: .inlineSmall, color: hasKey ? IconColor.green : IconColor.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name)
                    .font(.body)
                // RATIONALE: distinguish the two MiniMax siblings
                // (= international `https://api.minimax.chat` and
                // china `https://api.minimaxi.com`). The name alone
                // (= "MiniMax" vs "MiniMax (China)") is not enough
                // for a user to tell which API the key goes to;
                // = they sit on different keychain slots and different
                // base URLs (= Hermes's `Cloud / Custom / Local`
                // 3-tab ModelConfigPage surfaces the same fact by
                // grouping). Surface the slug as the role hint so the
                // user reads which endpoint is which before typing a
                // key.
                if p.slug == "minimax" || p.slug == "minimax-cn" {
                    Text(minimaxRegionHint(for: p))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if hasKey {
                Text(keyPrefix12(for: p))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "settings.provider.tbd_label"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    /// Localized hint distinguishing the two MiniMax providers.
    /// Mirrors the canonical Apple-HIG URL-on-row pattern
    /// (= show the endpoint so the user types the right key into
    /// the right row).
    private func minimaxRegionHint(for provider: Provider) -> String {
        switch provider.slug {
        case "minimax":
            return "国际 · https://api.minimax.chat/anthropic"
        case "minimax-cn":
            return "中国 · https://api.minimaxi.com/anthropic"
        default:
            return ""
        }
    }

    private func keyPrefix12(for provider: Provider) -> String {
        SettingsOps.keyPrefix12(provider: provider, keychain: WenshuAgent.shared.keychainBackend())
    }

    private func saveApiKey(for provider: Provider) {
        let result = SettingsOps.saveApiKey(
            provider: provider,
            draft: apiDraftKey,
            keychain: WenshuAgent.shared.keychainBackend()
        )
        if result.shouldClearDraft {
            apiDraftKey = ""
        }
        if result.shouldCollapse {
            apiExpandedProviders.remove(provider.slug)
        }
        if result.shouldNotify {
            NotificationCenter.default.post(
                name: .wenshuProviderKeychainChanged,
                object: nil,
                userInfo: ["slug": provider.slug]
            )
        }
        if let err = result.error {
            apiError = err
        }
        if result.didSave {
            apiError = nil
            refreshProviderStatus()
        }
    }

    // MARK: - 模型 pane

    var modelsPane: some View {
        Form {
            Section {
                Picker(String(localized: "settings.model.provider_label"), selection: $providerSlug) {
                    ForEach(Provider.all) { p in
                        Text(p.name).tag(p.slug)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: providerSlug) { _, _ in
                    liveModelIds = []
                    customBaseURLDraft = savedCustomBaseURL(for: currentProvider.slug)
                    Task { await reloadModels() }
                }

                Picker(String(localized: "settings.model.model_label"), selection: llmModelBinding) {
                    ForEach(modelIdList, id: \.self) { id in
                        Text(id).tag(id)
                    }
                }
                .pickerStyle(.menu)

                TextField(
                    String(localized: "settings.model.custom_endpoint_label"),
                    text: $customBaseURLDraft
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(.URL)
                .onSubmit { saveCustomBaseURL() }
            } header: {
                Text(String(localized: "settings.model.main_model_label"))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "settings.model.main_model_caption"))
                    Text(String(localized: "settings.model.custom_endpoint_caption"))
                    Text(currentProvider.defaultBaseURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            // P0-3 fix (= Spec audit): wenshu.llm.reasoningEffort is still READ by
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // v0.21 ticket 35b).
            Section {
                Picker(String(localized: "settings.model.reasoning_effort_label"), selection: $reasoningEffort) {
                    Text(String(localized: "settings.model.reasoning_effort_low")).tag("low" as String)
                    Text(String(localized: "settings.model.reasoning_effort_medium")).tag("medium" as String)
                    Text(String(localized: "settings.model.reasoning_effort_high")).tag("high" as String)
                    Text(String(localized: "settings.model.reasoning_effort_xhigh")).tag("xhigh" as String)
                    Text(String(localized: "settings.model.reasoning_effort_max")).tag("max" as String)
                }
                .pickerStyle(.menu)
                Text(String(localized: "settings.model.reasoning.effortHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // `.lineLimit(nil)` (= drop SwiftUI's default `.caption` single-line
                    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                    // window widening past the intended size).
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text(String(localized: "settings.model.reasoning_label"))
            }
            Section {
                ForEach(AuxTask.allCases, id: \.self) { task in
                    HStack {
                        SFIcon(task.icon, style: .inlineSmall, color: IconColor.secondary)
                        Text(task.label)
                            .font(.body)
                        Spacer()
                        Text(String(localized: "settings.model.use_main_model"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(String(localized: "settings.model.assistant_model_label"))
            } footer: {
                Text(String(localized: "settings.assistant.caption"))
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            customBaseURLDraft = savedCustomBaseURL(for: currentProvider.slug)
            Task { await reloadModels() }
        }
    }

    private var modelIdList: [String] {
        liveModelIds.isEmpty ? currentProvider.defaultModels : liveModelIds
    }

    /// The custom endpoint the user saved for a provider, if any.
    private func savedCustomBaseURL(for slug: String) -> String {
        AgentSettingsStore.shared.load().providers.baseURLs[slug] ?? ""
    }

    /// Persist the custom endpoint and hand it to the package.
    ///
    /// An empty field clears the override (= the provider's own default
    /// applies again). A value that is not a usable URL is rejected and
    /// the stored override is left alone, so a typo cannot leave the
    /// provider pointing at nothing.
    private func saveCustomBaseURL() {
        let trimmed = customBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || Self.isUsableEndpoint(trimmed) else { return }
        var settings = AgentSettingsStore.shared.load()
        if trimmed.isEmpty {
            settings.providers.baseURLs.removeValue(forKey: currentProvider.slug)
        } else {
            settings.providers.baseURLs[currentProvider.slug] = trimmed
        }
        AgentSettingsStore.shared.save(settings)
        AgentSettingsStore.installProviderEndpoints()
    }

    /// Whether a typed endpoint can actually be called.
    private static func isUsableEndpoint(_ value: String) -> Bool {
        guard let url = URL(string: value), let host = url.host, !host.isEmpty else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    // MARK: - SettingsOps plumbing (= unchanged)

    func refreshProviderStatus() {
        providersWithKeys = SettingsOps.refreshProviderStatus(keychain: WenshuAgent.shared.keychainBackend())
    }

    func reloadModels() async {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }
        liveModelIds = await SettingsOps.reloadModels(
            provider: currentProvider,
            keychain: WenshuAgent.shared.keychainBackend(),
            fetcher: ProviderFetcherAdapter()
        )
    }
}

/// / macOS 27 SwiftUI `Settings { }` scene workaround:
/// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
/// / the recipe ships in the same shape Apple-internal sample code uses.
struct WindowResizableEnabler: NSViewRepresentable {
    private final class Helper: NSView {
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            guard let newWindow else { return }
            Task { @MainActor in
                newWindow.styleMask.insert(.resizable)
                ensureResizableAcrossHostingTree(of: newWindow)
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.styleMask.insert(.resizable)
            ensureResizableAcrossHostingTree(of: window)
        }
    }

    func makeNSView(context _: Context) -> NSView {
        Helper()
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        // `updateNSView` fires every time the SwiftUI hosting tree is reconciled (= every
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // modifier).
        if let hostWindow = nsView.window {
            hostWindow.styleMask.insert(.resizable)
            ensureResizableAcrossHostingTree(of: hostWindow)
        } else {
            // Fallback for the first-render race (= helper NSView exists but SwiftUI has
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // attach).
            Task { @MainActor in
                for appWindow in NSApp.windows {
                    appWindow.styleMask.insert(.resizable)
                }
            }
        }
    }
}

/// / macOS 27 Settings scene helper: walks every `NSWindow`
/// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
/// / is a no-op), so the recomputation cost is minimal.
@MainActor
private func ensureResizableAcrossHostingTree(of hostWindow: NSWindow) {
    // RATIONALE: Swift 6 can't always infer @MainActor across file + extension seams; =
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // all main-actor-isolated).
    for candidateWindow in NSApp.windows where candidateWindow === hostWindow {
        candidateWindow.styleMask.insert(.resizable)
    }
    // Defensive: also walk any Settings scene peer windows (= the macOS process may host
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // every NSWindow SwiftUI has spun up gets the `.resizable` bit). Idempotent.
    for candidateWindow in NSApp.windows {
        candidateWindow.styleMask.insert(.resizable)
    }
}
