// TurnNotesTests.swift
//
// Drain-on-read is the whole contract. A note that survives its turn is a
// stale note, and a stale note reads as current state to the model.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Turn notes")
struct TurnNotesTests {

    @Test("draining returns the staged text")
    func drainReturnsStagedText() {
        var notes = TurnNotes()
        notes.stage("Current chapter: Chapter 4")
        #expect(notes.hasPending)
        #expect(notes.drain() == "Current chapter: Chapter 4")
    }

    @Test("a drained note is never delivered again")
    func drainClearsTheQueue() {
        var notes = TurnNotes()
        notes.stage("chapter moved")
        _ = notes.drain()
        #expect(!notes.hasPending)
        #expect(notes.drain().isEmpty, "a note must not survive the turn that carried it")
    }

    @Test("empty and whitespace notes are dropped at stage time")
    func emptyNotesAreDropped() {
        var notes = TurnNotes()
        notes.stage("")
        notes.stage("   \n  ")
        #expect(!notes.hasPending)
        #expect(notes.count == 0)
    }

    @Test("several notes drain as one block in staging order")
    func multipleNotesJoinInOrder() {
        var notes = TurnNotes()
        notes.stage("first")
        notes.stage("second")
        #expect(notes.count == 2)
        #expect(notes.drain() == "first\n\nsecond")
        #expect(notes.count == 0)
    }

    @Test("draining an empty queue returns empty rather than crashing")
    func drainOnEmptyQueue() {
        var notes = TurnNotes()
        #expect(notes.drain().isEmpty)
        #expect(notes.drain().isEmpty)
    }

    @Test("notes ride ahead of the user message")
    func notesPrecedeUserMessage() {
        let composed = TurnMessageComposer.compose(
            userMessage: "第三章重写",
            notes: "Current chapter: Chapter 4"
        )
        #expect(composed.contains("Session state"))
        #expect(composed.range(of: "Current chapter")!.lowerBound
                < composed.range(of: "第三章重写")!.lowerBound,
                "state must be read before the request, not near the cut-off")
    }

    @Test("a turn without notes leaves the user message untouched")
    func noNotesMeansNoRewrite() {
        #expect(TurnMessageComposer.compose(userMessage: "原样", notes: "") == "原样")
        #expect(TurnMessageComposer.compose(userMessage: "原样", notes: "  \n ") == "原样")
    }

    @Test("notes alone still carry the heading")
    func notesWithoutUserMessage() {
        let composed = TurnMessageComposer.compose(userMessage: "", notes: "chapter moved")
        #expect(composed.contains("Session state"))
        #expect(composed.contains("chapter moved"))
    }
}