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
    public var content: String
    public let timestamp: Date
    public var isPlaceholder: Bool
    public var tokens: Int?    // v0.21 ticket 34: real LLM API usage.total_tokens (nil if user message or unavailable)
    public var thinking: String?    // v0.21 ticket 39: CoT thinking content from MiniMaxBlock.thinking (folded footnote UI)

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        source: ChatSource = .wenshu,
        content: String,
        timestamp: Date = Date(),
        isPlaceholder: Bool = false,
        tokens: Int? = nil,
        thinking: String? = nil
    ) {
        self.id = id
        self.role = role
        self.source = source
        self.content = content
        self.timestamp = timestamp
        self.isPlaceholder = isPlaceholder
        self.tokens = tokens
        self.thinking = thinking
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

    /// recomputeContextUsed: sum of all agent message tokens (v0.21 ticket 34 real LLM API usage, replaces chars/4 heuristic)
    public func recomputeContextUsed() {
        contextUsed = messages.compactMap { $0.tokens }.reduce(0, +)
    }

    /// send: 发消息 → 文枢主 agent 真合成 (v0.21 ticket 06 + code-review S1+S2 真持久化)
    public func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        let userMsg = ChatMessage(role: .user, source: .user, content: text)
        messages.append(userMsg)
        inputText = ""
        isSending = true

        // v0.21 ticket 30: append AI placeholder message so 文枢 名字 + 头像 + "AI 思考中…" 占位立刻出现在消息列表
        let placeholderId = UUID()
        let placeholder = ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: "AI 思考中…", isPlaceholder: true)
        messages.append(placeholder)

        let userMsgStored = StoredChatMessage(id: userMsg.id.uuidString, source: "user", content: text, timestamp: Date())
        try? await store?.append(userMsgStored, sessionId: sessionId)

        do {
            // v0.21 ticket 06: 走 WenshuConductor.handle (intent classify → 派子 agent → LLM synthesis)
            // v0.21 ticket 34: receive real token count from LLM API (conductor + fallback verifier)
            // v0.21 ticket 38: read current model from UserDefaults (boss 反馈 "切换了 AI 没有真的换"
            // = 原 send() 不传 model → conductor/verifier 用 hardcoded .m3)
            // We need to pass model to the LLM call so the AI actually uses boss's selected model
            let currentModel: String = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? "MiniMax-M3"
            var reply: String
            var replyThinking: String?    // v0.21 ticket 39: MiniMaxBlock.thinking footnote UI
            var replyTokens: Int?
            if let conductor = conductor {
                let result = try await conductor.handle(userMessage: text, sessionId: sessionId, model: currentModel)
                reply = result.reply
                replyThinking = result.thinking
                replyTokens = result.totalTokens
            } else {
                // fallback 调 shared verifier — real usage from response.usage
                let verifier = MiniMaxVerifier()
                let response = try await verifier.chat(text, model: currentModel)
                // v0.21 ticket 39: union decode MiniMaxBlock (text / thinking / tool_use) — concat all text blocks for reply,
                // pick first thinking block for ChatMessage.thinking footnote UI (Apple HIG footnote 范式)
                reply = response.content.map(\.displayText).joined()
                if reply.isEmpty {
                    reply = "(no reply)"
                }
                replyThinking = response.content.compactMap(\.thinkingText).first
                replyTokens = response.usage?.total_tokens
            }
            // v0.21 ticket 30: 替换 placeholder 为真实回复 (with real tokens + thinking footnote)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: reply, tokens: replyTokens, thinking: replyThinking)
            }
            let agentMsgStored = StoredChatMessage(id: placeholderId.uuidString, source: "wenshu", content: reply, timestamp: Date(), tokens: replyTokens)
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
            // v0.21 ticket 30: 失败也替换 placeholder 为错误消息
            // v0.21 ticket 39 Q36 .error source: 中文明确错误信息, 不直接暴露 Swift Foundation "数据丢失" 翻译
            let errMsg: String
            if let decodingErr = error as? DecodingError {
                errMsg = "模型 \(currentModel) 返回数据格式不支持 (DecodingError). 真因查 stderr [wenshu.chat] decoder error 行."
            } else {
                errMsg = "Error: \(error.localizedDescription)"
            }
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = ChatMessage(id: placeholderId, role: .system, source: .system, content: errMsg)
            }
            lastError = error.localizedDescription
        }
        isSending = false
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
                                timestamp: stored.timestamp,
                                tokens: stored.tokens
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
            .padding(.horizontal, 18)
            .padding(.bottom, 4)
        }
        .animation(.default, value: vm.isSending)
    }
}

/// 1 条消息视图 (Apple HIG 真值)
struct ChatMessageView: View {
    let message: ChatMessage
    @State private var thinkingExpanded: Bool = false

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
                if message.isPlaceholder {
                    // v0.21 ticket 30: 文枢 AI placeholder status indicator (小机器人 + 小菊花 + 思考中文字)
                    HStack(spacing: 4) {
                        // v0.21 ticket 33: brain was not a small robot, 老板 said "similar to 🤖 emoji"
                        // New SF Symbol: person.crop.circle.badge.questionmark (Apple SF Symbols 5+
                        // real value, round face + question mark = robot assistant face style, closest to 🤖)
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .symbolEffect(.pulse, options: .repeating)
                            .foregroundStyle(.secondary)
                        Text(message.content)
                            .foregroundStyle(.secondary)
                        ProgressView()
                            .controlSize(.mini)
                            .progressViewStyle(.circular)
                    }
                    .padding(8)
                    .background(sourceColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    // v0.21 ticket 39: CoT thinking block 折叠显示 (Apple HIG footnote 范式)
                    // DisclosureGroup + 圆角 + Apple 默认动画 (.animation(.default, value:) per Q58.4)
                    if let thinking = message.thinking, !thinking.isEmpty, message.source == .wenshu {
                        DisclosureGroup(isExpanded: $thinkingExpanded) {
                            Text(thinking)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(.top, 4)
                                .transition(.opacity)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "brain")
                                    .font(.caption)
                                Text("AI 思考过程")
                                    .font(.caption)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .animation(.default, value: thinkingExpanded)
                    }
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(8)
                        .background(sourceColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
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
