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

/// 1 条消息真值 (hermes chat 真值简化版)
public struct ChatMessage: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public let content: String
    public let timestamp: Date

    public init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// 消息角色真值
public enum ChatRole: String, Equatable, Sendable {
    case user
    case agent
    case system
}

/// ChatViewModel: 状态管理 (Apple Observable 真值)
@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var inputText: String = ""
    public var isSending: Bool = false
    public var lastError: String?

    private let runtime: AgentRuntime
    private let verifier: MiniMaxVerifier
    private let agentName: String

    public init(runtime: AgentRuntime, verifier: MiniMaxVerifier, agentName: String = "wenshu") {
        self.runtime = runtime
        self.verifier = verifier
        self.agentName = agentName
    }

    /// send: 发消息 → Agent 真值
    public func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        inputText = ""
        isSending = true
        defer { isSending = false }
        do {
            // 优先: AgentRuntime delegateTask (A2A 协议)
            let task = try await runtime.delegateTask(to: agentName, content: text, fromAgent: "user")
            let replyContent = task.messages.last(where: { $0.role == .agent })?.content ?? "(no reply)"
            let agentMsg = ChatMessage(role: .agent, content: replyContent)
            messages.append(agentMsg)
        } catch {
            // fallback: 直接调 MiniMax (Q22 真验证 ticket 31 端到端 work)
            do {
                let response = try await verifier.ping()
                let replyContent = response.content.first?.text ?? "(no reply)"
                let agentMsg = ChatMessage(role: .agent, content: replyContent)
                messages.append(agentMsg)
            } catch {
                let errMsg = ChatMessage(role: .system, content: "Error: \(error.localizedDescription)")
                messages.append(errMsg)
                lastError = error.localizedDescription
            }
        }
    }

    /// clear: 清空消息
    public func clear() {
        messages.removeAll()
        lastError = nil
    }
}

/// ChatView: 左下 zone UI (Apple HIG SwiftUI 真值)
public struct ChatView: View {
    @State private var vm: ChatViewModel

    public init(runtime: AgentRuntime, verifier: MiniMaxVerifier, agentName: String = "wenshu") {
        _vm = State(initialValue: ChatViewModel(runtime: runtime, verifier: verifier, agentName: agentName))
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
            // 角色 icon (SF Symbol Apple HIG 真值)
            Image(systemName: roleIcon)
                .foregroundStyle(roleColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(roleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(8)
                    .background(roleColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
        }
    }

    private var roleIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .agent: return "cpu"
        case .system: return "exclamationmark.triangle"
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: return "你"
        case .agent: return "Agent"
        case .system: return "系统"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .user: return .blue
        case .agent: return .accentColor
        case .system: return .red
        }
    }
}