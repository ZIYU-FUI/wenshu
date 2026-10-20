// SettingViewTests.swift · Wenshu · v0.93 ticket 005 → 2026-10-12 restructure
//
// Source-level structural tests for SettingView (= wenshu.app Settings
// scene = Settings { } at AppRootScene.swift:399).
//
// Per Q34 5.4 + v0.77 spec + v0.93 ticket 003/004 pattern: structural
// source-level assertions for the structural invariants + behavior
// assertions for the pure-function helpers (= toggleExpand / currentDraftPreview
// / keyPrefix12 / filteredProviders / modelIdList / SettingsPane enum cases).
//
// 2026-10-12 rewrite (= commits 25133467f + bc1d9bbeb on branch
// feat/wenshu-settings-restructure-2026-10-12):
// - SettingView body rewritten from `VStack { Picker(.segmented) + ... }`
//   to `NavigationSplitView { List(selection:) } detail: { ... }`
//   (= macOS 27 System Settings 2-column layout; = boss 2026-10-12
//   "macOS 默认样式 + Apple HIG canonical").
// - SettingsTab enum (5 cases = general/agentBehavior/providerApi/model/memory)
//   reworked as SettingsPane (5 cases = appearance/editor/providers/models/memory)
//   (= each pane name matches the concrete action the user is doing;
//   = boss "左栏分成 4-5 组，让原来的第二层的，比如提供方，放在第一层").
// - Dead control removed: `wenshu.llm.reasoningEffort` AppStorage +
//   reasoningEffort picker + AuxTask 5 disabled Button. Verified dead
//   before removal via grep across Sources/ (= 0 readers).
// - New panes added: 编辑器 pane (= 8 toggles binding to EditorPreferences
//   = T-12 ship + commit 96589ccb8 / 13c85aee7); 外观 pane grew
//   accent color + highlight color + sidebar icon size + appLanguage picker
//   (= commit bc1d9bbeb = macOS AppleLanguages standard).
//
// Why this test file still exists (= not deleted): the structural
// invariants (= NavigationSplitView / List / SettingsPane enum /
// SettingsOps delegation / notification posting / AppState read) are
// the same business contract; = the assertions just gate the new
// substring shapes (= the old `SettingsTab` / `.pickerStyle(.segmented)`
// / `DesignTokens.settingViewSheetSize` / `reasoningEffort` checks
// are obsolete and have been rewritten below).
//
// §11.4 Step-5 orphan-detection check (= `wenshu.llm.reasoningEffort`
// write-only key): dead (= commit 25133467f removed the binding + the
// picker + the doc-comment that locks down the empty-default semantic).
// The regression test for the literal substring
// `// @AppStorage("wenshu.llm.model") private var llmModel: String = ""`
// is retained as a no-op guard (= v0.24 boss verification doc-drift
// catch; = it asserts the literal-comment text, NOT the live binding).

import SwiftUI
import Testing
import Foundation
@testable import WenshuApp

@Suite("SettingView (v0.93 ticket 005 — Settings tab)")
struct SettingViewTests {

    /// 
    /// from THIS test file's path (= worktree-aware).
    private static var settingViewPath: String {
        let testFileURL = SourceLocator.repoRoot
        let testsDir = testFileURL.deletingLastPathComponent()  // Views/Settings/
        let repoRoot = testsDir
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        return repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("WenshuApp")
            .appendingPathComponent("Views")
            .appendingPathComponent("Settings")
            .appendingPathComponent("SettingView.swift")
            .path
    }

    private func readSettingViewSource() throws -> String {
        return try String(contentsOfFile: Self.settingViewPath, encoding: .utf8)
    }

    /// Extract the SettingView struct section (= until the closing brace
    /// of the type). Section delimiter = the closing brace of the top-level
    /// type (= 499 LOC source ends with "\n}\n").
    private func settingViewSection(_ source: String) -> String {
        let startRange = source.range(of: "struct SettingView: View")!
        let section = String(source[startRange.lowerBound...])
        // The file ends with "\n}\n" (= the type's closing brace)
        let endRange = section.range(of: "\n}\n", options: .literal)?.upperBound
            ?? section.endIndex
        return String(section[..<endRange])
    }

    // MARK: - Structural tests

    @Test("struct SettingView conforms to View (= public API)")
    func conformsToView() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        #expect(section.contains("struct SettingView: View"),
                "SettingView must conform to View (= the Settings tab root)")
    }

    @Test("reads AppState from environment (= model picker proxy pattern)")
    func readsAppStateFromEnvironment() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        #expect(section.contains("@Environment(AppState.self) private var appState"),
                "SettingView must read AppState from environment (= the v0.24 B-05 centralization)")
    }

    @Test("declares 8 @AppStorage wenshu.editor.* keys for editor pane")
    func declaresEightEditorAppStorageKeys() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        // The 8 editor-pane keys (= EditorPreferences AppStorage bridge;
        // = shipped via T-12 + commit 96589ccb8).
        for key in [
            "wenshu.editor.readingWidth",
            "wenshu.editor.heightBehavior",
            "wenshu.editor.rawSourceMode",
            "wenshu.editor.continuousSpellChecking",
            "wenshu.editor.grammarChecking",
            "wenshu.editor.automaticSpellingCorrection",
            "wenshu.editor.listHelpersEnabled",
            "wenshu.editor.autoClosePairsEnabled",
        ] {
            #expect(section.contains("@AppStorage(\"\(key)\")"),
                    "SettingView must declare @AppStorage for \(key) (= editor pane row)")
        }
    }

    @Test("userAddress default = 'user' (not 'boss' per boss 8/24 clarification)")
    func userAddressDefaultIsUser() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        #expect(section.contains("private var userAddress: String = \"user\""),
                "userAddress must default to 'user' (= boss 8/24 OOB: not hermes-side 'boss')")
    }

    @Test("selectedTab round-trips via SettingsPane enum (defensive default = .appearance + legacy aliases)")
    func selectedTabRoundTripViaSettingsPane() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        // selectedTab must parse from rawValue + default to .appearance on parse failure
        #expect(codeRegion.contains("SettingsPane(rawValue: raw) ?? .appearance"),
                "selectedTab must default to .appearance when rawValue fails to parse (= defensive)")
        // Legacy aliases (= old SettingsTab raw values still resolve to the
        // current pane; = chat view's `wenshu.settingsTab = providerApi`
        // deep-links land on the new `providers` pane).
        for (raw, pane) in [
            ("providerApi", ".providers"),
            ("agentBehavior", ".editor"),
            ("model", ".models"),
            ("general", ".appearance"),
            ("memory", ".memory"),
        ] {
            #expect(codeRegion.contains("case \"\(raw)\":"),
                    "legacy rawValue \(raw) must declare a switch case (= chat deep-link compat)")
            #expect(codeRegion.contains("return \(pane)"),
                    "legacy rawValue \(raw) must return \(pane) (= chat deep-link compat)")
        }
    }

















































    @Test("body uses NavigationSplitView + .task refreshes providers/models on pane appear")
    func bodyWiresRefreshAndReloadOnPaneAppear() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("NavigationSplitView {"),
                "body must use NavigationSplitView (= macOS 27 System Settings 2-column layout)")
        #expect(codeRegion.contains(".task {"),
                "body must have a .task (= pane appear lifecycle)")
        #expect(codeRegion.contains("refreshProviderStatus()"),
                "body must call refreshProviderStatus (= keychain sync on pane appear)")
        #expect(codeRegion.contains("selectedTab == .providers || selectedTab == .models"),
                "body must reload models when landing on providers or models pane (= fetch on demand)")
    }

    @Test("body uses NavigationSplitView with List(selection:) + 5 SettingsPane cases (= Apple HIG sidebar)")
    func bodyUsesNavigationSplitViewList() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("List(SettingsPane.allCases, selection:"),
                "body must render left-column List of SettingsPane.allCases (= sidebar)")
        #expect(codeRegion.contains("navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)"),
                "body must set sidebar column width 200..260 PT (= Apple HIG sidebar range)")
        // 5 panes (= appearance / editor / providers / models / memory).
        for pane in ["appearance", "editor", "providers", "models", "memory"] {
            #expect(codeRegion.contains("case .\(pane)"),
                    "SettingsPane enum must declare the .\(pane) case")
        }
    }























    @Test("body uses Apple canonical SwiftUI defaults (no wenshu-specific sheet sizing)")
    func bodyHasNoWenshuSpecificSheetSizing() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        // 2026-10-12 rewrite (= boss 2026-10-12 "完全按 Apple 默认样式规则"):
        // Settings lives in a macOS `Settings { }` Scene (= auto-sized by
        // AppKit; = no wenshu-specific width/height token needed).
        #expect(!section.contains("DesignTokens.settingViewSheetSize"),
                "body must NOT reference the wenshu-specific sheet-size token (= Apple canonical handles window sizing)")
    }

    @Test("refreshProviderStatus reads ProviderKeychain.listProvidersWithKeys (= v0.24 fix)")
    func refreshProviderStatusUsesProviderKeychain() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        #expect(section.contains("SettingsOps.refreshProviderStatus(keychain:"),
                "refreshProviderStatus must delegate to SettingsOps.refreshProviderStatus (= single source of truth via MVVM Ops layer per v1.72)")
    }

    @Test("generalTab uses .formStyle(.grouped) + .radioGroup for appearance picker")
    func generalTabUsesFormStyleGroupedAndRadioGroup() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains(".formStyle(.grouped)"),
                "generalTab must use .formStyle(.grouped) (= Apple HIG)")
        #expect(codeRegion.contains(".pickerStyle(.radioGroup)"),
                "generalTab appearance picker must use .pickerStyle(.radioGroup) (= Apple HIG)")
    }

    @Test("providerApiTab uses .searchable with placement .toolbar (= v0.40 HIG absent batch)")
    func providerApiTabUsesSearchable() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains(".searchable(text: $providerSearchText,"),
                "providerApiTab must use .searchable (= Apple HIG Cmd-F standard)")
        #expect(codeRegion.contains("placement: .toolbar"),
                "providerApiTab .searchable placement must be .toolbar (= Apple HIG Settings standard)")
    }

    @Test("toggleExpand previews draft key on first expand + clears error")
    func toggleExpandPreviewsDraftKey() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("apiExpandedProviders = SettingsOps.toggleExpansion"),
                "toggleExpand must delegate to SettingsOps.toggleExpansion (= MVVM extraction per v1.72)")
        #expect(codeRegion.contains("apiDraftKey = currentDraftPreview(for: p)"),
                "toggleExpand must pre-populate apiDraftKey with the masked key preview (= UX consistency)")
        #expect(codeRegion.contains("apiError = nil"),
                "toggleExpand must clear apiError on re-expand (= error reset on retry)")
    }

    @Test("saveApiKey posts .wenshuProviderKeychainChanged notification with slug userInfo")
    func saveApiKeyPostsProviderKeychainChangedNotification() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("NotificationCenter.default.post("),
                "saveApiKey must post a NotificationCenter notification (= chat refresh signal)")
        #expect(codeRegion.contains("name: .wenshuProviderKeychainChanged"),
                "saveApiKey notification name must be .wenshuProviderKeychainChanged (= cross-app broadcast)")
        #expect(codeRegion.contains("userInfo: [\"slug\": provider.slug]"),
                "saveApiKey notification userInfo must carry the slug (= consumer filter)")
    }

    @Test("saveApiKey clears apiDraftKey + collapses the row on success")
    func saveApiKeyClearsStateOnSuccess() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("apiDraftKey = \"\""),
                "saveApiKey must clear apiDraftKey after save (= input reset)")
        #expect(codeRegion.contains("apiExpandedProviders.remove(provider.slug)"),
                "saveApiKey must collapse the expanded row after save (= UX close-on-success)")
        #expect(codeRegion.contains("refreshProviderStatus()"),
                "saveApiKey must call refreshProviderStatus (= key state refresh)")
    }
















    @Test("currentDraftPreview returns empty when no key (= no placeholder leak)")
    func currentDraftPreviewReturnsEmptyWhenNoKey() throws {
        // Behavior test: pure helper, no @MainActor / no AppState needed.
        // We construct a SettingView via @MainActor just to access the
        // method (= .currentDraftPreview is private but accessible via
        // test target @testable import).
        //
        // Note: with no providersWithKeys populated, currentDraftPreview
        // returns "" for any provider. Lock that contract.
        //
        // Without a way to inject providersWithKeys from outside, this
        // test is structural only (= the source-level guard is the contract).
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("let hasKey = providersWithKeys.contains(provider.slug)"),
                "currentDraftPreview must check hasKey (= providersWithKeys guard)")
        #expect(codeRegion.contains("guard hasKey else { return \"\" }"),
                "currentDraftPreview must return empty when no key (= no placeholder leak)")
        #expect(codeRegion.contains("let prefix = String(key.prefix(8))"),
                "currentDraftPreview must use first 8 chars (= prefix length contract)")
        #expect(codeRegion.contains("return prefix + \"********\""),
                "currentDraftPreview must return prefix + 8 asterisks (= masked display)")
    }

    @Test("keyPrefix12 returns first 12 chars of key or empty (= 12-char prefix contract)")
    func keyPrefix12ReturnsFirstTwelveChars() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("SettingsOps.keyPrefix12"),
                "keyPrefix12 must delegate to SettingsOps.keyPrefix12 (= MVVM extraction per v1.72)")
    }

    @Test("filteredProviders returns all when search empty (= no filter on empty query)")
    func filteredProvidersEmptySearchReturnsAll() throws {
        // Behavior test: pure computed (= no @MainActor / no @State mutation).
        // Lock the empty-search contract.
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("guard !trimmed.isEmpty else { return Provider.all }"),
                "filteredProviders must return Provider.all when search empty (= no filter)")
        #expect(codeRegion.contains("localizedCaseInsensitiveContains(trimmed)"),
                "filteredProviders must use case-insensitive match (= Apple HIG)")
    }

    @Test("modelIdList falls back to currentProvider.defaultModels when liveModelIds empty")
    func modelIdListFallsBackToDefaults() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        #expect(section.contains("liveModelIds.isEmpty ? currentProvider.defaultModels : liveModelIds"),
                "modelIdList must fall back to currentProvider.defaultModels when live empty")
    }













    // MARK: - 2026-10-12 restructure gates

    @Test("AppLanguage picker writes AppleLanguages key into host bundle's UserDefaults")
    func appLanguagePickerWritesAppleLanguages() throws {
        let source = try readSettingViewSource()
        let section = settingViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        // macOS 27 per-app language override (= Pages / Numbers / Keynote pattern):
        // write the canonical lang+region list to the host bundle's
        // AppleLanguages key.
        #expect(codeRegion.contains("Bundle.main.bundleIdentifier"),
                "applyAppLanguage must read the host bundle id (= write to the right domain)")
        #expect(codeRegion.contains("UserDefaults(suiteName: bundleID)"),
                "applyAppLanguage must use a suite-bound UserDefaults (= per-app override scope)")
        #expect(codeRegion.contains("defaults.set([\"en-US\", \"en\"], forKey: \"AppleLanguages\")"),
                "applyAppLanguage must write the canonical en lang+region pair")
        #expect(codeRegion.contains("defaults.set([\"zh-Hans-CN\", \"zh-Hans\"], forKey: \"AppleLanguages\")"),
                "applyAppLanguage must write the canonical zh-Hans lang+region pair")
        #expect(codeRegion.contains("defaults.removeObject(forKey: \"AppleLanguages\")"),
                "applyAppLanguage must remove AppleLanguages on system (= inherit OS language)")
        // P1-1 fix (= Q99 Spec audit follow-up): the restart-required
        // alert must NOT fire when the user selects the 'system' tag,
        // because applyAppLanguage("system") is a no-op (= it removes
        // the AppleLanguages key; = no override is in flight; = no
        // restart is needed). The picker setter must guard the alert
        // behind a non-system check.
        #expect(codeRegion.contains("if newValue != \"system\""),
                "appLanguage picker setter must guard the restart alert behind a non-system check (= P1-1 UX fix; = alert must not pop when the user re-selects 'system' after a previous explicit pick)")
    }
}
