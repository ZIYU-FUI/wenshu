//
//  BookChapterToolRegistry.swift
//
//  ToolRegistry bootstrap extracted from BookChapterTool.swift
//  in A111 (= §6.6 600-LOC cap god-class split; = the ToolRegistry
//  schema block was 130 LOC of inline schema definitions).
//
//  Why a separate file (= and not in BookChapterTool.swift): the
//  ToolRegistry registration is 1 single concern (= the schema + the
//  module-load bootstrap that registers the tool with the global
//  ToolRegistry.shared); = splitting it out lets the next reader find
//  "where does book_chapter get registered with the LLM" by name; =
//  and it shrinks BookChapterTool.swift from 1045 LOC (= 1.74x the cap)
//  to ~915 LOC.
//
//  Per the §6.2 4-slot spec: this is the @Tool actor's bootstrap =
//  belongs in Service/ (= already is; = sibling of
//  BookChapterFileSystem.swift in the same Service/ dir).
//

import Foundation
import os

extension BookChapterTool {
    /// Module-load registration with `ToolRegistry.shared`.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "book_chapter",
                toolset: "library",
                schema: ToolRegistrySchema(
                    name: "book_chapter",
                    description: "Per-book chapter CRUD (= wraps FileSystemChapterStore). LLM-friendly verbs: create / read / update / delete / list / find. v2.7 round-61: the `create` action ALWAYS writes to the book's `drafts/` folder (= the boss's \"Agent 写正文一律先写草稿\" rule; = the user promotes drafts/ → chapters/ manually). The `update` action is BLOCKED when the target chapter lives in `chapters/` (= confirmed; = the user must explicitly approve). To write a new chapter, use `create` (= it goes to `drafts/`). To re-edit a draft, use `update` with the draft's id. To edit a confirmed chapter, ASK the user first; = the tool will return an error with a message for the user.",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The chapter operation to perform.",
                            enumValues: ["create", "read", "update", "delete", "list", "find"]
                        ),
                        "book_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Owning book id (UUID). Required for create / list / find."
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Chapter id (UUID). Required for read / update / delete."
                        ),
                        "title": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Chapter title. Required for create / find; for update replaces the chapter title."
                        ),
                        "summary": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional 1-line summary."
                        ),
                        "markdown": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Full .md body. Alias: 'body'."
                        )
                    ],
                    required: ["action"]
            ),
            handler: BookChapterTool.shared,
            description: "Per-book chapter CRUD.",
            emoji: "📖"
        )
        }
    }()

    nonisolated static let shared: BookChapterTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-chapter-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return BookChapterTool(
            actor: BookChapterActor(
                bookDirectoryProvider: { tmpRoot },
                currentChatBookIDProvider: { nil }
            )
        )
    }()

    // MARK: - Static FileSystem helpers (actor-safe; = the actor
    // can't instantiate the @MainActor-isolated FileSystemChapterStore struct, so the
    // CRUD methods above call these static helpers (= FileManager + JSONEncoder
    // are thread-safe).

    /// Write a NEW chapter to the legacy FileSystem path (.md file +
    /// chapters.json index update).
    static func saveFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        chaptersDirectory: URL
    ) throws {
        try Self.ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        try Self.atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)
    }

    /// Replace an EXISTING chapter (.md body + index row update).
    static func writeFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        chaptersDirectory: URL
    ) throws {
        try Self.ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        guard FileManager.default.fileExists(atPath: chapterURL.path) else {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        try Self.atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)
    }

    /// Delete a chapter (.md body remove).
    static func deleteFileSystemChapter(
        id: UUID,
        chaptersDirectory: URL
    ) throws {
        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            try FileManager.default.removeItem(at: chapterURL)
        }
    }

    private static func ensureChaptersDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private static func atomicWrite(_ data: Data, to url: URL) throws {
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
