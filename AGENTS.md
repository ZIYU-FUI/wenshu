# AGENTS.md · 文枢 (Wenshu)

> 项目基线 v0.00.0(2026-08-06 你拍板)
> **本文件 = 协作规则真理源**
> 任何"角色边界/派单/插件策略/评论 SLA/升级/数据资产/跨设备"全在本文件,其他文档只放指针

---

## 1. 角色边界(2026-08-06 v0.00.0 拍)

- **AIF**:`/goal` 跨轮访谈出 3 类草稿 → 落档到本项目 3 文档(README/AGENTS/CLAUDE.md) → 派 PM → 退场。**AIF 派完不进 PM↔CC loop**
- **PM ↔ CC**:单 loop 跑实现(≤ 4 在跑卡)。你不在 loop 内,PM 自驱。详见 §4
- **你**:在阶段门控节点(v0.00.0 / v0.01.0 / v0.02.0 / ...)出现,看产品反馈,飞书会纠偏(均 loop 外)
- **本项目 AIF 边界**(v0.00.0 特殊化):
  - ✅ 写 3 类项目文档(README/AGENTS/CLAUDE.md)
  - ✅ 派任务给 PM(kanban 派单)
  - ✅ 改本项目 wenshu/ 根下的文件(README/AGENTS/CLAUDE.md、.hermes/ 跨项目工作区)
  - ✅ 改沙盒代码 `~/Engineering/llm-call-test/` + `~/Engineering/wenshu-arch-experiments/`
  - ❌ **不动**封存的旧 monorepo fork:`~/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/`(只读历史)
  - ❌ 不替 PM 验收 / 不派工单 / 不进 PM↔CC loop
  - ❌ 不改 PM 侧协议文件(归 PM)

## 2. 通道

- AIF ↔ PM:`hermes kanban`(同 board 跨 profile 自动可见)
- PM ↔ CC:Claude Code CLI(`claude -p "..."`,并发 ≤ 4)
- 你 ↔ AIF:飞书自然语言
- AIF ↔ 沙盒:本地 `~/Engineering/` 目录(实验代码、跑出来的报告)

## 3. 派单原则(2026-08-06 拍)

- 一次只派 1 个,确认 ≤ 4 才派下个
- 派单理由必填(为什么本卡必须现在派,≤ 3 行)
- `[Urgent]` 标记 = 例外允许,必带紧急原因
- ≤ 4 在跑卡硬约束
- **单任务单一功能 + 你试用验收**(沿用 7/10 18:14 拍板)
- **需求分级 L1/L2/L3**(沿用 8/6 拍):
  - L1 = 文案/样式/局部小修,只跑 PM 实际验收,不走 CC 审查
  - L2 = 标准功能/交互修改/普通 BUG,跑 PM 验收 + 自动测试 + 回归
  - L3 = 核心用户旅程/架构/数据/安装升级,跑 PM 验收 + 自动测试 + 回归 + 独立审查
- **模型名校验**(8/6 实测):minimax 错误模型名静默 fallback 到 `MiniMax-M3`,CC 写 provider 配置时必须用 minimax 官方列出的有效模型名

## 4. PM ↔ CC 单 loop 流程(沿用 7/16 拍,本项目沿用)

> 你不在 loop 内,PM 自驱

```
[I1] PM 优化工单提示词(历史反馈)
[I2] PM 拆工单(一个工单 = 一个工程闭环)
[I3] PM 派工单 → CC 执行(claude -p)
   ├─ 正常 → [I4]
   └─ CLI 失败(CC 挂)→ PM 自修 CC
      ├─ 修好 → 重派
      └─ 修不好 → 升级 AIF
[I4] CC 完成 → 写 LOG + 建议
[I5] PM 验收(30 秒 ✅/❌)
   ├─ ❌ → 改 → [I1]
   └─ ✅ → [I6]
[I6] 任务完成 + 队列清零?
   ├─ 否 → 拆新工单 → [I1]
   └─ 是 → 退出单 loop
→ 任务结果回流(你在 loop 外实际使用 + 验收)
```

**单任务小循环**(v0.00.0 文枢特定):
1. PM 派 CC 改 wenshu/ 根下的 Swift/SwiftUI/CoreData 代码(写在 wenshu/ 内,沙盒不进项目)
2. CC 跑完 `swift build` 验证编译,`swift test` 跑单元测试
3. PM 实际跑(在 Xcode 打开 wenshu.xcodeproj 或 swift run)
4. PM 验证用户旅程,记录 acceptance log
5. 你试用 + 验收
6. 下一任务

## 5. 拍单边界(2026-08-06 重写)

**CC 写代码**(wenshu/ 根下):
- SwiftUI 视图 + ViewModel
- CoreData model + actor store + 检索接口
- minimax cn LLM client(Anthropic 兼容协议)+ SSE parser
- 标记系统(`※` 待定、伏笔/信息点/历史事实)
- 看板组件、修订候选展示
- 单元测试 + 用户旅程测试
- `git commit`(本任务权限下)
- `Package.swift` / `.xcodeproj` 依赖增删(版本号变更需 PM 拍)

**PM 改**(CC 不动):
- `README.md` / `AGENTS.md` / `CLAUDE.md` / `CHANGELOG.md`(项目设定文档)
- Kanban 工单(hermes kanban DB)
- `.ws` 文件结构(PM-direct 决策)
- 跨设备同步策略(PM-direct)
- 蒸馏风格入库策略(PM-direct)
- 阶段门升级 / 阶段回流触发(PM-direct)
- minimax 模型名清单(PM 拍,从 minimax 官方文档拉)

**双向要问你**(CC 不能自己拍):
- 跳质量门禁(test/lint/CI)
- 改 LLM provider 适配层签名
- 改主进程 / actor / 阶段门 触发逻辑
- 改 `.ws` 文件 schema(新增/删除 entity / 改字段类型)
- 跨阶段(v0.00.x → v0.01.x, v0.01.x → v0.02.x)
- 改离线 / 在线状态切换行为
- 改多设备冲突解决策略

## 6. 评论格式(沿用 7/7 立 · 事事有反馈)

**任何评论必带**:task_id(自动) + 时间戳(自动) + 内容 < 5 行

**3 种规范答复**:
- ✅ 采纳:做了 + 何时生效
- ❌ 拒绝:理由 + 改做什么
- ⏸ 延后:原因 + 重新打开触发条件 + 跟踪 owner

**SLA**:
- 你 → AIF:≤ 4h
- AIF → PM:≤ 8h
- PM → CC:≤ 8h
- CC → PM:≤ 24h

## 7. 数据资产硬约束(2026-08-06 拍)

> 真理源:本节。CLAUDE.md §Security 必须 @本节

- **数据资产 = 你自管** — `.ws` 单文件 = 你的项目数据,文枢不依赖云端服务、不要求账号、不上传你的作品
- **跨设备靠你** — 你通过复制 `.ws` 文件、iCloud、OneDrive、Git、U 盘等任何方式跨设备,文枢不参与
- **多设备多入口经主控路由** — iPhone 记录的想法必须经主进程处理,不能直接修改主项目,避免多端并发覆盖
- **冲突解决:版本号 + 你后置决定** — 文件级版本号,打开时校验,不一致时备份旧版 + 创建新副本
- **卸载软件后数据仍可用** — 卸载文枢后 `.ws` 文件保留,数据不丢
- **格式:CoreData store + 附件包 + 资源目录**
- **LLM key 存 macOS Keychain** — 不在文件、log、commit message 中明文出现
- **封存的旧 monorepo fork 不可读不可写** — `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/` 是只读历史,CC/AIF 都不能改

## 8. 阶段门控(v0.00.x / v0.01.x / v0.02.x)

| 阶段 | 节点 | 验收标准 |
|------|------|---------|
| **v0.00.0** | 项目基线 | 3 文档定稿(README/AGENTS/CLAUDE) + Swift 包初始化 + CoreData 单文件验证 + minimax cn LLM 接入验证(Anthropic 兼容) |
| **v0.01.0** | 极简闭环 | 创建项目 → 写一句话故事 → AI 举一反三 → 你选择 → 生成人物/世界骨架(只读展示) |
| **v0.02.0** | 完整闭环 | 聊天驱动设定演化 + 资料库后台调研 + 看板实时反映 + 修订候选不覆盖 |
| **v0.03.0** | 阶段门 | 想法讨论 → 设定 → 大纲 → 正文,你控制节奏,AI 判断成熟度 |
| **v0.04.0** | 长篇工具 | 章节拖拽卡片 + 情绪曲线 + 关系图 + 时间线 + 注水量 1-9 级 + 文笔风格 |
| **v0.05.0** | 标记系统 | `※` 待定(快捷键+整章拦截) + 伏笔/信息点(选区右键) + 历史事实(AI 判断) |
| **v0.06.0** | iPhone 端 | 想法记录 + 聊天创作 + 项目状态查看 + 标记系统完整 |
| **v0.07.0** | 离线模式 | 本地写正文 + 看板 + 标记,LLM 联网,网络恢复增量合并 |
| **v1.00.0** | 发布候选 | App Store 提交(此时才付 Apple Developer Program $99) |

**版本号格式**:三位(Hermes 风格),中间位 = 阶段号,第三位 = hotfix。

**反馈包** = 产品截图(文枢跑起来) + 一句话 + 下一步方向(禁止文档截图)

## 9. Active vs Archive 区分(必读)

```
/Volumes/ANAN/Engineering/
├── wenshu/                                       ← ACTIVE 工作区(v0.00.0 文枢项目根)
├── .archive/
│   ├── wenshu-monorepo-fork/
│   │   └── v0.x-monorepo-fork-2026-08-06/        ← 旧 hermes monorepo fork 封存(只读)
│   ├── novel-craft/                              ← 历史归档
│   └── novel-platform/                           ← 历史归档
└── (其他历史:loop-engineering / novel-canvas / novel-research / open-design)
---
~/Engineering/                                   ← 沙盒(不进项目)
├── llm-call-test/                                ← 实验 4:minimax cn LLM (Anthropic 兼容)
├── wenshu-arch-experiments/
│   ├── Exp5-CoreData/                            ← 实验 5:CoreData 单文件
│   └── Exp6-Concurrency/                         ← 实验 6:Swift Concurrency + CoreData
└── (其他调研)
```

**规则**(2026-08-06 重写):
- ✅ 改 active 的 `wenshu/`(Swift/SwiftUI/CoreData/3 文档)
- ✅ 改沙盒 `~/Engineering/llm-call-test/` + `~/Engineering/wenshu-arch-experiments/`
- ❌ **绝对不动** `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/`(只读)
- ❌ **不动** `/Volumes/ANAN/Engineering/novel-platform/`(本机历史包袱)
- ❌ **不动** `/Volumes/ANAN/Engineering/Hermes-Slate-Desk/`(Tauri 时代留档)
- ❌ **不动** `~/.hermes/` 下任何 hermes 自带文件(你的边界外)
- ❌ **不动** 你自带的其他 hermes profile(`~/.hermes/profiles/` 下非 wenshu)

## 10. 风险与缓解(v0.00.0 重写)

| 风险 | 缓解 |
|------|------|
| **PM 不主动 LOOP** | AIF 主动 loop 派活方(7/10 13:05 拍板)+ 5 分钟内回 PM feedback |
| **token 撞 429** | 等 5h 重置(7/10 10:00 拍板)+ PM-direct + claude -p |
| **你想改方向** | loop 一头一尾决策(7/10 11:20 拍板)+ AIF 自决 |
| **minimax cn 服务中断** | 重试 + 错误展示 + 离线本地操作 + 任务排队 |
| **多设备 `.ws` 文件并发写冲突** | 关闭时强制 store coordinator sync + 文件级版本号 + 你后置决定 |
| **iOS 27 simulator 拉不到,iPad/iPhone 开发受阻** | macOS 端先行开发,等 Apple 公开 iOS 27 sim |
| **LLM 生成内容偏离你的意图** | 每次生成后显示影响摘要,你后置确认,不直接覆盖 |
| **修订候选累积过多** | 草稿和正式版本分别管理,定期清理,你主动触发修订 |
| **`.ws` 文件被云同步破坏** | 关闭时强制 sync,shm/wal 文件先合并 |
| **LLM key 泄露** | macOS Keychain 存储,不在文件/log/commit 明文 |
| **minimax 模型名错误静默 fallback** (8/6 实测) | CC 写 provider 配置时校验 minimax 官方模型列表;PM 派单必须写明确模型名 |
| **X-Api-Key header 缺失或不正确** | 用 minimax 官方推荐 header,错误信息明确提示 |

### 架构实验证据(2026-08-06 跑通)

| 实验 | 结论 | 沙盒位置 |
|------|------|---------|
| **实验 4:minimax cn LLM 调用(Anthropic 兼容)** | ✓ HTTP 200 + 流式 SSE ✓ (event 序列: message_start → content_block_start → ping → content_block_delta → content_block_stop → message_delta → message_stop, 无 [DONE]) + 错误 401 ✓ + 模型名错误静默 fallback ⚠ | `~/Engineering/llm-call-test/` |
| **实验 5:CoreData 单文件持久化** | ✓ 单文件 32KB + shm+wal ✓ / 跨进程读 ✓ / 事务回滚 ✓ / 追加写入 ✓ | `~/Engineering/wenshu-arch-experiments/Exp5-CoreData/` |
| **实验 6:Swift Concurrency + CoreData 协同** | ✓ actor 串行化(20 并发零冲突)+ Task 取消立即生效 + 交错 + ctx.perform FIFO ✓ | `~/Engineering/wenshu-arch-experiments/Exp6-Concurrency/` |
| **实验 1:SwiftUI 三端代码组织** | ⚠ 暂缓(iOS 27 simulator 未公开) | 待 iOS 27 sim 公开后跑 |

## 11. 升级路径

- 内环治不好 → 升级 AIF
- 外环治不好 → 升级你(拍板换方向/停/改 PM 模式)
- 升级 ≠ 甩锅 = 带当前进度 + 让对方能决策 + 不解释超过 3 行

## 12. 跨边界红线(v0.00.0 重写)

| 边界 | 红线 |
|------|------|
| AIF → PM | 替 PM 派工单 / 验收 |
| AIF → CC | 直接调 CC(必须走 PM) |
| PM → AIF | 替 AIF 定方向 / 推动阶段门 |
| PM → CC | 替 CC 执行 |
| 任何 → 同时多项目 | 派多项目并行 |
| AIF/PM/CC → `.archive/wenshu-monorepo-fork/` | 严禁(只读历史,改 = 越界) |
| **CC → 改任何 AI 平台任何代码文件** | **严禁**(沿用 8/4 你拍)。任何外部 AI 平台任何文件一律不动 |
| **CC → 改 LLM provider 适配层签名** | 严禁(改 = 越界,归 PM) |
| **CC → 改 `.ws` schema(增删 entity/字段类型)** | 严禁(改 = 越界,归 PM) |
| **CC → 跳质量门禁** | 严禁(改了必须回归测试,测试在 PM 权限) |
| **PM → 改 wenshu/ 源码** | 严禁(改 = 替 CC 执行,派工单走 CC) |
| **任何 → 替用户拍产品需求** | 严禁(你拍) |
| **任何 → 替你做 LLM key 配置决策** | 严禁(你自己配,key 不入项目) |
| **任何 → 上传你的 `.ws` 到云端** | 严禁(数据资产自管) |

## 13. 项目基线上下文(2026-08-06 你拍,整体转向)

你拍项目基线 v0.00.0:
- **架构**:Swift/SwiftUI + CoreData + 单进程协程 + 自建轻量 AI 内核
- **不调任何外部 AI 平台,不假设你懂任何 AI 工具**
- **第一版 LLM provider 只支持 minimax cn**(Anthropic 兼容协议,minimax 官方推荐)
- **`.ws` 单文件** = CoreData + 附件,本地自管
- **Apple 全家桶专属**(macOS/iPad/iPhone)
- **项目根** = `/Volumes/ANAN/Engineering/wenshu/`
- **支付 Apple Developer Program** 发布时再付(个人 $99/年)
- **版本号格式**:三位(Hermes 风格),中间位 = 阶段号
- **3 文档已落档** = 本文件(AGENTS.md v0.00.0)+ README.md v0.00.0 + CLAUDE.md v0.00.0
- **下步** = 派 v0.01.0 极简闭环工单给 PM

**历史拍板全废时间线**(2026-08-06 你拍):
- ❌ 2026-07-23 — 项目基线 0.0.0(NousResearch/hermes-agent v0.19.0 fork,monorepo 改品牌)→ 作废
- ❌ 2026-07-24 — wenshu 战略二次更正(1:1 复制 hermes 源码,仅 3 项改)→ 作废
- ❌ 2026-08-04 — wenshu = hermes v0.20.0 插件(整体转向)→ 作废
- ✅ 2026-08-06 — wenshu = Swift/SwiftUI 自建 + minimax cn LLM(Anthropic 兼容协议,官方推荐)→ **当前真值**

**CC 接到任务必读本节**:
- 不要带 hermes monorepo 痕迹(不再 fork)
- 不要带 Tauri / Rust / SQLite / Vue 3 痕迹
- 不要带 sparse clone 假设
- 不要带 novel-platform / novel-craft / Hermes-Slate-Desk 旧 V0.5.x 协议
- 不要调任何外部 AI 平台任何代码文件
- 不要替你决定 LLM key 配置
- 不要在 `~/wenshu-plugin/` 之外建项目目录(旧时代产物)
- 不要写 `~/.wenshu/` 任何文件(目录已取消)
- 不要自写 `wenshu` CLI(文枢 = Swift 桌面应用,不是 CLI)
- 不动 `~/.hermes/` 下 hermes 自带任何文件
- 不动 `.archive/wenshu-monorepo-fork/` 任何文件(只读历史)

---

*AGENTS.md v0.00.0 · 2026-08-06 你拍板"全新基线 · 自建 Swift/SwiftUI + CoreData + minimax cn LLM (Anthropic 兼容协议)" · 项目根 = `/Volumes/ANAN/Engineering/wenshu/`*
