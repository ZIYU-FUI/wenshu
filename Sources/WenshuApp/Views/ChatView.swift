// ChatView.swift · 文枢 (Wenshu) · v0.01.0 WO-004
//
// The chat surface. Three vertical zones:
//   top    = message list (user + AI, with streaming indicator on AI rows)
//   middle = ExpandOptionsView (only when 4-category options are loaded)
//   bottom = input bar + send button
//
// Streaming: ChatViewModel owns `messages`; each streaming AI message has
// `isStreaming=true` and content that grows chunk-by-chunk via VM. This
// view just renders the array + auto-scrolls to the last message.

import SwiftUI

struct ChatView: View {
    // B+ 重 (t_0f6bd6f6): @ObservedObject → @Bindable (ChatViewModel 已 @Observable)。
    // View 写 vm.currentProject / vm.pendingNavigation, @Bindable 提供双轨接口。
    @Bindable var vm: ChatViewModel
    let project: ProjectSnapshot
    @Binding var navPath: NavigationPath

    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            messageScroll
            Divider()
            ExpandOptionsView(vm: vm)
            Divider()
            inputBar
        }
        .navigationTitle(project.name)
        .navigationSubtitle("Chat · 阶段：想法")
        .onAppear {
            // WO-005: stash the active project on the shared VM so that
            // `vm.persist()` (called by CharacterWorldView before nav-pop)
            // can tag the saved note with the project id. ChatViewModel is
            // a process-wide @StateObject, so re-setting on every onAppear
            // is intentional — switching projects must update it.
            vm.currentProject = project
            // LT-N2: 切回已建项目时拉聊天历史 (上次 session 的 user + AI
            // 消息) — 走 WenshuProjectStore.loadChatHistory, 真从 .ws
            // 读, 不缓存假数据。 async / actor 不阻塞 UI (沿 v0.01.0
            // 范式)。 失败 silent-fail (stderr log) — 跟 `persist()`
            // 一致。
            let projectId = project.id
            Task { await vm.loadChatHistory(projectId: projectId) }
        }
        .onChange(of: vm.pendingNavigation) { _, newValue in
            if let route = newValue {
                navPath.append(route)
                vm.pendingNavigation = nil
            }
        }
    }

    // MARK: - Subviews

    private var messageScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if vm.messages.isEmpty {
                    emptyHint
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: vm.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: vm.messages.last?.content) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("在下方输入「一句话故事」开始")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == "user" {
                Spacer(minLength: 60)
                bubble(text: message.content, isUser: true)
            } else {
                bubble(text: message.content, isUser: false)
                if message.isStreaming {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                        .padding(.top, 6)
                }
                Spacer(minLength: 60)
            }
        }
    }

    private func bubble(text: String, isUser: Bool) -> some View {
        let display = text.isEmpty && !isUser ? "…" : text
        return Text(display)
            .font(.body)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isUser
                ? Color.accentColor.opacity(0.85)
                : Color.secondary.opacity(0.15))
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("写一句话故事…", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(vm.isGenerating)
                .onSubmit {
                    Task { await send() }
                }
            Button {
                Task { await send() }
            } label: {
                Label("发送", systemImage: "paperplane.fill")
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isGenerating)
        }
        .padding()
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = vm.messages.last else { return }
        withAnimation(.linear(duration: 0.1)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        // LT-N2: 改用 `sendChatMessage` alias (内部仍 delegate 到
        // `sendInitialStory`, 不破 v0.01.0 CharacterWorldView 路由 + 流式打字)。
        await vm.sendChatMessage(text)
    }
}
