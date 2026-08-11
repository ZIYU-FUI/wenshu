// WenshuProjectStore.swift · 文枢 (Wenshu) · v0.01.0 WO-005
//
// Thin wrapper over `WenshuStoreActor` for the v0.01.0 8-step user journey.
// Persists the current ChatViewModel state (project + characters + world
// rules + initial story) into the WenshuStoreActor.
//
// Per WO-005 spec:
//   - Triggered when user clicks "返回项目" in CharacterWorldView
//   - Storage path: `~/Documents/wenshu-projects/` (created on init)
//   - AGENTS §7: storeURL is set on the container, but the container's
//     persistent store is NOT loaded this phase (in-memory only).
//     SQLite round-trip + cross-device copy lands in v0.02.0.
//
// Why a separate actor (not just inlined into ChatViewModel)?
//   - Reusable from non-VM callers (e.g. project list reload after restart,
//     scheduled exports, etc. — none exist yet, but the boundary is cheap)
//   - Testable in isolation: tests inject a custom WenshuStoreActor with an
//     in-memory persistent store, exactly like `WenshuStoreActorTests` does
//
// Threading: this is an `actor`, all writes serialize through it. The init
// itself is fully synchronous (only touches `FileManager`); the persistence
// methods are async because they delegate to `WenshuStoreActor`.

import Foundation

actor WenshuProjectStore {

    /// Process-wide singleton. Lazy-initialized; first access triggers the
    /// `~/Documents/wenshu-projects/` directory creation.
    static let shared = WenshuProjectStore()

    /// Underlying CoreData serializer. Injected for tests; defaults to the
    /// shared store actor (which uses the on-disk SQLite URL but does NOT
    /// load the store this phase).
    ///
    /// LT-N2 改 visibility: `private` → `internal` (默认), 让
    /// `WenshuProjectStore+LTN2.swift` 扩展能调 `storeActor.listNotes*`
    /// / `deleteNotes` / `countChatNotes`。 不影响运行时行为, 只影响
    /// 模块内可见性。 现有调用方 (本文件内的 save / count / firstSavedStory /
    /// savedCharacterNames) 全部仍是同一 module 内访问, 行为不变。
    let storeActor: WenshuStoreActor

    /// Absolute URL of the projects directory. `nonisolated let` because
    /// `URL` is `Sendable` and we want callers (UI, diagnostics) to read it
    /// without `await`.
    nonisolated let directoryURL: URL

    init(storeActor: WenshuStoreActor? = nil) {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("wenshu-projects", isDirectory: true)
        self.directoryURL = directory
        self.storeActor = storeActor ?? .shared
        ensureDirectoryExists()
    }

    /// Synchronously make sure the projects directory exists on disk. Called
    /// from init so that `swift run` followed by any user interaction leaves
    /// the directory behind (WO-005 verification criterion).
    ///
    /// Marked `nonisolated` because actor init is itself nonisolated and
    /// Swift 6 won't let init call actor-isolated instance methods on self.
    /// Safe to mark: only touches the `nonisolated let directoryURL` and
    /// `FileManager`, no mutable actor state.
    private nonisolated func ensureDirectoryExists() {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            // Diagnostic only — if this fails (sandbox, permission, etc.),
            // subsequent CoreData writes will surface their own error.
            FileHandle.standardError.write(Data(
                "WenshuProjectStore: failed to create \(directoryURL.path): \(error)\n".utf8
            ))
        }
    }

    // MARK: - Save

    /// Persist a project's snapshot to the store. Writes:
    ///   - 1 `CDNote`  (the user's one-sentence story)
    ///   - N `CDCharacter` rows (1 主角 + 2 配角 per WO-004 mock)
    ///   - N `CDWorldRule` rows (4 per WO-004 mock)
    ///
    /// No chapter rows this phase (正文 editor is post-v0.01.0).
    func save(
        project: ProjectSnapshot,
        characters: [CharacterSnapshot],
        worldRules: [WorldRuleSnapshot],
        initialStory: String
    ) async throws {
        // 1. Initial story → CDNote. Tag with project id so future loaders
        //    can scope queries per project (v0.02.0 work).
        try await storeActor.createNote([
            "text": initialStory,
            "tags": "project-\(project.id.uuidString)",
            "createdAt": Date()
        ])
        // 2. Characters → CDCharacter rows.
        for character in characters {
            try await storeActor.createCharacter([
                "name": character.name,
                "role": character.role,
                "backstory": character.backstory,
                "createdAt": Date()
            ])
        }
        // 3. World rules → CDWorldRule rows.
        for rule in worldRules {
            try await storeActor.createWorldRule([
                "rule": rule.rule,
                "category": rule.category,
                "createdAt": Date()
            ])
        }
    }

    // MARK: - Diagnostics

    /// Total entities saved so far (across all entity types and all projects).
    /// Used by tests + future `pm-doctor` style diagnostics.
    func savedEntityCount() async throws -> Int {
        try await storeActor.countAll()
    }

    /// Read back the first saved story text (for tests + future "last project"
    /// header). Returns nil if no notes exist.
    func firstSavedStory() async throws -> String? {
        let stories = try await storeActor.listNotes()
        return stories.first
    }

    /// Read back all saved character names. Convenience for tests + future
    /// "characters in current project" rendering. Thin pass-through to the
    /// underlying store actor; kept here so callers don't need to know about
    /// `WenshuStoreActor` (private to this module).
    func savedCharacterNames() async throws -> [String] {
        try await storeActor.listCharacters()
    }

    /// Directory path as a String. Convenience for logs / acceptance docs.
    nonisolated func directoryPath() -> String {
        directoryURL.path
    }
}
