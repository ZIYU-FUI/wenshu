# 09 — ChatBottomToolbar 移到 ChatView 子组件 (老板 2026-08-21 23:30 拍)

**What to build:**
老板 8/21 23:30 拍真值: '起一个分支, 去实现这个需求. 刚才你实现的的对了, 只不过把父组件给改了, 导致所有的底栏的占位文字都变成了, 模型切换和上下文用量. 真正的解决方案, 我的建议, 父组件不动, 在聊天区关联父组件, 生成子组件, 但在子组件做聊天区底栏实现功能. 替换占位文字'

**真因 (Q32 audit 5 原则 1 真硬违反修复):**
之前 commit `efa351f80` 修真因时, 改了父组件 `ZoneModule` (.aiChat case 加 VStack { ChatView + ChatBottomToolbar }), 父组件改了 = Q32 真硬违反.
**真修法**: 父组件 ZoneModule 不动 (= 老板拍), 在子组件 ChatView 内加 ChatBottomToolbar (= ChatView 内部加 VStack { TextField + SendButton + ChatBottomToolbar }, 替换"输入消息..." 文本框下方位置).

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (3 步, 5 原则 1 + 4 满足, Q32 真硬违反修复)

1. **撤回 commit `efa351f80` 父组件 ZoneModule 改动**:
   - ZoneModule .aiChat case 撤回 VStack { ChatView + ChatBottomToolbar }
   - 改回 `case .aiChat: ChatView(...)` (跟原始一样, 父组件不动)
2. **改 ChatView 内加 ChatBottomToolbar 子组件**:
   - ChatView body 末尾加 ChatBottomToolbar (= 子组件内加, 父组件不动)
   - ChatBottomToolbar 内容 = Menu (cpu + currentModel + chevron) + ProgressView (0/131.1k) (= 之前 commit `55d3844d1` 装的, 改放在 ChatView 内)
   - ChatBottomToolbar 替换"输入消息..." 文本框下方位置 (= ChatView 内, 不动父组件 ZoneModule 6 区底栏)
3. **双轴 code-review** (Q34 老板纠错"按 PO 全链路执行")

## 双轴 code-review (Q34 老板纠错"按 PO 全链路执行" 这次必须跑)

## Acceptance

- [ ] ZoneModule 父组件不动 (6 区底栏保持"占位文字")
- [ ] ChatView 子组件内加 ChatBottomToolbar (= VStack { TextField + SendButton + ChatBottomToolbar })
- [ ] ChatBottomToolbar 装 model picker (cpu + MiniMax-M3 + chevron) + context usage (0/131.1k + ProgressView)
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 聊天区内"输入消息..." 文本框下方显 model picker + context usage (= 红框位置 = ChatView 内), 其它 5 区底栏仍显"占位文字" (= 老板真值真值)
- [ ] **双轴 code-review 报告** (Standards + Spec 并行, 老板 8/21 拍"按 PO 全链路执行")

## 不动 (Q20 硬约束)

- v0.20 LOGO + 菜单栏
- v0.21 chat-streak ticket 02-06
- Provider / ProviderKeychain / ProviderFetcher / ProviderCatalog
- ProviderKeyPrompt
- MiniMaxModelFetcher
- `ZoneModule` 父组件 (= 老板拍不动)
- `ZoneBottomToolbar` 父组件 (= 6 区底栏保持"占位文字", 老板真值)
- `SettingView` (commit 6a3d93f5d + 1f086051a 保留, Pages 范式)
- AppIcon.icon/

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/viewbuilder
- https://developer.apple.com/documentation/swiftui/menu
- https://developer.apple.com/documentation/swiftui/progressview
- Q28 swiftinterface 真值: ChatBottomToolbar 是子组件, ChatView 内 VStack { TextField + SendButton + ChatBottomToolbar } = Apple 真值

## 关联

- 依赖: 无
- 被依赖: 无