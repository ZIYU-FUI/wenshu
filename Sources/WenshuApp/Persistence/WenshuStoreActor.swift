import CoreData
import Foundation

actor WenshuStoreActor {
    static let shared = WenshuStoreActor()

    let container: NSPersistentContainer

    init(container: NSPersistentContainer? = nil) {
        let persistentContainer = container ?? NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        if container == nil {
            let directory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("wenshu-projects", isDirectory: true)
            // Enable automatic lightweight migration so adding a new entity
            // (e.g. CDLayoutState in LT-01) doesn't break pre-existing .ws
            // SQLite files: CoreData will auto-infer the mapping model and
            // add the new table in place.
            let description = NSPersistentStoreDescription(url: directory.appendingPathComponent("Wenshu.sqlite"))
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
            persistentContainer.persistentStoreDescriptions = [description]
        }
        self.container = persistentContainer
        loadStoresIfNeeded()
    }

    /// Load the persistent stores attached to `container`. Idempotent —
    /// tests that already pre-loaded their in-memory store will short-
    /// circuit here. Marked `nonisolated` because actor init isn't yet
    /// `isolated`-eligible and this method only touches the already-set
    /// `container` stored property.
    ///
    /// WO-LT-01: previously the production actor never loaded stores
    /// (per WO-005 comment: "container's persistent store is NOT loaded
    /// this phase (in-memory only)"). LT-01 needs real on-disk
    /// round-trip for layout state to actually persist across
    /// app restarts. Errors are logged to stderr instead of throwing
    /// so a corrupt .ws file can't brick app launch.
    private nonisolated func loadStoresIfNeeded() {
        if !container.persistentStoreCoordinator.persistentStores.isEmpty {
            return
        }
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let err = loadError {
            FileHandle.standardError.write(Data(
                "WenshuStoreActor: loadPersistentStores failed: \(err)\n".utf8
            ))
        }
    }

    func createCharacter(_ values: [String: Any]) async throws {
        let context = container.viewContext
        try await context.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDCharacter", into: context)
            for (key, value) in values { object.setValue(value, forKey: key) }
            if object.value(forKey: "createdAt") == nil { object.setValue(Date(), forKey: "createdAt") }
        }
    }

    func listCharacters() async throws -> [String] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDCharacter")
            return try context.fetch(request).compactMap { $0.value(forKey: "name") as? String }
        }
    }

    func createNote(_ values: [String: Any]) async throws {
        let context = container.viewContext
        try await context.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDNote", into: context)
            for (key, value) in values { object.setValue(value, forKey: key) }
            if object.value(forKey: "createdAt") == nil { object.setValue(Date(), forKey: "createdAt") }
        }
    }

    func listNotes() async throws -> [String] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDNote")
            return try context.fetch(request).compactMap { $0.value(forKey: "text") as? String }
        }
    }

    func createWorldRule(_ values: [String: Any]) async throws {
        let context = container.viewContext
        try await context.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDWorldRule", into: context)
            for (key, value) in values { object.setValue(value, forKey: key) }
            if object.value(forKey: "createdAt") == nil { object.setValue(Date(), forKey: "createdAt") }
        }
    }

    func countAll() async throws -> Int {
        let context = container.viewContext
        return try await context.perform {
            try ["CDCharacter", "CDChapter", "CDNote", "CDWorldRule", "CDForeshadow", "CDRevision", "CDAIDraft"].reduce(0) { total, name in
                let request = NSFetchRequest<NSManagedObject>(entityName: name)
                let count = try context.count(for: request)
                return total + count
            }
        }
    }

    // MARK: - Foreshadows (LT-02 inspector 伏笔 tab)
    //
    // LT-02 验收: 伏笔 tab 真接 CDForeshadow entity 从 .ws 读。
    // 当前 CDForeshadow schema 没有 chapter 关联字段 (CC 不动 .ws schema,
    // AGENTS §12 红线), 所以这里返回所有 CDForeshadow 行 — 装机 user
    // 选中段落联动在 v0.05.0 标记系统阶段接。 排序按 plantedAt 升序
    // (= 故事时间线), 让用户看到"先种后收"的自然顺序。
    //
    // 返回类型是 plain Sendable 值类型 — NSManagedObject 跨 actor 边界
    // 不能 Sendable, 在 .perform {} 内同步取值后直接还 Sendable 值类型,
    // caller (InspectorViewModel) 在 MainActor 上安全持有。

    /// Insert one `CDForeshadow` row. 单测会塞 fixture, 留接口好复用。
    func createForeshadow(_ values: [String: Any]) async throws {
        let context = container.viewContext
        try await context.perform {
            let object = NSEntityDescription.insertNewObject(
                forEntityName: "CDForeshadow", into: context
            )
            for (key, value) in values { object.setValue(value, forKey: key) }
            if object.value(forKey: "plantedAt") == nil {
                object.setValue(Date(), forKey: "plantedAt")
            }
        }
    }

    /// Read all `CDForeshadow` rows, sorted by `plantedAt` ascending.
    /// Returns zero-value tuples on any decode failure (defensive — one
    /// bad row should not break inspector rendering).
    func listForeshadows() async throws -> [ForeshadowRow] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDForeshadow")
            request.sortDescriptors = [NSSortDescriptor(key: "plantedAt", ascending: true)]
            let objects = try context.fetch(request)
            return objects.map { object in
                ForeshadowRow(
                    hook: (object.value(forKey: "hook") as? String) ?? "",
                    status: object.value(forKey: "status") as? String,
                    plantedAt: (object.value(forKey: "plantedAt") as? Date) ?? Date(),
                    resolvedAt: object.value(forKey: "resolvedAt") as? Date
                )
            }
        }
    }

    /// Diagnostics / tests: how many `CDForeshadow` rows are persisted.
    func countForeshadows() async throws -> Int {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDForeshadow")
            return try context.count(for: request)
        }
    }

    // MARK: - Layout state (WO-LT-01)
    //
    // Per AGENTS.md §8.1 + LT-01 spec the entity carries exactly 2 string
    // columns. Callers (LayoutShellViewModel) hand us already-encoded JSON
    // strings, we store them as-is and read them back as-is. Decoding to
    // the strong-typed `LayoutSnapshot` is the View layer's responsibility.

    /// Insert-or-update the singleton `CDLayoutState` row with the given
    /// JSON strings. There is at most one row per .ws file (the active
    /// layout). Defers to the View layer to debounce calls — the actor
    /// always writes to disk synchronously after `context.save()`.
    func saveLayoutState(panelStatesJSON: String, panelRatiosJSON: String) async throws {
        let context = container.viewContext
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDLayoutState")
            request.fetchLimit = 1
            let existing = try context.fetch(request).first
            let object = existing ?? NSEntityDescription.insertNewObject(
                forEntityName: "CDLayoutState", into: context
            )
            object.setValue(panelStatesJSON, forKey: "panel_states")
            object.setValue(panelRatiosJSON, forKey: "panel_ratios")
            if context.hasChanges {
                try context.save()
            }
        }
    }

    /// Read the singleton `CDLayoutState` row (if any). Returns `nil` on
    /// first-launch (no row written yet). The returned strings are raw
    /// JSON; the caller decodes them via `LayoutSnapshot.decodeCollapsed`
    /// / `decodeRatios`.
    func loadLayoutState() async throws -> (panelStatesJSON: String, panelRatiosJSON: String)? {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDLayoutState")
            request.fetchLimit = 1
            guard let object = try context.fetch(request).first else {
                return nil
            }
            let states = (object.value(forKey: "panel_states") as? String) ?? ""
            let ratios = (object.value(forKey: "panel_ratios") as? String) ?? ""
            return (states, ratios)
        }
    }

    /// Diagnostics / tests: how many `CDLayoutState` rows are in the store.
    /// The `saveLayoutState(...)` contract is upsert-singleton, so this
    /// should be 0 or 1 — anything else indicates a regression.
    func countLayoutStates() async throws -> Int {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDLayoutState")
            return try context.count(for: request)
        }
    }
}

// MARK: - Foreshadow row (LT-02 inspector)

/// Plain Sendable row read from `CDForeshadow`. Lives outside the actor
/// because `NSManagedObject` is not Sendable — we extract its scalar
/// fields inside `WenshuStoreActor.listForeshadows()` and hand back
/// this value type. InspectorViewModel holds an array of these on the
/// main actor without crossing actor boundaries with managed objects.
///
/// `status` is intentionally optional (the schema marks it optional); we
/// expose `nil` so the UI can show "未分类" rather than guessing a default.
struct ForeshadowRow: Identifiable, Sendable, Equatable {
    let id: UUID
    let hook: String
    let status: String?
    let plantedAt: Date
    let resolvedAt: Date?

    init(
        id: UUID = UUID(),
        hook: String,
        status: String?,
        plantedAt: Date,
        resolvedAt: Date?
    ) {
        self.id = id
        self.hook = hook
        self.status = status
        self.plantedAt = plantedAt
        self.resolvedAt = resolvedAt
    }

    /// "已回收" = resolvedAt 非空。 文枢 v0.02.0 inspector 显示用。
    var isResolved: Bool { resolvedAt != nil }
}
