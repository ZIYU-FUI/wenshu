//
//  Features/Cover/Model/CardCoverService.swift
//
//   : CardCoverService.
//  Owns the cover directory and the cover record.
//
//  Where the bytes live:
//
//    <active library>/assets/covers/<cardKey>/cover.heic
//    <active library>/assets/covers/<cardKey>/cover.mp4
//    <active library>/assets/covers/<cardKey>/cover.json
//
//  The `assets/` directory already exists in a real library and was
//  unused. The covers go there rather than beside the document,
//  because a document's own directory is the reference library's or
//  the book's, and a generated picture does not belong in a folder of
//  the user's writing.
//
//  The RECORD is a file too, beside the picture it describes. A cover
//  is a document's own data, so its record belongs to the document's
//  library. A store row cannot make that promise: the store the app
//  resolves at launch is not always the library the picture is written
//  to, because the app delegate activates the warehouse container
//  after the first view render. A record written before that point
//  and a picture written after it land in two different stores, and
//  the card then finds one without the other.
//
//  The CARD KEY is the one place that decides which cover belongs to
//  which card, and it deliberately namespaces the two card kinds, so a
//  reference card and a book card can never land on one key. Every
//  other part of the feature resolves a card's key through here
//  rather than building one, because two key functions produce two
//  different keys, and the symptom is a cover that belongs to the
//  wrong card (or to no card at all).
//
//  The picture and the record are read through ONE entry, held in
//  memory: the material zone asks about every card on every render,
//  and a grid that reads the disk per card per render is a grid that
//  stutters.
//

import Foundation
import WenshuData

/// The cover directory and the cover record.
@MainActor
struct CardCoverService {

    init() {}

    // MARK: - Keys

    /// The cover key for a reference card.
    ///
    /// `nonisolated` because the key is a PURE function of the card's
    /// identity: it does not touch the disk or the main actor, and
    /// the view layer needs it while building a card.
    nonisolated static func key(forReference id: UUID) -> String {
        "\(WSCardCoverKind.reference)-\(id.uuidString)"
    }

    /// The cover key for a book-doc card.
    nonisolated static func key(forBookDoc id: UUID) -> String {
        "\(WSCardCoverKind.bookDoc)-\(id.uuidString)"
    }

    // MARK: - Directory

    /// The directory that holds every cover, under the active library.
    ///
    /// Nil when no library is picked yet, which is the onboarding
    /// state: there is no cover without a library to put it in.
    static var coversRoot: URL? {
        guard let path = ActiveLibrary.path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("covers", isDirectory: true)
    }

    /// The directory for one card's cover files.
    static func directory(forKey key: String) -> URL? {
        coversRoot?.appendingPathComponent(key, isDirectory: true)
    }

    /// The path of one card's stored banner.
    static func imageURL(forKey key: String) -> URL? {
        directory(forKey: key)?.appendingPathComponent("cover.heic")
    }

    /// The path of one card's stored clip.
    static func videoURL(forKey key: String) -> URL? {
        directory(forKey: key)?.appendingPathComponent("cover.mp4")
    }

    /// The path of one card's cover record.
    static func recordURL(forKey key: String) -> URL? {
        directory(forKey: key)?.appendingPathComponent("cover.json")
    }

    // MARK: - Reading

    /// Everything one card's cover currently holds.
    ///
    /// The picture's own file decides whether there is a cover: a
    /// cover whose file is gone is no cover, and the card falls back
    /// to its gradient and symbol. The record carries the rest
    /// (= the state, the last failure).
    ///
    /// The answer is held in memory, because the material zone asks
    /// about every card on every render, and the disk is not the
    /// place to answer that question a hundred times a second.
    func entry(forKey key: String) -> CoverEntry {
        if let cached = CoverEntryCache.shared.entry(forKey: key) { return cached }
        let entry = readEntry(forKey: key)
        CoverEntryCache.shared.store(entry, forKey: key)
        return entry
    }

    /// The stored banner for a card, or nil when the card has no
    /// cover.
    func coverImageURL(for key: String) -> URL? {
        entry(forKey: key).imageURL
    }

    /// The stored clip for a card, or nil when the card has no moving
    /// cover.
    func coverVideoURL(for key: String) -> URL? {
        entry(forKey: key).videoURL
    }

    /// The record that describes a card's cover, or nil when the card
    /// has none.
    func record(forKey key: String) -> CoverRecord? {
        entry(forKey: key).record
    }

    /// Every cover key the library holds.
    ///
    /// The folders under the covers root are the covers: a key with
    /// a folder has a cover, and a key without one has nothing to
    /// clean up.
    func storedKeys() -> [String] {
        guard let root = Self.coversRoot else { return [] }
        let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return (contents ?? [])
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .map { $0.lastPathComponent }
            .sorted()
    }

    // MARK: - Writing

    /// Stores a card's banner and writes its record.
    ///
    /// The file is written atomically, so a crash mid-write cannot
    /// leave a half-written banner where the record claims a picture
    /// exists.
    func saveImage(_ data: Data, forKey key: String, kind: String) throws {
        guard let directory = Self.directory(forKey: key),
              let imageURL = Self.imageURL(forKey: key) else {
            throw CardCoverError.noLibrary
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.atomicWrite(data, to: imageURL)
        CoverImageCache.shared.evict(for: imageURL)

        var record = record(forKey: key) ?? CoverRecord(cardKind: kind)
        record.cardKind = kind
        record.status = WSCardCoverStatus.staticReady
        record.lastError = nil
        record.updatedAt = .now
        try writeRecord(record, forKey: key)
    }

    /// Stores a card's clip and writes its record.
    func saveVideo(_ data: Data, forKey key: String) throws {
        guard let directory = Self.directory(forKey: key),
              let videoURL = Self.videoURL(forKey: key) else {
            throw CardCoverError.noLibrary
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.atomicWrite(data, to: videoURL)

        var record = record(forKey: key) ?? CoverRecord(cardKind: WSCardCoverKind.reference)
        record.status = WSCardCoverStatus.dynamicReady
        record.lastError = nil
        record.updatedAt = .now
        try writeRecord(record, forKey: key)
    }

    /// Writes a card's record.
    func writeRecord(_ record: CoverRecord, forKey key: String) throws {
        guard let directory = Self.directory(forKey: key),
              let recordURL = Self.recordURL(forKey: key) else {
            throw CardCoverError.noLibrary
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(record)
        try Self.atomicWrite(data, to: recordURL)
        CoverEntryCache.shared.evict(forKey: key)
    }

    // MARK: - Removing

    /// Removes a card's cover: its picture, its clip and its record.
    ///
    /// The whole DIRECTORY is removed rather than the two recorded
    /// files, so a partial file from a failed generation cannot
    /// survive. The document itself is never touched: the cover is a
    /// child of the document, and this removes the child.
    ///
    /// Safe to call when there is no cover, and safe to call twice.
    func removeCover(forKey key: String) throws {
        CoverEntryCache.shared.evict(forKey: key)
        if let image = Self.imageURL(forKey: key) {
            CoverImageCache.shared.evict(for: image)
        }
        guard let directory = Self.directory(forKey: key),
              FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        try FileManager.default.removeItem(at: directory)
    }

    // MARK: - Disk

    /// Reads one card's cover from the disk.
    private func readEntry(forKey key: String) -> CoverEntry {
        let image = Self.imageURL(forKey: key)
        let video = Self.videoURL(forKey: key)
        let record = Self.readRecord(forKey: key)
        let hasImage = image.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let hasVideo = video.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        return CoverEntry(
            imageURL: hasImage ? image : nil,
            videoURL: hasVideo ? video : nil,
            record: record
        )
    }

    /// Reads one card's record from the disk.
    private static func readRecord(forKey key: String) -> CoverRecord? {
        guard let url = recordURL(forKey: key),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(CoverRecord.self, from: data)
    }

    // MARK: - Encoding

    /// The encoder for a cover record.
    ///
    /// ISO 8601 dates, so a record in the library is readable.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    /// The decoder for a cover record.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Atomic write

    /// Writes bytes so a reader never sees a partial file.
    static func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
        let fd = open(url.path, O_RDONLY)
        if fd >= 0 {
            fsync(fd)
            close(fd)
        }
    }
}

/// The cover entries the app already read.
///
/// The material zone renders a grid of cards, and every card asks
/// what its cover holds on every render. Holding the answer in memory
/// turns that from a disk read per card per render into a dictionary
/// lookup, which is what keeps a scroll smooth.
///
/// The lock is there so the cache can be dropped from anywhere (= a
/// library change), not only from the main actor.
final class CoverEntryCache: @unchecked Sendable {

    /// The one cache the app reads covers through.
    static let shared = CoverEntryCache()

    private let lock = NSLock()
    private var entries: [String: CoverEntry] = [:]

    /// The entry for a key, or nil when the key was never read.
    func entry(forKey key: String) -> CoverEntry? {
        lock.withLock { entries[key] }
    }

    /// Holds an entry.
    func store(_ entry: CoverEntry, forKey key: String) {
        lock.withLock { entries[key] = entry }
    }

    /// Drops an entry, so the next read goes to the disk.
    func evict(forKey key: String) {
        lock.withLock { entries.removeValue(forKey: key) }
    }

    /// Drops every entry.
    ///
    /// The app calls this when the library changes: a cover belongs to
    /// the library it was read from, so what the app remembers about
    /// the old library's covers is of no use to the new one.
    func removeAll() {
        lock.withLock { entries.removeAll() }
    }
}

/// The failures the cover service can raise.
enum CardCoverError: LocalizedError {
    case noLibrary

    var errorDescription: String? {
        switch self {
        case .noLibrary:
            return "No library is open, so a cover cannot be stored."
        }
    }
}
