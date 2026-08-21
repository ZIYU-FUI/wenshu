# 15 — 提供方 API 配置页面模仿 hermes auth 交互

依赖: 无 (ProviderKeychain 后端已存在)

**What to build:**
SettingView 加第 4 个 tab "提供方 API", 模仿 hermes auth list + add 交互 (老板 2026-08-22 04:50 拍):
1. SettingsTab 加 .providerApi case (icon "key.horizontal")
2. body switch 加 .providerApi case → providerApiTab
3. providerApiTab 新 view: List 列出 Provider.all + 点击展开 inline 编辑面板 (SecureField + 保存按钮, 不弹 NSWindow 弹窗)
4. providerTab L364 ProviderKeyPrompt.prompt 触发撤 (修真因: 不弹窗)

**Why:**
老板拍 "完全模仿 hermes 的提供方 api 配置的页面功能和交互" + "不要再弹出一个输入 key 的弹窗来粘贴 key, 参考 hermes 页面的交互". 当前 provider tab 点击没 key 的 provider 调 ProviderKeyPrompt.prompt = 弹 NSWindow standalone sheet = 老板拍的真硬违反.

**Acceptance:**
- 老板 macOS 真验: 提供方 API tab 可点 → 行点击展开 inline 编辑 → SecureField 输入 key → 保存 → 状态变 "已设 key"
- swift build exit 0
- swift test exit 0
- 双轴 code-review 报告 verbatim 进 commit body
- Q40: 任何文件 / log / commit 不含老板真 key