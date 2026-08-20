# 01 — 聊天底栏 model + context (Hermes appChrome 范式)

**Blocked by:** None (复用 ticket 04 MiniMaxModelFetcher).

**Status:** ready-for-agent

## 修法真值 (3 步)

1. ChatViewModel 加 `currentModel: String` (= `@AppStorage("wenshu.llm.model")`), `contextUsed: Int` (`messages.count * 500`), `contextMax: Int = 20`
2. ChatView 输入框下方加 HStack: 左 Button Menu (切 model), 右 progress + Text("\(X) / 20")
3. compact mode (width < 600): 只显 token count 不显 progress bar

## Acceptance

- [ ] ChatViewModel currentModel/context 字段
- [ ] ChatView 底栏 HStack
- [ ] 左 model Menu 切 model (复用 ticket 04 fetch)
- [ ] 右 context "X / 20" + progress bar
- [ ] compact mode (width < 600)
- [ ] swift build / test exit 0
- [ ] 老板 macOS 真验

## 不动 (Q20)

- v0.21 ticket 04 (复用)
- Settings (不动)
