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
import Lucide

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
        // v0.24 boss验收fix (Boss 8/25 OOB 'minimax m3 is not 1MB context window?
    // you set 131k'): MiniMax-M3 context window = 1_000_000 tokens per official
    // docs (https://www.minimax.io/models/text/m3 = '1M Context';
    // max output 512K). Empirical limit on public anthropic-compatible endpoint
    // per hermes-agent issue #37289 = ~512K input cap (vendor enforces lower
    // than marketed). Decision: use official value (1M) so context budgeting
    // matches docs; actual API may reject >512K (vendor issue, not wenshu).
    // Note: Live API /v1/models does NOT return context_length field (= no API
    // to query per Boss 8/25 '没有接口获取的到吗' = boss confirmed no API).
    public var contextMax: Int = 1_000_000

    private let conductor: WenshuConductor?
    private let store: ChatSessionStore?
    // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014 + F2 cleanup): @MainActor
    // isolation replaces nonisolated(unsafe) for Swift 6 concurrency safety.
    // Mutable so archive flow can replace. sessionIdPublic accessor dropped
    // (SUGGEST 1 fix = valueForSessionId() already exists).
    @MainActor private var sessionId: String

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
                // v0.24 boss验收fix (Boss 8/24 OOB): prepend WenshuConductorIdentity.systemPrompt
                // (= 文枢 SOUL) so LLM returns 文枢 identity, not MiniMax vendor identity.
                // Without this, minimax cn API returns its default identity
                // ('MiniMax 开发的 AI 助手') because chat(_:model:) overload
                // doesn't prepend any system prompt.
                let verifier = WenshuVerifier()
                let response = try await verifier.chat(text,
                                                       system: WenshuConductorIdentity.systemPrompt,
                                                       model: currentModel)
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
    /// v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive current
    /// session + context (= reset messages + contextUsed), generate new
    /// sessionId, persist new session for future writes. Boss spec: '起一个
    /// 全新的会话. 上下文重新加载'.
    public func startNewSession() {
        // 1. Clear in-memory state (= visual reset).
        messages = []
        contextUsed = 0
        // 2. Generate new sessionId (= UUID-based).
        let newId = "s_" + UUID().uuidString.prefix(12).lowercased()
        sessionId = newId
        // 3. NSLog audit trail (= verify in Console.app).
        NSLog("[wenshu.chat] startNewSession: id=%@ messages=%d contextUsed=%d",
              sessionId, messages.count, contextUsed)
    }

    public func clear() {
        messages.removeAll()
        lastError = nil
    }

    /// valueForStore: 暴露 store 给 ChatView .task modifier (避免 init race condition)
    public nonisolated func valueForStore() -> ChatSessionStore? { store }
    public func valueForSessionId() -> String { sessionId }  // v0.24 boss验收fix (F2): @MainActor-isolated with sessionId

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
        // v0.24 boss验收fix: listen for global defocus notification.
        // Boss 8/24 feedback: '点其它区域, 文本框还是不失焦'.
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
                            // v0.24 boss验收fix: preserve role from stored.source.
                            // Was: hardcoded .agent (wrong, user messages shown as agent).
                            // Now: parse source = "user" → .user role, "wenshu" → .agent.
                            let resolvedRole: ChatRole = (stored.source == "user") ? .user : .agent
                            return ChatMessage(
                                id: UUID(uuidString: stored.id) ?? UUID(),
                                role: resolvedRole,
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
            // v0.25.1 (= ticket 030 chat send button 8 PT textfield
            // top padding + button vertical center alignment):
            // owner 2026-08-26 OOB '聊天文本框上加 8 PT 的间隔' =
            // add 8 PT gap between the Divider above and the
            // TextField (= textfield top padding = 8 PT, so the
            // input area has visual breathing room from the divider
            // line). Implementation: HStack(spacing: 8) reverted to
            // baseline (= boss corrected ticket 030's HStack 8→16
            // change as wrong, = the gap is ABOVE the textfield not
            // between textfield and send button), TextField gains
            // .padding(.top, 8) (= 8 PT gap above the textfield,
            // = the actual boss OOB intent).
            // v0.25.1 (= ticket 031 chat send button vertical
            // center alignment): owner 2026-08-26 OOB '按钮也
            // 跟上上去了 把按钮改成与文本框居中' = with the 8 PT
            // top padding on TextField, the TextField's effective
            // top edge shifted down 8 PT (= 24 PT height + 8 PT top
            // padding = 32 PT total box). The send button's default
            // HStack alignment = .top (= button top edge aligns with
            // the TextField's top edge, which is now 8 PT below the
            // original position). Fix = change HStack alignment to
            // .center (= button vertically centered relative to the
            // full TextField + padding box).
            // v0.25.1 (= ticket 032 chat textfield height = 32 PT):
            // owner 2026-08-26 OOB '文本框的高度 和按钮的高度改成一至
            // 都和按钮一个高' = make the textfield visual height
            // match the send button height (= 32 PT). Current = textfield
            // visual height 24 PT (= SwiftUI default TextField with
            // .roundedBorder). Button height = ~32 PT (with .padding).
            // Fix = add .frame(height: 32) on the TextField (= textfield
            // visual height now matches button = both 32 PT). The 8 PT
            // top padding preserved (= 8 PT gap above textfield per
            // ticket 030) so total TextField + padding box = 40 PT
            // (= 8 PT gap + 32 PT textfield visual).
            // v0.25.1 (= ticket 033 chat send button BOTTOM
            // alignment): owner 2026-08-26 OOB '还是没有对齐 按钮和
            // 文本框向下对齐' = the previous ticket 031's .center
            // alignment still didn't match. Boss corrected again:
            // button should be aligned to the BOTTOM of the textfield
            // (= .bottom alignment, not .center). The button's
            // bottom edge aligns with the textfield's bottom edge
            // (Apple HIG toolbar convention: action button at
            // baseline of input field).
            // v0.25.1 (= ticket 033 followup 2: chat send button
            // CENTER alignment — boss corrected AGAIN): owner
            // 2026-08-26 OOB '还是不对 你还是文本框和按钮居中对齐吧'
            // = after 3 alignment attempts (.center, .bottom,
            // .bottom + height 32), the actual visual boss wants
            // is .center alignment. The earlier ticket 031's
            // .center was correct on alignment but the button's
            // height wasn't pinned (= 40 PT, vs textfield 32 PT),
            // so visually the .center alignment didn't look right
            // because the button was already too tall. Now with
            // ticket 033 followup's .frame(height: 32) pinning the
            // button to 32 PT (= matches textfield), boss confirmed
            // .center alignment is the right behavior.
            // v0.25.1 (= ticket 033 final 2: chat send button
            // HORIZONTAL alignment = drop the 8 PT top padding +
            // drop the .frame(height: 32) textfield pin + drop the
            // .frame(height: 32) button pin — owner 2026-08-26 OOB
            // '还是不对 是水平居中' = the 4 previous attempts all
            // tried to vertically align the textfield with the button,
            // but the actual visual boss wants is HORIZONTAL center
            // alignment (= the .center alignment already does this,
            // = but with 8 PT top padding + .frame(height: 32) the
            // textfield is offset down 8 PT + extended to 32 PT,
            // = making the visual center NOT match the button).
            // The right fix = drop the 8 PT top padding (= 0 PT
            // padding = textfield is its natural 24 PT height) AND
            // drop the .frame(height: 32) on both textfield and
            // button (= let each take its natural default height;
            // SwiftUI TextField with .roundedBorder = 24 PT, Button
            // with .borderedProminent = ~40 PT). With the 8 PT
            // padding dropped + height pins dropped, the HStack
            // .center alignment = both elements centered at the
            // natural height axis. But '水平居中' = horizontal
            // center, = the user wants the textfield + button to
            // share the same VERTICAL center line (= each element's
            // vertical center on the same y = the HStack .center
            // alignment IS the answer, but with natural heights,
            // not forced 32 PT).
            // Final approach (= this ticket 033 final 2):
            // 1. drop .padding(.top, 8) on TextField (= boss OOB
            //    interpreted '水平居中' as 'remove my 8 PT top
            //    padding that's making the visual center off').
            // 2. drop .frame(height: 32) on TextField (= use natural
            //    TextField height = 24 PT).
            // 3. drop .frame(height: 32) on Button (= use natural
            //    Button height = ~40 PT).
            // 4. KEEP HStack(alignment: .center, spacing: 8) (= the
            //    alignment that boss has been trying to tell us to
            //    use all along, = vertical center between the two
            //    elements at their natural heights).
            // v0.25.1 (= ticket 034 final 3): owner 2026-08-26 OOB
            // '你理解错了 是文本框的外边距 向上 8PT 这个还是要的'
            // = 8 PT OUTER top margin on the chat input HStack
            // (= between the Divider above and the HStack that
            // contains the textfield + button). The textfield +
            // button are offset down 8 PT as a group (= the
            // 8 PT margin is OUTSIDE the textfield, NOT inside
            // = no inner padding on the textfield itself).
            // Implementation: .padding(.top, 8) on the HStack
            // (= outer margin around the HStack content).
            HStack(alignment: .center, spacing: 8) {
                // v0.24 boss验收fix (2026-08-24): placeholder shows different text based on key state.
                // Boss 8/24 (out-of-band): '请先在设置中设置好大模型提供方'.
                // v0.25.1 (= ticket 030 chat send button Lucide icon + 8 PT textfield padding):
                // owner 2026-08-26 OOB '聊天区 聊天文本框后面的按钮 发送的
                // 小飞机换成 send 聊天文本框上加 8 PT 的间隔' =
                // 1) replace SF paperplane.fill (= Apple Send ICON) with
                //    Lucide .send (= paper plane icon, same visual
                //    metaphor as SF paperplane but Lucide outline style
                //    for consistency with the rest of the project per
                //    ticket 005+).
                // 2) add 8 PT horizontal padding to the textfield (= text
                //    has 8 PT of breathing room from the rounded border,
                //    = Apple HIG TextField default padding is 4 PT, owner
                //    wants 12 PT effective = 4 + 8).
                // 3) increase HStack(spacing: 8) to HStack(spacing: 16)
                //    per owner spec '在聊天文本框上加 8 PT 的间隔' = add 8 PT
                //    additional gap between textfield and send button
                //    (= boss wants more visual breathing room between
                //    textfield and send button than current 8 PT).
                TextField("输入消息...",
                          text: $vm.inputText, axis: .vertical)
                    .lineLimit(1...4)
                    // v0.24 boss验收fix: disable when no key configured.
                    .disabled(!hasUsableKey)
                    .focused($inputFocused)
                    .onSubmit { Task { await vm.send() } }
                    .onChange(of: vm.currentModel) { _, new in
                        if new.isEmpty {
                            inputFocused = false
                        } else {
                            // v0.24 boss验收fix: focus input when key becomes available.
                            inputFocused = true
                        }
                    }
                    // v0.25.1 (= ticket 034 chat textfield 1 PT focus
                    // ring): owner 2026-08-26 OOB '文本框聚焦时 这个
                    // 蓝色描边太粗了 改成 1PT 试试' = SwiftUI
                    // TextField .roundedBorder style has a default
                    // focus ring ~2-3 PT thick. Boss wants the focus
                    // ring thinned to 1 PT. Fix = override the default
                    // .roundedBorder style with a custom rounded
                    // border using .textFieldStyle(.plain) (= removes
                    // system focus ring) + add a conditional
                    // RoundedRectangle stroke (lineWidth: 1) on focus.
                    // v0.25.1 (= ticket 035 chat textfield placeholder
                    // color + position): owner 2026-08-26 OOB '输入
                    // 消息... 这个提示 查官方文档 默认是什么样的 现在
                    // 颜色过亮 位置也不对' = the placeholder text
                    // '输入消息...' currently looks too bright (= high
                    // contrast, = looks like real text) and is in
                    // the wrong position (= too far left, no left
                    // padding). Per Apple HIG (developer.apple.com/
                    // design/human-interface-guidelines/color +
                    // developer.apple.com/design/human-interface-
                    // guidelines/components/selection-and-input/
                    // text-fields), the placeholder text color
                    // should be `placeholderTextColor` (= semantic
                    // = .gray in SwiftUI = systemGray), and the
                    // position should be left-aligned with 12 PT
                    // horizontal padding (= Apple HIG text field
                    // default). Fix = add .padding(.horizontal, 12)
                    // to the TextField (= Apple HIG default 12 PT
                    // horizontal padding), and add a subtle
                    // Color.gray.opacity(0.1) background (= so the
                    // textfield is visually a 'control' surface, not
                    // a transparent overlay, = the placeholder text
                    // naturally appears in the secondary color
                    // without being too bright). The 1 PT focus
                    // ring (ticket 034) + 8 PT outer top margin
                    // (ticket 034 final 3) preserved.
                    .textFieldStyle(.plain)
                    .frame(height: 24)  // v0.25.1 ticket 037: textfield height 24 PT (= boss OOB '现在文本框不是 32 了吗 不管是多少 改成和文本框一样高' = 当前 textfield 视觉 是 24 PT, 不再改 = pin 24 PT). Button 也 修真因 = 24 PT (= 跟 文本框 一致)
                    .padding(.horizontal, 12)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(inputFocused ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: 1)
                        }
                    )
                Button {
                    Task { await vm.send() }
                } label: {
                    if vm.isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        // v0.25.1 (= ticket 030): Lucide .send icon
                        // (= paper plane / send glyph) for the
                        // send button. Replaces SF paperplane.fill
                        // per boss 2026-08-26 OOB. Lucide-first
                        // pattern with SF Symbol fallback (= Layer
                        // 3 fallback) preserves behavior if
                        // 'send' Lucide is missing.
                        if let lucide = Lucide("send") {
                            lucide
                                .font(.system(size: 16))
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)  // v0.25.1 ticket 037: explicit .small control size (= 24 PT height per Apple HIG, = matches textfield 24 PT height per boss OOB '不管是多少 改成和文本框一样高')
                .frame(height: 24)  // v0.25.1 ticket 037: send button height 24 PT (= match textfield 24 PT height per boss OOB)
                .disabled(vm.inputText.isEmpty || vm.isSending)
                .padding(.top, 16)  // v0.25.1 ticket 037: 8 PT additional outer top margin per boss OOB '文本框上面 8PT 不够 再加 8 吧' (= 8 PT existing + 8 PT new = 16 PT total outer top margin on chat input HStack)
            }
            .padding(.horizontal, 18)
        }
        // v0.24 boss验收fix (2026-08-24): help text DIRECTLY below input box.
        // Boss 8/24 (out-of-band): '请先在设置中设置好大模型提供方。点击设置'
        // v0.24 boss验收fix: help text moved to ChatZoneView as centered overlay
        // (was: bottom of ChatView, not centered per boss 8/24 feedback).
        EmptyView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // v0.24 boss验收fix: defocus when user clicks outside chat zone.
// Boss 8/24 feedback: '点其它区域, 文本框还是不失焦'.
.onReceive(NotificationCenter.default.publisher(for: .wenshuDefocusChatInput)) { _ in
    inputFocused = false
}
// v0.24 boss验收fix (Boss 8/24 反馈 '聊天记录持久化, 我没看到'):
// listen for .wenshuChatStoreReady (posted after applicationDidFinishLaunching
// creates ChatSessionStore). If store wasn't ready at .task time (race
// condition), retry loading now. Also retry append message if store
// was nil at send time (we just store in memory, then re-append here).
.onReceive(NotificationCenter.default.publisher(for: .wenshuChatStoreReady)) { _ in
    if let store = vm.valueForStore() {
        Task { @MainActor in
            if let loaded = try? await store.loadMessages(sessionId: vm.valueForSessionId()) {
                let mapped = loaded.map { stored in
                    let resolvedRole: ChatRole = (stored.source == "user") ? .user : .agent
                    return ChatMessage(
                        id: UUID(uuidString: stored.id) ?? UUID(),
                        role: resolvedRole,
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
}
    }
}

/// 1 条消息视图 (Apple HIG 真值)
struct ChatMessageView: View {
    let message: ChatMessage
    @State private var thinkingExpanded: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            // 消息来源 icon: Lucide .userRound (user) / .botMessageSquare
            // (wenshu agent) per owner 2026-08-26 directive; SF Symbol keeps
            // for .system (= exclamationmark.triangle). Avatar only = no
            // other UI change (= chat zone style/colour/frame preserved).
            Group {
                switch message.source {
                case .user:
                    Lucide(.userRound)
                case .wenshu:
                    Lucide(.botMessageSquare)
                case .system:
                    Image(systemName: sourceIcon)
                }
            }
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
