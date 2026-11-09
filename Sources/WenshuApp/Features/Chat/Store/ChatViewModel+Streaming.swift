// ChatViewModel+Streaming.swift = part of ChatViewModel, = = moved out of ChatSessionViewModel.swift.
// The members below keep their own comments; = = the class's stored
// properties stay in ChatViewModel.swift (= = an extension cannot hold them).

import Foundation
import WenshuData

extension ChatViewModel {
    /// Run the librarian's `curate` procedure and show what it found.
    ///
    /// The run is deterministic (= the analyser's own code, = no
    /// model), = and it reports; = it never deletes. = The report
    /// lands in the conversation as the librarian's own message, =
    /// because it is the librarian's output, = and it is written to
    /// the session as well, = because a report the user has to run
    /// again after a restart is a report that reads as never having
    /// happened.
    func runCuration() async {
        let runner = LibrarianCurationRunner(
            library: await ReferenceLibraryTool.shared.libraryActor
        )
        let outcome = await runner.run()

        let content: String
        switch outcome {
        case let .reported(report):
            content = LibrarianCurationRunner.text(for: report)
        case let .failed(reason):
            content = "The curation run could not read the library: \(reason)"
        }

        let message = ChatMessage(
            role: .agentResult,
            source: .agentResult,
            content: content
        )
        messages.append(message)

        // Persist it, = so the report survives a restart.
        try? await repository.append(message, sessionId: sessionId, bookID: currentBookID)
    }

    /// Write one coalesced batch into the streaming message.
    ///
    /// The accumulator is updated in place, and the message is rebuilt once
    /// from the accumulated parts. Rebuilding is cheap here because the
    /// accumulator already holds the finished text: the cost that used to
    /// matter was re-parsing and re-copying per token, and that is gone.
    func applyStreamBatch(
        _ batch: StreamBatch,
        placeholderId: UUID,
        accumulator: StreamingAccumulator
    ) {
        if !batch.text.isEmpty {
            accumulator.appendText(batch.text)
        }
        if !batch.reasoning.isEmpty {
            accumulator.appendReasoning(batch.reasoning)
        }
        // The trace marker is lifted once it is complete, so the reader
        // sees the reasoning as its own block rather than as part of the
        // answer.
        accumulator.liftTraceMarker()
        for block in batch.blocks {
            switch block {
            case let .toolUse(id, name, input):
                accumulator.appendPart(.toolUse(id: ToolCallID(rawValue: id), name: name, args: input))
            case let .toolResult(toolUseID, output):
                accumulator.appendPart(.toolResult(toolUseID: ToolCallID(rawValue: toolUseID), content: output, isError: false))
            case .text, .thinking:
                break
            }
        }
        guard let idx = messages.firstIndex(where: { $0.id == placeholderId }) else { return }
        // The message is updated in place rather than replaced. Replacing
        // an element of the observed array tells the view that the row
        // is a different row, so the row is rebuilt on every frame: the
        // text jumps, the animations restart, and the reader sees a
        // flicker. Writing the changed fields of the same message keeps
        // the row's identity, so only the text is drawn again.
        messages[idx].content = ChatMessagePart.joinedText(accumulator.parts)
        messages[idx].thinking = accumulator.snapshotThinking()
        messages[idx].parts = accumulator.snapshotParts()
        messages[idx].streamState = .streaming
    }

    /// Cancels the streaming reply (= the ⌘. handler). It is a no-op when
    /// nothing is streaming.
    func cancelStreaming() {
        cancelRequested = true
    }

    /// Copies the picked file into the library's attachment folder. The copy
    /// itself is delegated to the data layer (= LiveChatRepository).
    @discardableResult
    func attachImage(at sourceURL: URL) async -> Bool {
        // Config lookup: the business layer reads the app config from
        // `ActiveLibrary` (= the canonical single source of truth for the `.ws`
        // library URL, bound to the security-scoped bookmark via
        // `LibraryBookmark`). This is a config query (= not IO); the directory
        // creation and the file copy live in `LiveChatRepository`.
        guard let libraryPath = ActiveLibrary.path, !libraryPath.isEmpty else { return false }
        // Delegate the actual copy to the data layer.
        let destPath: String?
        do {
            destPath = try await repository.copyChatUpload(
                sourceURL: sourceURL,
                intoLibraryAt: libraryPath
            )
        } catch {
            Self.logSwallowedPersistenceFailure(operation: "copyChatUpload", error: error)
            return false
        }
        guard let destPath else { return false }
        attachedImagePath = destPath
        return true
    }

    /// Clears the pending image draft (= called when the user clicks the small ✕
    /// on the preview chip, or after the send).
    func clearAttachedImage() {
        attachedImagePath = nil
    }
}
