# 03 — LLM Keychain 集成 (老板 2026-08-21 拍)

**What to build:**
老板 8/21 macOS 真验 ChatView: echo → Error: 未完成操作 (MiniMax key 缺失, dev env). 老板 8/21 给 LLM key 真值 (老板现场 macOS NSAlert 提示框输入, 不入文件 / log / commit).

CLAUDE.md L42 项目基线真值: "LLM key 存 macOS Keychain, 不入文件、不入 log、不入 commit".

修法真值 (4 步, Apple 官方范式):
1. 新建 `Sources/WenshuApp/Core/Agent/LLMKeychain.swift` (actor 真值, Keychain 读 / 写 / 删)
   - `func saveKey(_ key: String) throws` → `kSecClassGenericPassword` + `kSecAttrService="com.wenshu.app.minimax"`, kSecValueData
   - `func loadKey() throws -> String?` → SecItemCopyMatching
   - `func deleteKey() throws` → SecItemDelete
2. `MiniMaxVerifier.init` 改: 优先 Keychain.loadKey(), fallback env `MINIMAX_CN_API_KEY` (向后兼容, dev env 仍 work)
4. App.swift `applicationDidFinishLaunching` 末尾: 如果 Keychain 没 key + env 没 key, 弹 NSAlert "请设置 MiniMax API Key" (输入框 + Save 按钮 → Keychain.saveKey)
5. 1 ticket 1 commit + 真 verify pkill + build + open + 老板 macOS 验

**Blocked by:** None.**

**Status:** ready-for-agent

## 修法真值 (4 步)

1. 新建 `Sources/WenshuApp/Core/Agent/LLMKeychain.swift` (actor 真值, Keychain 读 / 写 / 删)
   - `func saveKey(_ key: String) throws` → `kSecClassGenericPassword` + `kSecAttrService="com.wenshu.app.minimax"`, kSecValueData
   - `func loadKey() throws -> String?` → SecItemCopyMatching
   - `func deleteKey() throws` → SecItemDelete
2. `MiniMaxVerifier.init` 改: 优先 Keychain.loadKey(), fallback env `MINIMAX_CN_API_KEY` (向后兼容, dev env 仍 work)
3. App.swift `applicationDidFinishLaunching` 末尾: 如果 Keychain 没 key + env 没 key, 弹 NSAlert "请设置 MiniMax API Key" (输入框 + Save 按钮 → Keychain.saveKey)
4. 1 ticket 1 commit + 真 verify pkill + build + open + 老板 macOS 验

## Acceptance

- [ ] LLMKeychain actor + saveKey / loadKey / deleteKey 真值 (Apple Security framework)
- [ ] MiniMaxVerifier.init 优先 Keychain 读
- [ ] App 启动如 Keychain 没 key 弹 NSAlert 提示
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 新增测试: testLLMKeychainSaveLoad (save → load 返一致) + testLLMKeychainLoadEmpty (没 key 返 nil)
- [ ] 老板 macOS 真验: ChatView 发消息拿真值 LLM 中文回复 (非 Error)

## 不动 (Q20 硬约束)

- MiniMaxVerifier.chat / send / ping 接口 (不变)
- WenshuConductor / AgentProtocol (不重写)
- AppIcon.icon/ (v0.21 ticket 04 落地, 老板拍先放着)
- 设置页 UI (commit 0082bd1fe 通过)

## Apple HIG 真值引用

- https://developer.apple.com/documentation/security/keychain_services
- https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
- CLAUDE.md L42 "LLM key 存 macOS Keychain, 不入文件 / log / commit"

## 关联

- 依赖: 无
- 被依赖: ticket 04 (真 verify) — 不依赖, 可并行