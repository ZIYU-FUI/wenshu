# 03 — AgentProtocol.handle 改真合成 (删 echo)

**What to build:**
老板 2026-08-21 验过 v0.20 ticket 01 ChatView, "有回复但不知真假". 真因 = `AgentProtocol.handleMessageSend` L188-190 echo user message 前 50 字符当 agent 回复, 不是真 LLM. 删 echo, 改成调 MiniMaxVerifier.send 真发 user message 给 MiniMax-M3, 拿 content 回写. LLM 失败 throw AgentRuntimeError.llmFailed, ChatViewModel 走到 fallback `verifier.ping` (已有路径).

**Blocked by:** ticket 01 (ChatMessage source 已加).

**Status:** ready-for-agent

## 修法真值

1. `Sources/WenshuApp/Core/Agent/AgentProtocol.swift` `handleMessageSend` L188-190 删 echo 真值:
   ```swift
   // 删
   let ack = AgentMessage(role: .agent, content: "received from \(fromAgent): \(message.content.prefix(50))")
   task.messages.append(ack)
   ```
2. 改成调 MiniMaxVerifier.send 真合成:
   - WenshuAppDelegate.sharedVerifier 注入 AgentProtocol (init 时传)
   - handleMessageSend 拿 user message.content → 拼 MiniMaxRequest (model: "MiniMax-M3", max_tokens: 1024, messages: [MiniMaxMessage(role: "user", content)])
   - 调 verifier.send(request)
   - 成功 → AgentMessage(role: .agent, content: response.content.first.text)
   - 失败 → throw AgentRuntimeError.llmFailed (在 AgentRuntime.swift 加 case)
3. ChatViewModel.send() 已有 fallback: delegateTask catch → verifier.ping (L75-80). 但 ping 只发 "ping" 字符, 改成发 user 原文 + retry 一次 (L77 调 `verifier.ping()` 改 `verifier.chat(text)`).
4. MiniMaxVerifier 加 `public func chat(_ text: String) async throws -> MiniMaxResponse` (跟 ping 同实现, 但 messages = [MiniMaxMessage(role: "user", content: text)], max_tokens 1024).

## Acceptance

- [ ] AgentProtocol.handleMessageSend 删 echo 字符串
- [ ] 真调 MiniMaxVerifier.send 拿 LLM 真回复
- [ ] LLM 失败 throw AgentRuntimeError.llmFailed
- [ ] AgentRuntimeError 新增 .llmFailed case
- [ ] MiniMaxVerifier 加 chat(text:) 方法
- [ ] ChatViewModel fallback 路径用 chat(text:) 不用 ping()
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: ChatView 收到真 LLM 回复, 不是 "received from user: ..."

## 不动

- A2A protocol message/send / task/get / task/list 接口 (删 echo 但保留 messageReceived response)
- AgentRuntime.delegateTask 调用链
- MiniMaxVerifier.ping() (其他 ticket 可能复用)

## 关联

- 依赖: ticket 01
- 被依赖: ticket 04 (WenshuConductor 用真 LLM 合成最终回复)