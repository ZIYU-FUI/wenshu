//
//  Features/Cover/Model/CardCoverService.swift
//
//   : CardCoverService.
//  Owns the cover directory and the cover row.
//
//  Where the bytes live:
//
//    <active library>/assets/covers/<cardKey>/cover.heic
//    <active library>/assets/covers/<cardKey>/cover.mp4
//
//  The `assets/` directory already exists in a real library and was
//  unused. The covers go there rather than beside the document,
//  because a document's own directory is the reference library's or
//  the book's, and a generated picture does not belong in a folder of
//  the user's writing.
//
//  The CARD KEY is the one place that decides which cover belongs to
//  which card, and it deliberately namespaces the two card kinds, so a
//  reference card and a book card can never land on one key. Every
//  other part of the feature resolves a card's key through here
//  rather than building one, because two key functions produce two
//  different keys, and the symptom is a cover that belongs to the
//  wrong card (or to no card at all).
//
//  The row and the files are kept in step: writing a cover writes
//  the file and upserts the row, and removing a cover removes both.
//

import Foundation
import SwiftData
import WenshuData

/// The cover directory and the cover row.
@MainActor
struct CardCoverService {

    /// The service's store, for the cover rows.
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Keys

    /// The cover key for a reference card.
    static func key(forReference id: UUID) -> String {
        "\(WSCardCoverKind.reference)-\(id.uuidString)"
    }

    /// The cover key for a book-doc card.
    static func key(forBookDoc id: UUID) -> String {
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

    // MARK: - Rows

    /// The cover row for a key, if there is one.
    func row(forKey key: String) -> WSCardCover? {
        let descriptor = FetchDescriptor<WSCardCover>(
            predicate: #Predicate { $0.id == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Every cover row.
    func allRows() -> [WSCardCover] {
        (try? modelContext.fetch(FetchDescriptor<WSCardCover>())) ?? []
    }

    // MARK: - Writing

    /// Stores a card's banner and upserts its row.
    ///
    /// The file is written atomically, so a crash mid-write cannot
    /// leave a half-written banner where the row claims a picture
    /// exists.
    func saveImage(_ data: Data, forKey key: String, kind: String) throws {
        guard let directory = Self.directory(forKey: key) else {
            throw CardCoverError.noLibrary
        }
        guard let imageURL = Self.imageURL(forKey: key) else {
            throw CardCoverError.noLibrary
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.atomicWrite(data, to: imageURL)

        let existing = row(forKey: key)
        if let existing {
            existing.imagePath = imageURL.path
            existing.status = WSCardCoverStatus.staticReady
            existing.lastError = nil
            existing.updatedAt = .now
        } else {
            modelContext.insert(
                WSCardCover(
                    id: key,
                    cardKind: kind,
                    imagePath: imageURL.path,
                    status: WSCardCoverStatus.staticReady
                )
            )
        }
        try modelContext.save()
    }

    /// Stores a card's clip and updates its row.
    func saveVideo(_ data: Data, forKey key: String) throws {
        guard let directory = Self.directory(forKey: key),
              let videoURL = Self.videoURL(forKey: key) else {
            throw CardCoverError.noLibrary
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.atomicWrite(data, to: videoURL)

        let existing = row(forKey: key)
        existing?.videoPath = videoURL.path
        existing?.status = WSCardCoverStatus.dynamicReady
        existing?.lastError = nil
        existing?.updatedAt = .now
        try modelContext.save()
    }

    // MARK: - Removing

    /// Removes a card's cover row and its files.
    ///
    /// The whole DIRECTORY is removed rather than the two recorded
    /// files, so a partial file from a failed generation cannot
    /// survive. The document itself is never touched: the cover is a
    /// child of the document, and this removes the child.
    ///
    /// Safe to call when there is no cover, and safe to call twice.
    func removeCover(forKey key: String) throws {
        if let existing = row(forKey: key) {
            modelContext.delete(existing)
            try modelContext.save()
        }
        guard let directory = Self.directory(forKey: key),
              FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        try FileManager.default.removeItem(at: directory)
    }

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
