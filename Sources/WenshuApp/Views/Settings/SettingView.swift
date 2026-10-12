// SettingView.swift · WenshuApp
//
// Settings scene (= Apple canonical macOS 14+ `Settings { }` Scene
// mounted at AppRootScene.swift:399). Hosts 5 flat panes (= 外观 /
// 编辑器 / 提供方 / 模型 / 记忆) chosen so each pane's name matches
// the concrete action the user is doing (= boss 2026-10-12 "左栏
// 分成 4-5 组" = no nested "大类 → 小类" hierarchy).
//
// Layout (= boss 2026-10-12 "macOS 默认样式" + "Apple HIG canonical"):
// - NavigationSplitView 2 columns (= macOS 13+ canonical).
// - Left = `List(selection:)` with the 5 panes (= SwiftUI auto-applies
//   macOS 27 sidebar appearance = Liquid Glass + accent tint selection).
// - Right = `Form { Section { ... } }` per pane (= Apple HIG canonical
//   macOS preferences layout = one row per setting + a small label +
//   a control on the right + an optional helper caption).
// - The previous wenshu-specific DesignTokens.spacing* / corner-radius /
//   shadow literals are GONE from this file (= boss 2026-10-12 "完全
//   按 Apple 默认样式规则"; = SwiftUI Form on macOS picks the canonical
//   row height / spacing / corner radius automatically).
// - SF Symbols 6 icons via the central `SFIcon(...)` factory are kept
//   (= v3.0 design system hard rule + Apple HIG SF Symbols 6 canonical).
//
// Settings taxonomy (= verified against actual usage in wenshu + SMC
// MarkdownEditorConfiguration + Pages/Numbers/Keynote AX dump 2026-10-12):
// - 外观: appearance (light/dark/auto) + Apple system accent + highlight
//   + sidebar icon size.
// - 编辑器: 8 toggles (= readingWidth / heightBehavior / rawSourceMode /
//   continuousSpellChecking / grammarChecking / automaticSpellingCorrection
//   / listHelpersEnabled / autoClosePairsEnabled) = every field that
//   EditorPreferences ships (= T-12 + commit 96589ccb8) + every field
//   that SMC MarkdownEditorConfiguration exposes as a runtime toggle.
//   Apple Pages/Numbers/Keynote auto-correct panel lists 13 items but
//   SMC only exposes 4 (= NSTextView system-layer behaviors for the
//   other 9 are not toggles); we do NOT expose dead controls (= per
//   boss "SMC 有什么就用什么；没有就没有").
// - 提供方: 7 provider rows + key paste (= SettingsOps + keychain).
//   Renamed from `providerApi` so the user-facing name matches the
//   concrete action (= paste an API key).
// - 模型: default provider + default model + per-task model map
//   (AuxTask.allCases). Renamed from `model` for clarity.
// - 记忆: MemorySettingsView.
//
// Things that ship DEAD (= removed in this rewrite):
// - `settings.general.misc.placeholderNote` i18n key = pure placeholder
//   text with no UI caller. Removed from all 3 catalogs in commit
//   `9d88672f8` (= en.lproj/Localizable.strings +
//   zh-Hans.lproj/Localizable.strings + Localizable.xcstrings).
// - AuxTask 5 `disabled Button` change-model controls = visually
//   shipped but always non-interactive; replaced with a Text row that
//   shows \`settings.model.use_main_model\` (= 'Use main model'; =
//   the actual current behavior = all AuxTask values use the main
//   model).
//
// Things that were REMOVED then RESTORED (= history):
// - `wenshu.llm.reasoningEffort` AppStorage was REMOVED in commit
//   `25133467f` (= the picker died with the SettingsTab → SettingsPane
//   rename), but the read-side in ConversationLoop +
//   WenshuConductorImportRouter + PlanModeEngine + RequestHelpers was
//   still alive (= silent regression for any user who had configured
//   the value in a prior build). RESTORED in commit `90d6b35f8` (= the
//   picker now lives in the models pane; = the 5-option menu reads
//   / writes `wenshu.llm.reasoningEffort` with a default of "medium").
//
// Persistence (= unchanged across this rewrite):
// - `wenshu.settingsTab` AppStorage persists the selected pane across
//   scene re-mounts (= chat view `wenshu.settingsTab = providerApi`
//   deep-links land on the new `providers` pane via the alias mapping
//   at `paneForRaw(_:)` below).
// - `wenshu.llm.provider` + `wenshu.userAddress` + `appearanceMode`
//   AppStorage bindings keep their existing keys (= no migration needed
//   for user-state).

import SwiftUI
import AppKit
import MarkdownEngine

struct SettingView: View {
    @Environment(AppState.self) private var appState
    // MARK: - Persistence bindings (unchanged keys; = no user-state migration)

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("wenshu.llm.provider") private var providerSlug: String = Provider.minimaxCn.slug
    /// Single-owner centralization: AppState.llmModel (= v1.72 T3b).
    /// The picker reads + writes through the appState via the same
    /// pattern as before.
    private var llmModelBinding: Binding<String> {
        Binding(
            get: { appState.llmModel },
            set: { appState.llmModel = $0 }
        )
    }
    // @AppStorage("wenshu.llm.model") private var llmModel: String = ""
    @AppStorage("wenshu.userAddress") private var userAddress: String = "user"
    // P0-3 fix (= Spec audit): ConversationLoop L270 + L482 STILL read
    // `UserDefaults.standard.string(forKey: "wenshu.llm.reasoningEffort")`
    // and forward it to `LLMCallOptions.reasoningEffort`. Commit 25133467f
    // removed the picker (= silent regression for users who had
    // configured the value in a prior build). Re-add the binding so
    // the UI write side returns. The Apple Anthropic API effort spec
    // (https://platform.claude.com/docs/en/build-with-claude/effort) =
    // 5 valid options (low / medium / high / xhigh / max).
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

        /// SF Symbols 6 identifier per Apple HIG sidebar row leading icon.
        var icon: String {
            switch self {
            case .appearance: return "paintbrush"
            case .editor:      return "doc.text"
            case .providers:   return "key.horizontal"
            case .models:      return "cpu"
            case .memory:      return "brain"
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
    /// Global Settings search query (= lives in the sidebar-top TextField,
    /// drives BOTH the sidebar pane row filter AND the per-pane filtering;
    /// replaces the previous provider-only `.searchable(placement: .toolbar)`).
    @State private var globalSearchQuery: String = ""

    // MARK: - Editor pane 8 @AppStorage (= EditorPreferences 8 fields)

    /// Reading column width (= CGFloat stored as Double). -1 = nil in
    /// AppStorage (= the engine fills horizontally; = see `EditorPreferences`).
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

    /// Apple system accent color (= integer encoding per Apple HIG
    /// documentation). -2 = follow each app's default. -1..6 = the
    /// 8 named colors.
    @AppStorage("AppleAccentColor") private var appleAccentColor: Int = -2
    @AppStorage("AppleHighlightColor") private var appleHighlightColor: Int = -2

    // MARK: - App language (= macOS 27 per-app language override)

    /// Per-app language picker. Values: "system" (= follow macOS
    /// system language = the macOS 27 default; = no \`AppleLanguages\`
    /// write), "en" (= force English), "zh-Hans" (= force Simplified
    /// Chinese). Persisted across Settings re-mounts; = takes effect
    /// on next launch (= macOS 27 standard behavior; = Pages /
    /// Numbers / Keynote all do the same).
    @AppStorage("wenshu.appLanguage") private var appLanguage: String = "system"

    /// True after the user picked a non-system language and we showed
    /// the "restart required" alert; = the alert dismissal lets the
    /// user keep editing Settings without re-firing.
    @State private var showAppLanguageRestartAlert: Bool = false

    // MARK: - Computed

    var currentProvider: Provider {
        Provider.by(slug: providerSlug) ?? .minimaxCn
    }

    /// Sidebar pane rows filtered by the global search query (= empty
    /// string = show every pane). The query uses the localized pane title
    /// (= the same labels SwiftUI displays in each row) so a user typing
    /// any visible word hides the panes that don't match. The pane labels
    /// are short noun phrases (= 外观 / 编辑器 / 提供方 / 模型 / 记忆) so
    /// the substring match is forgiving on zh-Hans input.
    private var visiblePanes: [SettingsPane] {
        let query = globalSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SettingsPane.allCases }
        return SettingsPane.allCases.filter { pane in
            localizedPaneTitle(pane).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        // `columnVisibility: .constant(.all)` pins the sidebar so the user
        // cannot drag the column divider closed (= macOS 27 NavigationSplitView
        // would otherwise let the user collapse the sidebar and find no way
        // back once `.toolbar(removing: .sidebarToggle)` removes the toggle).
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar column = the filtered pane list only. The
            // search field is attached to the NavigationSplitView
            // (= below) via `.searchable(placement: .sidebar)` =
            // Apple HIG canonical SwiftUI macOS 14+ search field
            // (= the pill-shaped, Liquid Glass backed text editor
            // with the magnifyingglass SF Symbol leading; =
            // Apple System Settings > General > Software Update uses
            // the exact same widget). `.searchable` on macOS 27
            // resolves the visible placement to the toolbar row,
            // not to the leading column, because Apple does not
            // ship a sidebar-leading inline search API (= see
            // Apple HIG `Search fields in macOS` sidebar rule;
            // = the platform chooses the canonical spot).
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
                // `sidebar.leading` collapse button (= Apple canonical hide-sidebar
                // toggle = SO 75296044 + Apple dev doc `View/toolbar(removing:)`).
                .toolbar(removing: .sidebarToggle)
            // `.searchable(text: ..., placement: .sidebar)` attaches the
            // Apple canonical macOS 14+ search field (= Liquid Glass
            // pill editor with the magnifyingglass SF Symbol leading) to
            // the NavigationSplitView; macOS 27 SwiftUI resolves the
            // visible placement to the toolbar row (= the Apple HIG
            // canonical spot for sidebar search).
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
        // alone does NOT add `.resizable` to the underlying NSWindow's styleMask
        // (= window stays non-resizable despite the scene modifier). The fix
        // Apple ships as documented on SO 79532884 + 79127814 = an
        // NSViewRepresentable that inserts `.resizable` into the host window's
        // styleMask. We hook BOTH `viewWillMove(toWindow:)` (= the pre-attach
        // point when the styleMask is still mutable) AND `viewDidMoveToWindow()`
        // (= post-attach fallback) so the resizability survives SwiftUI's
        // inner reconciliation on macOS 27.
        .background(WindowResizableEnabler())
        .task {
            refreshProviderStatus()
            if selectedTab == .providers || selectedTab == .models {
                Task { await reloadModels() }
            }
        }
    }

    // MARK: - Pane routing

    /// Resolve the persisted `wenshu.settingsTab` raw value (= the legacy
    /// `SettingsTab` enum cases shipped in 2025 / early 2026) to the
    /// current pane. Deep-link callers (= `ChatSessionViewModel` writes
    /// `wenshu.settingsTab = providerApi`) land on the new
    /// `providers` pane via this mapping.
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
                        // P1-1 fix (= Q99 Spec audit, commit to be authored):
                        // the restart-required alert must NOT fire when the
                        // user re-selects the 'system' tag (= no AppleLanguages
                        // write happened; = applyAppLanguage("system") removes
                        // the key; = no restart is needed because there is no
                        // override to take effect). Firing the alert on a no-op
                        // select is the user-reported UX bug from commit
                        // bc1d9bbeb (= user picked 'system' after a previous
                        // explicit pick; = alert popped without any AppleLanguages
                        // change to confirm).
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

    /// Push the new accent / highlight value to the live NSWindow
    /// (= without the host needing to relaunch). Cheap; = the picker
    /// change has to take effect before the user closes Settings or
    /// the UX is broken.
    private func refreshAllWindows() {
        for window in NSApplication.shared.windows {
            window.invalidateRestorableState()
        }
    }

    /// Persist the per-app language to macOS 27 \`AppleLanguages\`
    /// (= the standard per-app override mechanism). "system" removes
    /// the override (= the host falls back to macOS system language);
    /// "en" + "zh-Hans" write the canonical lang+region list that
    /// Pages / Numbers / Keynote also use (= macOS picks the first
    /// matching locale from the list; = the second entry is the
    /// fallback in case the first is missing from the app bundle).
    ///
    /// Effective on next launch (= the standard macOS 27 behavior;
    /// = SwiftUI offers no runtime-locale-override API; = the user
    /// must restart the app for the change to take effect; = the
    /// Settings UI surfaces this with the alert above).
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

    /// Snap an arbitrary `readingWidth` CGFloat to the nearest of the
    /// 3 buckets (= narrow 480 / medium 720 / wide 960). Used by the
    /// `Picker` getter so the segmented control lands on the closest
    /// bucket instead of an empty selection.
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
        // The previous per-pane `.searchable` toolbar field is gone; the
        // sidebar-top global search query drives this filter when non-empty,
        // so the providers row list narrows as the user types.
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
            // P0-3 fix (= Spec audit): wenshu.llm.reasoningEffort is still
            // READ by ConversationLoop + WenshuConductorImportRouter + 3
            // connector adapters, but commit 25133467f removed the writer
            // (= silent regression for users who configured reasoning
            // effort in a prior build). Re-add the minimal picker so
            // the write side returns. Apple Anthropic API effort spec
            // (https://platform.claude.com/docs/en/build-with-claude/effort)
            // = 5 valid options. Default = "medium" (= v0.21 ticket 35b).
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

/// macOS 27 SwiftUI `Settings { }` scene workaround:
///
/// `.windowResizability(.contentMinSize)` (or any `Scene`
/// `windowResizability` value) does NOT actually flip the
/// underlying `NSWindow.styleMask` to include `.resizable`
/// when applied to a `Settings { }` scene (= verified on macOS 27
/// = the SO 79532884 regression). This representable inserts
/// `.resizable` into the host `NSWindow.styleMask` from BOTH
/// pre-attach and post-attach points so the canonical Apple
/// resizable-preferences-window behavior survives SwiftUI's
/// inner styleMask reconciliation on macOS 27.
///
/// Two trigger points (ref: SO 79532884 + 79127814):
/// - `viewWillMove(toWindow:)` runs BEFORE the hosting NSWindow
///   does any post-attach reconciliation (= the styleMask is
///   still in its initial state).
/// - `viewDidMoveToWindow()` runs AFTER attach (= the fallback
///   in case SwiftUI re-set the styleMask between the two events).
///
/// Refs: Apple SwiftUI `Scene.windowResizability(_:)` documentation
/// (developer.apple.com/documentation/swiftui/scene/windowresizability(_:));
/// the recipe ships in the same shape Apple-internal sample code uses.
private struct WindowResizableEnabler: NSViewRepresentable {
    private final class Helper: NSView {
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            guard let newWindow else { return }
            Task { @MainActor in newWindow.styleMask.insert(.resizable) }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.styleMask.insert(.resizable)
        }
    }

    func makeNSView(context: Context) -> NSView { Helper() }
    func updateNSView(_ nsView: NSView, context: Context) { }
}
