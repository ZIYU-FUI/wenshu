//
//  ChatView.swift · Wenshu · v0.20 ticket 01 (Agent 对话左下区)
//
//  左下角 zone 接入真 Chat UI + Agent 对话 (复刻 hermes 35 skill chat 真值).
//  老板 2026-08-19 evening 拍 "先实现聊天区, 就是左下角区域, 能进行 Agent 对话".
//
//  业务语言描述 (老板懂):
//  - wenshu 左下 zone 改成真 chat (消息列表 + 输入框 + 发送按钮)
//  - 点发送 → AgentRuntime.delegateTask → WenshuVerifier.ping 调 MiniMax-M3
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
    public var tokens: Int?    // real LLM API usage.total_tokens (nil if user message or unavailable)
    public var thinking: String?    // CoT thinking content from WenshuLLMBlock.thinking (folded footnote UI)

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

/// ChatViewModel: 状态管理 (Apple Observable + ChatSessionStore + WenshuConductor)
@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var inputText: String = ""
    public var isSending: Bool = false
    public var lastError: String?
    // v0.24 boss验收fix (2026-08-24): default empty string when no provider key
    // configured (not "MiniMax-M3" which implies a MiniMax provider is
    // selected even when user has no key). UI shows "无模型可用" placeholder
    // when this is empty.
    public var currentModel: String = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? ""
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
        // v0.24 boss验收fix (2026-08-24): use multi-provider discovery.
        // Was: fallback to WenshuLLMModel.allCases (3 MiniMax-only cases).
        // Now: query all configured providers via AvailableModelsDiscovery,
        // sectioned by provider per ticket 011 spec.
        let configured = AvailableModelsDiscovery.loadFromKeychain()
        var modelIds: [String] = []
        for section in configured {
            for modelId in section.models {
                // Prefix with provider slug for clarity (e.g. "anthropic / claude-3.7-sonnet").
                modelIds.append(modelId)
            }
        }
        if modelIds.isEmpty {
            // No provider keys configured. Fall back to MiniMax hardcoded
            // list (current WenshuLLMModel scope per boss 8/21).
            modelIds = WenshuLLMModel.allCases.map { $0.rawValue }
        }
        availableModels = modelIds
        if !availableModels.contains(currentModel) {
            availableModels = [currentModel] + availableModels
        }
        recomputeContextUsed()
    }

    /// recomputeContextUsed: sum of all agent message tokens (real LLM API usage, replaces chars/4 heuristic)
    public func recomputeContextUsed() {
        contextUsed = messages.compactMap { $0.tokens }.reduce(0, +)
        // trace: ChatViewModel.contextUsed accumulation
        NSLog("[wenshu.context] sum tokens after recompute: %d (messages=%d)", contextUsed, messages.count)
    }

    /// send: 发消息 → 文枢主 agent 合成
    public func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        let userMsg = ChatMessage(role: .user, source: .user, content: text)
        messages.append(userMsg)
        inputText = ""
        isSending = true

        // append AI placeholder message (name + avatar + "AI 思考中…" in list immediately)
        let placeholderId = UUID()
        let placeholder = ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: "AI 思考中…", isPlaceholder: true)
        messages.append(placeholder)

        let userMsgStored = StoredChatMessage(id: userMsg.id.uuidString, source: "user", content: text, timestamp: Date())
        try? await store?.append(userMsgStored, sessionId: sessionId)

        do {
            // WenshuConductor.handle (intent → sub-agent → LLM synthesis)
            // receive real token count from LLM API
            // read current model from UserDefaults
            // = 原 send() 不传 model → conductor/verifier 用 hardcoded .m3)
            // We need to pass model to the LLM call so the AI actually uses boss's selected model
            // trace: effective model per send
            // v0.24 boss验收fix (2026-08-24): default empty string when no key.
            let currentModel: String = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? ""
            NSLog("[wenshu.model] effective model: %@ (UserDefaults source)", currentModel)
            var reply: String
            var replyThinking: String?    // WenshuLLMBlock.thinking footnote UI
            var replyTokens: Int?
            if let conductor = conductor {
                let result = try await conductor.handle(userMessage: text, sessionId: sessionId, model: currentModel)
                reply = result.reply
                replyThinking = result.thinking
                replyTokens = result.totalTokens
            } else {
                // fallback 调 shared verifier — real usage from response.usage
                let verifier = WenshuVerifier()
                let response = try await verifier.chat(text, model: currentModel)
                // union decode WenshuLLMBlock (text/thinking/tool_use) — concat all text blocks for reply
                // pick first thinking block for ChatMessage.thinking footnote UI (Apple HIG footnote 范式)
                reply = response.content.map(\.displayText).joined()
                if reply.isEmpty {
                    reply = "(no reply)"
                }
                replyThinking = response.content.compactMap(\.thinkingText).first
                replyTokens = response.usage?.total_tokens
            }
            // replace placeholder with real reply (tokens + thinking footnote)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                // trace: placeholder replacement count check
                NSLog("[wenshu.scroll] placeholder replace: id=%@ beforeCount=%d afterCount=%d", placeholderId.uuidString, messages.count, messages.count)
                messages[idx] = ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: reply, tokens: replyTokens, thinking: replyThinking)
            }
            let agentMsgStored = StoredChatMessage(id: placeholderId.uuidString, source: "wenshu", content: reply, timestamp: Date(), tokens: replyTokens)
            try? await store?.append(agentMsgStored, sessionId: sessionId)
            recomputeContextUsed()

            // trigger summary generation (LLM + saveSummary + deleteOldMessages order)
            if let store = store {
                let verifier = WenshuVerifier()
                Task { @MainActor in
                    _ = try? await store.summarizeIfNeeded(sessionId: sessionId, lastN: 10, threshold: 20, verifier: verifier)
                }
            }
        } catch {
            // on failure, replace placeholder with error message
            // Chinese error messages, not Swift Foundation data-loss text
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

/// ChatView: 左下 zone UI (Apple HIG SwiftUI + conductor + store)
public struct ChatView: View {
    @State private var vm: ChatViewModel
    // v0.24 boss验收fix (2026-08-24): focus management for input box.
    // Boss 8/24 feedback: when no provider key, chat input should be disabled
    // AND lose focus (no cursor blinking, no keyboard capture).
    @FocusState private var inputFocused: Bool
    // Reactive check: is the current model usable?
    private var hasUsableKey: Bool { !vm.currentModel.isEmpty && !vm.isSending }

    public init(conductor: WenshuConductor? = nil, store: ChatSessionStore? = nil, sessionId: String = "default", vm: ChatViewModel? = nil) {
        // optional ChatViewModel injection (ChatZoneView shared vm for bottom toolbar
        // 读 vm.contextUsed 自动 propagate. Q51 子组件 override 父组件部分, 不动 ChatViewModel.send() body, 不动 ChatView body)
        if let vm = vm {
            _vm = State(initialValue: vm)
        } else {
            // initialMessages via .task async load (avoids init race)
            _vm = State(initialValue: ChatViewModel(conductor: conductor, store: store, sessionId: sessionId, initialMessages: []))
        }
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
                // Apple SwiftUI 14+ .defaultScrollAnchor(.bottom)
                // Apple 真值 = ScrollView 内容变化时自动贴底, 兜底 placeholder -> reply 替换时 scrollTo 不触发
                .defaultScrollAnchor(.bottom)
                // onChange of lastContent, not just count
                // placeholder 创建时 content="AI 思考中…" (15 chars), reply 替换后 content=长 reply (~hundreds chars)
                // content 变化触发 onChange, scrollTo 新 last.id
                .onChange(of: vm.messages.last?.content ?? "") { _, _ in
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            // async load history via .task modifier (non-blocking)
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
                // v0.24 boss验收fix (2026-08-24): placeholder shows different text based on key state.
                // Boss 8/24 (out-of-band): '请先在设置中设置好大模型提供方'.
                TextField(hasUsableKey ? "输入消息..." : "请先在设置中设置好大模型提供方",
                          text: $vm.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    // v0.24 boss验收fix: disable when no key configured.
                    .disabled(!hasUsableKey)
                    .focused($inputFocused)
                    .onSubmit { Task { await vm.send() } }
                    // Defocus when key becomes unusable (e.g. user removed key).
                    .onChange(of: vm.currentModel) { _, new in
                        if new.isEmpty { inputFocused = false }
                    }
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
        }
        // v0.24 boss验收fix (2026-08-24): help text DIRECTLY below input box.
        // Boss 8/24 (out-of-band): '请先在设置中设置好大模型提供方。点击设置'
        // (设置 clickable, jumps to Settings → provider tab).
        Group {
            if !hasUsableKey {
                HStack(spacing: 4) {
                    Text("请先在")
                        .foregroundStyle(.secondary)
                    // v0.24 boss验收fix: NSApp.showSettingsWindow (works without capture).
                    // UserDefaults pre-set selects providerApi tab.
                    Button {
                        UserDefaults.standard.set("providerApi", forKey: "wenshu.settingsTab")
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } label: {
                        Text("设置")
                            .foregroundStyle(Color.accentColor)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    Text("中设置好大模型提供方")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            }
        }
        .animation(.default, value: vm.isSending)
        .animation(.default, value: hasUsableKey)
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
                    // 文枢 AI placeholder status indicator
                    HStack(spacing: 4) {
                        // brain SF Symbol — 🤖 emoji per user feedback
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
                    // CoT thinking block collapsed (Apple HIG footnote)
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
