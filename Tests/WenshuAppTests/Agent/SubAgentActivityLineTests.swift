//
//  SubAgentActivityLineTests.swift · Wenshu
//
//  The card's activity line: = = what a sub-agent just did.
//
//  The rule is a pure function, = = so it is tested here (= = not
//  through a running agent, = = and not through the view).
//
//  The card's line has two jobs, = = and both are pinned here:
//
//  - it NAMES the argument (= = "which file"), = = because the tool's
//    name alone does not;
//  - it is ONE line (= = so the card's height does not change while
//    the agent runs).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The sub-agent activity line")
struct SubAgentActivityLineTests {
    // MARK: - The tool call

    @Test("a call reads as the tool's name and the path it is reading")
    func callNamesThePathItReads() {
        let line = SubAgentActivityLine.text(
            toolName: "read_file",
            input: #"{"path": "/Volumes/book/Scene03.md"}"#
        )
        #expect(line == "Read File · /Volumes/book/Scene03.md",
                "The line names the file the agent is reading (= = not the tool alone)")
    }

    @Test("the argument's key is read in reading order, not in JSON order")
    func argumentKeyIsReadInReadingOrder() {
        // The query key comes first in the JSON, = = but the path is
        // what a reader names first.
        let line = SubAgentActivityLine.text(
            toolName: "grep",
            input: #"{"query": "letter", "path": "/Volumes/book"}"#
        )
        #expect(line == "Grep · /Volumes/book",
                "The line names the path (= = the thing the reader is looking at)")
    }

    @Test("a call with no nameable argument reads as the tool's name alone")
    func callWithoutAnArgumentReadsAsTheToolName() {
        let line = SubAgentActivityLine.text(toolName: "list_dir", input: #"{"limit": 20}"#)
        #expect(line == "List Dir",
                "A count says nothing about what the agent is doing (= = so the name is the line)")
    }

    @Test("a call with no arguments at all reads as the tool's name alone")
    func callWithoutArgumentsReadsAsTheToolName() {
        let line = SubAgentActivityLine.text(toolName: "list_dir", input: "")
        #expect(line == "List Dir")
    }

    @Test("an argument that is not JSON is still the argument")
    func nonJSONArgumentIsStillTheArgument() {
        let line = SubAgentActivityLine.text(toolName: "remember", input: "the red thread")
        #expect(line == "Remember · the red thread")
    }

    @Test("a long argument is cut to one line")
    func longArgumentIsCutToOneLine() {
        let path = "/" + String(repeating: "a", count: 200) + ".md"
        let line = SubAgentActivityLine.text(toolName: "read_file", input: #"{"path": "\#(path)"}"#)
        #expect(!line.contains("\n"), "The line is one line (= = the card's height does not change)")
        #expect(line.count <= SubAgentActivityLine.maxArgumentCharacters + 20,
                "The argument is cut (= = the line stays readable)")
    }

    // MARK: - The agent's own words

    @Test("the agent's words read as the line itself")
    func thinkingReadsAsTheLine() {
        let line = SubAgentActivityLine.text(thinking: "  Looking for the scene where the letter arrives.  ")
        #expect(line == "Looking for the scene where the letter arrives.",
                "The line is what the agent said (= = trimmed)")
    }

    @Test("empty words read as no line")
    func emptyThinkingReadsAsNoLine() {
        #expect(SubAgentActivityLine.text(thinking: "   ").isEmpty)
    }

    // MARK: - The card

    @Test("a running card that has done something shows that something")
    func runningCardShowsTheActivity() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .running,
            activityText: "Read File · /Volumes/book/Scene03.md"
        )
        let task = InspectorStatusTask(handle: handle)
        #expect(task.activityText == "Read File · /Volumes/book/Scene03.md")
        #expect(InspectorStatusActivityStyle.text(for: task) == "Read File · /Volumes/book/Scene03.md",
                "The card shows what the agent just did")
    }

    @Test("a running card that has done nothing still shows a line")
    func runningCardWithoutActivityStillShowsALine() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .running
        )
        let task = InspectorStatusTask(handle: handle)
        let line = InspectorStatusActivityStyle.text(for: task)
        #expect(!line.isEmpty,
                "The line is always drawn (= = the card's height does not change when the first action arrives)")
    }

    @Test("the fallback's word is in the catalog, in both languages")
    func theFallbackWordIsInTheCatalog() throws {
        // Offscreen, `String(localized:)` hands back the KEY (= = the
        // host has no catalog), = = so the line's own text cannot be
        // checked here. = = What can be checked is the catalog itself:
        // = = the key must carry a real word, = = or the card shows a
        // key to the reader.
        let url = SourceLocator.url("Sources/WenshuApp/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        let strings = try #require((object as? [String: Any])?["strings"] as? [String: Any])
        let entry = try #require(strings["inspector.status.activity.waiting"] as? [String: Any],
                                 "the catalog must carry the fallback's key")
        let localizations = try #require(entry["localizations"] as? [String: Any])
        #expect(localizations["en"] != nil, "the fallback must have an English word")
        #expect(localizations["zh-Hans"] != nil, "the fallback must have a Chinese word")
    }

    @Test("a finished card keeps what the agent did (= = a card is a history)")
    func finishedCardKeepsWhatTheAgentDid() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .completed,
            result: "Scene 3.",
            activityText: "Read File · /Volumes/book/Scene03.md"
        )
        let task = InspectorStatusTask(handle: handle)
        #expect(task.activityText == "Read File · /Volumes/book/Scene03.md",
                "The card says what the agent did (= = a finished task did things)")
    }

    @Test("the drawn line never says 'waiting' about a task that is done")
    func theDrawnLineNeverSaysWaitingAboutAFinishedTask() {
        // The card's line is DRAWN for every state (= = so the cards
        // differ in height and never in layout), = = and the word it
        // draws must fit the state: = = a finished task that says it is
        // waiting is lying.
        for state in [BackgroundDelegationState.completed, .failed, .timeout] {
            let handle = BackgroundDelegationHandle(
                agentName: "researcher",
                userMessage: "Find the scene where the letter arrives.",
                state: state
            )
            let task = InspectorStatusTask(handle: handle)
            let drawn = InspectorStatusActivityStyle.text(for: task)
            #expect(drawn != "inspector.status.activity.waiting",
                    Comment("a \(state) card must not draw the waiting word (= \(drawn))"))
            #expect(!drawn.isEmpty, "the line is always drawn (= = the card's height must not change)")
        }
    }

    @Test("a pending card says it is queued")
    func aPendingCardSaysItIsQueued() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .pending
        )
        let task = InspectorStatusTask(handle: handle)
        let drawn = InspectorStatusActivityStyle.text(for: task)
        #expect(drawn == "inspector.status.activity.queued",
                Comment("the queued word is its own (= \(drawn))"))
    }

    @Test("the tool column and the activity line name one tool the same way")
    func toolColumnAndActivityLineAgreeOnTheName() {
        #expect(InspectorStatusToolLabel.text("delegate_research") == "Delegate Research")
        #expect(SubAgentActivityLine.readableToolName("delegate_research") == "Delegate Research")
    }

    // MARK: - The wiring

    @Test("the registry carries the activity line to the card")
    func theRegistryCarriesTheActivityLine() async throws {
        // The pure rule above is only half the card: = = the runner has
        // to WRITE what it saw into the registry, = = and the registry
        // has to carry it to the card. = = This is the seam the two
        // mutation arms bite (= = without it, = = dropping the tool's
        // input again would leave every test green).
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .running
        )
        await registry.register(handle: handle)

        await registry.recordCurrentTool(handleID: handle.id, tool: "read_file")
        await registry.recordActivity(
            handleID: handle.id,
            activity: SubAgentActivityLine.text(
                toolName: "read_file",
                input: #"{"path": "/Volumes/book/Scene03.md"}"#
            )
        )

        let carried = try #require(await registry.get(id: handle.id))
        #expect(carried.currentTool == "read_file")
        #expect(carried.activityText == "Read File · /Volumes/book/Scene03.md",
                "The card reads the line the registry carries")

        // The card takes it from the record.
        let task = InspectorStatusTask(handle: carried)
        #expect(task.activityText == "Read File · /Volumes/book/Scene03.md")
    }

    @Test("the runner's stream callback writes the tool's argument into the registry")
    func theRunnerWritesTheToolArgument() throws {
        // The runner writes the tool call's argument into the registry
        // (= = and the agent's thinking beside it). = = This test reads
        // the runner's own source, = = because the callback is a closure
        // inside a long method (= = and a test that reaches it would
        // have to run a whole agent turn).
        let url = SourceLocator.url("Sources/WenshuApp/Features/Agent/Store/SubAgentRunner.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        #expect(source.contains("case let .toolUse(_, toolName, input):"),
                "The callback must read the tool call's argument (= = not drop it)")
        #expect(source.contains("SubAgentActivityLine.text(toolName: toolName, input: input)"),
                "The callback must turn the call into the activity line")
        #expect(source.contains("case let .thinking(text, _)"),
                "The callback must read the agent's thinking (= = not drop it)")
        #expect(source.contains("SubAgentActivityLine.text(thinking: text)"),
                "The agent's words must reach the activity line")
    }
}
