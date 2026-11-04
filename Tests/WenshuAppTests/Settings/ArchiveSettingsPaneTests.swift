//
//  Tests/Settings/ArchiveSettingsPaneTests.swift · Wenshu
//
//  The archive pane's contract.
//
//  The archive is the ninth settings pane, = and it is the pane that
//  tells the user what the agents did. = What is pinned here is not
//  the pixels but the promises:
//
//  1. The pane exists, = and it is wired into the scene, = so the
//     user can actually reach it.
//  2. Every string the pane shows has a key in the catalog, = in
//     both languages. = A missing key shows the key itself to the
//     user, = which is worse than no pane.
//  3. The retention window is a closed set, = the same shape the
//     memory pane uses, = and its setting is its own: = the archive's
//     window and the memory's window mean different things, = and one
//     key for two meanings is a setting nobody can reason about.
//  4. The pane deletes the agent's work, = and never the user's own
//     conversations. = The purge says so in its own code.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The archive settings pane")
struct ArchiveSettingsPaneTests {

    /// The pane's source.
    private static var paneSource: String {
        get throws {
            let url = SourceLocator.url("Sources/WenshuApp/Features/Settings/View/ArchiveSettingsPane.swift")
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

    @Test("The archive is a pane, and the scene routes to it")
    func theArchiveIsAPaneTheSceneRoutesTo() throws {
        let scene = try Self.sceneSource
        #expect(scene.contains("case archive"), "the settings scene must declare the archive pane")
        #expect(scene.contains("ArchiveSettingsPane()"), "the scene must route the archive pane to its view")
    }

    @Test("The pane lists the agent's work and keeps its own retention window")
    func thePaneListsTheWorkAndKeepsItsOwnWindow() throws {
        let pane = try Self.paneSource
        #expect(pane.contains("listRuns"), "the pane must read the archive's rows")
        #expect(pane.contains("purgeRuns"), "the pane must be able to purge what fell out of the window")
        #expect(pane.contains("deleteRun"), "the pane must be able to delete one run")
    }

    // MARK: - The strings

    @Test("Every string the pane shows has a key, in both languages")
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

    // MARK: - The retention

    @Test("The retention window is a closed set, and it is the archive's own")
    func theRetentionWindowIsAClosedSetAndItsOwn() throws {
        let pane = try Self.paneSource

        // The four values, = the memory pane's set.
        for days in ["30", "90", "180", "365"] {
            #expect(pane.contains("settings.archive.retention.d\(days)"),
                    "the pane must offer the \(days)-day window")
        }

        // Its own key: = not the memory pane's, = because the two
        // settings mean different things.
        #expect(pane.contains("wenshu.archive.retentionDays"),
                "the archive keeps its own retention key")
        #expect(!pane.contains("wenshu.memory.retentionDays"),
                "the archive must not share the memory pane's retention key")
    }

    // MARK: - What it deletes

    @Test("The pane deletes the agent's work and says it never touches the user's conversations")
    func thePaneNeverTouchesTheUsersConversations() throws {
        // The sentence the user reads is in the catalog, = not in the
        // Swift source, = so the catalog is what the assertion reads.
        // = The promise is made to the user, = so it is checked where
        // the user will find it.
        let catalog = try Self.catalog
        let key = "settings.archive.retention.footer"
        let entry = try #require(catalog[key] as? [String: Any], "the catalog must carry \(key)")
        let localizations = try #require(entry["localizations"] as? [String: Any])
        let english = try #require((localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any])
        let value = try #require(english["value"] as? String)

        #expect(value.contains("conversations are never touched"),
                "the pane's footer must say that the user's own conversations are not the archive's to delete")
    }

    // MARK: - The filters

    @Test("The agent filter says what the data layer takes")
    func theAgentFilterSaysWhatTheDataLayerTakes() {
        // "Every agent" is nil, = because nil is what the data
        // layer reads as "no filter". = A filter that passed a
        // sentinel string instead would ask the data layer for a
        // row nobody has.
        #expect(ArchiveAgentFilter.all.agentName == nil,
                "the all case must ask for every agent")
        #expect(ArchiveAgentFilter.agent("researcher").agentName == "researcher",
                "a named agent must ask for that agent")
    }

    @Test("The kind filter says what the data layer takes")
    func theKindFilterSaysWhatTheDataLayerTakes() {
        #expect(ArchiveSourceFilter.all.sourceValue == nil,
                "the all case must ask for every kind")
        #expect(ArchiveSourceFilter.source("subagent").sourceValue == "subagent",
                "a named kind must ask for that kind")
    }

    @Test("The pane narrows the archive and the data layer does the narrowing")
    func thePaneNarrowsTheArchive() throws {
        let pane = try Self.paneSource

        // The filters reach the data layer, = and they reach it as
        // the filters' values. = A pane that reads every row and
        // filters it in the view would show the same rows, = but the
        // archive grows without bound, = and the data layer already
        // has the predicate.
        #expect(pane.contains("source: sourceFilter.sourceValue"),
                "the pane must ask the data layer for the kind it shows")
        #expect(pane.contains("agentName: agentFilter.agentName"),
                "the pane must ask the data layer for the agent it shows")

        // And the two menus exist, = or the filters have nowhere to
        // be set.
        #expect(pane.contains("settings.archive.filter.agent"),
                "the pane must offer a filter by agent")
        #expect(pane.contains("settings.archive.filter.kind"),
                "the pane must offer a filter by kind")
    }

    @Test("The filter's options come from the rows, and not from a list written by hand")
    func theFilterOptionsComeFromTheRows() throws {
        let pane = try Self.paneSource

        #expect(pane.contains("compactMap(\\.agentName)"),
                "the agent options must come from the rows the archive holds")
        #expect(pane.contains("compactMap(\\.source)"),
                "the kind options must come from the rows the archive holds")

        // A menu that names a role the app does not have is a menu
        // that lies. = The roles are named in the role table, = and
        // the archive's roles are whatever actually ran.
        for role in ["researcher", "writer", "analyst", "librarian", "archivist", "auditor"] {
            #expect(!pane.contains("\"\(role)\""),
                    "the pane must not hardcode the role \(role) in its filter options")
        }
    }

    @Test("an archive the filter emptied does not say the archive is empty")
    func aFilteredEmptyArchiveIsNotAnEmptyArchive() throws {
        let pane = try Self.paneSource

        // Two empties, = and they are different facts. = An archive
        // with nothing in it is empty; = an archive whose rows the
        // filter hid is not, = and saying "nothing has run" then is
        // a message that lies about the work the agents did.
        #expect(pane.contains("settings.archive.filteredEmpty"),
                "the pane must have a message for an archive the filter emptied")
        #expect(pane.contains("totalCount"),
                "and it must know how many rows the archive holds before any filter")
        #expect(pane.contains("totalCount == 0"),
                "and the two empties must be told apart by that count")

        // The catalog must carry the new message in both languages.
        let catalog = try Self.catalog
        let entry = try #require(catalog["settings.archive.filteredEmpty"] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: Any])
        #expect(localizations["en"] != nil, "the key must have an English value")
        #expect(localizations["zh-Hans"] != nil, "the key must have a Chinese value")
    }
}
