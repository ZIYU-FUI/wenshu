import Foundation
import WenshuAgent

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
    func appendText(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        if case let .text(last)? = _parts.last?.kind {
            _parts[_parts.count - 1] = .text(last + chunk)
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
        _parts.remove(at: textIndex)
        var content = trace.thinking
        if !trace.steps.isEmpty {
            content += (content.isEmpty ? "" : "\n") + trace.steps
        }
        _parts.insert(.reasoning(content), at: textIndex)
        let remainder = trace.cleaned
        if !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _parts.insert(.text(remainder), at: textIndex + 1)
        }
    }

    /// Append reasoning to the trailing reasoning part, or start one.
    func appendReasoning(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        if case let .reasoning(last)? = _parts.last?.kind {
            _parts[_parts.count - 1] = .reasoning(last + chunk)
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
}
