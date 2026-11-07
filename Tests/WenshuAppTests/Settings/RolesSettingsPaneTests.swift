//
//  Tests/Settings/RolesSettingsPaneTests.swift · Wenshu
//
//  The roles pane's contract.
//
//  The multi-agent work gave the app six roles, = and they were
//  reachable only through the model and the debug surfaces. = What is
//  pinned here is not the pixels but the promises:
//
//  1. The pane exists, = and it is wired into the scene, = so the
//     user can actually reach it.
//  2. Every string the pane ASKS FOR has a key in the catalog, = in
//     both languages. = A missing key shows the key itself to the
//     user, = which is worse than no pane.
//  3. The rows come from the REGISTRY, = never from a copy written
//     in the pane. = A second table is a table that can drift.
//  4. The pane is READ-ONLY. = The role table is the app's contract
//     with the model, = and a pane that edited it would be offering
//     to break the guarantee while showing it.
//  5. The pane says WHERE each role runs. = The archivist and the
//     auditor do not call the model at all, = and a role table of
//     names hides that.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The roles settings pane")
struct RolesSettingsPaneTests {
    /// The pane's source.
    private static var paneSource: String {
        get throws {
            let url = SourceLocator.url("Sources/WenshuApp/Features/Settings/View/RolesSettingsPane.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    /// The scene's source (= the pane's enum and its routing).
    private static var sceneSource: String {
        get throws {
            let url = SourceLocator.url("Sources/WenshuApp/Features/Settings/View/SettingView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    /// The string catalog.
    private static var catalog: [String: Any] {
        get throws {
            let url = SourceLocator.url("Sources/WenshuApp/Resources/Localizable.xcstrings")
            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)
            return (object as? [String: Any])?["strings"] as? [String: Any] ?? [:]
        }
    }

    // MARK: - The pane exists

    @Test("The roles are a pane, and the scene routes to it")
    func theRolesAreAPaneTheSceneRoutesTo() throws {
        let scene = try Self.sceneSource
        #expect(scene.contains("case roles"), "the settings scene must declare the roles pane")
        #expect(scene.contains("RolesSettingsPane()"), "the scene must route the roles pane to its view")
    }

    // MARK: - The strings

    @Test("Every string the pane ASKS FOR has a key, in both languages")
    func everyStringHasAKey() throws {
        let pane = try Self.paneSource
        let catalog = try Self.catalog

        // The keys the pane asks for, = read out of its own source, =
        // so a new string in the pane is a new key that has to be
        // added to the catalog, = and this test says so.
        var keys: [String] = []
        var rest = pane
        while let range = rest.range(of: "String(localized: \"") {
            rest = String(rest[range.upperBound...])
            guard let end = rest.firstIndex(of: "\"") else { break }
            keys.append(String(rest[..<end]))
            rest = String(rest[end...])
        }
        #expect(!keys.isEmpty, "the pane must ask for localized strings")

        for key in keys {
            let entry = try #require(
                catalog[key] as? [String: Any],
                "the catalog must carry the key \(key)"
            )
            let localizations = try #require(
                entry["localizations"] as? [String: Any],
                "the key \(key) must carry its localizations"
            )
            #expect(localizations["en"] != nil, "the key \(key) must have an English value")
            #expect(localizations["zh-Hans"] != nil, "the key \(key) must have a Chinese value")
        }
    }

    // MARK: - The rows

    @Test("The pane's rows come from the registry, and not from a copy")
    func theRowsComeFromTheRegistry() throws {
        let pane = try Self.paneSource
        #expect(pane.contains("SubAgentRoleRegistry.roles"),
                "the pane must read the registry's own table")
        // A second table written in the pane is a table that can drift
        // from the one the runner dispatches from.
        #expect(!pane.contains("SubAgentRoleRegistry.researcher"),
                "the pane must not name the roles one by one (= that is a copy)")
    }

    @Test("The registry holds the six roles the multi-agent work promised")
    func theRegistryHoldsTheSixRoles() {
        #expect(SubAgentRoleRegistry.roles.count == 6,
                "the role table must hold exactly the six roles")
        let slugs = SubAgentRoleRegistry.roles.map(\.slug)
        #expect(slugs.contains("researcher"))
        #expect(slugs.contains("writer"))
        #expect(slugs.contains("analyst"))
        #expect(slugs.contains("librarian"))
        #expect(slugs.contains("archivist"))
        #expect(slugs.contains("auditor"))
    }

    @Test("The pane shows the REGISTRY's label, = and holds no label of its own")
    func thePaneShowsTheRegistrysOwnLabel() throws {
        let pane = try Self.paneSource
        // The role's display label is the REGISTRY's (= a hardcoded Chinese
        // literal, = the house pattern for a model's display name, = and the
        // same string the chat already shows via `SubAgentIdentity`). = **⇒
        // The pane reads it, = and does not carry a copy of it** (= a second
        // table of role names is a table that can drift).
        #expect(pane.contains("role.displayLabel"),
                "the pane must show the registry's own label")
        // No role name is spelled out in the pane. = The registry owns the
        // table, = so the pane may name NONE of them.
        for role in SubAgentRoleRegistry.roles {
            #expect(!pane.contains(role.displayLabel),
                    "the pane must not carry a copy of the \(role.slug) label (= the registry owns it)")
        }
    }

    @Test("Every role says what it may call and where it runs")
    func everyRoleSaysItsToolsAndItsDispatch() {
        for role in SubAgentRoleRegistry.roles {
            #expect(!role.slug.isEmpty, "a role must carry a slug")
            #expect(!role.displayLabel.isEmpty, "a role must carry a label")
            #expect(!role.prompt.isEmpty, "a role must carry a prompt")
        }
        // The two roles that do not call the model at all.
        let archivist = SubAgentRoleRegistry.role(forSlug: "archivist")
        #expect(archivist?.dispatch == .archiveRun)
        let auditor = SubAgentRoleRegistry.role(forSlug: "auditor")
        #expect(auditor?.dispatch == .auditRun)
    }

    // MARK: - The pane is read-only

    @Test("The pane is read-only (= the role table is the app's own contract)")
    func thePaneIsReadOnly() throws {
        let pane = try Self.paneSource
        // A control that EDITS the role table would be offering to
        // break the guarantee the pane shows. = There is none.
        for control in ["TextField(", "Picker(", "Toggle(", "Stepper(", "Slider("] {
            #expect(!pane.contains(control),
                    "the roles pane must not offer a control that edits the role table (= \(control))")
        }
    }

    // MARK: - The dispatch

    @Test("The pane says where each role runs")
    func thePaneSaysWhereEachRoleRuns() throws {
        let pane = try Self.paneSource
        // The dispatch line is the part a role table of names hides:
        // = the archivist and the auditor do not call a model.
        #expect(pane.contains("dispatch"), "the pane must show each role's dispatch")
        #expect(pane.contains("settings.roles.dispatch.llmRun"))
        #expect(pane.contains("settings.roles.dispatch.archiveRun"))
        #expect(pane.contains("settings.roles.dispatch.auditRun"))
    }
}
