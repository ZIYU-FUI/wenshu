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
        messages[idx].parts = Self.carryingReaderChoices(
            accumulator.snapshotParts(),
            over: messages[idx].parts
        )
        messages[idx].streamState = .streaming
    }

    /// Puts the reader's own choices back on the parts a stream frame
    /// produced.
    ///
    /// A frame replaces the parts array with the accumulator's copy, and
    /// that copy is built from the stream: it knows nothing about what the
    /// reader opened or closed. Apple's rule for a scrolling list is not to
    /// "depend on view state for data that needs to be kept alive after
    /// scrolling", and the same rule applies to a list that is rewritten
    /// every frame: a choice that belongs to the reader has to be carried
    /// across the rewrite, or the next token undoes it. The choice is
    /// matched by part id, which is what the row is keyed on, so a part
    /// that kept its identity keeps the reader's answer about it.
    static func carryingReaderChoices(
        _ incoming: [ChatMessagePart],
        over previous: [ChatMessagePart]
    ) -> [ChatMessagePart] {
        let closed = Set(previous.filter { !$0.isThinkingRevealed }.map(\.id))
        // Nothing was closed, so there is nothing to carry: the frame's own
        // parts are returned untouched, which keeps the common case (= a
        // reader who never collapsed a block) free of the copy below.
        guard !closed.isEmpty else { return incoming }
        return incoming.map { part in
            guard closed.contains(part.id) else { return part }
            var carried = part
            carried.isThinkingRevealed = false
            return carried
        }
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

    // MARK: - What the reader opened

    /// Records whether the reader has a thinking block open.
    ///
    /// The answer goes into the model, not into the row that drew it. The
    /// row is built again whenever the reply grows and is not built at all
    /// while the transcript scrolls it out of the viewport (= a
    /// `LazyVStack` realises the rows near the visible band only), so an
    /// answer kept in the row is lost with the row. `partID` names the
    /// block when the reply carries parts; nil is a legacy reply that keeps
    /// its thinking text on the message instead.
    func setThinkingRevealed(_ revealed: Bool, messageID: UUID, partID: UUID?) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageID }) else { return }
        guard let partID else {
            messages[messageIndex].isThinkingRevealed = revealed
            return
        }
        guard let partIndex = messages[messageIndex].parts.firstIndex(where: { $0.id == partID }) else {
            return
        }
        messages[messageIndex].parts[partIndex].isThinkingRevealed = revealed
    }
}
