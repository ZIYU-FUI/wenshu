//
//  ChatView.swift · Wenshu · v0.20 ticket 01 (Agent 对话左下区)
//
//  左下角 zone 接入真 Chat UI + Agent 对话 (复刻 hermes 35 skill chat 真值).
//  老板 2026-08-19 evening 拍 "先实现聊天区, 就是左下角区域, 能进行 Agent 对话".
//
//  业务语言描述 (老板懂):
//  - wenshu 左下 zone 改成真 chat (消息列表 + 输入框 + 发送按钮)
//  - 点发送 → AgentRuntime.delegateTask → MiniMaxVerifier.ping 调 MiniMax-M3
//  - MiniMax key 端到端调通 (Q22 真验证, ticket 31 done, HTTP 200)
//  - 工程管理老板授权 + 不需要验收
//
//  Apple HIG 真值: SwiftUI VStack + List + TextField + Button 范式 (跟 Pages / Numbers 一样).
//

import SwiftUI

/// 1 条消息真值 (user / 文枢 / 系统 三方, 文枢背后多 agent 调度不进 ChatMessage 流)
public struct ChatMessage: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public let source: ChatSource
    public let content: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        source: ChatSource = .wenshu,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.source = source
        self.content = content
        self.timestamp = timestamp
    }
}

/// 消息角色真值 (兼容 v0.20 ticket 01, 实际显示走 source)
public enum ChatRole: String, Equatable, Sendable {
    case user
    case agent
    case system
}

/// 消息来源真值 (user = 用户发的 / wenshu = 文枢回的 / system = 系统报错). 文枢背后多 agent 调度结果不显 ChatMessage, 走 KanbanStore 看板.
public enum ChatSource: String, Equatable, Sendable, Codable {
    case user
    case wenshu
    case system
}

/// ChatViewModel: 状态管理 (Apple Observable 真值, v0.21 ticket 06 集成 ChatSessionStore + WenshuConductor)
@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var inputText: String = ""
    public var isSending: Bool = false
    public var lastError: String?

    private let conductor: WenshuConductor?
    private let store: ChatSessionStore?
    private let sessionId: String

    public init(conductor: WenshuConductor? = nil, store: ChatSessionStore? = nil, sessionId: String = "default") {
        self.conductor = conductor
        self.store = store
        self.sessionId = sessionId
        // v0.21 ticket 06: 启动时异步加载历史
        if let store = store {
            Task { @MainActor in
                if let loaded = try? await store.loadMessages(sessionId: sessionId) {
                    self.messages = loaded.map { stored in
                        ChatMessage(id: UUID(uuidString: stored.id) ?? UUID(), role: .agent, source: ChatSource(rawValue: stored.source) ?? .wenshu, content: stored.content, timestamp: stored.timestamp)
                    }
                }
            }
        }
    }

    /// send: 发消息 → 文枢主 agent 真合成 (v0.21 ticket 06 走 WenshuConductor.handle, 调 MiniMaxVerifier 真 LLM)
    public func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        let userMsg = ChatMessage(role: .user, source: .user, content: text)
        messages.append(userMsg)
        inputText = ""
        isSending = true
        defer { isSending = false }

        let userMsgStored = StoredChatMessage(id: userMsg.id.uuidString, source: "user", content: text, timestamp: Date())
        try? await store?.append(userMsgStored, sessionId: sessionId)

        do {
            // v0.21 ticket 06: 走 WenshuConductor.handle (intent classify → 派子 agent → LLM synthesis)
            let reply: String
            if let conductor = conductor {
                reply = try await conductor.handle(userMessage: text, sessionId: sessionId)
            } else {
                // 没 conductor (向后兼容) → fallback 调 verifier.chat
                let response = try await MiniMaxVerifier().chat(text)
                reply = response.content.first?.text ?? "(no reply)"
            }
            let agentMsg = ChatMessage(role: .agent, source: .wenshu, content: reply)
            messages.append(agentMsg)
            let agentMsgStored = StoredChatMessage(id: agentMsg.id.uuidString, source: "wenshu", content: reply, timestamp: Date())
            try? await store?.append(agentMsgStored, sessionId: sessionId)

            // v0.21 ticket 06: 异步触发 sliding window summary (不阻塞 UI)
            if let store = store {
                Task { @MainActor in
                    if let cutoff = try? await store.summaryCutoffTimestamp(sessionId: sessionId, keepLastN: 20) {
                        try? await store.deleteOldMessages(sessionId: sessionId, beforeTimestamp: cutoff)
                    }
                }
            }
        } catch {
            let errMsg = ChatMessage(role: .system, source: .system, content: "Error: \(error.localizedDescription)")
            messages.append(errMsg)
            lastError = error.localizedDescription
        }
    }

    /// clear: 清空消息
    public func clear() {
        messages.removeAll()
        lastError = nil
    }
}

/// ChatView: 左下 zone UI (Apple HIG SwiftUI 真值, v0.21 ticket 06 传 conductor + store 集成)
public struct ChatView: View {
    @State private var vm: ChatViewModel

    public init(conductor: WenshuConductor? = nil, store: ChatSessionStore? = nil, sessionId: String = "default") {
        _vm = State(initialValue: ChatViewModel(conductor: conductor, store: store, sessionId: sessionId))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 消息列表 (ScrollView + LazyVStack 真值)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.messages) { msg in
                            ChatMessageView(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 输入框 + 发送按钮 (Apple HIG SwiftUI 真值)
            HStack(spacing: 8) {
                TextField("输入消息...", text: $vm.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit { Task { await vm.send() } }
                Button {
                    Task { await vm.send() }
                } label: {
                    if vm.isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.inputText.isEmpty || vm.isSending)
            }
            .padding(8)
        }
    }
}

/// 1 条消息视图 (Apple HIG 真值)
struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            // 消息来源 icon (SF Symbol Apple HIG 真值, 按 source 显示 user / 文枢 / 系统)
            Image(systemName: sourceIcon)
                .foregroundStyle(sourceColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(8)
                    .background(sourceColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
        }
    }

    private var sourceIcon: String {
        switch message.source {
        case .user: return "person.fill"
        case .wenshu: return "text.book.closed.fill"
        case .system: return "exclamationmark.triangle"
        }
    }

    private var sourceLabel: String {
        switch message.source {
        case .user: return "你"
        case .wenshu: return "文枢"
        case .system: return "系统"
        }
    }

    private var sourceColor: Color {
        switch message.source {
        case .user: return .blue
        case .wenshu: return .accentColor
        case .system: return .red
        }
    }
}