//
//  InspectorRightColumnPushTests.swift · Wenshu ·  (2026-11-21)
//
//  The trailing column's two pages are told, they do not ask.
//
//  Both pages mirror a store that changes outside the view: the status
//  page mirrors the delegation registry, the plan page mirrors the
//  agent's todo store. Until now both mirrored it by re-reading on a
//  one-second clock, which is work the column paid while the user read,
//  wrote or scrolled, and which delayed every change the user was
//  waiting for by up to a second.
//
//  The clock is replaced by the store's own signal:
//
//    * the registry announces its record mutations (`changes()`),
//    * a plan write posts `AppStateEvents.todoPlanDidChange`.
//
//  Being told is only half of it: the plan announcement is delivered on
//  the thread that WROTE it (= the assistant writes through
//  `ToolExecutor`, off the main actor) and the page's mirror holds
//  main-actor state, so that announcement is hopped before anything
//  draws from it. The registry's stream resumes on its consumer's own
//  actor, so it needs no hop and carries none.
//
//  So a page re-reads when there is something to show, and re-reads
//  zero times while nothing happens. These tests hold both halves of
//  that promise, = the signal fires on a write, and the clock is gone
//  from the source that used to run it.
//
//

import Combine
import Foundation
import Testing
@testable import WenshuApp
import WenshuData

@Suite("Inspector right column push (a plan write is announced; the clock is gone)")
struct InspectorRightColumnPushTests {
    private static let planChangeName = Notification.Name.wenshuTodoPlanDidChange

    private static func source(_ relative: String) throws -> String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent(relative)
        return try String(contentsOfFile: url.path, encoding: .utf8)
    }

    // MARK: - A plan write announces itself

    /// The observation is scoped to the SENDER, not to the notification
    /// name alone. Posted with no sender, these two counters would see
    /// every plan write in the process, = including the ones a
    /// co-running suite makes, = so their green would be a fact about
    /// which suites the runner scheduled together, and a LOST
    /// announcement could hide behind another suite's write. Scoped to
    /// the store this test created, a count of 1 can only be this write.
    @Test("writing a plan announces the plan, once, from the store that wrote it")
    func planWriteIsAnnounced() {
        // A store of its own, so the test never touches the shared plan.
        let store = HermesTodoStore()
        let tool = HermesTodoTool(store: store)
        var announced = 0
        // An observer with no queue runs on the posting thread, and the
        // write posts on the writing thread, so this needs no run loop:
        // registered before the write, removed after it.
        let token = NotificationCenter.default.addObserver(
            forName: Self.planChangeName, object: store, queue: nil
        ) { notification in
            // The sender IS the store that wrote: an observer cannot be
            // scoped to an object the post does not name.
            #expect(notification.object as AnyObject === store)
            announced += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        tool.writePlan([
            HermesTodoItem(id: "1", content: "read the brief", status: .pending),
            HermesTodoItem(id: "2", content: "write the outline", status: .inProgress),
        ])

        #expect(announced == 1)
        #expect(store.announcementCount == 1)
    }

    @Test("reading a plan announces nothing (= a mirror is told, not polled)")
    func planReadIsSilent() {
        let store = HermesTodoStore()
        let tool = HermesTodoTool(store: store)
        tool.writePlan([HermesTodoItem(id: "1", content: "seed", status: .pending)])
        let announcedByTheWrite = store.announcementCount

        var announced = 0
        let token = NotificationCenter.default.addObserver(
            forName: Self.planChangeName, object: store, queue: nil
        ) { _ in announced += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        for _ in 0 ..< 20 {
            _ = tool.readPlan()
        }
        #expect(announced == 0)
        #expect(store.announcementCount == announcedByTheWrite)
    }

    @Test("another store's write does not announce to this store's mirror")
    func aWriteToAnotherPlanIsNotThisPlansNews() {
        // The app builds more than one `HermesTodoStore`
        // (= `HermesTodoTool.shared`, and the separate one
        // `TodoStoreTool.shared` owns). A mirror of one plan must not be
        // woken by the other (= a wake with nothing to show), = and a
        // test of one plan must not be paid for by the other (= the
        // green-by-accident half of the same defect).
        let mine = HermesTodoStore()
        let theirs = HermesTodoStore()
        var announced = 0
        let token = NotificationCenter.default.addObserver(
            forName: Self.planChangeName, object: mine, queue: nil
        ) { _ in announced += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        HermesTodoTool(store: theirs).writePlan([
            HermesTodoItem(id: "1", content: "some other chat's plan", status: .pending),
        ])

        #expect(announced == 0)
        #expect(mine.announcementCount == 0)
        #expect(theirs.announcementCount == 1)
    }

    @Test("the page's mirror follows the store it reads (= one plan, not the process)")
    @MainActor
    func theMirrorFollowsThePlanItReads() {
        // The view has no other way to name its plan: if the model's
        // sender were a different object from the store the page reads
        // through, the `.onReceive` would be scoped to a plan nobody is
        // drawing (= the clock's return, in a shape no test can see).
        let model = InspectorTodoModel()
        #expect(model.planSource === HermesTodoTool.shared.planSender)
    }

    // MARK: - The clock is gone from the pages that ran it

    @Test("neither page re-reads on a repeating clock")
    func pagesCarryNoRepeatingClock() throws {
        let status = try Self.source(
            "Sources/WenshuApp/Features/Editor/View/InspectorStatusView.swift"
        )
        let plan = try Self.source(
            "Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift"
        )

        for (name, source) in [("status page", status), ("plan page", plan)] {
            // A re-read loop is a sleep inside a cancellation loop; a
            // one-shot wait for a quiet window is not.
            #expect(!source.contains("while !Task.isCancelled"),
                    "\(name) still loops on a clock")
            #expect(!source.contains("Timer.scheduledTimer"),
                    "\(name) still runs a timer")
            #expect(!source.contains("Timer.publish"),
                    "\(name) still publishes a timer")
        }
    }

    @Test("each page subscribes to the store it mirrors")
    func pagesReadTheStoresOwnSignal() throws {
        let status = try Self.source(
            "Sources/WenshuApp/Features/Editor/View/InspectorStatusView.swift"
        )
        let plan = try Self.source(
            "Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift"
        )

        #expect(status.contains("registry.changes()"),
                "the status page no longer follows the registry's signal")
        #expect(plan.contains(".wenshuTodoPlanDidChange"),
                "the plan page no longer follows the plan store's signal")
        // Whitespace folded, because the formatter, not the author,
        // decides where this call wraps (= what must not change is the
        // subscription naming its store, not the line it sits on).
        let foldedPlan = plan.split(whereSeparator: \.isWhitespace).joined()
        #expect(foldedPlan.contains("for:.wenshuTodoPlanDidChange,object:model.planSource"),
                "the plan page follows every plan write in the process again")
    }

    // MARK: - The mirror answers the write, not a beat

    /// Waits for a condition for up to two seconds, and says whether it
    /// got there. There is no beat left to count, so the honest shape of
    /// "the mirror heard" is that the state arrives.
    @MainActor
    private static func waitUntil(
        _ body: @MainActor () async -> Bool
    ) async -> Bool {
        for _ in 0 ..< 200 {
            if await body() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await body()
    }

    @MainActor
    @Test("a delegation the registry gains shows in the status page's mirror")
    func gainedRecordAppearsInMirror() async {
        let registry = AsyncDelegationRegistry()
        let model = InspectorStatusModel(registry: registry)
        let scope = AgentScope(
            sessionID: SessionID(rawValue: "book:book-A:default"),
            bookID: BookID(rawValue: "book-A")
        )

        let follow = Task { await model.follow(scope: scope) }
        defer { follow.cancel() }

        // The subscribe read lands first: an empty scope is loaded, not
        // spinner-forever (= the page used to wait up to a second here).
        #expect(await Self.waitUntil { model.isLoaded })
        #expect(model.tasks.isEmpty)

        await registry.register(handle: BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "the probe",
            scope: scope
        ))

        // Nothing else drives the model: no timer runs, nobody asks
        // again. The only thing that can make this card appear is the
        // registry's own announcement.
        #expect(
            await Self.waitUntil { model.tasks.count == 1 },
            "the registry gained a record and the mirror never heard"
        )
        #expect(model.tasks.first?.taskText == "the probe")
    }

    @MainActor
    @Test("a page that follows nothing stays empty instead of guessing")
    func followWithoutScopeLeavesTheMirrorEmpty() async {
        let model = InspectorStatusModel(registry: AsyncDelegationRegistry())

        await model.follow(scope: nil)

        #expect(model.isLoaded)
        #expect(model.tasks.isEmpty)
    }

    // MARK: - The announcement is answered on the main actor

    /// Main-ness, read from a synchronous frame: `Thread.current` is
    /// `noasync`, and the writer this case drives is an async task, so
    /// the question has to be asked one call away from the `await`.
    private nonisolated static func isCurrentThreadMain() -> Bool {
        Thread.current.isMainThread
    }

    /// A value a test records from a closure that cannot await (= an
    /// observer runs on whatever thread delivered to it, and the test
    /// reads the record afterwards). The first record wins, so a write
    /// and its delivery cannot overwrite each other's reading.
    private final class ThreadRecord: @unchecked Sendable {
        private let lock = NSLock()
        private var landedOnMain: Bool?

        func record(_ value: Bool) {
            lock.withLock {
                if landedOnMain == nil {
                    landedOnMain = value
                }
            }
        }

        var value: Bool? {
            lock.withLock { landedOnMain }
        }
    }

    /// A consumer that is NOT main-actor-isolated, which is the whole
    /// point of it. A closure formed inside a `@MainActor` frame inherits
    /// that isolation, and Combine calls it on whatever thread delivered
    /// the value, so a background post traps at the closure's own entry
    /// (`dispatch_assert_queue`; measured: the probe version of this case
    /// printed nothing from inside its sink and died on the post). The
    /// page's `onReceive` action is exactly such a closure, = which is
    /// B3. This one can stand on the delivering thread and report it.
    private nonisolated static func deliveryRecorder(
        deliveredOnMain: ThreadRecord,
        draw: @escaping @MainActor @Sendable () -> Void
    ) -> (Notification) -> Void {
        { _ in
            let onMain = Self.isCurrentThreadMain()
            // The draw the page makes, made only where it may be made:
            // with the hop removed this case reddens on the record below
            // instead of trapping the rest of the run.
            if onMain {
                MainActor.assumeIsolated { draw() }
            }
            deliveredOnMain.record(onMain)
        }
    }

    /// Drives the page's consumer from outside the main actor, = where
    /// the assistant's plan write really happens (`HermesTodoTool.execute`
    /// is `nonisolated async` behind `public actor ToolExecutor`, and
    /// `HermesTodoStoreConcurrencyTests` already writes from a
    /// `Task.detached`).
    @MainActor
    @Test("a plan written off the main actor is drawn on the main actor")
    func offMainPlanWriteIsDrawnOnMain() async {
        let store = HermesTodoStore()
        let tool = HermesTodoTool(store: store)
        let wroteOnMain = ThreadRecord()
        let deliveredOnMain = ThreadRecord()
        let drewOnMain = ThreadRecord()

        // The read IS the draw: whatever thread runs this closure is the
        // thread the mirror was refreshed on.
        let model = InspectorTodoModel(
            readPlan: {
                drewOnMain.record(Self.isCurrentThreadMain())
                return store.read()
            },
            planSource: store
        )
        let draw: @MainActor @Sendable () -> Void = { model.refresh() }

        // The page's own subscription, through the page's own hop.
        let subscription = InspectorTodoModel.hoppedToMain(
            NotificationCenter.default.publisher(for: Self.planChangeName, object: store)
        ).sink(receiveValue: Self.deliveryRecorder(
            deliveredOnMain: deliveredOnMain, draw: draw
        ))
        defer { subscription.cancel() }

        await Task.detached(priority: .userInitiated) {
            wroteOnMain.record(Self.isCurrentThreadMain())
            tool.writePlan([
                HermesTodoItem(id: "1", content: "written off-main", status: .pending),
            ])
        }.value

        // The premise first, so a green is not available by the test
        // accidentally writing from the main thread.
        #expect(wroteOnMain.value == false,
                "the plan was written ON the main actor, so this case says nothing about the hop")
        #expect(await Self.waitUntil { deliveredOnMain.value != nil },
                "the page's subscription never answered a plan write made off the main actor")
        #expect(deliveredOnMain.value == true,
                "the plan announcement was delivered on the writing thread, not on the main actor")
        #expect(drewOnMain.value == true,
                "the mirror read the plan off the main actor")
        // And the draw was the real one (= the mirror now holds the row
        // the background write put in the store, and nothing else asked).
        #expect(model.isLoaded)
        #expect(model.todos.map(\.title) == ["written off-main"])
    }

    /// The other half: that the page's own source is the one that hops.
    /// The behavioural case above drives `hoppedToMain`; this one fails
    /// if the page stops calling it (= a hop orphaned on the model would
    /// keep the suite green while the app stayed broken).
    @Test("the page hops the announcement it subscribes to")
    func pageSubscriptionHopsToMain() throws {
        let plan = try Self.source(
            "Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift"
        )
        // Whitespace folded, because the formatter, not the author,
        // decides where this wraps (= what must not move is the hop
        // sitting between the announcement and the draw).
        let folded = plan.split(whereSeparator: \.isWhitespace).joined()
        #expect(
            folded.contains("InspectorTodoModel.hoppedToMain(NotificationCenter.default"
                + ".publisher(for:.wenshuTodoPlanDidChange,object:model.planSource))"),
            "the plan page draws the plan announcement on the writing thread again"
        )
        #expect(folded.contains(".receive(on:DispatchQueue.main)"),
                "the page's announcement no longer hops to the main queue")
    }
}
