import Foundation
import WenshuAgent
import WenshuData

// A reference-type accumulator for the streaming LLMBlock callback. It is a
// reference type because the callback is @Sendable, and the value
// `snapshotParts()` returns is safe to pass across actor boundaries.

final class StreamingAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var _parts: [ChatMessagePart] = []
    private var _thinking: String = ""
    var parts: [ChatMessagePart] {
        get { lock.lock(); defer { lock.unlock() }; return _parts }
        set { lock.lock(); defer { lock.unlock() }; _parts = newValue }
    }

    var thinking: String {
        get { lock.lock(); defer { lock.unlock() }; return _thinking }
        set { lock.lock(); defer { lock.unlock() }; _thinking = newValue }
    }

    /// Takes a thread-safe snapshot of `parts` (= a copy that is safe to pass
    /// across the actor boundary at the message-replacement site).
    func snapshotParts() -> [ChatMessagePart] {
        lock.lock(); defer { lock.unlock() }
        return _parts
    }

    func snapshotThinking() -> String {
        lock.lock(); defer { lock.unlock() }
        return _thinking
    }

    /// Append text to the trailing text part, or start one.
    ///
    /// The streaming path used to rebuild the whole parts array per chunk,
    /// which copied every part written so far on every chunk. Appending in
    /// place keeps the cost proportional to the new text.
    ///
    /// The trailing part is EXTENDED, not replaced. Replacing it would
    /// mint a fresh id (= the `.text(_:)` factory builds one), and the id
    /// is what SwiftUI keys the row on, so the row would be torn down and
    /// built again on every chunk (= once per frame, = = 60 times a
    /// second while a reply streams).
    func appendText(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        if case .text = _parts.last?.kind {
            _parts[_parts.count - 1].appending(chunk)
        } else {
            _parts.append(.text(chunk))
        }
    }

    /// The reply text accumulated so far.
    func accumulatedText() -> String {
        lock.lock(); defer { lock.unlock() }
        return _parts.compactMap { part in
            if case let .text(text) = part.kind {
                return text
            }
            return nil
        }.joined()
    }

    /// Move a completed trace marker out of the reply text.
    ///
    /// The model wraps its reasoning in a marker so the reader sees the
    /// reasoning as a separate block rather than as part of the answer. The
    /// marker is complete only once its closing bracket has arrived, so the
    /// check is made on the accumulated text each time the view updates.
    ///
    /// Until the marker is complete the text shows as it arrives, which
    /// includes the opening bracket. The alternative (= hiding the text
    /// until the marker closes) would hide the reply's beginning for as
    /// long as the reasoning takes, which is worse.
    func liftTraceMarker() {
        lock.lock(); defer { lock.unlock() }
        // A model that marks only its steps (= no thinking marker) still
        // gets them lifted, so the condition looks for any of the markers.
        guard let textIndex = _parts.firstIndex(where: { part in
            if case let .text(text) = part.kind {
                return text.contains("[[thinking:")
                    || text.contains("[[action:")
                    || text.contains("[[result:")
            }
            return false
        }) else { return }
        guard case let .text(text) = _parts[textIndex].kind else { return }

        // The whole segment is scanned, not only the thinking marker: the
        // step markers sit after it, in the same text run, and leaving them
        // in the body would show the reader the raw markers.
        let trace = MessageContent.extractTraceTags(from: text)
        guard !trace.thinking.isEmpty || !trace.steps.isEmpty else { return }

        // The trace becomes a reasoning part; the answer stays a text part.
        //
        // The text part is not removed and put back. Its id is what the
        // transcript row is keyed on, so removing it tore down the answer
        // the reader is watching and built a different row in its place,
        // mid-sentence, and the reader's own choice about the block went
        // with it. The part that carried the marker keeps its id and
        // changes kind into the answer again; the only part minted is the
        // block that genuinely appeared.
        var content = trace.thinking
        if !trace.steps.isEmpty {
            content += (content.isEmpty ? "" : "\n") + trace.steps
        }
        let remainder = trace.cleaned
        let hasAnswer = !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var carrier = _parts[textIndex]
        if hasAnswer {
            carrier.kind = .text(remainder)
            _parts[textIndex] = ChatMessagePart.reasoning(content)
            _parts.insert(carrier, at: textIndex + 1)
        } else {
            // Nothing of the answer is left in the run, so the run itself
            // becomes the block instead of being replaced by one.
            carrier.kind = .reasoning(content)
            _parts[textIndex] = carrier
        }
    }

    /// Append reasoning to the trailing reasoning part, or start one.
    func appendReasoning(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        if case .reasoning = _parts.last?.kind {
            _parts[_parts.count - 1].appending(chunk)
        } else {
            _parts.append(.reasoning(chunk))
        }
        _thinking += chunk
    }

    /// Append a discrete part (= a tool call or a tool result).
    ///
    /// These never coalesce: the user is watching for the boundary between
    /// one tool finishing and the next starting.
    func appendPart(_ part: ChatMessagePart) {
        lock.lock(); defer { lock.unlock() }
        _parts.append(part)
    }

    /// Settle a tool call with its result.
    ///
    /// The call and its result are ONE card: the call card already knows
    /// how to draw a state (= = its status, = = its duration, = = its
    /// tint), = = and the writer was reading "the assistant is calling
    /// tool X" FOREVER (= = because nothing ever wrote the state), next
    /// to a second card carrying the answer.
    ///
    /// So the result settles the call instead of becoming a second part:
    /// the transcript shows one row per call, = = and the row says what
    /// happened.
    ///
    /// A result with NO matching call (Hermes has that shape too: "a
    /// result WITHOUT a prior use") stays its own part: there is no card
    /// to settle, = = and dropping it would lose the answer.
    ///
    /// - Parameters:
    ///   - toolUseID: the call this result belongs to.
    ///   - content: the tool's output.
    ///   - isError: whether the call failed.
    func settleToolResult(toolUseID: ToolCallID, content: String, isError: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard let index = _parts.firstIndex(where: { part in
            guard case let .toolUse(call) = part.kind else { return false }
            return call.id == toolUseID
        }) else {
            // An orphan result: it has no card to settle, = = so it
            // draws itself.
            _parts.append(.toolResult(toolUseID: toolUseID, content: content, isError: isError))
            return
        }
        guard case var .toolUse(call) = _parts[index].kind else { return }
        // The call is settled ONCE: a second result for the same call
        // (= a retry that reported twice) does not reopen it.
        guard call.status == .running else { return }
        call.status = isError ? .error : .complete
        call.result = content
        if isError {
            call.errorMessage = content
        }
        _parts[index].kind = .toolUse(call)
    }
}
