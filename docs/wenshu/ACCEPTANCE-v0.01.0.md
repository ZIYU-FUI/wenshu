# ACCEPTANCE-v0.01.0 · 装机 user 验收

> WO-005 (v0.01.0 L2 子任务 5/5, 最后一卡) · 2026-08-07 PM-direct 起卡
> 装机 user 跑完填此清单 → 每步勾选 + 一句话问题记录
> 注: 本文件是 **装机 user 验收脚本**, 不是 PM-direct 验收。PM-direct 跑通步骤 1-7 mock 跑通部分见 `ACCEPTANCE-v0.01.0.md` (根目录那份是 WO-001 的 acceptance log)

---

## 0. 装机 user 环境准备 (跑前必做)

- [ ] macOS 27.0+ 装好 Xcode-beta (`xcrun --show-sdk-version` 返 27.0)
- [ ] `git clone` 本仓库到 `~/Engineering/wenshu/` (或同等路径)
- [ ] `cd ~/Engineering/wenshu && swift build` exit 0
- [ ] `swift test` 全部 16 个测试通过 (3 SSEParser + 3 KeychainHelper + 3 WenshuStoreActor + 1 SSEParser byte accumulation + 5 WenshuProjectStore)
- [ ] **(可选, 想跑真 LLM)** Keychain 配 key:
  ```bash
  security add-generic-password -s "com.wenshu.llm" -a "minimax-api-key" -w "<你的 minimax cn API key>"
  ```
  然后把 `Sources/WenshuApp/Config/FeatureFlag.swift` 的 `useRealLLM` 翻 `true` (PM-direct 默认 `false`, 跑 mock)

---

## 1. 8 步用户旅程验收清单

### 步骤 1 · 启动 app
- [ ] `swift run` 能起 macOS 文枢 app
- [ ] 窗口标题显示 "文枢"
- [ ] 左侧栏 heading 显示 "项目"
- [ ] 右侧栏空状态显示 "暂无项目" + "+ 新建" 提示
- **PM-direct 已验**: cua-driver AX tree 109+ elements (WO-001 acceptance log 记过 134 elements)
- **装机 user 自验**: 截图存档 `/tmp/wenshu-acceptance/step-1-launch.png`

### 步骤 2 · 创建项目
- [ ] 点击右上角 "+ 新建项目" 按钮
- [ ] sheet 弹出 "新建项目" 表单
- [ ] 项目名 = "测试故事" (填必填项)
- [ ] 文笔风格 = "轻松" (默认 "严肃", 改下)
- [ ] 注水量 = 5 (默认值)
- [ ] 标签 = "都市, 言情" (可选, 不填也行)
- [ ] 点击 "创建" 按钮
- [ ] sheet 自动关闭, 左侧栏多出一行 "测试故事"

### 步骤 3 · 进入 Chat
- [ ] 点击左侧 "测试故事"
- [ ] 右侧栏切到 ChatView, 标题 = "测试故事"
- [ ] 中部输入框 placeholder = "写一句话故事…"

### 步骤 4 · 写一句话 + AI 流式
- [ ] 输入框输入 "女主角在雨天咖啡店偶遇十年未见的初恋"
- [ ] 按 cmd+return (或点发送按钮)
- [ ] 用户消息出现在上半部 (右对齐蓝底)
- [ ] AI 消息以流式 typewriter 方式出现 (每 ~45ms 一段 chunk)
- [ ] 流式指示器 (ProgressView) 出现 + 消失
- **Mock vs 真 LLM**:
  - `FeatureFlag.useRealLLM = false` → 走 WO-004 mock, 文本固定
  - `FeatureFlag.useRealLLM = true` + Keychain 有 key → 调 `LLMService.streamChat(...)` 走真 minimax cn, 文案由模型生成

### 步骤 5 · 弹出 4 类候选
- [ ] AI 回复完后, 下半部出现 ExpandOptionsView
- [ ] 4 类标签按顺序: 核心冲突 / 主角延伸 / 世界观缺口 / 发展方向
- [ ] 每类 2-3 个候选 (mock 数据共 10 条)
- [ ] 每个候选有 checkbox + 标题 + 一句话描述

### 步骤 6 · 多选 + 确认
- [ ] 勾选 2-3 个候选 (checkbox toggle)
- [ ] 点击 "确认选择" 按钮
- [ ] 用户消息 "已选择方向：XXX" 出现
- [ ] AI 流式确认消息出现
- [ ] 自动跳到 CharacterWorldView

### 步骤 7 · 人物/世界骨架
- [ ] 看到 3 张人物卡 (主角 + 2 配角), 每张 = 名字 + 角色 + 一句话 backstory
- [ ] 看到 4 条世界规则, 每条 = 规则正文 + 类别
- [ ] 点 "返回项目" 按钮回到 ProjectListView
- [ ] 项目仍然在列表里 (in-memory, 重启不丢是 v0.02.0 工作)

### 步骤 8 · 数据持久化 (本阶段部分实现)
- [ ] 退出 app
- [ ] 检查 `~/Documents/wenshu-projects/` 目录存在
- [ ] **本阶段不要求**: Wenshu.sqlite 文件存在 — AGENTS §7 / WO-005 spec 明说 "本阶段 in-memory,只 set storeURL,不真 loadPersistentStores"
- [ ] **本阶段不要求**: 关闭 + 重开 app 项目列表仍在 — 明确留 v0.02.0
- [ ] (可选) 跨设备: `cp -r ~/Documents/wenshu-projects /tmp/test-copy` 然后跑 app 不会污染 (因为根本没写盘)

---

## 2. 已知边界 (装机 user 不要撞)

| 边界 | 现象 | 原因 |
|------|------|------|
| 重启 app 项目消失 | 左侧栏 "暂无项目" | in-memory only, v0.02.0 接 SQLite round-trip |
| Wenshu.sqlite 不存在 | `ls ~/Documents/wenshu-projects/` 只有空目录 | WO-005 故意不 loadPersistentStores |
| 真 LLM 调用失败 | fallback 到 mock 流式 (用户看不出来, 但 stderr 有日志) | 网络/解析错误时主动 fallback, 避免 UI 卡死 |
| Keychain 无 key + `useRealLLM=true` | 走 mock fallback | `shouldUseRealLLM()` 三层检查任一失败 → mock |
| 跨设备复制 .ws 无效 | copy 到 iPad 打开数据不存在 | WO-005 不实现, AGENTS §7 留装机 user 手动管理 |

---

## 3. 验收回执 (装机 user 填)

```
跑完日期:    ________________
机型 + macOS: ________________
跑真 LLM 还是 mock: ________________
总耗时:    ________________

步骤 1 (启动):       □ 通过    □ 失败 → 问题: ________________
步骤 2 (创建项目):   □ 通过    □ 失败 → 问题: ________________
步骤 3 (进入 Chat): □ 通过    □ 失败 → 问题: ________________
步骤 4 (写一句话):  □ 通过    □ 失败 → 问题: ________________
步骤 5 (4 类候选):   □ 通过    □ 失败 → 问题: ________________
步骤 6 (多选确认):   □ 通过    □ 失败 → 问题: ________________
步骤 7 (人物世界):   □ 通过    □ 失败 → 问题: ________________
步骤 8 (持久化):     □ 通过    □ N/A (本阶段明确跳过)

整体观感:
- UI 是否符合"文枢 = 长篇小说 AI 创作平台"定位: ________________________________
- 流式 typewriter 是否舒服: ________________________________
- 4 类候选是否好懂: ________________________________
- 是否撞 minimax 真 API 错 (网络/认证/限流): ________________________________

建议 v0.01.1 修的问题:
1. ________________________________
2. ________________________________
3. ________________________________

建议 v0.02.0 加的功能:
1. ________________________________
2. ________________________________
3. ________________________________
```

---

## 4. CC 留的施工痕迹 (装机 user 不必读, PM-direct / 后续 worker 看)

### 新增文件 (WO-005 本卡)
- `Sources/WenshuApp/Config/FeatureFlag.swift` — `useRealLLM` 开关
- `Sources/WenshuApp/Storage/WenshuProjectStore.swift` — actor, 封 WenshuStoreActor
- `Tests/WenshuAppTests/WenshuProjectStoreTests.swift` — 5 个 case (save 1+load 2+multiple-save 1+directory 1)

### 修改文件 (公开 API 影响范围 = 0)
- `Sources/WenshuApp/ViewModels/ChatViewModel.swift` — 新增 `currentProject` / `persist()`, 改 `appendStreamingMessage()` 接 FeatureFlag + LLMService。4 个原公开方法 (`sendInitialStory` / `selectDirections` / `toggleSelection` / `reset`) 签名不变
- `Sources/WenshuApp/Views/ChatView.swift` — `onAppear` 设 `vm.currentProject = project`
- `Sources/WenshuApp/Views/CharacterWorldView.swift` — "返回项目" 按钮改 `Task { await vm.persist(); vm.reset(); ... }`
- `Sources/WenshuApp/App.swift` — `init` 触发 `WenshuProjectStore.shared` 确保目录在启动时存在

### 未触碰的硬边界 (per 派单 prompt)
- `WenshuStoreActor` 6 个方法签名 (`createCharacter` / `listCharacters` / `createNote` / `listNotes` / `createWorldRule` / `countAll`) 全部原样
- `LLMService` / `LLMProvider` / `MinimaxProvider` / `SSEParser` / `KeychainHelper` 签名全部原样
- `Package.swift` swift-tools-version / platforms 全部原样 (6.4 + .macOS(.v27))
- `AGENTS.md` / `CLAUDE.md` / `README.md` 全部原样
- 不替装机 user 配 LLM key, 不实跑 minimax 真请求

### 已知未来工作 (WO-005 主动留尾)
1. **v0.02.0**: 真 loadPersistentStores + `.ws` 单文件 export → 跨设备复制可用
2. **v0.02.0**: 启动时自动 load 已存项目 (本阶段 in-memory, 项目列表重启消失)
3. **v0.02.0**: UI toggle 替代码 FeatureFlag (Settings → LLM 开关)
4. **v0.02.0**: 多文件并发写冲突解决 (AGENTS §7 已拍方案)
5. **v0.02.0**: LLMService.shared 加 `hasKey` 计算属性替 `KeychainHelper.loadKey() != nil` 散落检查

---

## 5. CC 验收 (装机 user 不必看, PM-direct 跑过的勾)

```
swift build:    exit 0  ✅ (0.36s warm)
swift test:     16/16 passed  ✅ (3 SSEParser + 3 KeychainHelper + 3 WenshuStoreActor + 5 WenshuProjectStore + 2 other)
swift run smoke: process alive 6s+  ✅, no errors in stderr
目录 ~/Documents/wenshu-projects/: 创建于 swift run 期间 ✅
```

CC 完成时间: 2026-08-07 (本卡).
PM-direct 兜底: 已跑上面 3 项验收, 装机 user 收到此文档后照 §1 走 8 步.

