# 06 — 聊天底栏 model + context 用量 (Hermes appChrome 范式)

> Date: 2026-08-22
> 老板 2026-08-22 拍: "聊天区底栏两个占位文字功能替换, 左边显示当前使用的模型, 点击可以切换, 右边显示上下文用量. 参考 hermes"

## 业务语言 (老板懂)

聊天区底栏 (输入框下方) 2 个元素:
- 左侧: 当前模型 label (例 "MiniMax-M3"), 点击 → 切模型 (走 Settings 提供方 + 模型 tab 同样的 provider Picker, 或 popup menu)
- 右侧: 上下文用量 (例 "12 / 20" 或 progress bar)

## Hermes 真值 (ui-tui/src/components/appChrome.tsx 真值)

- `modelText = modelLabel(model, reasoningEffort, fast)` — 左 segment, clickable
- `ctxLabel = fmtK(usage.context_used) + '/' + fmtK(usage.context_max)` — 右 segment
- `pct = usage.context_percent` — progress bar fill
- compact mode = narrow terminal → 折叠到 "12k tok" bare token count

## 修法真值 (5 原则1 + 4 满足, Hermes 范式)

1. ChatViewModel 加 `currentModel: String` (= `@AppStorage("wenshu.llm.model")` 真值, 不动现有 model Picker)
2. ChatViewModel 加 `contextUsed: Int` (估算 = `messages.count * ~500 tokens`), `contextMax: Int` (= 20, ticket 05 sliding window threshold)
3. ChatView 在输入框下方加 HStack:
   - 左: Button("currentModel") → Menu 当前 provider 的 model 列表 (从 setting 同样 provider 拉)
   - 右: Text("\(contextUsed) / \(contextMax)") + progress bar (.progressViewStyle(.linear), 绿色 → 红色比例)
4. compact mode (窗口 < 600 PT): 只显 token count 不显进度条 (Hermes 真值)
5. 1 ticket 1 commit + 双轴 review

## 验收标准

- [ ] ChatViewModel 加 currentModel + contextUsed/Max
- [ ] ChatView 底栏 HStack (左 model, 右 context)
- [ ] 点击左 model → Menu 切 model (走 Settings 同一 fetch, fallback curated)
- [ ] 右 context 显 "X / 20" + progress bar
- [ ] 窗口 < 600 PT compact mode = 只显 token count
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 聊天底栏显当前 model + context 用量, 点击 model 切换

## 不动 (Q20)

- v0.21 ticket 04 MiniMaxModelFetcher (后续重构)
- v0.21 ticket 05 sliding window (不动)
- ticket 01 Provider enum (不动)
- App.swift Settings (不动)

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/menu (Popup menu 真值)
- https://developer.apple.com/documentation/swiftui/progressview (progress bar 真值)
- ui-tui/src/components/appChrome.tsx (Hermes 真值)

## 关联

- 依赖: ticket 04 (MiniMaxModelFetcher) — 已 commit, 复用 loadModelIds
- 被依赖: 无