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
import ImageIO
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

    /// The card id of the book doc whose file lives at `fileURL`.
    ///
    /// A book doc's card id is DERIVED from where its file lives
    /// (= the book it belongs to + the folder it sits in + the file
    /// name), so a delete path that knows the file's location names
    /// the card without holding the derived id.
    ///
    /// Nil when the path does not name a book doc (= the layout is
    /// not the library's = shelves/<shelf>/books/<book>/<folder>/<file>.md),
    /// because a card that cannot be named must never be named by
    /// guesswork. The reconciler reads the live cards from the same
    /// layout, so ONE rule decides both what a card is and what a
    /// cover belongs to.
    nonisolated static func bookDocId(forBookDocFileAt fileURL: URL) -> UUID? {
        let folder = fileURL.deletingLastPathComponent()
        let book = folder.deletingLastPathComponent()
        guard book.deletingLastPathComponent().lastPathComponent == "books",
              let bookId = UUID(uuidString: book.lastPathComponent),
              fileURL.pathExtension == "md" else { return nil }
        return BookDocIDFactory.make(
            bookId: bookId,
            folderName: folder.lastPathComponent,
            fileName: fileURL.lastPathComponent
        )
    }

    /// The cover key for the book doc whose file lives at `fileURL`.
    ///
    /// Nil when the path does not name a book doc, because a cover
    /// whose card cannot be named must never be removed by
    /// guesswork.
    nonisolated static func key(forBookDocFileAt fileURL: URL) -> String? {
        guard let id = bookDocId(forBookDocFileAt: fileURL) else { return nil }
        return key(forBookDoc: id)
    }

    // MARK: - Directory

    /// The file names one card's cover folder holds.
    ///
    /// They are named ONCE, here: the door that reads a folder and the
    /// walk that warms a whole library both decide a cover by them, and
    /// two spellings of a file name is how a cover stops existing for
    /// one of them.
    nonisolated static let imageFileName = "cover.heic"
    nonisolated static let clipFileName = "cover.mp4"
    nonisolated static let recordFileName = "cover.json"

    /// The directory that holds every cover, under the active library.
    ///
    /// Nil when no library is picked yet, which is the onboarding
    /// state: there is no cover without a library to put it in.
    ///
    /// `nonisolated` because it is path arithmetic on
    /// `ActiveLibrary.path`, which is itself nonisolated: the cover
    /// walk needs these paths off the main thread, and a main-actor
    /// hop is exactly what this feature is paying down.
    nonisolated static var coversRoot: URL? {
        guard let path = ActiveLibrary.path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("covers", isDirectory: true)
    }

    /// The directory for one card's cover files.
    nonisolated static func directory(forKey key: String) -> URL? {
        coversRoot?.appendingPathComponent(key, isDirectory: true)
    }

    /// The path of one card's stored banner.
    nonisolated static func imageURL(forKey key: String) -> URL? {
        directory(forKey: key)?.appendingPathComponent(imageFileName)
    }

    /// The path of one card's stored clip.
    nonisolated static func videoURL(forKey key: String) -> URL? {
        directory(forKey: key)?.appendingPathComponent(clipFileName)
    }

    /// The path of one card's cover record.
    nonisolated static func recordURL(forKey key: String) -> URL? {
        directory(forKey: key)?.appendingPathComponent(recordFileName)
    }

    // MARK: - Reading

    /// Everything one card's cover currently holds, in ONE library.
    ///
    /// The picture's own file decides whether there is a cover: a
    /// cover whose file is gone is no cover, and the card falls back
    /// to its gradient and symbol. The record carries the rest
    /// (= the state, the last failure).
    ///
    /// The answer is held in memory, because the material zone asks
    /// about every card on every render, and the disk is not the
    /// place to answer that question a hundred times a second.
    ///
    /// The first question about a key this process has never read is
    /// still answered from the disk on the caller's thread, and it
    /// cannot be otherwise: a view body reads synchronously. What
    /// changed is that the cold question is now asked ONCE for the
    /// whole column instead of once per card, and that the rest of the
    /// column is read off the main thread the moment the first cold
    /// ask happens (= `CoverIndex.prefill`).
    ///
    /// THE ROOT IS A PARAMETER, NOT SOMETHING THIS LOOKUP FETCHES. A
    /// warm column answers from memory, and if the lookup also had to
    /// ask which library is active it would pay a UserDefaults read
    /// plus a bookmark decode per card, per render, on the drawing
    /// thread - preparation, which Apple says the draw must not do:
    /// "Rely on previously prepared data in draw(_:), don't perform
    /// I/O or complex calculations in this method". So a column resolves
    /// the covers folder ONCE for the pass and hands the same value to
    /// every card. The root-resolving form below exists for a SINGLE
    /// ask and is not this door's shape (= a column that loops it pays
    /// twenty-four decodes where it owes one).
    func entry(forKey key: String, root: URL?) -> CoverEntry {
        if let cached = CoverEntryCache.shared.entry(forKey: key, root: root) {
            return cached
        }
        return readCold(forKey: key, root: root)
    }

    /// Every card of one column, from ONE covers folder.
    ///
    /// The shape a grid's body pays once per render instead of once per
    /// card, and the shape the counting suite drives because it is the
    /// only one whose library lookups can be bounded: twenty-four cards
    /// answered from memory cost ONE lookup and zero disk asks.
    func entries(forKeys keys: [String], root: URL?) -> [CoverEntry] {
        let held = CoverEntryCache.shared.entries(forKeys: keys, root: root)
        var answers: [CoverEntry] = []
        answers.reserveCapacity(keys.count)
        for (key, cached) in zip(keys, held) {
            answers.append(cached ?? readCold(forKey: key, root: root))
        }
        return answers
    }

    /// The cold half of the door: ask the folder, hold the answer, and
    /// kick the walk that keeps the rest of the column off the frame.
    ///
    /// Reachable only when nothing holds the key, which is once per card
    /// per library per cache generation, and never on a warm pass.
    private func readCold(forKey key: String, root: URL?) -> CoverEntry {
        CoverIndex.shared.prefill()
        let entry = Self.readEntry(forKey: key)
        CoverEntryCache.shared.store(entry, forKey: key, root: root)
        return entry
    }

    /// The stored answer for one card in the active library.
    ///
    /// The single-ask door, for the callers that ask about ONE card (a
    /// generation, a removal, a menu), where one lookup of the library
    /// is neither a frame's cost nor avoidable. A loop over this is the
    /// defect: a column asks `entries(forKeys:root:)` or resolves the
    /// root once and calls `entry(forKey:root:)`.
    func entry(forKey key: String) -> CoverEntry {
        entry(forKey: key, root: Self.coversRoot)
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

    /// Whether the stored picture is the shape the app draws in.
    ///
    /// The picture's shape changed when the card became the App
    /// Store's shape (= a 4:3 tile with the words on it). A picture
    /// from before that is the wrong shape, and the new tile trims a
    /// third of it, so it has to be drawn again.
    ///
    /// The rule is self-limiting: the new picture has the new shape,
    /// so a document is never asked for a third one.
    ///
    /// The picture's own size is read from the file's header, so the
    /// check costs a few bytes and not a decode.
    func coverPictureIsCurrent(forKey key: String) -> Bool {
        guard let file = Self.imageURL(forKey: key),
              FileManager.default.fileExists(atPath: file.path),
              let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int
        else {
            return false
        }
        return width == CardCoverImageEncoder.bannerWidth
            && height == CardCoverImageEncoder.bannerHeight
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
    func saveImage(
        _ data: Data,
        forKey key: String,
        kind: String,
        motifs: CoverMotifs? = nil
    ) throws {
        guard let directory = Self.directory(forKey: key),
              let imageURL = Self.imageURL(forKey: key)
        else {
            throw CardCoverError.noLibrary
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.atomicWrite(data, to: imageURL)
        CoverImageCache.shared.evict(for: imageURL)

        // A clip belongs to the still it was made from. A new still
        // makes the old clip wrong (= the card would play a clip of
        // another picture), so it goes.
        //
        // The `clip` below is what the folder says AFTER the delete, and
        // not what this call meant: a delete that threw leaves the file,
        // and an entry that denies a file the disk still holds is a card
        // that cannot play its own cover until something re-reads it.
        var clip: URL?
        if let videoURL = Self.videoURL(forKey: key),
           FileManager.default.fileExists(atPath: videoURL.path)
        {
            try? FileManager.default.removeItem(at: videoURL)
            if FileManager.default.fileExists(atPath: videoURL.path) {
                clip = videoURL
            }
        }

        var record = record(forKey: key) ?? CoverRecord(cardKind: kind)
        record.cardKind = kind
        record.status = WSCardCoverStatus.staticReady
        record.lastError = nil
        // The clip belonged to the still that was just replaced, and
        // its file is gone (= the card would play a clip of another
        // picture), so the clip's state goes with it.
        record.clipStatus = WSCardCoverStatus.clipNone
        record.clipError = nil
        record.motifs = motifs ?? record.motifs
        record.updatedAt = .now
        try writeRecord(record, forKey: key)
        // The write publishes its own answer: the picture this call just
        // wrote is there, the clip it just deleted is not, and the
        // record is the one it just wrote. The card the announcement
        // wakes up reads THAT, and asks the disk nothing (= the old
        // shape dropped the entry and made that card go and re-read the
        // folder, on the main thread, inside its own body).
        publish(CoverEntry(imageURL: imageURL, videoURL: clip, record: record), forKey: key)
    }

    /// Stores a card's clip and writes its record.
    func saveVideo(_ data: Data, forKey key: String) throws {
        guard let directory = Self.directory(forKey: key),
              let videoURL = Self.videoURL(forKey: key)
        else {
            throw CardCoverError.noLibrary
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.atomicWrite(data, to: videoURL)

        var record = record(forKey: key) ?? CoverRecord(cardKind: WSCardCoverKind.reference)
        // The clip's state is its own: the still's state says nothing
        // about the clip, and the card's failure mark follows the
        // still.
        record.clipStatus = WSCardCoverStatus.clipReady
        record.clipError = nil
        record.clipAttemptAt = .now
        record.updatedAt = .now
        try writeRecord(record, forKey: key)
        // The writer publishes. The still is the one the entry already
        // named (= `record(forKey:)` above read it, or the door read the
        // folder and held it), and the clip is the file this call wrote.
        let still = CoverEntryCache.shared.entry(forKey: key, root: Self.coversRoot)?.imageURL
        publish(CoverEntry(imageURL: still, videoURL: videoURL, record: record), forKey: key)
    }

    /// Writes a card's record.
    func writeRecord(_ record: CoverRecord, forKey key: String) throws {
        guard let directory = Self.directory(forKey: key),
              let recordURL = Self.recordURL(forKey: key)
        else {
            throw CardCoverError.noLibrary
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(record)
        try Self.atomicWrite(data, to: recordURL)
        publishRecord(record, forKey: key)
    }

    // MARK: - Removing

    /// Removes a card's moving cover: the clip and the clip's state.
    ///
    /// The PICTURE stays: the user liked the picture, and the motion
    /// is what they are getting rid of. A removal that takes the
    /// picture too is a different removal (= `removeCover`).
    ///
    /// The record carries the clip's state, so a card whose record
    /// still says the clip is ready would show the motion mark with
    /// nothing to play.
    ///
    /// Safe to call when the card has no clip, and safe to call twice.
    func removeVideo(forKey key: String) throws {
        let existing = record(forKey: key)
        let video = Self.videoURL(forKey: key)
        if let video, FileManager.default.fileExists(atPath: video.path) {
            try FileManager.default.removeItem(at: video)
        }
        // The entry is published either way: the card asks the entry for
        // its clip, and the entry must not keep a file that is gone.
        // Dropping the entry instead (= the old shape) sent the next
        // render to the folder, on the main thread.
        let held = entry(forKey: key)
        guard var record = existing else {
            publish(
                CoverEntry(imageURL: held.imageURL, videoURL: nil, record: held.record),
                forKey: key
            )
            return
        }
        record.clipStatus = WSCardCoverStatus.clipNone
        record.clipError = nil
        record.clipAttemptAt = nil
        record.updatedAt = .now
        try writeRecord(record, forKey: key)
        publish(
            CoverEntry(imageURL: held.imageURL, videoURL: nil, record: record),
            forKey: key
        )
    }

    /// Removes a card's cover: its picture, its clip and its record.
    ///
    /// The whole DIRECTORY is removed rather than the two recorded
    /// files, so a partial file from a failed generation cannot
    /// survive. The document itself is never touched: the cover is a
    /// child of the document, and this removes the child.
    ///
    /// Safe to call when there is no cover, and safe to call twice.
    func removeCover(forKey key: String) throws {
        if let image = Self.imageURL(forKey: key) {
            CoverImageCache.shared.evict(for: image)
        }
        guard let directory = Self.directory(forKey: key),
              FileManager.default.fileExists(atPath: directory.path)
        else {
            // Nothing on the disk and nothing the card may keep: the
            // empty answer IS the answer, so it is published rather
            // than left for the next render to go and discover.
            publish(.none, forKey: key)
            return
        }
        try FileManager.default.removeItem(at: directory)
        publish(.none, forKey: key)
    }

    // MARK: - Disk

    /// Reads one card's cover from the disk: ONE listing of its folder.
    ///
    /// It used to be three asks (= an existence check per file, plus a
    /// read of the record whether or not the folder was even there), and
    /// every one of them was paid on whichever thread asked, which for
    /// the material column is the main thread. A listing answers all
    /// three questions at once: which files this cover folder holds.
    ///
    /// `nonisolated` because `CoverIndex` reads the same way for a whole
    /// library on a background task, and two readers of one folder
    /// layout is how a cover stops being found by one of them.
    nonisolated static func readEntry(forKey key: String) -> CoverEntry {
        guard let directory = directory(forKey: key) else { return .none }
        CoverDiskCounting.note(.metadata)
        let held = ((try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []).map(\.lastPathComponent)
        guard !held.isEmpty else { return .none }
        return CoverEntry(
            imageURL: held.contains(imageFileName) ? imageURL(forKey: key) : nil,
            videoURL: held.contains(clipFileName) ? videoURL(forKey: key) : nil,
            record: held.contains(recordFileName) ? readRecord(forKey: key) : nil
        )
    }

    /// Reads one card's record from the disk.
    nonisolated static func readRecord(forKey key: String) -> CoverRecord? {
        guard let url = recordURL(forKey: key) else { return nil }
        CoverDiskCounting.note(.bytes)
        return record(decodedFrom: try? Data(contentsOf: url))
    }

    /// Decodes a cover record's bytes, when there are any.
    ///
    /// The decoder is built here rather than held as a shared instance:
    /// a `JSONDecoder` is a mutable object, and the covers walk decodes
    /// on a background task while the app's own writes decode on the
    /// main actor.
    nonisolated static func record(decodedFrom data: Data?) -> CoverRecord? {
        guard let data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CoverRecord.self, from: data)
    }

    // MARK: - Publishing

    /// Publishes what a write left on the disk, so the next card that
    /// asks is answered from memory.
    ///
    /// The OLD shape was `evict`: drop the held answer and let the next
    /// render go and read the folder back. That is a disk read inside
    /// the view body, on the main thread, and it landed on exactly the
    /// frame the cover's own announcement had just woken up (= the
    /// symptom commit b5f34f59e0 named: "the card asks the disk again").
    ///
    /// A writer knows the answer without asking: it wrote the file.
    func publish(_ entry: CoverEntry, forKey key: String) {
        CoverEntryCache.shared.store(entry, forKey: key, root: Self.coversRoot)
    }

    /// Publishes a record write over the entry the app already holds.
    ///
    /// A record write changes no file's existence, so the presence half
    /// of the answer is whatever the held entry says. A key nothing
    /// holds stays unheld: inventing presence from a record write is how
    /// a card gets a cover it does not have, and the door reads the
    /// folder once in that case, which is what it is for.
    private func publishRecord(_ record: CoverRecord, forKey key: String) {
        guard let held = CoverEntryCache.shared.entry(forKey: key, root: Self.coversRoot) else {
            CoverEntryCache.shared.evict(forKey: key, root: Self.coversRoot)
            return
        }
        publish(
            CoverEntry(imageURL: held.imageURL, videoURL: held.videoURL, record: record),
            forKey: key
        )
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
