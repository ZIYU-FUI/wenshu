// Sources/WenshuApp/Editor/EditorScrollMemory.swift
//
// Host-side persistence layer for the engine's scroll-memory
// surfaces (= T-13). The engine exposes 3 closures
// (= `onPersistScrollOffset` / `restoreScrollOffset` /
// `retainedScrollDocumentIds`) for the host to wire to a backing
// store. Wenshu persists scroll offsets to a small JSON file
// (= canonical Apple HIG "remember what you were reading"
// behavior = Pages / Numbers reopens at the last scroll position).
//
// Storage shape (= JSON `File` keyed by document id; = the value is
// the persisted Y-offset in points; = persisted offsets decay
// gracefully = if a document is deleted, = the persisted offset is
// orphaned but never surfaces back to the engine = the host's
// `restoreScrollOffset` returns nil = the engine keeps the default
// top-of-document scroll position).
import Foundation

/// Scroll-memory persistence layer (= JSON-backed = keyed by
/// document id). `onAppear` registers the persistence callbacks
/// against the engine (= the engine calls `onPersistScrollOffset`
/// on every scroll; = the host writes the JSON file via
/// `EditorScrollMemory.persist(_:for:)`). `restoreScrollOffset`
/// reads the JSON file (= if a document id was never seen, =
/// return nil so the engine falls back to top-of-document).
struct EditorScrollMemory: Sendable {
    /// Document id set to retain scroll for (= the engine's
    /// `retainedScrollDocumentIds` parameter; = nil = retain all;
    /// = wenshu's default = nil = the engine retains scroll for
    /// every document the host app shows the engine up to).
    static let retainedDocumentIds: Set<String>? = nil

    /// JSON file URL (= wenshu's app-support / scroll-memory.json;
    /// = the canonical Apple HIG "remember what you were reading"
    /// pattern = the engine's closure callbacks wire to this file
    /// via `EditorScrollMemory.persist` and
    /// `EditorScrollMemory.restore`).
    static func fileURL() -> URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = support.appendingPathComponent("com.wenshu.app", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("scroll-memory.json")
    }

    /// Persist the offset (= engine calls this on every scroll
    /// event). Writes synchronously to the JSON file (= the host
    /// can debounce later if needed; = today the file is small =
    /// <= 100 entries = no debounce required).
    static func persist(_ offset: CGFloat, for documentId: String) {
        var map = readMap()
        map[documentId] = Double(offset)
        writeMap(map)
    }

    /// Restore the offset (= engine calls this on every view
    /// appearance). Returns nil if the document id was never seen
    /// (= the engine falls back to top-of-document).
    static func restore(for documentId: String) -> CGFloat? {
        let map = readMap()
        guard let value = map[documentId] else { return nil }
        return CGFloat(value)
    }

    // MARK: - File I/O (= private; = small synchronous read/write
    // of the JSON map).

    /// Read the entire map (= or an empty map if the file doesn't
    /// exist or fails to decode).
    private static func readMap() -> [String: Double] {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode(
            [String: Double].self, from: data
        )) ?? [:]
    }

    /// Write the entire map (= overwrites the file; = the file is
    /// small = <= 100 entries; = atomic-write not needed for this
    /// scale).
    private static func writeMap(_ map: [String: Double]) {
        let url = fileURL()
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: url, options: .atomic)
    }
}