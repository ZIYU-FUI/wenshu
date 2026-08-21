# 06 — 设置面板 UI 重做 (Pages 范式 + Hermes 提供方/模型 真值, 老板 2026-08-21 拍)

**What to build:**
老板 8/21 拍 (3 个需求):
1. **Pages 范式设置面板 UI** (= Pages 顶部 toolbar tab + Toggle + Picker + 分割线)
2. **提供方配置按 hermes 设置-提供方-API 配置真值真值** (= List 11 provider + status icon + "粘贴 X 密钥" 提示)
3. **模型设置按 hermes 设置-模型 真值真值** (= 提供方 dropdown + 模型 dropdown + 推理级别 dropdown + 辅助模型列表)
4. **低栏占位文字替换 = 只聊天区的, 其它区的不替换, 不要直接在父组件上直接替换** (= 撤回 ZoneBottomToolbar 全 6 区替换)

**Hermes 源码真值真值 (apps/desktop/src/):**
- `providers-settings.tsx`: sidebar subnav + List provider rows + status icon (key.fill 绿 / key 灰) + "粘贴 X 密钥" 提示
- `model-settings.tsx`: 提供方 Select + 模型 Select + 应用按钮 + 推理级别 EFFORT_VALUES = none/minimal/low/medium/high/xhigh + 辅助模型 AUX_TASKS = vision/web_extract/compression/skills_hub/approval/mcp/title_generation/curator
- 不做 MoA (老板 8/21 evening 拍 MOA 不做)
- Pages macOS 27 设置面板 (真值真值)

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (3 步, 5 原则 1 + 4 满足)

### Step 1: 重写 `SettingView` Pages 范式
- 顶部 toolbar 3 tab (Tab API macOS 15+): 通用 / 提供方 / 模型
- 通用 tab (Pages 范式):
  - 用于新文稿 分组: Toggle group
  - 默认缩放比例: Picker
  - 默认字体: Toggle
  - 编辑 分组: Toggle group
  - 不可见元素: Toggle
  - 添加媒体 分组: Toggle group
  - 触控 ID: Toggle
  - 作者: TextField (老板填 "安百强")
  - 文本大小: Picker "12 点"
- 提供方 tab (Hermes 真值):
  - SearchField 搜 provider
  - List Provider.all 11 provider (priority + name 排序)
  - 每行: status icon (key.fill 绿 / key 灰) + provider.name + "粘贴 X 密钥" 或现有 key 预览
  - 点行 → ProviderKeyPrompt 弹 NSWindow sheet 填 key (commit a894d6a52 已装)
- 模型 tab (Hermes 真值):
  - 提供方 Picker (Select style)
  - 模型 Picker (Select style, availableModels = ProviderFetcher.loadModelIds)
  - "应用" 按钮 → 写 UserDefaults
  - 推理级别 (Reasoning Effort): Picker low/medium/high/xhigh (Hermes EFFORT_VALUES 真值, boss 8/21 evening 拍 MED 真值, MOA 不做)
  - 辅助模型 (Auxiliary Models): List AUX_TASKS = 8 个, 每行 "使用主模型" + "更改" 按钮 (未来真值真值)

### Step 2: ChatView zone 底栏只替换 chat zone, 其它区不动
- 撤回 commit 55d3844d1 把 ZoneBottomToolbar 整个替换 (= 全 6 区都改了)
- 改 ZoneModule 加 slot-specific:
  - .aiChat → ChatBottomToolbar (model picker + context usage)
  - 其它 zone → ZoneBottomToolbar 原版 (占位文字)

### Step 3: Domain-modeling
- 加 `CONTEXT.md`:
  - `SettingView` Pages 范式 (新 domain word)
  - `ProviderAuthStatus` enum (Hermes 真值)
  - `ReasoningEffort` enum (low/medium/high/xhigh, Hermes EFFORT_VALUES 真值)
  - `AuxTask` enum (vision/web_extract/.../curator, Hermes AUX_TASKS 真值)

## Acceptance

- [ ] SettingView 3 tab Pages 范式
- [ ] 通用 tab 内容跟 Pages 范式
- [ ] 提供方 tab: List 11 provider + status icon + key 提示
- [ ] 模型 tab: 提供方 + 模型 + 推理级别 + 辅助模型
- [ ] ZoneBottomToolbar 撤回全 6 区替换, 只 chat zone 装
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 设置面板跟 Pages + Hermes 真值

## 不动 (Q20 硬约束)

- v0.20 LOGO + 菜单栏
- v0.21 chat-streak ticket 02-06
- Provider / ProviderKeychain / ProviderFetcher / ProviderCatalog
- ProviderKeyPrompt
- MiniMaxModelFetcher
- AppIcon.icon/

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/tabview
- https://developer.apple.com/documentation/swiftui/form
- https://developer.apple.com/documentation/swiftui/toggle
- https://developer.apple.com/documentation/swiftui/picker
- hermes apps/desktop/src/app/settings/providers-settings.tsx
- hermes apps/desktop/src/app/settings/model-settings.tsx
- Pages 设置面板 macOS 27

## 关联

- 依赖: 无
- 被依赖: 无