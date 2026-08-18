# CLAUDE.md · 文枢 (Wenshu)

> CC(未来的 Claude Code CLI)启动时自动读取的项目上下文
> 真理源指针:@AGENTS.md(项目基线 §11 + 跨角色称谓硬约束 §12)
> v0.02.0 layout grammar(5 区 + 折叠 + 拖拽)详见 @AGENTS.md §8.1
> 项目基线 v0.07(2026-08-18 pocock single agent 净化版拍)

---

## 1. Project Overview

> **文枢 = Apple 全家桶专属的长篇虚构小说 AI 创作平台**(2026-08-06 你拍板)

**项目基线**(2026-08-06 你拍板):
- 你拍板"自建 Swift/SwiftUI 桌面应用 + 自建轻量 AI 内核 + minimax cn LLM(Anthropic 兼容协议,minimax 官方推荐),你配 key 即用"
- **架构 = Swift/SwiftUI 单进程应用 + CoreData 单文件 `.ws` + Swift Concurrency actor 串行化 + LLM provider 抽象层(minimax cn,Anthropic 兼容)**
- **不复用**:任何外部 AI 平台 / 任何 AI 平台进程 / 任何 AI 平台 CLI / 任何 monorepo / 旧 wenshu monorepo fork / 旧 plugin 路线
- **核心用户**:有长篇小说想法但缺创作经验的人(普通用户)
- **第一版 LLM provider**:minimax cn(你配置 API key,Anthropic 兼容)
- **`.ws` 单文件** = CoreData + 附件,本地自管
- **平台**:macOS / iPad / iPhone(同一 Swift/SwiftUI 代码,交互适配)
- **版本号格式**:三位(Hermes 风格),中间位 = 阶段号,第三位 = hotfix

**基线信息**:
- 项目根 = `/Volumes/ANAN/Engineering/wenshu/`
- 沙盒 = `~/Engineering/llm-call-test/` + `~/Engineering/wenshu-arch-experiments/{Exp5-CoreData,Exp6-Concurrency}/`
- 旧 monorepo fork = `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/`(只读,9.7GB)
- LICENSE = MIT(项目本身),minimax cn 协议另行遵守
- LLM API key = 你自己配(存 macOS Keychain),不入项目

## 2. Tech Stack

| 层 | 技术 | 版本 | 选型理由 |
|----|------|------|---------|
| 语言 | Swift | 6.4+ | Apple 平台原生,SwiftUI 6 完整覆盖三端 |
| 桌面应用 | SwiftUI | iOS 17 / iPadOS 17 / macOS 14+ | 同一套代码覆盖三端,自动适配 |
| 数据存储 | CoreData | Apple framework | 跨 Apple 平台、单文件、SQLite WAL 模式、actor 友好 |
| 并发模型 | Swift Concurrency | Swift 5.5+ | actor 串行化 + Task 异步 + AsyncSequence 流式 |
| LLM provider | minimax cn | Anthropic 兼容 | minimax 官方推荐,支持 thinking 块、tool_use 块、1M 上下文,流式 SSE |
| 流式响应 | URLSession + 自建 SSE parser | - | 字节级累积,识别 event 类型,event 序列: message_start → content_block_start → ping → content_block_delta → content_block_stop → message_delta → message_stop,无 [DONE] 终止符 |
| 项目格式 | `.ws` | CoreData store + 附件 | 本地单文件,跨设备复制 |
| LLM key 存储 | macOS Keychain | Apple framework | 不入文件、不入 log、不入 commit |
| 多端同步 | 你自带云(iCloud/OneDrive/Git/U 盘) | - | 文枢不参与,文枢不感知 |
| 支付 | Apple Developer Program | 个人 $99/年 | 发布到 App Store 时才付,开发期免费 ID 即可 |
| 测试 | XCTest + swift test | SwiftPM | 沿用 Apple 官方测试框架 |

**用**(已落地):
- ✅ Swift / SwiftUI / CoreData / Swift Concurrency
- ✅ minimax cn LLM(Anthropic 兼容协议,minimax 官方推荐路径)
- ✅ `.ws` 单文件作为项目数据
- ✅ macOS Keychain 存 LLM key

**不用**(P0 / v0.00.x 阶段):
- ❌ 任何外部 AI 平台代码、平台进程、平台 CLI
- ❌ 任何 LLM provider 框架(直连 minimax cn,不引入 LangChain / SwiftAI / Vercel AI SDK 等)
- ❌ 任何云服务、账号体系、跨设备同步服务
- ❌ 任何 monorepo / 任何 npm / 任何 Python / 任何 Rust / 任何 Tauri / 任何 Vue
- ❌ 任何 SQLite 直连(用 CoreData,不动 SQLite 层)
- ❌ 任何 user-installer 脚本 / 任何 hermes 自举链路
- ❌ 任何 iCloud 同步集成(你自带云)

## 3. Directory Structure

```
wenshu/                                                ← 项目根(v0.00.0)
├── README.md                                          ← 项目门面(已落档 v0.07)
├── AGENTS.md                                          ← 协作规则真理源(2026-08-18 净化到 §11 §12)
├── CLAUDE.md                                          ← 本文件(已落档 v0.07)
├── .hermes/                                           ← 设计稿 (v0.07 sketch 真值等)
│
├── (空 — 待 v0.01.0 起开始写 Swift Package)
│
├── wenshu.xcodeproj/                                  ← Xcode 工程(v0.01.0 起)
├── Package.swift                                      ← SwiftPM 入口(v0.01.0 起)
├── Sources/
│   ├── WenshuApp/                                     ← SwiftUI App 入口(macOS)
│   │   ├── App.swift
│   │   ├── MainView.swift
│   │   └── Info.plist
│   │
│   ├── WenshuCore/                                    ← 核心(跨端共享)
│   │   ├── Model/
│   │   │   ├── CDCharacter.swift                      ← 人物
│   │   │   ├── CDChapter.swift                        ← 章节
│   │   │   ├── CDNote.swift                           ← 待定/伏笔/信息点/历史事实
│   │   │   ├── CDWorldRule.swift                      ← 世界规则
│   │   │   ├── CDForeshadow.swift                     ← 伏笔(带状态机)
│   │   │   ├── CDRevision.swift                       ← 修订候选(带原稿关联)
│   │   │   └── CDAIDraft.swift                        ← AI 推演(带置信度)
│   │   │
│   │   ├── Store/
│   │   │   ├── WenshuStoreActor.swift                 ← CoreData 写串行化
│   │   │   ├── PersistenceController.swift
│   │   │   └── WenshuModel.xcdatamodeld
│   │   │
│   │   ├── LLM/
│   │   │   ├── LLMProvider.swift                      ← provider 抽象
│   │   │   ├── MinimaxProvider.swift                  ← minimax cn 实现(Anthropic 兼容)
│   │   │   ├── SSEParser.swift                        ← 流式 SSE 解析(按 event 类型)
│   │   │   └── LLMMessage.swift
│   │   │
│   │   ├── Search/
│   │   │   ├── ContextAssembler.swift                 ← 长期记忆 → LLM 上下文
│   │   │   └── ChapterSummarizer.swift                ← 章节摘要生成
│   │   │
│   │   ├── Stage/
│   │   │   ├── StageGate.swift                        ← 阶段门(想法/设定/大纲/正文)
│   │   │   └── StageDetector.swift                    ← 成熟度判断
│   │   │
│   │   ├── Marker/
│   │   │   ├── TodoMarker.swift                       ← ※ 待定
│   │   │   ├── ForeshadowMarker.swift                 ← 伏笔
│   │   │   ├── InfoPointMarker.swift                  ← 信息点
│   │   │   └── FactCheckMarker.swift                  ← 历史事实
│   │   │
│   │   ├── Revision/
│   │   │   ├── RevisionManager.swift                  ← 修订候选管理
│   │   │   └── DiffRenderer.swift                     ← 飘红 + 边栏历史
│   │   │
│   │   └── Style/
│   │       ├── BuiltinStyles.swift                    ← 内置风格库
│   │       ├── StyleDistiller.swift                   ← 上传作品蒸馏
│   │       └── StyleInference.swift                   ← 用户表达反推
│   │
│   ├── WenshuUI/                                      ← SwiftUI 视图(跨端)
│   │   ├── ChatView.swift                             ← 对话层
│   │   ├── ProjectListView.swift                      ← 项目列表
│   │   ├── DashboardView.swift                        ← 看板
│   │   ├── EditorView.swift                           ← 正文编辑器
│   │   ├── RelationGraphView.swift                    ← 关系图
│   │   ├── TimelineView.swift                         ← 时间线
│   │   ├── EmotionCurveView.swift                     ← 情绪曲线
│   │   └── DetailView.swift                           ← 详情页(看板点开)
│   │
│   └── WenshuPlatform/                                ← 平台特定
│       ├── macOS/
│       ├── iPadOS/
│       └── iOS/
│
├── Tests/
│   ├── WenshuCoreTests/                               ← 单元测试
│   │   ├── StoreActorTests.swift
│   │   ├── SSEParserTests.swift
│   │   └── RevisionManagerTests.swift
│   │
│   └── WenshuIntegrationTests/                        ← 集成测试
│       ├── UserJourneyTests.swift                     ← 用户旅程
│       └── CrossDeviceTests.swift                     ← 跨设备
│
└── (沙盒代码在 ~/Engineering/ 不进项目)
```

## 4. Modules(文枢视角)

| Module | 路径 | 职责 | 依赖 |
|--------|------|------|------|
| MainActor 对话层 | `Sources/WenshuApp/` | 用户对话永远响应,阶段门判断,看板渲染,@ 语法解析 | WenshuCore, WenshuUI |
| Background Tasks | `Sources/WenshuCore/LLM/` + `/Search/` | LLM 调用,章节摘要,资料调研,修订候选,风格蒸馏 | WenshuCore,LLM provider |
| Store actor | `Sources/WenshuCore/Store/` | CoreData 写串行化,事务,版本管理 | CoreData |
| LLM provider | `Sources/WenshuCore/LLM/` | minimax cn(Anthropic 兼容),流式 SSE,key 管理 | minimax cn API |
| 阶段门 | `Sources/WenshuCore/Stage/` | 想法/设定/大纲/正文切换,成熟度判断 | WenshuCore |
| 标记系统 | `Sources/WenshuCore/Marker/` | ※待定,伏笔,信息点,历史事实 | WenshuCore |
| 修订候选 | `Sources/WenshuCore/Revision/` | 修订生成,飘红对比,后置确认 | WenshuCore |
| 文笔风格 | `Sources/WenshuCore/Style/` | 内置 + 用户反推 + 上传作品蒸馏 | WenshuCore |
| 上下文拼装 | `Sources/WenshuCore/Search/` | 长期记忆 → LLM 最小上下文 | WenshuCore,LLM provider |
| 看板 | `Sources/WenshuUI/DashboardView.swift` | 主阶段智能筛选,详情页完整展开 | WenshuCore |
| 编辑器 | `Sources/WenshuUI/EditorView.swift` | 正文编辑,选区右键,标记,修订候选展示 | WenshuCore |
| 关系图 | `Sources/WenshuUI/RelationGraphView.swift` | 人物关系可视化 | WenshuCore |
| 时间线 | `Sources/WenshuUI/TimelineView.swift` | 故事时间线 | WenshuCore |
| 情绪曲线 | `Sources/WenshuUI/EmotionCurveView.swift` | 情绪/节奏/强度曲线 | WenshuCore |

## 5. Web/IPC 接口(文枢特有)

文枢是桌面应用,无外部 Web/IPC 接口。所有内部通信走 Swift actor / NotificationCenter / @Published。

| 内部接口 | 路径 | 用途 |
|---------|------|------|
| `WenshuStore` actor | `Sources/WenshuCore/Store/` | CoreData 写串行化,跨模块唯一写入入口 |
| `LLMProvider` protocol | `Sources/WenshuCore/LLM/LLMProvider.swift` | 抽象 LLM 调用,MinimaxProvider 是唯一实现(Anthropic 兼容) |
| `ContextAssembler` | `Sources/WenshuCore/Search/ContextAssembler.swift` | 长期记忆 → LLM 最小上下文 |
| `StageGate` | `Sources/WenshuCore/Stage/StageGate.swift` | 阶段门主控 |

## 6. Project Conventions

- **代码风格**:沿用 Swift 官方 API Design Guidelines + SwiftLint 标准配置(`swift run swiftlint` 在 wenshu/ 内验证)
- **测试**:沿用 XCTest + Swift Testing(`swift test` 在 wenshu/ 根跑)
- **Git**:用 git(你自管,不需要 GitHub repo 也能本地开发)
- **不要新增** 任何依赖管理工具、ORM、HTTP 客户端框架、JSON 解析框架 — 沿用 Swift 标准库

## 7. Security(CC 必读,源自 AGENTS.md §7)

- **数据资产 = 你自管** — `.ws` 单文件 = 你的项目数据,文枢不依赖云端服务、不要求账号、不上传你的作品
- **跨设备靠你** — 你通过复制 `.ws` 文件、iCloud、OneDrive、Git、U 盘等任何方式跨设备,文枢不参与
- **多设备多入口经主控路由** — iPhone 记录的想法必须经主进程处理,不能直接修改主项目,避免多端并发覆盖
- **冲突解决:版本号 + 你后置决定** — 文件级版本号,打开时校验,不一致时备份旧版 + 创建新副本
- **卸载软件后数据仍可用** — 卸载文枢后 `.ws` 文件保留,数据不丢
- **LLM key 存 macOS Keychain** — 不在文件、log、commit message 中明文出现
- **封存的旧 monorepo fork 不可读不可写** — `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/` 是只读历史,CC 不能改

## 8. Verification(CC 写完代码必跑)

```bash
# wenshu/ 根
cd /Volumes/ANAN/Engineering/wenshu

# 编译
swift build

# 单元测试
swift test

# 集成测试
swift test --filter WenshuIntegrationTests

# 代码风格
swift run swiftlint

# 用户旅程测试
# macOS 端实际跑:
# 1. swift run WenshuApp 或 open wenshu.xcodeproj
# 2. 创建项目
# 3. 写一句话故事
# 4. AI 举一反三
# 5. 生成人物/世界骨架
# 6. 关闭并重开
# 7. 跨设备复制 .ws 到 iPad
# 8. iPad 端打开同一 .ws,验证数据一致
```

## 9. Project Baseline Context(CC 必读)

> **本节最重要,CC 接到任务必先读**

文枢 = Swift/SwiftUI 自建桌面应用 + CoreData + minimax cn LLM(Anthropic 兼容协议,minimax 官方推荐路径)。**禁止**:

- ❌ 引入任何外部 AI 平台依赖
- ❌ 引入任何 LLM 框架(LangChain / SwiftAI / Vercel AI SDK / OpenAI Swift Client 等)
- ❌ 引入任何 monorepo / 任何 npm / 任何 Python / 任何 Rust / 任何 Tauri / 任何 Vue
- ❌ 直接连 SQLite(用 CoreData,不动 SQLite 层)
- ❌ 任何 user-installer 脚本 / 任何 hermes 自举链路
- ❌ 任何 iCloud 同步集成(你自带云)
- ❌ 改 LICENSE 文本
- ❌ 改 LLM provider 签名(改 = 升级 PM)
- ❌ 改 `.ws` schema(增删 entity/改字段类型,改 = 升级 PM)
- ❌ 跳质量门禁(改 = 升级 PM)
- ❌ 替你拍产品需求
- ❌ 替你配置 LLM key(key 必须你自己配)
- ❌ 上传你的 `.ws` 到云端
- ❌ 动 `~/.hermes/` 下任何 hermes 自带文件
- ❌ 动 `.archive/wenshu-monorepo-fork/` 任何文件
- ❌ 动 `~/wenshu-plugin/`(旧 plugin 时代产物,已废)
- ❌ 写 `~/.wenshu/` 任何文件(目录已取消)
- ❌ 自写 `wenshu` CLI(文枢 = Swift 桌面应用,不是 CLI)
- ❌ 写错误模型名(8/6 实测:minimax 静默 fallback 到 `MiniMax-M3`,任务必须写明 minimax 官方模型名)

**minimax cn 模型白名单**(2026-08-06 从 minimax 官方文档拉):
- `MiniMax-M3` (推荐,1M 上下文,Coding/Agentic SOTA)
- `MiniMax-M2.7` / `MiniMax-M2.7-highspeed` (60 TPS / 100 TPS)
- `MiniMax-M2.5` / `MiniMax-M2.5-highspeed`
- `MiniMax-M2.1` / `MiniMax-M2.1-highspeed`
- `MiniMax-M2`
- `M2-her` (对话场景,64K 上下文)

**minimax cn 端点 & Auth**:
- 端点: `https://api.minimaxi.com/anthropic/v1/messages`
- Auth: `X-Api-Key: <key>`(官方错误信息推荐,`Authorization: Bearer ***` 也可)
- 流式 SSE,event 序列: `message_start` → `content_block_start` → `ping` → `content_block_delta` → `content_block_stop` → `message_delta` → `message_stop`,无 [DONE] 终止符
- Content block 类型: `text` / `thinking` / `tool_use` / `image`
- 工具调用: `tools: [{name, description, input_schema}]` + `tool_choice: {type: auto}`

**CC 改的关键文件清单**(v0.07 阶段):

- `Sources/WenshuApp/App.swift` — SwiftUI App 入口
- `Sources/WenshuApp/MainView.swift` — 主视图
- `Sources/WenshuCore/Model/*.swift` — CoreData entity(PM 拍 schema 后才能改)
- `Sources/WenshuCore/Store/WenshuStoreActor.swift` — CoreData 写串行化
- `Sources/WenshuCore/LLM/MinimaxProvider.swift` — minimax cn 实现(Anthropic 兼容)
- `Sources/WenshuCore/LLM/SSEParser.swift` — 流式 SSE 解析(按 event 类型)
- `Sources/WenshuCore/Stage/StageGate.swift` — 阶段门
- `Sources/WenshuCore/Search/ContextAssembler.swift` — 长期记忆 → LLM 上下文
- `Sources/WenshuUI/EditorView.swift` — 正文编辑器

## 10. References

- 真理源:`AGENTS.md`(项目基线 §11 + 跨角色称谓硬约束 §12)
- 项目门面:`README.md`
- 沙盒实验:
  - `~/Engineering/llm-call-test/` — 实验 4:minimax cn LLM 调用(Anthropic 兼容)
  - `~/Engineering/wenshu-arch-experiments/Exp5-CoreData/` — 实验 5:CoreData 单文件
  - `~/Engineering/wenshu-arch-experiments/Exp6-Concurrency/` — 实验 6:Swift Concurrency + CoreData
- 旧 monorepo fork(只读):`/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/`
- minimax cn API:`https://api.minimaxi.com/anthropic/v1/messages`
- minimax cn 文档:`https://platform.minimaxi.com/docs/llms.txt`
- minimax cn 模型白名单:见 §9
- Apple Developer Program:发布时再付个人 $99/年
- iOS 27 simulator:暂未公开,iPad/iPhone 端实机测试待 iOS 27 sim 公开后补

---

*CLAUDE.md v0.07 · 2026-08-18 pocock single agent 净化版 · 自建 Swift/SwiftUI + CoreData + minimax cn LLM (Anthropic 兼容协议) · 项目根 = `/Volumes/ANAN/Engineering/wenshu/`*
