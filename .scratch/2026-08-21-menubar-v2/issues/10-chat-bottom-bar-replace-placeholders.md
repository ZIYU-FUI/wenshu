# 10 — 聊天区底栏占位文字替换 (子组件 ChatZoneView, 老板 2026-08-21 23:35 拍)

**What to build:**
老板 8/21 23:35 拍真值:
1. '理解有误, 我的需求是替换聊天区的底栏的两个占位文字, 实现模型选择, 上下文用量, 但替换占位文字时, 不影响其它区域的占位文字'
2. '不要把占位, 或者我和你的决策写到界面上, 界面不显示那些说明. 界面是给用户的, 不是用来做功能管理的'

= 父组件 ZoneModule .aiChat case 改 ChatZoneView 子组件 (= ChatView + ChatBottomToolbar)
= 其它 5 区 case 不动 (= ZoneBottomToolbar 父组件保留 "占位文字" 显真值)
= 界面不显开发说明 (= 老板 8/21 23:35 拍"界面是给用户的, 不是用来做功能管理的")

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (3 步, 5 原则 1 + 4 满足, Q32 真硬违反修复)

1. **撤回 ticket 09 commit `f423e4678`** (= `git revert --no-edit f423e4678` = `404bef105` Revert, 父组件 ZoneModule .aiChat case 改 VStack = 5 原则 1 违反, 撤)
2. **装回 chat zone ChatBottomToolbar 但用子组件 ChatZoneView** (= 老板 8/21 23:35 拍"父组件不动, 在聊天区关联父组件, 生成子组件")
   - ZoneModule .aiChat case 改 `ChatZoneView(conductor:store:)` (= 父组件**没动**, 只换 .aiChat case 的内容)
   - ChatZoneView = VStack { ChatView + ChatBottomToolbar } (= 子组件内含 ChatView + ChatBottomToolbar)
   - 其它 5 区 case 不动 (= ZoneBottomToolbar 父组件保留 "占位文字" 显真值)
3. **界面不显开发说明** (= 老板 8/21 23:35 拍"界面是给用户的, 不是用来做功能管理的")
   - ChatZoneView 撤所有开发说明注释
   - ChatBottomToolbar 撤所有 "(= 老板 8/21 拍)" 类历史注释 (= Q8 硬约束)
   - commit body / spec / issue 不写"修因"等开发管理说明 (= 修因 = 改用"修因"/"实现"/"装入")

## 双轴 code-review (Q34 老板纠错"按 PO 全链路执行" 这次必须跑)

## Acceptance

- [ ] ticket 09 commit f423e4678 撤回 (= git revert 跑)
- [ ] ZoneModule .aiChat case 改 ChatZoneView 子组件 (= 父组件 ZoneModule 不动其它 5 区)
- [ ] ChatZoneView = VStack { ChatView + ChatBottomToolbar } (= 替换 chat zone 底栏 "占位文字" 位置)
- [ ] 其它 5 区 case 不动 (= ZoneBottomToolbar 父组件保留 "占位文字")
- [ ] 界面不显开发说明 (= 老板 8/21 23:35 拍"界面是给用户的, 不是用来做功能管理的")
- [ ] 注释不写 "(= 老板 8/21 拍)" 类历史 (= Q8 硬约束)
- [ ] commit body 不写 "修因" 等开发管理说明
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: chat zone 底栏 = model picker + context usage (替换"占位文字"), 其它 5 区底栏 = "占位文字", 界面干净无开发说明
- [ ] **双轴 code-review 报告** (Standards + Spec 并行, 老板 8/21 拍"按 PO 全链路执行")

## 不动 (Q20 硬约束)

- v0.20 LOGO + 菜单栏
- v0.21 chat-streak ticket 02-06
- Provider / ProviderKeychain / ProviderFetcher / ProviderCatalog
- ProviderKeyPrompt
- MiniMaxModelFetcher
- `ZoneModule` 父组件 (其它 5 区 case 不动)
- `ZoneBottomToolbar` 父组件 (5 区底栏保持"占位文字")
- `SettingView` (commit 6a3d93f5d + 1f086051a 保留, Pages 范式)
- AppIcon.icon/

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/viewbuilder
- https://developer.apple.com/documentation/swiftui/menu
- https://developer.apple.com/documentation/swiftui/progressview

## 关联

- 依赖: 无
- 被依赖: 无