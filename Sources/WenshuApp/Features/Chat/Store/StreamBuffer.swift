// StreamBuffer.swift
//
// Coalesces the token stream into one state change per frame.
//
// The problem this solves is not cosmetic. Every chunk used to enqueue its
// own @MainActor Task that rebuilt the whole ChatMessage, so a thousand-chunk
// reply meant a thousand tasks, a thousand full-array replacements, and a
// thousand markdown re-parses of text the user had already read. The UI then
// rendered whatever state survived the queue, which is why replies arrived in
// visible jumps rather than flowing.
//
// The rule is one state change per frame. Chunks keep arriving at whatever
// rate the provider sends them; they land in the buffer, and the buffer is
// drained by a single scheduled flush. A frame is the right unit because it is
// the only rate a person can perceive, and because the display can only
// present that fast anyway.
//
// Hermes coalesces on its side too (ui-tui's resize coalescer is the same
// shape), which is why its output reads as continuous.

import Foundation
import WenshuAgent

/// What the buffer accumulated since the last publish.
public struct StreamBatch: Sendable, Equatable {
    /// Text appended during this frame.
    public var text: String
    /// Reasoning appended during this frame.
    public var reasoning: String
    /// Discrete blocks (= tool calls and results), which never coalesce.
    public var blocks: [LLMBlock]

    public init(text: String = "", reasoning: String = "", blocks: [LLMBlock] = []) {
        self.text = text
        self.reasoning = reasoning
        self.blocks = blocks
    }

    public var isEmpty: Bool { text.isEmpty && reasoning.isEmpty && blocks.isEmpty }
}

/// Collects chunks and publishes them at most once per frame.
@MainActor
public final class StreamBuffer {
    private var pending: StreamBatch
    /// Whether a flush is already scheduled. This flag is the whole throttle:
    /// a second chunk arriving before the flush sees it and extends the buffer
    /// instead of scheduling another one.
    private var flushScheduled = false
    private var onFlush: ((StreamBatch) -> Void)?

    public init(onFlush: @escaping (StreamBatch) -> Void) {
        self.onFlush = onFlush
        self.pending = StreamBatch()
    }

    /// Add one streamed block.
    ///
    /// Text and reasoning coalesce because they arrive in fragments; tool calls
    /// and results are discrete events and are queued as-is, because merging
    /// two tool calls into one would lose the boundary the user is watching
    /// for.
    public func append(_ block: LLMBlock) {
        switch block {
        case .text(let chunk):
            guard !chunk.isEmpty else { return }
            pending.text += chunk
        case .thinking(let chunk, _):
            guard !chunk.isEmpty else { return }
            pending.reasoning += chunk
        case .toolUse, .toolResult:
            pending.blocks.append(block)
        }
        scheduleFlush()
    }

    /// Publish everything buffered right now, cancelling the pending flush.
    ///
    /// The terminal flush: when a reply ends, the last partial frame must land
    /// rather than waiting for the timer, or the tail of the message appears
    /// after the UI has already marked the bubble complete.
    public func flushNow() {
        flushScheduled = false
        guard !pending.isEmpty else { return }
        let batch = pending
        pending = StreamBatch()
        onFlush?(batch)
    }

    /// Whether anything is waiting to be published.
    public var hasPending: Bool { !pending.isEmpty }

    private func scheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        // A wall-clock interval, not a bare yield.
        //
        // A yield-based flush is not reliable: the flush task needs two
        // scheduler turns to run (one to start, one for its own yield), and
        // a caller that awaits a single yield can observe the buffer before
        // it has published anything. A short sleep is one hop and one timer,
        // and the interval is what actually defines "one frame" — a yield
        // defines nothing measurable, so the coalescing window would depend
        // on how busy the main actor happened to be.
        //
        // 16ms is one frame at 60Hz. Shorter and the display cannot keep up,
        // so the extra renders buy nothing; longer and the text visibly
        // stutters between updates.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(16))
            guard let self, self.flushScheduled else { return }
            self.flushScheduled = false
            guard !self.pending.isEmpty else { return }
            let batch = self.pending
            self.pending = StreamBatch()
            self.onFlush?(batch)
        }
    }
}