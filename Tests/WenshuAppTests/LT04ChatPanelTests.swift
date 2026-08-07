import XCTest
@testable import WenshuApp

final class LT04ChatPanelTests: XCTestCase {
    func testChatPanel_initialState_chatTabActive() {
        XCTAssertEqual(ChatPanelTab.allCases.first, .chat)
    }

    func testChatPanel_disabledTabs_cannotBeSelected() {
        XCTAssertTrue(ChatPanelTab.timeline.isDisabled)
        XCTAssertTrue(ChatPanelTab.relationships.isDisabled)
        XCTAssertTrue(ChatPanelTab.outline.isDisabled)
    }

    func testChatPanel_disabledTabs_showV040Hint() {
        XCTAssertEqual(ChatPanelTab.timeline.placeholder, "v0.04.0 实现")
        XCTAssertEqual(ChatPanelTab.relationships.placeholder, "v0.04.0 实现")
        XCTAssertEqual(ChatPanelTab.outline.placeholder, "v0.04.0 实现")
    }

    @MainActor
    func testChatPanel_chatTab_emptyProject_showsPlaceholder() {
        let vm = ChatViewModel()
        XCTAssertNil(vm.currentProject)
        XCTAssertEqual(ChatPanelView.chatPlaceholder, "先在项目里开始一次创作")
    }

    @MainActor
    func testChatPanel_chatTab_withProject_rendersChatView() {
        let vm = ChatViewModel()
        vm.currentProject = ProjectSnapshot(name: "测试项目", style: "轻松")
        XCTAssertNotNil(vm.currentProject)
        XCTAssertTrue(ChatPanelView.shouldRenderChat(for: vm))
    }
}
