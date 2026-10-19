// SettingView.swift · WenshuApp Settings scene (= Apple canonical macOS 14+ `Settings {
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// (= no migration needed for user-state).
import SwiftUI
import AppKit
import MarkdownEngine

struct SettingView: View {
    @Environment(AppState.self) private var appState
    // MARK: - Persistence bindings (unchanged keys; = no user-state migration)

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("wenshu.llm.provider") private var providerSlug: String = Provider.minimaxCn.slug
    @AppStorage("wenshu.useKeychainForProviderKeys") private var useKeychainForProviderKeys: Bool = true
    // / Single-owner centralization: AppState.llmModel (= v1.72 T3b).
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / pattern as before.
    private var llmModelBinding: Binding<String> {
        Binding(
            get: { appState.llmModel },
            set: { appState.llmModel = $0 }
        )
    }
    // @AppStorage("wenshu.llm.model") private var llmModel: String = ""
    @AppStorage("wenshu.userAddress") private var userAddress: String = "user"
    // P0-3 fix (= Spec audit): ConversationLoop L270 + L482 STILL read
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // claude/effort) = 5 valid options (low / medium / high / xhigh / max).
    @AppStorage("wenshu.llm.reasoningEffort") private var reasoningEffort: String = "medium"
    @AppStorage("wenshu.settingsTab") private var selectedTabRaw: String = SettingsPane.appearance.rawValue

    private var selectedTab: SettingsPane {
        get { paneForRaw(selectedTabRaw) }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }

    // MARK: - Pane enum (= NavigationSplitView's left-column `selection`)

    enum SettingsPane: String, CaseIterable, Identifiable {
        case appearance
        case editor
        case network
        case providers
        case models
        case memory
        var id: String { rawValue }

        // / SF Symbols 7 identifier per Apple HIG sidebar row leading icon.
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // / = every sidebar row icon occupies the identical optical width).
        var icon: String {
            switch self {
            case .appearance: return "paintpalette"
            case .editor:      return "apple.writing.tools"
            case .network:     return "wifi.router"
            case .providers:   return "key.fill"
            case .models:      return "sparkles"
            case .memory:      return "bonjour"
            }
        }
    }

    // MARK: - Provider API state (= unchanged from SettingsOps era)

    @State private var liveModelIds: [String] = []
    @State private var isLoadingModels = false
    @State private var providersWithKeys: Set<String> = []
    @State private var apiExpandedProviders: Set<String> = []
    @State private var apiDraftKey: String = ""
    @State private var apiError: String?
    // / Global Settings search query (= lives in the sidebar-top TextField,
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / replaces the previous provider-only `.searchable(placement: .toolbar)`).
    @State private var globalSearchQuery: String = ""
    // / §11.26 弧 ticket C2. Embedding model kind (= persisted across app
    // / restarts). Default = .minimax (per EmbeddingService default).
    @AppStorage("wenshu.embedding.kind") private var embeddingProviderSlug: String = EmbeddingModelKind.minimax.rawValue

    // MARK: - Editor pane 8 @AppStorage (= EditorPreferences 8 fields)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / AppStorage (= the engine fills horizontally; = see `EditorPreferences`).
    @AppStorage("wenshu.editor.readingWidth")
    private var readingWidthDouble: Double = -1
    /// Height behavior (= serialized as "scrolls" / "fitsContent").
    @AppStorage("wenshu.editor.heightBehavior")
    private var heightBehaviorRaw: String = "scrolls"
    private var heightBehaviorBinding: Binding<MarkdownEditorConfiguration.HeightBehavior> {
        Binding(
            get: {
                switch heightBehaviorRaw {
                case "fitsContent": return .fitsContent
                default: return .scrolls
                }
            },
            set: { newValue in
                switch newValue {
                case .fitsContent: heightBehaviorRaw = "fitsContent"
                case .scrolls:     heightBehaviorRaw = "scrolls"
                }
            }
        )
    }
    @AppStorage("wenshu.editor.rawSourceMode") private var rawSourceMode: Bool = false
    @AppStorage("wenshu.editor.continuousSpellChecking")
    private var continuousSpellChecking: Bool = true
    @AppStorage("wenshu.editor.grammarChecking") private var grammarChecking: Bool = true
    @AppStorage("wenshu.editor.automaticSpellingCorrection")
    private var automaticSpellingCorrection: Bool = true
    @AppStorage("wenshu.editor.listHelpersEnabled") private var listHelpersEnabled: Bool = true
    @AppStorage("wenshu.editor.autoClosePairsEnabled") private var autoClosePairsEnabled: Bool = true

    // MARK: - Apple system accent (= AppleAccentColor / AppleHighlightColor)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / 8 named colors.
    @AppStorage("AppleAccentColor") private var appleAccentColor: Int = -2
    @AppStorage("AppleHighlightColor") private var appleHighlightColor: Int = -2

    // MARK: - App language (= macOS 27 per-app language override)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / Numbers / Keynote all do the same).
    @AppStorage("wenshu.appLanguage") private var appLanguage: String = "system"

    // / True after the user picked a non-system language and we showed
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / user keep editing Settings without re-firing.
    @State private var showAppLanguageRestartAlert: Bool = false

    // MARK: - Computed

    var currentProvider: Provider {
        Provider.by(slug: providerSlug) ?? .minimaxCn
    }

    // / Sidebar pane rows filtered by the global search query (= empty
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / the substring match is forgiving on zh-Hans input.
    private var visiblePanes: [SettingsPane] {
        let query = globalSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SettingsPane.allCases }
        return SettingsPane.allCases.filter { pane in
            localizedPaneTitle(pane).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        // `columnVisibility: .constant(.all)` pins the sidebar so the user cannot drag
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // once `.toolbar(removing: .sidebarToggle)` removes the toggle).
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar column = the filtered pane list only. The search field is attached
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // spot).
            List(visiblePanes, selection: Binding(
                get: { selectedTab },
                set: { newValue in
                    if let newValue { selectedTab = newValue }
                }
            )) { pane in
                    Label {
                        Text(localizedPaneTitle(pane))
                    } icon: {
                        SFIcon(pane.icon, style: .sidebar, color: IconColor.secondary)
                    }
                    .tag(pane)
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
                .listStyle(.sidebar)
                // `toolbar(removing: .sidebarToggle)` strips the system-rendered
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // `View/toolbar(removing:)`).
                .toolbar(removing: .sidebarToggle)
            // `.searchable(text: ..., placement: .sidebar)` attaches the Apple canonical
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // for sidebar search).
            .searchable(
                text: $globalSearchQuery,
                placement: .sidebar,
                prompt: String(localized: "settings.search.global.placeholder")
            )
        } detail: {
            paneBody(for: selectedTab)
                .frame(minWidth: 520)
                .animation(.default, value: selectedTab)
                .animation(.default, value: globalSearchQuery)
        }
        // macOS 27 SwiftUI Settings scene bug: `.windowResizability(.contentMinSize)`
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // survives SwiftUI's inner reconciliation on macOS 27.
        .background(WindowResizableEnabler())
        .task {
            refreshProviderStatus()
            if selectedTab == .providers || selectedTab == .models {
                Task { await reloadModels() }
            }
        }
    }

    // MARK: - Pane routing
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / `providers` pane via this mapping.
    private func paneForRaw(_ raw: String) -> SettingsPane {
        switch raw {
        case "general":       return .appearance
        case "agentBehavior": return .editor
        case "network":       return .network
        case "providerApi":   return .providers
        case "model":         return .models
        case "memory":        return .memory
        default:
            return SettingsPane(rawValue: raw) ?? .appearance
        }
    }

    @ViewBuilder
    private func paneBody(for pane: SettingsPane) -> some View {
        switch pane {
        case .appearance: appearancePane
        case .editor:      editorPane
        case .network:     NetworkDiagnosticsPane()
        case .providers:   providersPane
        case .models:      modelsPane
        case .memory:      MemorySettingsView()
        }
    }

    // / Localized pane title (= sidebar row label). Falls back to the
    // / raw value if a key is missing (= never blank).
    private func localizedPaneTitle(_ pane: SettingsPane) -> String {
        switch pane {
        case .appearance: return String(localized: "settings.pane.appearance")
        case .editor:      return String(localized: "settings.pane.editor")
        case .network:     return String(localized: "settings.pane.network")
        case .providers:   return String(localized: "settings.pane.providers")
        case .models:      return String(localized: "settings.pane.models")
        case .memory:      return String(localized: "settings.pane.memory")
        }
    }

    // MARK: - 外观 pane

    private var appearancePane: some View {
        Form {
            Section {
                Picker(String(localized: "settings.general.appearance"), selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            Section {
                Picker(String(localized: "settings.appearance.appLanguage_label"), selection: Binding(
                    get: { appLanguage },
                    set: { newValue in
                        appLanguage = newValue
                        applyAppLanguage(newValue)
                        // P1-1 fix (audit pending): the
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // AppleLanguages change to confirm).
                        if newValue != "system" {
                            showAppLanguageRestartAlert = true
                        }
                    }
                )) {
                    Text(String(localized: "settings.appearance.appLanguage.system")).tag("system")
                    Text(String(localized: "settings.appearance.appLanguage.en")).tag("en")
                    Text(String(localized: "settings.appearance.appLanguage.zh-Hans")).tag("zh-Hans")
                }
                .pickerStyle(.menu)
            } header: {
                Text(String(localized: "settings.appearance.appLanguage_section_header"))
            } footer: {
                Text(String(localized: "settings.appearance.appLanguage_section_footer"))
                    .font(.caption)
            }
            .alert(String(localized: "settings.appearance.appLanguage.restartAlert_title"),
                   isPresented: $showAppLanguageRestartAlert) {
                Button(String(localized: "settings.appearance.appLanguage.restartAlert_confirm"), role: .cancel) { }
            } message: {
                Text(String(localized: "settings.appearance.appLanguage.restartAlert_message"))
            }
            Section {
                Picker(String(localized: "settings.appearance.accent_label"), selection: Binding(
                    get: { appleAccentColor },
                    set: { newValue in
                        appleAccentColor = newValue
                        UserDefaults.standard.set(newValue, forKey: "AppleAccentColor")
                        refreshAllWindows()
                    }
                )) {
                    Text(String(localized: "settings.appearance.color.default")).tag(-2)
                    Text(String(localized: "settings.appearance.color.graphite")).tag(-1)
                    Text(String(localized: "settings.appearance.color.red")).tag(0)
                    Text(String(localized: "settings.appearance.color.orange")).tag(1)
                    Text(String(localized: "settings.appearance.color.yellow")).tag(2)
                    Text(String(localized: "settings.appearance.color.green")).tag(3)
                    Text(String(localized: "settings.appearance.color.blue")).tag(4)
                    Text(String(localized: "settings.appearance.color.violet")).tag(5)
                    Text(String(localized: "settings.appearance.color.magenta")).tag(6)
                }
                .pickerStyle(.menu)
                Picker(String(localized: "settings.appearance.highlight_label"), selection: Binding(
                    get: { appleHighlightColor },
                    set: { newValue in
                        appleHighlightColor = newValue
                        UserDefaults.standard.set(newValue, forKey: "AppleHighlightColor")
                        refreshAllWindows()
                    }
                )) {
                    Text(String(localized: "settings.appearance.color.default")).tag(-2)
                    Text(String(localized: "settings.appearance.color.graphite")).tag(-1)
                    Text(String(localized: "settings.appearance.color.red")).tag(0)
                    Text(String(localized: "settings.appearance.color.orange")).tag(1)
                    Text(String(localized: "settings.appearance.color.yellow")).tag(2)
                    Text(String(localized: "settings.appearance.color.green")).tag(3)
                    Text(String(localized: "settings.appearance.color.blue")).tag(4)
                    Text(String(localized: "settings.appearance.color.violet")).tag(5)
                    Text(String(localized: "settings.appearance.color.magenta")).tag(6)
                }
                .pickerStyle(.menu)
            } header: {
                Text(String(localized: "settings.appearance.accent_section_header"))
            } footer: {
                Text(String(localized: "settings.appearance.accent_section_footer"))
                    .font(.caption)
            }
            Section {
                Text(String(localized: "settings.general.liquidGlass.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "settings.general.liquidGlass.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "settings.general.liquidGlass"))
            }
            Section {
                TextField(String(localized: "settings.general.agentAddress"), text: $userAddress,
                          prompt: Text(String(localized: "settings.general.agentAddress.prompt")))
                    .textFieldStyle(.roundedBorder)
                Text(String(localized: "settings.general.agentAddress.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "settings.general.agentAddress"))
            }
        }
        .formStyle(.grouped)
    }

    // / Push the new accent / highlight value to the live NSWindow
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / the UX is broken.
    private func refreshAllWindows() {
        for window in NSApplication.shared.windows {
            window.invalidateRestorableState()
        }
    }

    // / Persist the per-app language to macOS 27 \`AppleLanguages\`
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / Settings UI surfaces this with the alert above).
    private func applyAppLanguage(_ lang: String) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let defaults = UserDefaults(suiteName: bundleID) ?? .standard
        switch lang {
        case "en":
            defaults.set(["en-US", "en"], forKey: "AppleLanguages")
        case "zh-Hans":
            defaults.set(["zh-Hans-CN", "zh-Hans"], forKey: "AppleLanguages")
        case "system":
            defaults.removeObject(forKey: "AppleLanguages")
        default:
            break
        }
    }

    // MARK: - 编辑器 pane

    private var editorPane: some View {
        Form {
            Section {
                Picker(String(localized: "settings.editor.readingWidth_label"), selection: Binding(
                    get: { readingWidthBucket() },
                    set: { bucket in
                        switch bucket {
                        case "narrow": readingWidthDouble = 480
                        case "medium": readingWidthDouble = 720
                        case "wide":   readingWidthDouble = 960
                        default:       readingWidthDouble = -1
                        }
                    }
                )) {
                    Text(String(localized: "settings.editor.readingWidth.none")).tag("none")
                    Text(String(localized: "settings.editor.readingWidth.narrow")).tag("narrow")
                    Text(String(localized: "settings.editor.readingWidth.medium")).tag("medium")
                    Text(String(localized: "settings.editor.readingWidth.wide")).tag("wide")
                }
                .pickerStyle(.segmented)
                Picker(String(localized: "settings.editor.heightBehavior_label"), selection: heightBehaviorBinding) {
                    Text(String(localized: "settings.editor.heightBehavior.scrolls")).tag(MarkdownEditorConfiguration.HeightBehavior.scrolls)
                    Text(String(localized: "settings.editor.heightBehavior.fitsContent")).tag(MarkdownEditorConfiguration.HeightBehavior.fitsContent)
                }
                .pickerStyle(.segmented)
                Toggle(String(localized: "settings.editor.rawSourceMode_label"), isOn: $rawSourceMode)
            } header: {
                Text(String(localized: "settings.editor.display_section_header"))
            } footer: {
                Text(String(localized: "settings.editor.display_section_footer"))
                    .font(.caption)
            }
            Section {
                Toggle(String(localized: "settings.editor.continuousSpellChecking_label"), isOn: $continuousSpellChecking)
                Toggle(String(localized: "settings.editor.grammarChecking_label"), isOn: $grammarChecking)
                Toggle(String(localized: "settings.editor.automaticSpellingCorrection_label"), isOn: $automaticSpellingCorrection)
            } header: {
                Text(String(localized: "settings.editor.spelling_section_header"))
            }
            Section {
                Toggle(String(localized: "settings.editor.listHelpersEnabled_label"), isOn: $listHelpersEnabled)
                Toggle(String(localized: "settings.editor.autoClosePairsEnabled_label"), isOn: $autoClosePairsEnabled)
            } header: {
                Text(String(localized: "settings.editor.lists_section_header"))
            }
        }
        .formStyle(.grouped)
    }

    // / Snap an arbitrary `readingWidth` CGFloat to the nearest of the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / bucket instead of an empty selection.
    private func readingWidthBucket() -> String {
        let w = readingWidthDouble
        if w < 0 { return "none" }
        if w < 600 { return "narrow" }
        if w < 840 { return "medium" }
        return "wide"
    }

    // MARK: - 提供方 pane

    private var providersPane: some View {
        Form {
            Section {
                Toggle(isOn: $useKeychainForProviderKeys) {
                    Text("使用系统钥匙串保存 key")
                }
                .onChange(of: useKeychainForProviderKeys) { _, newValue in
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
        if result.shouldClearDraft { apiDraftKey = "" }
        if result.shouldCollapse { apiExpandedProviders.remove(provider.slug) }
        if result.shouldNotify {
            NotificationCenter.default.post(
                name: .wenshuProviderKeychainChanged,
                object: nil,
                userInfo: ["slug": provider.slug]
            )
        }
        if let err = result.error { apiError = err }
        if result.didSave {
            apiError = nil
            refreshProviderStatus()
        }
    }

    // MARK: - 模型 pane

    private var modelsPane: some View {
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
                    Task { await reloadModels() }
                }

                Picker(String(localized: "settings.model.model_label"), selection: llmModelBinding) {
                    ForEach(modelIdList, id: \.self) { id in
                        Text(id).tag(id)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(String(localized: "settings.model.main_model_label"))
            } footer: {
                Text(String(localized: "settings.model.main_model_caption"))
                    .font(.caption)
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

            // §11.26 弧 ticket C2. Embedding model section (= separate
            // configuration from the LLM model, per boss OOB 2026-10-19
            // "设置分开配, 两类模型"). The same Provider key powers both LLM
            // and embedding (= reuses WenshuAgent's existing Apple Keychain
            // entry). The dropdown is the list of remote providers; the
            // subtext shows the active embedding kind and dimension.
            Section {
                Picker(String(localized: "settings.embedding.provider_label"),
                       selection: embeddingProviderSlugBinding) {
                    ForEach(EmbeddingModelKind.allCases, id: \.rawValue) { kind in
                        Text(kind.displayName).tag(kind.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: embeddingProviderSlug) { _, new in
                    if let k = EmbeddingModelKind(rawValue: new) {
                        Task { await EmbeddingService.shared.setActiveKind(k) }
                    }
                }

                HStack {
                    Text(String(localized: "settings.embedding.status_label"))
                    Spacer()
                    Text(embeddingStatusText)
                        .foregroundStyle(embeddingHasKey ? .primary : .secondary)
                        .font(.callout)
                }
            } header: {
                Text(String(localized: "settings.embedding.section_label"))
            } footer: {
                Text(String(localized: "settings.embedding.section_caption"))
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear { Task { await reloadModels() } }
    }

    private var modelIdList: [String] {
        liveModelIds.isEmpty ? currentProvider.defaultModels : liveModelIds
    }

    // / §11.26 弧 ticket C2. Binding that wraps the persisted kind
    // / string. Setting the picker mutates @AppStorage; EmbeddingService
    // / is updated via onChange (= the actor is the source of truth at
    // / runtime, this @AppStorage is just for the picker display).
    private var embeddingProviderSlugBinding: Binding<String> {
        Binding(
            get: { embeddingProviderSlug },
            set: { embeddingProviderSlug = $0 }
        )
    }

    // / Human-readable status: shows "minimax (1024-dim) — API key ready"
    // / or "... — no API key, set in Providers" depending on whether the
    // / user has added the matching provider key in Apple Keychain.
    private var embeddingStatusText: String {
        guard let kind = EmbeddingModelKind(rawValue: embeddingProviderSlug) else { return "" }
        let dim = kind.dimension
        let slug = kind.providerSlug
        let hasKey = providersWithKeys.contains(slug)
        let keyState = hasKey
            ? String(localized: "settings.embedding.status_key_ready")
            : String(localized: "settings.embedding.status_key_missing")
        return "\(kind.displayName) (\(dim)-dim) — \(keyState)"
    }

    private var embeddingHasKey: Bool {
        guard let kind = EmbeddingModelKind(rawValue: embeddingProviderSlug) else { return false }
        return providersWithKeys.contains(kind.providerSlug)
    }

    // MARK: - SettingsOps plumbing (= unchanged)

    private func refreshProviderStatus() {
        providersWithKeys = SettingsOps.refreshProviderStatus(keychain: WenshuAgent.shared.keychainBackend())
    }

    private func reloadModels() async {
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

// / macOS 27 SwiftUI `Settings { }` scene workaround:
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / the recipe ships in the same shape Apple-internal sample code uses.
private struct WindowResizableEnabler: NSViewRepresentable {
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

    func makeNSView(context: Context) -> NSView { Helper() }
    func updateNSView(_ nsView: NSView, context: Context) {
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

// / macOS 27 Settings scene helper: walks every `NSWindow`
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / is a no-op), so the recomputation cost is minimal.
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
