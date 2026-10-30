//
//  InspectorTodoPageViewTests.swift · Wenshu
//
//  The todo page's own logic: the plan it reads, the count the header
//  shows, and the shape the cards take.
//
//  The page is a View, so per the wenshu test convention its logic
//  is exercised through the value types behind it
//  (= InspectorTodo + InspectorTodoModel + InspectorTodoDepths),
//  not through ViewInspector.
//
//  The plan comes from the agent's OWN plan store (= HermesTodoStore,
//  = the store the agent's todo tool writes), so the suite proves that
//  the plan the agent wrote is the plan the page shows.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Inspector todo page")
struct InspectorTodoPageViewTests {

    // MARK: - Fixtures

    /// The page's mirror of the plan (= the same reader the view draws
    /// from).
    @MainActor
    private static func makePage(_ items: [HermesTodoItem]) -> InspectorTodoModel {
        let model = InspectorTodoModel(readPlan: { items })
        model.refresh()
        return model
    }

    /// One plan item (= the shape the agent's tool writes).
    private static func item(
        _ id: String,
        _ status: HermesTodoStatus,
        parent: String? = nil
    ) -> HermesTodoItem {
        HermesTodoItem(
            id: id,
            content: "Draft chapter \(id)",
            status: status,
            parent: parent
        )
    }

    // MARK: - The same plan the agent wrote

    @Test("the page shows the plan item the agent wrote")
    @MainActor
    func pageShowsThePlanItemTheAgentWrote() {
        let page = Self.makePage([Self.item("1", .pending)])

        #expect(page.todos.count == 1, "the plan item is on the page")
        #expect(page.todos.first?.title == "Draft chapter 1")
    }

    @Test("the page shows every plan item the agent wrote")
    @MainActor
    func pageShowsEveryPlanItemTheAgentWrote() {
        let page = Self.makePage([
            Self.item("1", .pending),
            Self.item("2", .pending),
        ])

        #expect(page.todos.count == 2, "both plan items are on the page")
        #expect(Set(page.todos.map(\.title)) == ["Draft chapter 1", "Draft chapter 2"])
    }

    @Test("the page reads the agent's own plan store")
    @MainActor
    func pageReadsTheAgentsOwnPlanStore() throws {
        // The page's default reader IS the agent's shared plan store,
        // so the plan on screen and the plan the agent works from are
        // one list (= the page never shows a copy).
        let store = HermesTodoStore()
        _ = try store.write(todos: [Self.item("1", .pending)], merge: false)

        let model = InspectorTodoModel(readPlan: { store.read() })
        model.refresh()

        #expect(model.todos.count == 1, "the plan the store holds is on the page")
        #expect(model.todos.first?.title == "Draft chapter 1")
    }

    // MARK: - The plan's shape

    @Test("an item that belongs to another item reads indented under it")
    @MainActor
    func anItemThatBelongsToAnotherItemReadsIndentedUnderIt() {
        let page = Self.makePage([
            Self.item("1", .inProgress),
            Self.item("2", .pending, parent: "1"),
        ])

        let depths = Dictionary(uniqueKeysWithValues: page.todos.map { ($0.id, $0.depth) })
        #expect(depths["1"] == 0, "the parent is a top-level step")
        #expect(depths["2"] == 1, "the sub-step reads one step in")
    }

    @Test("a sub-step of a sub-step reads two steps in")
    @MainActor
    func aSubStepOfASubStepReadsTwoStepsIn() {
        let page = Self.makePage([
            Self.item("1", .inProgress),
            Self.item("2", .pending, parent: "1"),
            Self.item("3", .pending, parent: "2"),
        ])

        let depths = Dictionary(uniqueKeysWithValues: page.todos.map { ($0.id, $0.depth) })
        #expect(depths["3"] == 2)
    }

    @Test("an item whose parent is missing reads as a top-level step")
    @MainActor
    func anItemWhoseParentIsMissingReadsAsATopLevelStep() {
        let page = Self.makePage([Self.item("2", .pending, parent: "gone")])

        #expect(page.todos.first?.depth == 0,
                "a dangling parent does not push the item off the top")
    }

    @Test("an item that is its own parent reads as a top-level step")
    @MainActor
    func anItemThatIsItsOwnParentReadsAsATopLevelStep() {
        let page = Self.makePage([Self.item("1", .pending, parent: "1")])

        #expect(page.todos.first?.depth == 0,
                "a self-parented item does not loop forever")
    }

    @Test("a cycle in the plan does not hang the depth")
    @MainActor
    func aCycleInThePlanDoesNotHangTheDepth() {
        let page = Self.makePage([
            Self.item("1", .pending, parent: "2"),
            Self.item("2", .pending, parent: "1"),
        ])

        #expect(page.todos.count == 2, "both items are still on the page")
        #expect(page.todos.allSatisfy { $0.depth == 0 },
                "a cycle degrades to the top level")
    }

    // MARK: - A read that fails

    @Test("a failed read says so and invents no count")
    @MainActor
    func aFailedReadSaysSoAndInventsNoCount() {
        struct PlanReadFailure: Error {}

        let failing = InspectorTodoModel(readPlan: { throw PlanReadFailure() })
        failing.refresh()

        #expect(failing.loadFailed, "the page says the plan could not be read")
        #expect(failing.todos.isEmpty, "a failed read invents no items")
        #expect(failing.todos.isEmpty)
    }

    @Test("a failed read keeps the last good cards")
    @MainActor
    func aFailedReadKeepsTheLastGoodCards() {
        struct PlanReadFailure: Error {}

        let model = InspectorTodoModel(readPlan: { [Self.item("1", .pending)] })
        model.refresh()
        #expect(model.todos.count == 1)
        #expect(!model.loadFailed)

        let failing = InspectorTodoModel(readPlan: { throw PlanReadFailure() })
        failing.refresh()
        #expect(failing.loadFailed)
    }

    // MARK: - The depth rule on its own

    @Test("the depth rule reads the tree the plan declares")
    func theDepthRuleReadsTheTreeThePlanDeclares() {
        let todos = [
            InspectorTodo(id: "1", title: "a", status: .pending),
            InspectorTodo(id: "2", title: "b", status: .pending, parent: "1"),
            InspectorTodo(id: "3", title: "c", status: .pending, parent: "2"),
            InspectorTodo(id: "4", title: "d", status: .pending),
        ]

        let depths = InspectorTodoDepths.resolve(todos)
        #expect(depths["1"] == 0)
        #expect(depths["2"] == 1)
        #expect(depths["3"] == 2)
        #expect(depths["4"] == 0, "an item without a parent is a top-level step")
    }
}
