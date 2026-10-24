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
    /// The length of one frame.
    ///
    /// 16ms is one frame at 60Hz. Shorter and the display cannot keep up,
    /// so the extra renders buy nothing; longer and the text visibly
    /// stutters between updates.
    private static let frameInterval = Duration.milliseconds(16)

    /// The frame of words being collected.
    ///
    /// Its identity is what a flush task checks when it wakes: a task that
    /// was scheduled for a frame the buffer has since moved past publishes
    /// nothing, so a frame's words are published by the task that owns it.
    private struct Frame {
        let id: Int
        /// When this frame must be published by.
        let deadline: ContinuousClock.Instant
    }

    private var pending: StreamBatch
    /// The frame in flight, or nil when no frame is being collected.
    ///
    /// A second chunk arriving while a frame is in flight joins that frame
    /// rather than starting a new one: this is the whole throttle.
    private var frame: Frame?
    private var nextFrameID = 0
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
        // A frame is already in flight: this chunk joins it, and the task
        // that owns the frame publishes both together.
        guard frame == nil else { return }
        nextFrameID += 1
        let frame = Frame(id: nextFrameID, deadline: ContinuousClock.now + Self.frameInterval)
        self.frame = frame
        scheduleFlush(frame: frame)
    }

    /// Publish everything buffered right now, cancelling the pending flush.
    ///
    /// The terminal flush: when a reply ends, the last partial frame must land
    /// rather than waiting for the timer, or the tail of the message appears
    /// after the UI has already marked the bubble complete.
    public func flushNow() {
        frame = nil
        guard !pending.isEmpty else { return }
        let batch = pending
        pending = StreamBatch()
        onFlush?(batch)
    }

    /// Whether anything is waiting to be published.
    public var hasPending: Bool { !pending.isEmpty }

    private func scheduleFlush(frame: Frame) {
        // A wall-clock deadline, not a bare yield.
        //
        // A yield-based flush is not reliable: the flush task needs two
        // scheduler turns to run (one to start, one for its own yield), and
        // a caller that awaits a single yield can observe the buffer before
        // it has published anything. A short sleep is one hop and one timer,
        // and the interval is what actually defines "one frame" — a yield
        // defines nothing measurable, so the coalescing window would depend
        // on how busy the main actor happened to be.
        //
        // The deadline is stamped when the first chunk of the frame arrives,
        // not when this task starts running. A task's own sleep clock starts
        // when the task begins, so a window measured from the task's start
        // would be pushed back by however long the main actor's queue was
        // deep, and the frame would publish whole frames after the words
        // arrived. Sleeping until the stamped deadline keeps the window one
        // frame long however busy the main actor is: a flush that starts late
        // finds the deadline already past and publishes in the same turn it
        // starts, rather than after another frame.
        Task { @MainActor [weak self] in
            let remaining = frame.deadline - ContinuousClock.now
            if remaining > .zero {
                try? await Task.sleep(for: remaining)
            }
            // The frame is the identity: a task that wakes for a frame the
            // buffer has moved past (= a terminal flush, or a newer frame)
            // publishes nothing.
            guard let self, self.frame?.id == frame.id else { return }
            self.frame = nil
            guard !self.pending.isEmpty else { return }
            let batch = self.pending
            self.pending = StreamBatch()
            self.onFlush?(batch)
        }
    }
}