//
//  ChatViewTests.swift · Wenshu · v0.20 ticket 01 (chat UI)
//
//  单元测试 ChatViewModel + ChatMessage 真值.
//  不测真 UI (sandbox 限制), 测 ChatViewModel 行为.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView (wenshu 左下 zone)")
struct ChatViewTests {
    @Test("ChatMessage + ChatRole 真值")
    func testChatMessageEquatable() {
        let m1 = ChatMessage(role: .user, content: "hello")
        let m2 = ChatMessage(role: .user, content: "hello")
        #expect(m1.content == m2.content)
        #expect(m1.role == m2.role)
        let m3 = ChatMessage(role: .agent, content: "world")
        #expect(m1 != m3)
    }

    @Test("ChatViewModel 初始空")
    @MainActor
    func testInitialState() {
        let runtime = AgentRuntime()
        let verifier = MiniMaxVerifier()
        let vm = ChatViewModel()
        #expect(vm.messages.isEmpty)
        #expect(vm.inputText.isEmpty)
        #expect(vm.isSending == false)
        #expect(vm.lastError == nil)
    }

    @Test("clear 清空消息")
    @MainActor
    func testClear() {
        let runtime = AgentRuntime()
        let verifier = MiniMaxVerifier()
        let vm = ChatViewModel()
        // 直接 push (绕过 send 异步)
        vm.messages.append(ChatMessage(role: .user, content: "test"))
        vm.lastError = "some error"
        vm.clear()
        #expect(vm.messages.isEmpty)
        #expect(vm.lastError == nil)
    }

    @Test("send 空字符串不发送")
    @MainActor
    func testSendEmpty() async {
        let runtime = AgentRuntime()
        let verifier = MiniMaxVerifier()
        let vm = ChatViewModel()
        vm.inputText = "   "
        await vm.send()
        #expect(vm.messages.isEmpty)
    }

    @Test("ChatMessage source 真值 (user / wenshu / system)")
    func testChatMessageSource() {
        let userMsg = ChatMessage(role: .user, source: .user, content: "hi")
        let wenshuMsg = ChatMessage(role: .agent, source: .wenshu, content: "hello back")
        let sysMsg = ChatMessage(role: .system, source: .system, content: "err")
        #expect(userMsg.source == .user)
        #expect(wenshuMsg.source == .wenshu)
        #expect(sysMsg.source == .system)
        // 不同 source 不等
        #expect(userMsg != wenshuMsg)
        // 同 source 不同 content 不等
        let wenshuMsg2 = ChatMessage(role: .agent, source: .wenshu, content: "different")
        #expect(wenshuMsg != wenshuMsg2)
    }
}