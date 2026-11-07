// SettingView.swift · WenshuApp Settings scene (= Apple canonical macOS 14+ `Settings {
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// (= no migration needed for user-state).
import AppKit
import MarkdownEngine
import SwiftUI
import WenshuAgent

struct SettingView: View {
    @Environment(AppState.self) private var appState

    // MARK: - Persistence bindings (unchanged keys; = no user-state migration)

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("wenshu.llm.provider") var providerSlug: String = Provider.minimaxCn.slug
    @AppStorage("wenshu.useKeychainForProviderKeys") var useKeychainForProviderKeys: Bool = true
    /// / Single-owner centralization: AppState.llmModel (= v1.72 T3b).
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / pattern as before.
    var llmModelBinding: Binding<String> {
        Binding(
            get: { appState.llmModel },
            set: { appState.llmModel = $0 }
        )
    }

    /// @AppStorage("wenshu.llm.model") private var llmModel: String = ""
    @AppStorage("wenshu.userAddress") private var userAddress: String = "user"
    // P0-3 fix (= Spec audit): ConversationLoop L270 + L482 STILL read
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // claude/effort) = 5 valid options (low / medium / high / xhigh / max).
    @AppStorage("wenshu.llm.reasoningEffort") var reasoningEffort: String = "medium"
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
        case agent
        case covers
        /// The archive (= what the agents did, = and for how long it
        /// is kept). = It is a ninth pane, = and the pane count is
        /// asserted by a tripwire (= IconStylesTests), = so the two
        /// must move together.
        case archive
        // The six sub-agent roles (= what each one is, = and what it
        // may do). = It is a tenth pane, = and the pane count is
        // asserted by a tripwire (= IconStylesTests), = so the two
        // must move together.
        case roles
        var id: String {
            rawValue
        }

        /// / SF Symbols 7 identifier per Apple HIG sidebar row leading icon.
        /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        /// / = every sidebar row icon occupies the identical optical width).
        var icon: String {
            switch self {
            case .appearance: return "paintpalette"
            case .editor: return "apple.writing.tools"
            case .network: return "wifi.router"
            case .providers: return "key.fill"
            case .models: return "sparkles"
            case .memory: return "bonjour"
            case .agent: return "wand.and.stars"
            case .covers: return "photo.on.rectangle.angled"
            case .archive: return "archivebox"
            case .roles: return "person.2.badge.gearshape"
            }
        }
    }

    // MARK: - Provider API state (= unchanged from SettingsOps era)

    @State var liveModelIds: [String] = []
    @State var isLoadingModels = false
    @State var providersWithKeys: Set<String> = []
    @State var apiExpandedProviders: Set<String> = []
    @State var apiDraftKey: String = ""
    @State var apiError: String?
    /// The custom endpoint the user typed for the selected provider.
    /// Empty = the provider's own default applies.
    @State var customBaseURLDraft: String = ""
    /// / Global Settings search query (= lives in the sidebar-top TextField,
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / replaces the previous provider-only `.searchable(placement: .toolbar)`).
    @State var globalSearchQuery: String = ""

    // MARK: - Editor pane 8 @AppStorage (= EditorPreferences 8 fields)

    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / AppStorage (= the engine fills horizontally; = see `EditorPreferences`).
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
                case .scrolls: heightBehaviorRaw = "scrolls"
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

    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / Numbers / Keynote all do the same).
    @AppStorage("wenshu.appLanguage") private var appLanguage: String = "system"

    /// / True after the user picked a non-system language and we showed
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / user keep editing Settings without re-firing.
    @State private var showAppLanguageRestartAlert: Bool = false

    // MARK: - Computed

    var currentProvider: Provider {
        Provider.by(slug: providerSlug) ?? .minimaxCn
    }

    /// / Sidebar pane rows filtered by the global search query (= empty
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / the substring match is forgiving on zh-Hans input.
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
                    if let newValue {
                        selectedTab = newValue
                    }
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

    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / `providers` pane via this mapping.
    private func paneForRaw(_ raw: String) -> SettingsPane {
        switch raw {
        case "general": return .appearance
        case "agentBehavior": return .editor
        case "network": return .network
        case "providerApi": return .providers
        case "model": return .models
        case "memory": return .memory
        case "agent": return .agent
        default:
            return SettingsPane(rawValue: raw) ?? .appearance
        }
    }

    @ViewBuilder
    private func paneBody(for pane: SettingsPane) -> some View {
        switch pane {
        case .appearance: appearancePane
        case .editor: editorPane
        case .network: NetworkDiagnosticsPane()
        case .providers: providersPane
        case .models: modelsPane
        case .memory: MemorySettingsView()
        case .agent: AgentSettingsPane()
        case .covers: CoverSettingsView()
        case .archive: ArchiveSettingsPane()
        case .roles: RolesSettingsPane()
        }
    }

    /// / Localized pane title (= sidebar row label). Falls back to the
    /// / raw value if a key is missing (= never blank).
    private func localizedPaneTitle(_ pane: SettingsPane) -> String {
        switch pane {
        case .appearance: return String(localized: "settings.pane.appearance")
        case .editor: return String(localized: "settings.pane.editor")
        case .network: return String(localized: "settings.pane.network")
        case .providers: return String(localized: "settings.pane.providers")
        case .models: return String(localized: "settings.pane.models")
        case .memory: return String(localized: "settings.pane.memory")
        case .agent: return String(localized: "settings.pane.agent")
        case .covers: return String(localized: "settings.pane.covers")
        case .archive: return String(localized: "settings.pane.archive")
        case .roles: return String(localized: "settings.pane.roles")
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
                   isPresented: $showAppLanguageRestartAlert)
            {
                Button(String(localized: "settings.appearance.appLanguage.restartAlert_confirm"), role: .cancel) {}
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

    /// / Push the new accent / highlight value to the live NSWindow
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / the UX is broken.
    private func refreshAllWindows() {
        for window in NSApplication.shared.windows {
            window.invalidateRestorableState()
        }
    }

    /// / Persist the per-app language to macOS 27 \`AppleLanguages\`
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / Settings UI surfaces this with the alert above).
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
                        case "wide": readingWidthDouble = 960
                        default: readingWidthDouble = -1
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

    /// / Snap an arbitrary `readingWidth` CGFloat to the nearest of the
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / bucket instead of an empty selection.
    private func readingWidthBucket() -> String {
        let w = readingWidthDouble
        if w < 0 {
            return "none"
        }
        if w < 600 {
            return "narrow"
        }
        if w < 840 {
            return "medium"
        }
        return "wide"
    }
}
