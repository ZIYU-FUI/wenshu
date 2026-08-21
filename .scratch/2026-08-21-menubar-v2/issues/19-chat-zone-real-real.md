# 19 — ChatZoneView 底栏 2 红框真值 (model picker 真列表 + context usage 真 tokens)

依赖: MiniMaxModelFetcher.fetchLiveModelIds + ModelCache + Provider.minimaxCn.defaultModels + ChatViewModel 现有 API

**What to build:**
ChatZoneView 红框 2 个真硬功能实现 (老板 2026-08-22 06:20 拍):
1. model picker Menu = 真可调模型列表 (走 MiniMaxModelFetcher.fetchLiveModelIds 真值 + ModelCache TTL 3600s)
2. context usage Text + ProgressView = 真 token 计数 (走 MiniMaxResponse.usage input_tokens + output_tokens 累加)
3. ChatView / ChatZoneView 共享 ChatViewModel 单一实例 (Q51 子组件 override 范式)

**Why:**
老板拍 "实现这红框两个功能的真实功能". 当前 ChatZoneView L1110-1113 @State 双源状态 + 硬编码 contextMax = 老板截图 "0 / 131.1k" 永远 0 = 用户误以为没在用. 真硬功能 = 真可调列表 + 真 token 计数.

**Acceptance:**
- 老板 macOS 真验: model picker 下拉 = 真可调列表 + 切模型 = 持久化 + context usage = 真 token 数
- swift build exit 0 + swift test exit 0 (老 test 兼容)
- 双轴 code-review 报告 verbatim 进 commit body
- Q40: 任何文件 / log / commit 不含老板真 key