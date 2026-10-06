//
//  Persistence/ModelsSchema.swift
//
//  SwiftData VersionedSchema namespace for wenshu.
//
//  Per the 2026-10-06 macOS system-upgrade-style library upgrade arc
//  (boss OOB 'FCP 风格库升级' = visible progress panel + auto retry).
//  Container.swift previously used a bare Schema([22 classes]) without
//  versioning (= no migration path; = SwiftData would fatal on any
//  schema field change). VersionedSchema namespaces give SwiftData a
//  per-stage checksum so it can drive SchemaMigrationPlan and route
//  lightweight or custom migrations.
//
//  Two schema snapshots at the moment (= both == current 22 @Model
//  classes, because v1 of the .ws layout has not yet introduced a
//  breaking change to the SwiftData layer):
//  - ModelsSchemaV1 = the schema as it shipped in v1 of the post-SwiftData
//    migration wenshu (= the state captured in Container.swift:63-99
//    prior to this commit). Persistent on user disks today.
//  - ModelsSchemaV2 = identical to V1 today. When a real schema delta
//    lands (= e.g. a new field, an optional default, a renamed entity),
//    V2's `models` array and the schema enum bodies diverge from V1.
//    Lightweight migration runs automatically for additive changes; = a
//    custom stage is required for renames or deletions.
//
//  Per Apple WWDC24 'Model your schema with SwiftData' + WWDC23 sample
//  (SampleTripsSchemaV1/V2/V3 pattern), each VersionedSchema is a
//  top-level enum that namespaces its model list. The 22 @Model classes
//  themselves stay file-scope (= in Sources/WenshuApp/Persistence/
//  WS*.swift) so this commit touches 1 file. Each VersionedSchema
//  references the file-scope types via .self = distinct Swift type
//  identity from each schema's namespace per Apple guidance
//  (github.com/awizemann/harness/wiki/SwiftData-Migrations).
//
//  Container.swift is intentionally NOT modified in this commit (= the
//  Container cutover to MigrationPlan is the next ticket; = 1 commit
//  1 ticket per the Q112 standing rule).

import Foundation
import SwiftData

/// VersionedSchema snapshot of the 22 @Model classes as they shipped
/// in v1 of the post-SwiftData migration wenshu. Persistent on user
/// disks today. Bump CURRENT_SCHEMA_VERSION and add ModelsSchemaV2
/// divergence when the next breaking schema change ships.
enum ModelsSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    /// The 22 @Model class types at v1. Order is informational
    /// (= matches the tier grouping in Container.swift:63-99). SwiftData
    /// computes its per-stage checksum from the type set, not the order.
    static var models: [any PersistentModel.Type] {
        [
            // Tier 1: leaf entities (= no relationships)
            WSManifest.self,
            WSMemory.self,
            WSTodo.self,
            WSBookmark.self,
            WSLink.self,
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
            WSKanbanTask.self,
            WSEntity.self,
            WSBody.self,
            WSOutlineEntry.self,
            WSReference.self,
            // Tier 4: workspace layout tree (= 2026-10-05 #9 commit 1)
            WSLayoutTreeState.self,
            WSLayoutNode.self,
            WSPaneNode.self,
            WSTabSpec.self
        ]
    }
}

/// VersionedSchema snapshot at v2 (= identical to V1 today; = the
/// placeholder for the next real schema delta). When a real delta
/// ships, this enum's model list diverges from V1 (= e.g. a new field
/// in WSBook), and SchemaMigrationPlan routes lightweight migration
/// automatically.
enum ModelsSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    /// The 22 @Model class types at v2 (= same as V1 today). When a
    /// breaking change lands, this list changes (= additions are
    /// picked up by lightweight migration; = renames or deletions
    /// require a custom MigrationStage in WenshuMigrationPlan).
    static var models: [any PersistentModel.Type] {
        [
            // Tier 1: leaf entities (= no relationships)
            WSManifest.self,
            WSMemory.self,
            WSTodo.self,
            WSBookmark.self,
            WSLink.self,
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
            WSKanbanTask.self,
            WSEntity.self,
            WSBody.self,
            WSOutlineEntry.self,
            WSReference.self,
            // Tier 4: workspace layout tree (= 2026-10-05 #9 commit 1)
            WSLayoutTreeState.self,
            WSLayoutNode.self,
            WSPaneNode.self,
            WSTabSpec.self
        ]
    }
}
