//
//  AsyncDelegationOutputTailTests.swift · Wenshu ·  (2026-10-23)
//
//  What a RUNNING sub-agent has produced so far.
//
//  The background runner streams the sub-agent's tokens, so the
//  handle carries the text produced so far. Only the tail is kept,
//  so a long run cannot grow the record without bound, and the
//  finished answer still arrives through `markCompleted`.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("AsyncDelegation output tail (what a running sub-agent produced)")
struct AsyncDelegationOutputTailTests {

    // MARK: - The tail grows with what the sub-agent produced

    @Test("appendOutput appends the streamed text to the handle's tail")
    func appendOutputAppendsToTheTail() async {
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "output tail probe"
        )
        await registry.register(handle: handle)

        await registry.appendOutput(handleID: handle.id, text: "first chunk ")
        await registry.appendOutput(handleID: handle.id, text: "second chunk")

        let stored = await registry.get(id: handle.id)
        #expect(stored?.outputTail == "first chunk second chunk")
    }

    // MARK: - The tail stays bounded

    @Test("the tail keeps only the last 16384 characters")
    func tailNeverGrowsPastTheLimit() async {
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "long output probe"
        )
        await registry.register(handle: handle)

        // Longer than the cap, with a marked head and a marked tail.
        let head = String(repeating: "A", count: 20_000)
        let tail = "THE-VERY-END"
        await registry.appendOutput(handleID: handle.id, text: head)
        await registry.appendOutput(handleID: handle.id, text: tail)

        let stored = await registry.get(id: handle.id)
        let outputTail = stored?.outputTail ?? ""

        #expect(outputTail.count == AsyncDelegationRegistry.maxOutputTailCharacters)
        // The oldest text fell off the front ...
        #expect(!outputTail.hasPrefix(head))
        // ... and the newest text is still there.
        #expect(outputTail.hasSuffix(tail))
    }

    // MARK: - An unknown handle is a no-op

    @Test("appendOutput on an unknown handle id does not throw")
    func appendOutputOnUnknownHandleIsANoOp() async {
        let registry = AsyncDelegationRegistry()

        await registry.appendOutput(handleID: "no-such-handle", text: "ignored")

        let stored = await registry.get(id: "no-such-handle")
        #expect(stored == nil)
    }
}
