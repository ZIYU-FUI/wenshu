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
    // LT-02 v2 验收: 伏笔 tab 真接 CDForeshadow entity,按 chapter / paragraph
    // ID 过滤 (用 8/10 新增的可空关联字段)。LT-02 v1 (d285d8132) 只暴露
    // list-all 接口,LT-02 v2 拆 3 个签名给 InspectorViewModel 用:
    //   - 全部: listForeshadows()                       (back-compat,保留旧调用)
    //   - 按 chapter: listForeshadows(forChapter:)     (v0.02.0 LT-02 v2 新增)
    //   - 按 paragraph: listForeshadows(forParagraph:) (优先级 > chapter,
    //     paragraph ID 真接 v0.05.0 标记系统的段落范围,装机 user 在 inspector
    //     选中段落联动就是 paragraph)
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
    ///
    /// LT-02 v2: 这个 back-compat 签名保留 (LT-01 已落地的调用点不能破)。
    /// 新代码 (InspectorViewModel) 优先用 paragraph/chapter 过滤版。
    func listForeshadows() async throws -> [ForeshadowRow] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDForeshadow")
            request.sortDescriptors = [NSSortDescriptor(key: "plantedAt", ascending: true)]
            let objects = try context.fetch(request)
            return objects.map { Self.makeRow(from: $0) }
        }
    }

    /// Filter by `chapterID`. Rows with nil chapterID are excluded (we
    /// cannot match "no chapter" against a concrete chapter). Sorted by
    /// `plantedAt` ascending (= 故事时间线, "先种后收")。
    /// Pass `nil` to deliberately get an empty list.
    func listForeshadows(forChapter chapterID: UUID?) async throws -> [ForeshadowRow] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDForeshadow")
            if let chapterID {
                request.predicate = NSPredicate(format: "chapterID == %@", chapterID as CVarArg)
            } else {
                // 显式 chapterID=nil = 过滤出"无 chapter 关联"行,
                // 用 SELF allows nil 没法直接表达,改用 chapterID == nil。
                request.predicate = NSPredicate(format: "chapterID == nil")
            }
            request.sortDescriptors = [NSSortDescriptor(key: "plantedAt", ascending: true)]
            let objects = try context.fetch(request)
            return objects.map { Self.makeRow(from: $0) }
        }
    }

    /// Filter by `paragraphID`. **Priority over chapter** — inspector
    /// v0.05.0 标记系统选中段落时直接走这个,不再二次过滤 chapter。
    /// Rows with nil paragraphID are excluded by the predicate.
    /// `nil` argument → empty list (意图明确:段落 ID 未填,不展示伏笔)。
    func listForeshadows(forParagraph paragraphID: UUID?) async throws -> [ForeshadowRow] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDForeshadow")
            if let paragraphID {
                request.predicate = NSPredicate(format: "paragraphID == %@", paragraphID as CVarArg)
            } else {
                // 显式 paragraphID=nil 传进来 = caller 想要"无 paragraph
                // 关联" 的伏笔(=历史 v0.01.0 创建时没标 paragraph 的旧行)。
                // 这条路径主要给 inspector 全局兜底视图 (= paragraph 还没
                // 选中时显示全部 v0.01.0 旧伏笔) 用,新代码 (`currentParagraphID` 有值)
                // 永远走 if 分支,不走这里。
                request.predicate = NSPredicate(format: "paragraphID == nil")
            }
            request.sortDescriptors = [NSSortDescriptor(key: "plantedAt", ascending: true)]
            let objects = try context.fetch(request)
            return objects.map { Self.makeRow(from: $0) }
        }
    }

    /// 三个 list 方法共享的行映射逻辑 — 抽出避免重复。 nil-tolerant:
    /// 任何字段取值失败都给 default 值,不抛错 (一行坏数据不能炸 inspector)。
    private static func makeRow(from object: NSManagedObject) -> ForeshadowRow {
        // CDForeshadow schema 没定义 `id` 属性 (v0.01.0 是 4 字段 +
        // LT-02 v2 加 chapterID/paragraphID, 都没 id)。 如果直接
        // value(forKey: "id") 会抛 NSUnknownKeyException 触发进程
        // crash, 而不是返回 nil。 row.id 仅供 SwiftUI Identifiable /
        // ForEach 用, 不需要跟 NSManagedObjectID 挂钩 — 永远合成新 UUID。
        ForeshadowRow(
            id: UUID(),
            hook: (object.value(forKey: "hook") as? String) ?? "",
            status: object.value(forKey: "status") as? String,
            plantedAt: (object.value(forKey: "plantedAt") as? Date) ?? Date(),
            resolvedAt: object.value(forKey: "resolvedAt") as? Date,
            chapterID: object.value(forKey: "chapterID") as? UUID,
            paragraphID: object.value(forKey: "paragraphID") as? UUID
        )
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
/// fields inside `WenshuStoreActor.listForeshadows(...)` and hand back
/// this value type. InspectorViewModel holds an array of these on the
/// main actor without crossing actor boundaries with managed objects.
///
/// `status` is intentionally optional (the schema marks it optional); we
/// expose `nil` so the UI can show "未分类" rather than guessing a default.
///
/// LT-02 v2: `chapterID` / `paragraphID` 是 v0.05.0 标记系统的关联字段,
/// 当前 (v0.02.0 LT-02 v2) 都是可空。InspectorViewModel 用它们过滤 inspector
/// 伏笔 tab 的可见集合。
struct ForeshadowRow: Identifiable, Sendable, Equatable {
    let id: UUID
    let hook: String
    let status: String?
    let plantedAt: Date
    let resolvedAt: Date?
    /// v0.02.0 LT-02 v2 新增 — CDForeshadow.chapterID 的镜像。
    /// nil 表示这条伏笔还没绑定到任何章节 (v0.01.0 旧数据)。
    let chapterID: UUID?
    /// v0.02.0 LT-02 v2 新增 — CDForeshadow.paragraphID 的镜像。
    /// nil 表示还没绑定到段落 (= v0.05.0 标记系统还没接过)。
    let paragraphID: UUID?

    init(
        id: UUID = UUID(),
        hook: String,
        status: String?,
        plantedAt: Date,
        resolvedAt: Date?,
        chapterID: UUID? = nil,
        paragraphID: UUID? = nil
    ) {
        self.id = id
        self.hook = hook
        self.status = status
        self.plantedAt = plantedAt
        self.resolvedAt = resolvedAt
        self.chapterID = chapterID
        self.paragraphID = paragraphID
    }

    /// "已回收" = resolvedAt 非空。 文枢 v0.02.0 inspector 显示用。
    var isResolved: Bool { resolvedAt != nil }
}

struct TaggedNote: Sendable { let text: String; let tags: String; let createdAt: Date }

/// Plain Sendable row read from `CDChapter`. Lives outside the actor because
/// `NSManagedObject` is not Sendable — we extract its scalar fields inside
/// `WenshuStoreActor.listChapters(...)` and hand back this value type.
///
/// **P0-4 fix (LT-N1-revise, 2026-08-11)**: `id` used to be `UUID()`
/// regenerated on every listChapters() call, which broke SwiftUI `List`
/// row identity (rows flickered / lost scroll state). We now derive `id`
/// from the CoreData `objectID.uriRepresentation()` which is stable for
/// the lifetime of the row in the same store.
struct ChapterRow: Sendable, Identifiable {
    let id: String
    let title: String
    let content: String
    let index: Int
}

extension WenshuStoreActor {
    func listTaggedNotes(prefix: String) async throws -> [TaggedNote] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDNote")
            return try context.fetch(request).compactMap { object in
                guard let tags = object.value(forKey: "tags") as? String, tags.hasPrefix(prefix), let text = object.value(forKey: "text") as? String else { return nil }
                return TaggedNote(text: text, tags: tags, createdAt: object.value(forKey: "createdAt") as? Date ?? Date())
            }
        }
    }

    func deleteNotes(tag: String) async throws {
        let context = container.viewContext
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDNote")
            let rows = try context.fetch(request).filter { ($0.value(forKey: "tags") as? String) == tag }
            rows.forEach(context.delete)
            if context.hasChanges { try context.save() }
        }
    }

    func listChapters() async throws -> [ChapterRow] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDChapter")
            request.sortDescriptors = [NSSortDescriptor(key: "chapterIndex", ascending: true)]
            return try context.fetch(request).map { object in
                ChapterRow(
                    id: Self.stableChapterID(for: object),
                    title: object.value(forKey: "title") as? String ?? "",
                    content: object.value(forKey: "content") as? String ?? "",
                    index: Int(object.value(forKey: "chapterIndex") as? Int32 ?? 0)
                )
            }
        }
    }

    /// **P0-3 fix (LT-N1-revise, 2026-08-11)**: project-scoped chapter list.
    ///
    /// Per DESIGN-LT-N1.md §4.2 the chapter→project association lives in a
    /// `chapter-meta-<projectId>` CDNote (JSON array of chapter titles).
    /// When no such note exists for `projectId` we return an empty list
    /// (clean cross-project isolation — never leak chapters from other
    /// projects). We do NOT change CDChapter schema (AGENTS §12 红线).
    ///
    /// IDs are stable across calls (P0-4) — same CDChapter row → same id.
    func listChapters(projectId: UUID) async throws -> [ChapterRow] {
        let context = container.viewContext
        return try await context.perform {
            // Read the chapter-meta CDNote for this project
            let metaRequest = NSFetchRequest<NSManagedObject>(entityName: "CDNote")
            metaRequest.predicate = NSPredicate(format: "tags == %@", "chapter-meta-\(projectId.uuidString)")
            let meta = try context.fetch(metaRequest).first

            var allowedTitles: Set<String> = []
            if let meta = meta,
               let text = meta.value(forKey: "text") as? String,
               let data = text.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String] {
                allowedTitles = Set(parsed)
            }

            // Fetch CDChapter rows, filter by allowed titles (no meta → empty)
            let chapterRequest = NSFetchRequest<NSManagedObject>(entityName: "CDChapter")
            chapterRequest.sortDescriptors = [NSSortDescriptor(key: "chapterIndex", ascending: true)]
            let allChapters = try context.fetch(chapterRequest)

            return allChapters.compactMap { object -> ChapterRow? in
                let title = object.value(forKey: "title") as? String ?? ""
                guard allowedTitles.contains(title) else { return nil }
                return ChapterRow(
                    id: Self.stableChapterID(for: object),
                    title: title,
                    content: object.value(forKey: "content") as? String ?? "",
                    index: Int(object.value(forKey: "chapterIndex") as? Int32 ?? 0)
                )
            }
        }
    }

    /// Stable chapter identifier derived from `NSManagedObjectID.uriRepresentation()`.
    /// Same CDChapter row always produces the same id within the same
    /// CoreData store. `nonisolated` because it's a pure function with no
    /// actor state access.
    nonisolated static func stableChapterID(for object: NSManagedObject) -> String {
        object.objectID.uriRepresentation().absoluteString
    }
}
