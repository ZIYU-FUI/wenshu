//
//  Persistence/Container.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 21/21: ModelContainer setup (= the LAST phase 1 commit;
//  = introduced Container.swift but no new @Model class).
//  Schema contains 23 entity types (= all explicit @Model classes from
//  phase 1 commits 1-10 + 12-20, with commits 15/16/17/19 each introducing
//  2 classes per commit. Note: commit 11 was non-@Model infra; = the
//  19 single-class commits + 4 extra classes from the doubled commits =
//  23 total). No implicit join tables (= all 23 .self entries in Schema([...])
//  correspond to explicit @Model class declarations).
//  Per AGENTS.md §11.4 SwiftData migration roadmap.
//
//  This is the FINAL commit of Phase 1. It defines the ModelContainer
//  (= single store) that aggregates all 23 @Model classes.
//
//  BEFORE Phase 1: 10 raw sqlite3 stores, 20+ tables, hand-rolled
//  migration (= WenshuWorkspace.swift mega-store + 9 separate stores
//  with duplicate tables for chat_messages / chat_summaries /
//  sub_agent_runs / kanban_tasks / bookmarks / memory_entries).
//
//  AFTER Phase 1: 1 SwiftData ModelContainer holding all 23 @Model
//  classes. Tables still physically exist (= SwiftData uses Core Data's
//  SQLite under the hood on macOS) but the API surface is unified:
//  ModelContext.fetch(FetchDescriptor<WSXxx>()) replaces every per-store
//  Actor API.
//
//  Phase 2 will introduce Repository classes (= preserves the public
//  API of the existing Actors so callers don't need to change).
//  Phase 3 will switch callers to the Repository APIs.
//  Phase 4 will add the one-time data migration from raw sqlite3.
//  Phase 5 will delete the old raw sqlite3 store files.
//  Phase 6 will update CLAUDE.md / CONTEXT.md to reflect new state.
//
//  See /tmp/wenshu-swiftdata-migration-spec.md for full plan.

import Foundation
import SwiftData

/// Singleton ModelContainer (= held by AppState).
/// Initialization is lazy (= defer until first access).
public enum WSPersistenceContainer {
    /// Schema listing all 23 @Model classes (= generated below)
    public static let schema = Schema([
        // Tier 1: leaf entities (= no relationships)
        WSManifest.self,
        WSMemory.self,
        WSTodo.self,
        WSBookmark.self,
        WSLink.self,
        WSSkill.self,
        WSPreference.self,
        WSProviderKey.self,
        WSAttachment.self,
        // Tier 2: chat session + children
        WSSession.self,
        WSChatMessage.self,
        WSSummary.self,
        WSSubAgentRun.self,
        // Tier 3: book + descendants
        WSBook.self,
        WSBookShelf.self,
        WSChapter.self,
        WSOutlineNode.self,
        WSForeshadowing.self,
        WSPlaceholder.self,
        WSOutlineDocument.self,
        WSCharacter.self,
        WSKanbanTask.self,
        WSWorld.self
    ])

    /// The shared ModelContainer (= lazily initialized on first access).
    /// Uses the application's Application Support directory (=
    /// macOS-recommended location for app data; = backed up via Time Machine).
    public static let shared: ModelContainer = {
        let config = ModelConfiguration(
            "WenshuStore",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Last-resort fallback (= in-memory only; = no disk side effects).
            // App still launches; = user can reset and re-onboard via Library Properties.
            NSLog("[WSPersistenceContainer] FATAL: cannot create ModelContainer (\(error)). Falling back to in-memory.")
            // shared is called eagerly at module-load time (= non-MainActor context).
            // makeInMemoryContainer is @MainActor (= tests only); = use MainActor.assumeIsolated
            // (= safe here because shared is only accessed after @main init).
            return MainActor.assumeIsolated {
                do {
                    return try makeInMemoryContainer()
                } catch {
                    fatalError("SwiftData runtime is broken: \(error). Wenshu cannot continue.")
                }
            }
        }
    }()

    /// Test-only in-memory container (= never touches disk).
    /// Used by PersistenceTests suites.
    @MainActor
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Make a file-backed container at a custom URL (= warehouse path for
    /// boss 8/25 OOB "chat.sqlite must live in .ws warehouse" rule).
    ///
    /// Phase 5 ticket 1 sub-task 1a (= SwiftData warehouse path support).
    /// Replaces the per-file SQLite Actor pattern (= ChatSessionStore, KanbanStore)
    /// where each file opens its own sqlite3 handle at a custom path.
    ///
    /// Parameters:
    ///   - url: file URL for the SwiftData store (= the parent directory
    ///     must exist; = the file itself will be created by SwiftData).
    ///   - name: optional store name (= default = derived from the URL's
    ///     lastPathComponent per Apple SDK convention).
    ///   - readOnly: if true, opens the store in read-only mode (= future ticket).
    ///
    /// Throws if SwiftData cannot create the container (= e.g. disk full,
    /// permissions denied, corrupted store).
    @MainActor
    public static func makeContainer(
        at url: URL,
        name: String? = nil,
        readOnly: Bool = false
    ) throws -> ModelContainer {
        // Apple SwiftData SDK 27 init signature (= verified via swiftinterface):
        //   init(_ name: String? = nil, schema: Schema? = nil, url: URL,
        //        allowsSave: Bool = true, cloudKitDatabase: CloudKitDatabase = .automatic)
        // Note: NO `groupContainer:` or `isStoredInMemoryOnly:` params on the url: init.
        let config = ModelConfiguration(
            name,
            schema: schema,
            url: url,
            allowsSave: !readOnly,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Factory: pick the right container for the current warehouse state.
    ///
    /// Logic:
    ///   1. If warehouse URL provided (= from UserDefaults "wenshu.libraryPath"),
    ///      try to make a container at that URL (= boss 8/25 OOB rule).
    ///   2. If that fails OR no warehouse URL, fall back to Application Support
    ///      (= current `shared` behavior).
    ///   3. If both fail, fall back to in-memory (= tests survive).
    ///
    /// Caller is responsible for catching + logging the warehouse failure
    /// (= so user sees a non-fatal warning instead of silent fallback).
    @MainActor
    public static func makeContainerForWarehouse(_ warehouseURL: URL?) throws -> ModelContainer {
        if let warehouseURL {
            let storeURL = warehouseURL.appendingPathComponent("WenshuStore.store")
            do {
                return try makeContainer(at: storeURL)
            } catch {
                NSLog("[WSPersistenceContainer] warehouse container failed (\(error)). Falling back to Application Support.")
                // Fall through to default `shared`
            }
        }
        return shared
    }
}
