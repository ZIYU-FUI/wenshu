// FileSystemCharacterStore.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Per-Book character storage layer (= ticket 005 of the FCP library
// replica spec).
//
// Storage path (= per spec v5):
//   <.ws>/shelves/<shelf-uuid>/books/<book-uuid>/
//     characters/<char-uuid>.md     <- free-form markdown biography
//     characters.json                <- index = [Character] (with id +
//                                      structured fields; the .md body
//                                      holds the free-form bio)
//
// Book-private (= each Book has its own characters/ folder; no
// cross-book sharing). Character struct (ticket 002) holds structured
// metadata; the .md body holds free-form character biography.
//
// Implementation pattern matches FileSystemWorldStore (= ticket 004)
// with identical atomic-write + Codable JSON + id-based identity.

import Foundation

// MARK: - Protocol

protocol CharacterStoring: Sendable {
    /// The book's directory URL.
    var bookDirectory: URL { get }

    /// Returns the parsed `characters.json` index. Missing = [],
    /// corrupt = [] (Apple HIG forgiving-reset).
    func loadCharacters() throws -> [Character]

    /// Persist the Character (= creates the .md body + appends to the
    /// index). First-save-wins.
    func saveCharacter(_ character: Character, bodyMarkdown: String) throws

    /// Update an existing character in place.
    func replaceCharacter(_ character: Character, bodyMarkdown: String) throws

    /// Remove a character. Idempotent.
    func deleteCharacter(id: UUID) throws

    /// Read the raw .md body for a given character. Returns nil if the
    /// .md file doesn't exist.
    func loadCharacterBody(id: UUID) -> String?

    /// Look up a single character by id. Returns nil if not found.
    func characterExists(id: UUID) -> Bool
}

// MARK: - Errors

enum CharacterStoreError: Error, LocalizedError {
    case characterAlreadyExists(id: UUID)
    case characterNotFound(id: UUID)
    case bookDirectoryMissing(path: String)

    var errorDescription: String? {
        switch self {
        case .characterAlreadyExists(let id):
            return "Character \(id.uuidString) already exists on disk."
        case .characterNotFound(let id):
            return "Character \(id.uuidString) not found on disk."
        case .bookDirectoryMissing(let path):
            return "Book directory does not exist: \(path). Cannot save characters."
        }
    }
}

// MARK: - FileSystem implementation

struct FileSystemCharacterStore: CharacterStoring {
    let bookDirectory: URL

    private var charactersDirectory: URL {
        bookDirectory.appendingPathComponent("characters", isDirectory: true)
    }

    private var indexURL: URL {
        bookDirectory.appendingPathComponent("characters.json")
    }

    // MARK: CharacterStoring

    func loadCharacters() throws -> [Character] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            return try JSONDecoder().decode([Character].self, from: data)
        } catch {
            return []
        }
    }

    func saveCharacter(_ character: Character, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw CharacterStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureCharactersDirectoryExists()

        let charURL = character.onDiskPath(under: bookDirectory)
        if FileManager.default.fileExists(atPath: charURL.path) {
            throw CharacterStoreError.characterAlreadyExists(id: character.id)
        }

        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: charURL)

        var current = (try? loadCharacters()) ?? []
        current.append(character)
        try writeIndex(current)
    }

    func replaceCharacter(_ character: Character, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw CharacterStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureCharactersDirectoryExists()

        let charURL = character.onDiskPath(under: bookDirectory)
        guard FileManager.default.fileExists(atPath: charURL.path) else {
            throw CharacterStoreError.characterNotFound(id: character.id)
        }

        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: charURL)

        var current = (try? loadCharacters()) ?? []
        guard let idx = current.firstIndex(where: { $0.id == character.id }) else {
            throw CharacterStoreError.characterNotFound(id: character.id)
        }
        current[idx] = character
        try writeIndex(current)
    }

    func deleteCharacter(id: UUID) throws {
        let url = bookDirectory
            .appendingPathComponent("characters")
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var current = (try? loadCharacters()) ?? []
        current.removeAll { $0.id == id }
        try writeIndex(current)
    }

    func loadCharacterBody(id: UUID) -> String? {
        let url = bookDirectory
            .appendingPathComponent("characters")
            .appendingPathComponent("\(id.uuidString).md")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func characterExists(id: UUID) -> Bool {
        let url = bookDirectory
            .appendingPathComponent("characters")
            .appendingPathComponent("\(id.uuidString).md")
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: Private helpers

    private func ensureCharactersDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: charactersDirectory.path) {
            try FileManager.default.createDirectory(
                at: charactersDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
    }

    private func writeIndex(_ characters: [Character]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(characters)
        try atomicWrite(data, to: indexURL)
    }
}