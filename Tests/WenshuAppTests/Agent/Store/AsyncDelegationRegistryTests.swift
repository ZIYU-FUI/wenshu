//
//  AsyncDelegationRegistryTests.swift · Wenshu ·  (2026-10-23)
//
//  The ONE registry every delegation lands in.
//
//  Two things are proved here:
//  1. A handle registered on the shared registry reads back through
//     `get(id:)`.
//  2. The chat's @-mention path and the LLM-facing `delegate_research`
//     tool write to the SAME registry. Before the unification the
//     mention path wrote to a second, private instance that the
//     background runner never drained, so a sub-agent started that way
//     was registered and then never ran.
//
//  The second test drives the real mention path
//  (`ChatViewModel.routeInput()`) and looks for the handle it produced
//  in the shared registry, so it proves the WIRING rather than the
//  shape of the source.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("AsyncDelegationRegistry (one registry for every delegation)")
struct AsyncDelegationRegistryTests {

    // MARK: - Test 1: a handle round-trips through the shared registry

    @Test("a handle registered on the shared registry reads back through get(id:)")
    func sharedRegistryRoundTripsAHandle() async {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "registry round trip probe",
            state: .pending
        )
        await AsyncDelegationRegistry.shared.register(handle: handle)

        let stored = await AsyncDelegationRegistry.shared.get(id: handle.id)
        #expect(stored != nil)
        #expect(stored?.id == handle.id)
        #expect(stored?.agentName == "researcher")
        #expect(stored?.state == .pending)
    }

    // MARK: - Test 3: the tool the sub-agent is calling

    @Test("the tool a sub-agent is calling lands in the record")
    func theToolASubAgentIsCallingLandsInTheRecord() async {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "current tool probe",
            state: .running
        )
        await AsyncDelegationRegistry.shared.register(handle: handle)

        await AsyncDelegationRegistry.shared.recordCurrentTool(handleID: handle.id, tool: "read_file")

        let stored = await AsyncDelegationRegistry.shared.get(id: handle.id)
        #expect(stored?.currentTool == "read_file",
                "the record names the tool the sub-agent is calling right now")
    }

    @Test("a blank tool name clears the record's tool")
    func aBlankToolNameClearsTheRecordsTool() async {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "clearing probe",
            state: .running,
            currentTool: "read_file"
        )
        await AsyncDelegationRegistry.shared.register(handle: handle)

        await AsyncDelegationRegistry.shared.recordCurrentTool(handleID: handle.id, tool: "  ")

        let stored = await AsyncDelegationRegistry.shared.get(id: handle.id)
        #expect(stored?.currentTool == nil,
                "a blank name means the sub-agent stopped calling tools")
    }

    @Test("an unknown handle id is a no-op")
    func anUnknownHandleIdIsANoOp() async {
        await AsyncDelegationRegistry.shared.recordCurrentTool(handleID: "no-such-handle", tool: "read_file")
        // The call must not trap or register anything.
        let stored = await AsyncDelegationRegistry.shared.get(id: "no-such-handle")
        #expect(stored == nil)
    }

    // MARK: - Test 2: the mention path lands in the shared registry

    @MainActor
    @Test("the chat's @-mention path registers into the shared registry")
    func mentionPathRegistersIntoTheSharedRegistry() async {
        let task = "unify the delegation registry probe 2026-10-23"
        let vm = ChatViewModel()
        vm.inputText = "@researcher \(task)"

        await vm.routeInput()

        // The mention path reports the handle it created.
        let mentionsReported = vm.messages.contains { message in
            message.source == .system && message.content.contains("researcher")
        }
        #expect(
            mentionsReported,
            "the mention path should report the handle it created"
        )

        // ... and that handle lives in the SHARED registry (= the one the
        // background runner drains). A mention path that still wrote to
        // a private registry would leave this empty.
        let shared = await AsyncDelegationRegistry.shared.runningDelegations()
        let landed = shared.first {
            $0.agentName == "researcher" && $0.userMessage == task
        }
        #expect(
            landed != nil,
            "the mention path's handle must be visible in the shared registry"
        )
    }
}
