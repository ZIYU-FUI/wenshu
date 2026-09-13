//
//  Persistence/Container.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 21 of 21 @Model classes: ModelContainer setup.
//  Per AGENTS.md §11.4 SwiftData migration roadmap.
//
//  This is the FINAL commit of Phase 1. It defines the ModelContainer
//  (= single store) that aggregates all 20 @Model classes.
//
//  BEFORE Phase 1: 10 raw sqlite3 stores, 20+ tables, hand-rolled
//  migration (= WenshuWorkspace.swift mega-store + 9 separate stores
//  with duplicate tables for chat_messages / chat_summaries /
//  sub_agent_runs / kanban_tasks / bookmarks / memory_entries).
//
//  AFTER Phase 1: 1 SwiftData ModelContainer holding all 20 @Model
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
}
