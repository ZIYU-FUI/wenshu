// SettingView.swift · WenshuApp Settings scene (= Apple canonical macOS 14+ `Settings {
// … (= 46 rationale lines collapsed; = A112 docblock collapse per §1.8)
// (= no migration needed for user-state).
import SwiftUI
import AppKit
import MarkdownEngine

struct SettingView: View {
    @Environment(AppState.self) private var appState
    // MARK: - Persistence bindings (unchanged keys; = no user-state migration)

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("wenshu.llm.provider") private var providerSlug: String = Provider.minimaxCn.slug
    // / Single-owner centralization: AppState.llmModel (= v1.72 T3b).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        case providers
        case models
        case memory
        var id: String { rawValue }

        // / SF Symbols 7 identifier per Apple HIG sidebar row leading icon.
        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / = every sidebar row icon occupies the identical optical width).
        var icon: String {
            switch self {
            case .appearance: return "paintpalette"
            case .editor:      return "apple.writing.tools"
            case .providers:   return "network"
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
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / replaces the previous provider-only `.searchable(placement: .toolbar)`).
    @State private var globalSearchQuery: String = ""

    // MARK: - Editor pane 8 @AppStorage (= EditorPreferences 8 fields)
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 8 named colors.
    @AppStorage("AppleAccentColor") private var appleAccentColor: Int = -2
    @AppStorage("AppleHighlightColor") private var appleHighlightColor: Int = -2

    // MARK: - App language (= macOS 27 per-app language override)
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Numbers / Keynote all do the same).
    @AppStorage("wenshu.appLanguage") private var appLanguage: String = "system"

    // / True after the user picked a non-system language and we showed
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / user keep editing Settings without re-firing.
    @State private var showAppLanguageRestartAlert: Bool = false

    // MARK: - Computed

    var currentProvider: Provider {
        Provider.by(slug: providerSlug) ?? .minimaxCn
    }

    // / Sidebar pane rows filtered by the global search query (= empty
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // once `.toolbar(removing: .sidebarToggle)` removes the toggle).
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar column = the filtered pane list only. The search field is attached
            // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // `View/toolbar(removing:)`).
                .toolbar(removing: .sidebarToggle)
            // `.searchable(text: ..., placement: .sidebar)` attaches the Apple canonical
            // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `providers` pane via this mapping.
    private func paneForRaw(_ raw: String) -> SettingsPane {
        switch raw {
        case "general":       return .appearance
        case "agentBehavior": return .editor
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
        case .providers:   providersPane
        case .models:      modelsPane
        case .memory:      MemorySettingsView()
        }
    }

    /// Localized pane title (= sidebar row label). Falls back to the
    /// raw value if a key is missing (= never blank).
    private func localizedPaneTitle(_ pane: SettingsPane) -> String {
        switch pane {
        case .appearance: return String(localized: "settings.pane.appearance")
        case .editor:      return String(localized: "settings.pane.editor")
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
                        // P1-1 fix (= Q99 Spec audit, commit to be authored): the
                        // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the UX is broken.
    private func refreshAllWindows() {
        for window in NSApplication.shared.windows {
            window.invalidateRestorableState()
        }
    }

    // / Persist the per-app language to macOS 27 \`AppleLanguages\`
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else { return "" }
        let prefix = String(key.prefix(8))
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
            Text(p.name)
                .font(.body)
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

    private func keyPrefix12(for provider: Provider) -> String {
        SettingsOps.keyPrefix12(provider: provider, keychain: ProviderKeychain.backend)
    }

    private func saveApiKey(for provider: Provider) {
        let result = SettingsOps.saveApiKey(
            provider: provider,
            draft: apiDraftKey,
            keychain: ProviderKeychain.backend
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
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        .onAppear { Task { await reloadModels() } }
    }

    private var modelIdList: [String] {
        liveModelIds.isEmpty ? currentProvider.defaultModels : liveModelIds
    }

    // MARK: - SettingsOps plumbing (= unchanged)

    private func refreshProviderStatus() {
        providersWithKeys = SettingsOps.refreshProviderStatus(keychain: ProviderKeychain.backend)
    }

    private func reloadModels() async {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }
        liveModelIds = await SettingsOps.reloadModels(
            provider: currentProvider,
            keychain: ProviderKeychain.backend,
            fetcher: ProviderFetcherAdapter()
        )
    }
}

// / macOS 27 SwiftUI `Settings { }` scene workaround:
// … (= 36 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // modifier).
        if let hostWindow = nsView.window {
            hostWindow.styleMask.insert(.resizable)
            ensureResizableAcrossHostingTree(of: hostWindow)
        } else {
            // Fallback for the first-render race (= helper NSView exists but SwiftUI has
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
// … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / is a no-op), so the recomputation cost is minimal.
@MainActor
private func ensureResizableAcrossHostingTree(of hostWindow: NSWindow) {
    // RATIONALE: Swift 6 can't always infer @MainActor across file + extension seams; =
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // all main-actor-isolated).
    for candidateWindow in NSApp.windows where candidateWindow === hostWindow {
        candidateWindow.styleMask.insert(.resizable)
    }
    // Defensive: also walk any Settings scene peer windows (= the macOS process may host
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // every NSWindow SwiftUI has spun up gets the `.resizable` bit). Idempotent.
    for candidateWindow in NSApp.windows {
        candidateWindow.styleMask.insert(.resizable)
    }
}
