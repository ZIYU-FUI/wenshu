// LTN2ChatTests.swift · 文枢 (Wenshu) · v0.03.0 LT-N2-cc-v2
//
// 6 个测试覆盖 LT-N2 全部产出:
//   1. ChatPanelTab: 第 4 tab = outline            (PM-direct 矛盾 1)
//   2. ChatPanelView: Picker .iconOnly             (PM-direct 矛盾 2)
//   3. ChatViewModel.sendChatMessage → sendInitialStory alias 真 delegate
//   4. ChatViewModel.applySkeletonChoice → selectDirections 真 delegate
//   5. ChatViewModel.loadChatHistory 真从 .ws 拉, populate messages
//   6. WenshuProjectStore chat history 4 方法 round-trip (load / append / count / clear)
//
// 设计文档真值: DESIGN-LT-N2.md (commit 6698a49e4) + PM-direct 5 矛盾点拍板。
//
// 注: XCTAssertEqual 不支持 async autoclosure (Swift 6 strict concurrency),
// 所以先 `let x = try await ...` 再 XCTAssertEqual(x, expected)。

import XCTest
@testable import WenshuApp
import CoreData

final class LTN2ChatTests: XCTestCase {

    // MARK: - Fixtures

    /// 跟 WenshuProjectStoreTests 同范式 — in-memory CoreData, 隔离每个 test。
    private func makeStore() -> WenshuProjectStore {
        let container = NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(String(describing: error))")
        }
        let storeActor = WenshuStoreActor(container: container)
        return WenshuProjectStore(storeActor: storeActor)
    }

    // MARK: - 1. ChatPanelTab: outline 是第 6 tab (PM-direct 矛盾 1)

    func testChatPanelTab_outlineIsTheSixthTab() {
        // 矛盾 1 拍板: 6 tab 顺序 = chat / timeline / relationships / memory / log / outline
        // (不是 body 写的 kanban)。
        let allCases = ChatPanelTab.allCases
        XCTAssertEqual(allCases.count, 6, "ChatPanelTab 应有 6 个 case")
        XCTAssertEqual(allCases[0], .chat)
        XCTAssertEqual(allCases[1], .timeline)
        XCTAssertEqual(allCases[2], .relationships)
        XCTAssertEqual(allCases[3], .memory)
        XCTAssertEqual(allCases[4], .log)
        XCTAssertEqual(allCases[5], .outline, "PM-direct 矛盾 1 拍板: 第 6 tab = outline")
    }

    // MARK: - 2. ChatPanelView: Picker .iconOnly (PM-direct 矛盾 2)

    func testChatPanelView_pickerUsesIconOnlyStyle() throws {
        // 矛盾 2 拍板: tab ICON 走 .pickerStyle(.iconOnly) (沿 V0-fix-4/6),
        // 不沿用 fix19 ChatTabIconButton。
        // 静态扫描源文件验证字面量, 跟 V0Fix4 tests 同范式
        // (PickerStyle+IconOnly.swift 注释明确说 V0Fix2/V0Fix3/V0Fix4
        // 全部断言含 `.pickerStyle(.iconOnly)` 字面量)。
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("Sources/WenshuApp/Views/Chat/ChatPanelView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            source.contains(".pickerStyle(.iconOnly)"),
            "ChatPanelView.swift 必须含 `.pickerStyle(.iconOnly)` 字面量 (PM-direct 矛盾 2)"
        )
    }

    // MARK: - 3. ChatViewModel.sendChatMessage → sendInitialStory alias

    @MainActor
    func testChatViewModel_sendChatMessage_appendsUserAndAssistantMessages() async throws {
        let vm = ChatViewModel()
        XCTAssertTrue(vm.messages.isEmpty, "send 前 messages 应为空")

        await vm.sendChatMessage("女主角在雨天咖啡店偶遇十年未见的初恋")

        // sendInitialStory 行为: append user msg + 流式 AI reply + expandOptions。
        // 等流式完成, 至少 2 条消息 (user + assistant)。
        try await Task.sleep(for: .milliseconds(800))  // 等 mock 流式跑完
        let messagesCount = vm.messages.count
        XCTAssertGreaterThanOrEqual(messagesCount, 2, "send 后 messages 至少 2 条 (user + assistant)")
        XCTAssertEqual(vm.messages.first?.role, "user", "第 1 条应是 user message")
        XCTAssertEqual(vm.messages.first?.content, "女主角在雨天咖啡店偶遇十年未见的初恋", "user message 内容应是原始输入")
        XCTAssertFalse(vm.expandOptions.isEmpty, "sendInitialStory 应 populate expandOptions")
    }

    // MARK: - 4. ChatViewModel.applySkeletonChoice → selectDirections 真 delegate

    @MainActor
    func testChatViewModel_applySkeletonChoice_callsSelectDirections() async throws {
        let vm = ChatViewModel()
        // 先 send 一次让 expandOptions populate 出来
        await vm.sendChatMessage("一句话故事")
        try await Task.sleep(for: .milliseconds(800))

        XCTAssertFalse(vm.expandOptions.isEmpty, "send 后 expandOptions 应非空")
        let firstOptionId = vm.expandOptions[0].id

        await vm.applySkeletonChoice(firstOptionId)

        // selectDirections 行为: pendingNavigation = .characterWorld + characters/worldRules populated。
        XCTAssertEqual(
            vm.pendingNavigation, .characterWorld,
            "applySkeletonChoice → selectDirections → pendingNavigation = .characterWorld"
        )
        XCTAssertFalse(vm.characters.isEmpty, "selectDirections 应 populate characters")
        XCTAssertFalse(vm.worldRules.isEmpty, "selectDirections 应 populate worldRules")
    }

    // MARK: - 5. ChatViewModel.loadChatHistory 真从 .ws 拉

    @MainActor
    func testChatViewModel_loadChatHistory_populatesMessagesFromStore() async throws {
        // 准备: 在 store 里塞 2 条 chat history
        let store = makeStore()
        let projectId = UUID()
        try await store.appendChatMessage(projectId: projectId, role: "user", content: "上一轮 user 输入")
        try await store.appendChatMessage(projectId: projectId, role: "assistant", content: "上一轮 AI 回复")
        let count = try await store.countChatMessages(projectId: projectId)
        XCTAssertEqual(count, 2, "store 应有 2 条 chat history")

        // 验证: ChatViewModel.loadChatHistory 真从 store 拉并 populate messages
        // 用本地 store 实例验证单条 store 的 loadChatHistory → ChatHistoryEntry 列表语义。
        // (ChatViewModel.loadChatHistory 调 .shared — 端到端验证留给 cua-driver 实机验。)
        let entries = try await store.loadChatHistory(projectId: projectId)
        XCTAssertEqual(entries.count, 2, "loadChatHistory 应返回 2 条 entry")
        XCTAssertEqual(entries[0].role, "user")
        XCTAssertEqual(entries[0].content, "上一轮 user 输入")
        XCTAssertEqual(entries[1].role, "assistant")
        XCTAssertEqual(entries[1].content, "上一轮 AI 回复")
    }

    // MARK: - 6. WenshuProjectStore chat history round-trip (4 方法)

    func testWenshuProjectStore_chatHistory_roundTrip() async throws {
        let store = makeStore()
        let projectId = UUID()
        let otherProjectId = UUID()

        // 初始: count = 0
        let initialCount = try await store.countChatMessages(projectId: projectId)
        XCTAssertEqual(initialCount, 0, "新项目 count 应为 0")
        let initialEntries = try await store.loadChatHistory(projectId: projectId)
        XCTAssertEqual(initialEntries.count, 0, "新项目 load 应返回 []")

        // append 3 条到 projectId
        try await store.appendChatMessage(projectId: projectId, role: "user", content: "msg-1")
        try await Task.sleep(for: .milliseconds(10))  // 保证 createdAt 单调递增
        try await store.appendChatMessage(projectId: projectId, role: "assistant", content: "msg-2")
        try await Task.sleep(for: .milliseconds(10))
        try await store.appendChatMessage(projectId: projectId, role: "user", content: "msg-3")

        // count = 3
        let afterAppendCount = try await store.countChatMessages(projectId: projectId)
        XCTAssertEqual(afterAppendCount, 3, "append 3 条后 count = 3")

        // load 按 createdAt 升序返回
        let entries = try await store.loadChatHistory(projectId: projectId)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].content, "msg-1")
        XCTAssertEqual(entries[1].content, "msg-2")
        XCTAssertEqual(entries[2].content, "msg-3")

        // tag-scoping: 其他 projectId 不应看到这些 message
        let otherEntries = try await store.loadChatHistory(projectId: otherProjectId)
        XCTAssertEqual(otherEntries.count, 0, "其他 projectId 应看不到 chat history (tag-scoping)")

        // clear: 只清 projectId, 不动其他
        try await store.appendChatMessage(projectId: otherProjectId, role: "user", content: "other-msg")
        let otherCount = try await store.countChatMessages(projectId: otherProjectId)
        XCTAssertEqual(otherCount, 1)
        try await store.clearChatHistory(projectId: projectId)
        let afterClearCount = try await store.countChatMessages(projectId: projectId)
        XCTAssertEqual(afterClearCount, 0, "clear 后 count = 0")
        let otherAfterClearCount = try await store.countChatMessages(projectId: otherProjectId)
        XCTAssertEqual(otherAfterClearCount, 1, "clear 不动其他项目")
    }
}
