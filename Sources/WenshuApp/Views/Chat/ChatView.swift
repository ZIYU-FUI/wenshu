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
    public var currentModel: String = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? MiniMaxModel.m3.rawValue
    public var availableModels: [String] = []
    public var contextUsed: Int = 0
    public var contextMax: Int = 131072  // MiniMax-M3 真值 context window = 128k = 131072 tokens (Hermes ModelInfoResponse.context_length 范式)

    private let conductor: WenshuConductor?
    private let store: ChatSessionStore?
    private let sessionId: String

    public init(conductor: WenshuConductor? = nil, store: ChatSessionStore? = nil, sessionId: String = "default", initialMessages: [ChatMessage] = []) {
        self.conductor = conductor
        self.store = store
        self.sessionId = sessionId
        self.messages = initialMessages
    }

    public func switchModel(_ id: String) {
        currentModel = id
        UserDefaults.standard.set(id, forKey: "wenshu.llm.model")
    }

    public func loadAvailableModels() async {
        let base = ProcessInfo.processInfo.environment["MINIMAX_CN_BASE_URL"] ?? "https://api.minimaxi.com/anthropic"
        if let key = LLMKeychain.loadKeySync(), !key.isEmpty {
            availableModels = await MiniMaxModelFetcher.loadModelIds(apiKey: key, baseUrl: base)
        } else {
            availableModels = MiniMaxModel.allCases.map { $0.rawValue }
        }
        if !availableModels.contains(currentModel) {
            availableModels = [currentModel] + availableModels
        }
        recomputeContextUsed()
    }

    /// 用 messages 真值估 contextUsed (4 chars/token 真值估算, Hermes真值近似)
    public func recomputeContextUsed() {
        let totalChars = messages.reduce(0) { $0 + $1.content.count }
        contextUsed = max(0, totalChars / 4)
    }

    /// send: 发消息 → 文枢主 agent 真合成 (v0.21 ticket 06 + code-review S1+S2 真持久化)
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
                // 没 conductor (向后兼容) → fallback 调 shared verifier
                let verifier = MiniMaxVerifier()
                let response = try await verifier.chat(text)
                reply = response.content.first?.text ?? "(no reply)"
            }
            let agentMsg = ChatMessage(role: .agent, source: .wenshu, content: reply)
            messages.append(agentMsg)
            let agentMsgStored = StoredChatMessage(id: agentMsg.id.uuidString, source: "wenshu", content: reply, timestamp: Date())
            try? await store?.append(agentMsgStored, sessionId: sessionId)
            recomputeContextUsed()

            // v0.21 ticket 06 code-review S1: 真触发 summary 生成 (LLM call + saveSummary + deleteOldMessages 顺序, 不直接 delete)
            if let store = store {
                let verifier = MiniMaxVerifier()
                Task { @MainActor in
                    _ = try? await store.summarizeIfNeeded(sessionId: sessionId, lastN: 10, threshold: 20, verifier: verifier)
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

    /// valueForStore: 暴露 store 给 ChatView .task modifier (避免 init race condition)
    public nonisolated func valueForStore() -> ChatSessionStore? { store }
    public nonisolated func valueForSessionId() -> String { sessionId }

    /// replaceMessages: ChatView .task 加载完成后整体替换 (避免增量 append 重复)
    public func replaceMessages(_ newMessages: [ChatMessage]) {
        self.messages = newMessages
    }
}

/// ChatView: 左下 zone UI (Apple HIG SwiftUI 真值, v0.21 ticket 06 传 conductor + store 集成)
public struct ChatView: View {
    @State private var vm: ChatViewModel

    public init(conductor: WenshuConductor? = nil, store: ChatSessionStore? = nil, sessionId: String = "default") {
        // v0.21 ticket 06 code-review S2: initialMessages 用 .task 异步 load, 避免 init race condition
        _vm = State(initialValue: ChatViewModel(conductor: conductor, store: store, sessionId: sessionId, initialMessages: []))
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
            // v0.21 ticket 06 code-review S2: 异步 load 历史 (在 .task modifier 不阻塞首渲染)
            .task {
                await vm.loadAvailableModels()
                if let store = vm.valueForStore() {
                    if let loaded = try? await store.loadMessages(sessionId: vm.valueForSessionId()) {
                        let mapped = loaded.map { stored in
                            ChatMessage(
                                id: UUID(uuidString: stored.id) ?? UUID(),
                                role: .agent,
                                source: ChatSource(rawValue: stored.source) ?? .wenshu,
                                content: stored.content,
                                timestamp: stored.timestamp
                            )
                        }
                        vm.replaceMessages(mapped)
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
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // 底栏 (Hermes appChrome 范式): 左 model + 右 context 用量
            HStack(spacing: 8) {
                Menu {
                    ForEach(vm.availableModels, id: \.self) { id in
                        Button(id) { vm.switchModel(id) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                        Text(vm.currentModel)
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: 220, alignment: .leading)
                .help("点击切换模型")

                Spacer()

                Text("\(compactNumber(vm.contextUsed)) / \(compactNumber(vm.contextMax))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(min(vm.contextUsed, vm.contextMax)), total: Double(max(1, vm.contextMax)))
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                    .tint(vm.contextUsed >= vm.contextMax ? .red : (vm.contextUsed > vm.contextMax * 3 / 4 ? .orange : .green))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
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
/// compactNumber: 真实 token count 折 compact 格式 (Hermes format_token_count_compact 真值)
/// 1k → "1.0k", 1.5M → "1.5M", 200 → "200"
private func compactNumber(_ n: Int) -> String {
    let d = Double(n)
    if d >= 1_000_000 { return String(format: "%.1fM", d / 1_000_000).replacingOccurrences(of: ".0M", with: "M") }
    if d >= 1_000 { return String(format: "%.1fk", d / 1_000).replacingOccurrences(of: ".0k", with: "k") }
    return "\(n)"
}
