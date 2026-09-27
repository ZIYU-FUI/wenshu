//
//  EditChapterTool.swift · wenshu · edit-chapter-tool 2026-09-28
//
//  Thin tool-call wrapper around EditChapterActor (= hermes 0.21.5
//  `edit_file` 1:1). Surfaces the JSON envelope through the standard
//  ToolRegistry path so the LLM can call `book_edit_chapter`.
//  Mirrors BookChapterTool's shared-singleton + module-load
//  ToolRegistry bootstrap pattern.
//
//  The success envelope carries the same kind:'diff' + diff block
//  + stats that BookChapterTool.update emits (= ChatToolDiffPreview's
//  input stays stable across both surfaces; = hermes tool-fallback.tsx
//  schema, 1:1).
//

import Foundation

/// Patch-style chapter edit tool (= hermes edit_file 1:1).
/// `actor:` is the underlying `EditChapterActor`. The tool wrapper
/// forwards the JSON envelope to the actor's `execute(input:)`
/// entry point (= hermes-style tool-call dispatch).
actor EditChapterTool: Tool {
    let name = "book_edit_chapter"
    let description = "Patch-style chapter edit (= hermes edit_file 1:1): replace old_text with new_text inside the chapter body. Returns a unified-diff envelope so the chat preview can render the file card."

    private let actor: EditChapterActor

    init(actor: EditChapterActor) {
        self.actor = actor
    }

    func execute(input: String) async throws -> String {
        try await actor.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap

extension EditChapterTool {
    /// Module-load registration with `ToolRegistry.shared`.
    /// Mirrors BookChapterTool's `_registryBootstrap` (= a `Void`
    /// static let that fires a Task at module load to register the
    /// tool under the canonical name `book_edit_chapter`).
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "book_edit_chapter",
                toolset: "library",
                schema: ToolRegistrySchema(
                    name: "book_edit_chapter",
                    description: "Patch-style chapter edit (= hermes edit_file 1:1). Replaces old_text with new_text inside the chapter body. Returns a unified-diff envelope so the chat preview can render the file card.",
                    inputSchema: [
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Chapter id (UUID)."
                        ),
                        "book_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Owning book id (UUID)."
                        ),
                        "old_text": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Substring to replace (= must occur verbatim in the chapter body)."
                        ),
                        "new_text": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Replacement text."
                        ),
                        "summary": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional updated 1-line summary."
                        )
                    ],
                    required: ["id", "book_id", "old_text", "new_text"]
                ),
                handler: EditChapterTool.shared,
                description: "Patch-style chapter edit (= hermes edit_file 1:1).",
                emoji: "✏️"
            )
        }
    }()

    nonisolated static let shared: EditChapterTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-edit-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return EditChapterTool(
            actor: EditChapterActor(bookDirectoryProvider: { tmpRoot })
        )
    }()
}