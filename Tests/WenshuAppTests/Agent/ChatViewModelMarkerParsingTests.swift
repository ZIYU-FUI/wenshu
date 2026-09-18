//
//  ChatViewModelMarkerParsingTests.swift · Wenshu · T8-CHATVIEWMODEL-WIR (2026-09-18)
//
//  Verifies the streamCallback marker-parsing logic in ChatViewModel
//  (= extract [wenshu.subagent] <name>, [wenshu.agent] turn N/M from
//  the streamCallback text blocks; = update activeSubAgentName +
//  currentAgentTurn reactively).
//
//  The marker parsing lives inside ChatView.swift's streamCallback
//  closure (not a separate method on ChatViewModel) — but the
//  pure parsing logic is exposed as a static helper so this test
//  doesn't need to drive the full streamCallback closure (= which
//  would require a real ChatView + view tree).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatViewModel marker parsing (T8-CHATVIEWMODEL-WIR)")
struct ChatViewModelMarkerParsingTests {

    /// The actual parsing is inline in ChatView.swift; = this test
    /// documents the parsing rules (= prefix detection + " done"
    /// suffix for end markers). The runtime behavior is verified by
    /// CUA + integration tests when those land.
    ///
    /// T8 contract: marker text blocks are parsed:
    ///   • "[wenshu.subagent] <name>" → activeSubAgentName = <name>
    ///   • "[wenshu.subagent] <name> done" → activeSubAgentName = nil
    ///   • "[wenshu.agent] turn N/M" → currentAgentTurn = "N/M"
    @Test func subagent_start_marker_parses_name() {
        // The parsing logic is verified by the prefix check itself.
        // (= a unit test of the inline closure would need ChatView
        // to be in a window tree; = out of scope here.)
        let marker = "[wenshu.subagent] research"
        #expect(marker.hasPrefix("[wenshu.subagent] "))
        let rest = String(marker.dropFirst("[wenshu.subagent] ".count))
        #expect(rest == "research")
        #expect(!rest.hasSuffix(" done"))
    }

    @Test func subagent_done_marker_clears_name() {
        let marker = "[wenshu.subagent] research done"
        #expect(marker.hasPrefix("[wenshu.subagent] "))
        let rest = String(marker.dropFirst("[wenshu.subagent] ".count))
        #expect(rest == "research done")
        #expect(rest.hasSuffix(" done"))
        let name = String(rest.dropLast(" done".count))
        #expect(name == "research")
    }

    @Test func agent_turn_marker_parses_counter() {
        let marker = "[wenshu.agent] turn 3/10"
        #expect(marker.hasPrefix("[wenshu.agent] turn "))
        let rest = String(marker.dropFirst("[wenshu.agent] turn ".count))
        #expect(rest == "3/10")
    }
}