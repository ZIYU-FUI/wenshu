# AGENTS.md · 文枢 (Wenshu)

> 项目基线 0.0.0(2026-07-23 18:55 出资方拍板)· **本文件 = 协作规则真理源**
> 任何"角色边界/派单/客户侧硬约束/评论 SLA/升级/跟上游漂移"全在本文件,其他文档只放指针
> **基线**:NousResearch/hermes-agent v0.19.0(tag `v2026.7.20`,commit `3ef6bbd20`),MIT License,Copyright (c) 2025 Nous Research
> **v0.6.0 PM 协议**:PM↔CC 单 loop(详见 §4)+ AIF 派完退场
> **新增**:跟上游漂移工作流(详见 §10,出资方 2026-07-23 拍)
> **v0.6.1 (2026-07-23 拍)**:小单快跑 + CC 并发 ≤ 3(详见 §11),PM 派单前必读

---

## 0. 进入研发模式加载清单 (PM-direct 默认行为)

任何角色(PM / AIF / CC)进 wenshu 项目开工前, **必须** 加载以下内容:

### 0.1 项目文档 (本仓)
- `AGENTS.md` ← 当前文件,协作规则真理源
- `CLAUDE.md` ← CC 启动自动读,项目上下文
- `README.md` ← 项目基线 + 跟上游漂移策略

### 0.2 PM-direct 必加载技能 (进 wenshu 项目时)
- `novel-platform-pm-workflow` (v1.85+,含 GD 小单快跑 + CC 并发 ≤ 3 + GB CC fire session-detach)
- `pm-workflow` (PM 整体工作流硬边界)
- `pm-loop-execution` (看板任务执行)
- `user-communication-style` (出资方 安百强 飞书回复风格)

### 0.3 CC 必加载 (进 wenshu 项目时)
- `~/.claude/CLAUDE.md` (CC 全局 anti-hallucination 紧箍咒)
- `wenshu/CLAUDE.md` (本项目上下文)
- `wenshu/AGENTS.md` §4 PM↔CC 单 loop 流程 + §11 小单快跑

### 0.4 AIF 必加载 (进 wenshu 项目时)
- `novel-platform-pm-workflow` (沿用 PM-direct 工作流真值源)
- `wenshu/AGENTS.md` (AIF 边界在 §1)

### 0.5 不需要加载
- 任何 hermes 内部 skill(跟上游漂移是 PM 维护性任务,不阻塞研发)
- 跨项目 skill(如 novel-craft 路径校验,只 novel-craft 项目用)

---

## 1. 角色边界(出资方 7/9-7/23 拍)

- **AIF**:`/goal` 跨轮访谈出 3 类草稿 → 落档到本项目 CC 三文档 → 派 PM → 退场。**AIF 派完不进 PM↔CC loop**
- **PM ↔ CC**:单 loop 跑实现(≤ 4 在跑卡,出资方 v0.5.25 拍板放宽)。老板不在 loop 内,PM 自驱。详见 §4
- **老板(出资方 安百强)**:在阶段门控节点(0.0.0 / 0.0.1 / 0.1.0 / ...)出现,看产品反馈,飞书会纠偏(均 loop 外)
- **本项目 AIF 边界**(跟 v0.6.0 一致,文枢特殊化):
  - ✅ 写 3 类项目文档(README/AGENTS/CLAUDE.md)
  - ✅ 派任务给 PM(kanban 派单)
  - ❌ 不动 hermes 任何代码文件(改 productName / appId / 字符串 / About / Settings 全部归 CC,0.0.1 起)
  - ❌ 不替 PM 验收 / 不派工单 / 不进 PM↔CC loop
  - ❌ 不改 PM 侧协议文件(归 PM)

## 2. 通道

- AIF ↔ PM:`hermes kanban`(同 board 跨 profile 自动可见)
- PM ↔ CC:Claude Code CLI(`claude -p "..."`,并发 ≤ 4)
- 老板 ↔ AIF:飞书自然语言
- PM ↔ upstream:PM-direct `git fetch upstream` + `git log upstream/main` 监测 hermes 上游新 release
- CC ↔ Python 内核:自包含 venv(`~/.wenshu/hermes-agent/`,**不读本机 `~/.hermes/hermes-agent/`**)

## 3. 派单原则(出资方 7/9-7/23 拍)

- 一次只派 1 个,确认 ≤ 4 才派下个
- 派单理由必填(为什么本卡必须现在派,≤ 3 行)
- `[Urgent]` 标记 = 例外允许,必带紧急原因
- ≤ 4 在跑卡硬约束(出资方 v0.5.25 拍板放宽,从 ≤ 2 → ≤ 4)
- **单任务单一功能 + 打 .app 给老板试用验收**(出资方 7/10 18:14 拍板沿用,7/23 拍文枢沿用)
  - 协议:v0.6.0 PM↔CC 单 loop,详见 §4
- **小单快跑 + CC 并发 ≤ 3** (出资方 7/23 拍,文枢 v0.6.1):
  - 每个工单 AC ≤ 5 + 文件 ≤ 3,超标 → 拆
  - 文件互不冲突 → 并发派 ≤ 3
  - 文件冲突 / 依赖 → 串行
  - 大单 (跑 > 10 分钟无进展) → PM-direct 主动 abort + 拆小单重派
  - 详细协议见 §11.5
- **跟上游漂移 = 维护性任务**(出资方 7/23 拍):
  - 不阻塞 P0/P1 阶段门控
  - PM 每周/每月同步一次进度(老板不在 loop 内)
  - 详见 §10

## 4. PM ↔ CC 单 loop 流程(出资方 7/16 拍,文枢沿用)

> 老板不在 loop 内,PM 自驱

```
[I1] PM 优化工单提示词(历史反馈)
[I2] PM 拆工单(一个工单 = 一个工程闭环)
[I3] PM 派工单 → CC 执行(claude -p)
   ├─ 正常 → [I4]
   └─ CLI 失败(CC 挂)→ PM 自修 CC
      ├─ 修好 → 重派
      └─ 修不好 → 升级 AIF
[I4] CC 完成 → 写 LOG + **方案**
[I5] PM 验收(30 秒 ✅/❌)
   ├─ ❌ → 改 → [I1]
   └─ ✅ → [I6]
[I6] 任务完成 + 队列清零?
   ├─ 否 → 拆新工单 → [I1]
   └─ 是 → 退出单 loop
→ 任务结果回流(老板在 loop 外实际使用 + 验收)
```

**单任务小循环**:
1. PM 派 CC 跑任务
2. CC 跑完 `pnpm build` + `electron-builder --mac` 出 `文枢.app` + `文枢.dmg`
3. PM cp 到 `/Applications/文枢.app`
4. PM open + cua 验证主流程
5. 老板试用 + 验收
6. 下一任务

## 5. 拍单边界(CC 改什么,PM 改什么)

**CC 写代码**(文枢 monorepo 根 + apps/desktop + agent + gateway + hermes_cli):
- 业务逻辑、UI 组件、store、composable
- 单元测试
- `package.json` 依赖增删(版本号变更需 PM 拍)
- `electron-builder` config(appId / productName 变更需 PM 拍)
- `git commit`(本任务权限下)
- 字符串替换(品牌重塑任务,全 monorepo "Hermes" → "文枢")

**PM 改**(CC 不动):
- `README.md` / `AGENTS.md` / `CLAUDE.md` / `CHANGELOG.md` / `loop-run-log.md` / `WORKLOG.md`(项目设定文档)
- Kanban 工单(hermes kanban DB)
- 改 4 个 metadata 字段(name / appId / productName / window title)= PM-direct,CC 跑批量 apply
- 跟上游漂移的 patch series(`wenshu-patches/`,PM 维护)
- GitHub Releases 资产(token + assets)
- `cp` 到 `/Applications/文枢.app`(最后一次手装)
- 改本项目 README/AGENTS/CLAUDE/LOOP-CONSTRAINTS 等项目设定文档

**双向要问出资方**(CC 不能自己拍):
- 跳质量门禁(test/lint/CI)
- 改 API 接口签名
- 改 4-tier ladder 顺序或新增 rung(**文枢 = 砍 rung 1-4 留 rung 5 = 自包含内核**,改这个 = 问老板)
- 跨阶段(0.0.x → 0.1.x,0.1.x → 0.2.x)
- 改 hermes 上游 API 同步节奏
- 改 LICENSE 内容

## 6. 评论格式(出资方 7/7 立 · 事事有反馈)

**任何评论必带**:task_id(自动)+ 时间戳(自动)+ 内容 < 5 行

**3 种规范答复**:
- ✅ 采纳:做了 + 何时生效
- ❌ 拒绝:理由 + 改做什么
- ⏸ 延后:原因 + 重新打开触发条件 + 跟踪 owner

**SLA**:
- 老板 → AIF:≤ 4h
- AIF → PM:≤ 8h
- PM → CC:≤ 8h
- CC → PM:≤ 24h

## 7. 客户侧硬约束(出资方 7/15 拍 · 真理源)

> 真理源:本节。CLAUDE.md §Security 必须 @本节

- **不复用即错**:任何项目侧(文枢)不准硬塞 hermes gateway 端口 / base_url / provider / API key / MoA / UI 预设
- **配置只在** `~/.wenshu/hermes-agent/config.yaml`(文枢独立配置,**不读 `~/.hermes/profiles/default/config.yaml`**)
- **客户侧只读不写**
- **端口动态查询**:启动时查文枢自有 venv 暴露的查询接口,不写死
- 文枢 APP 启动时**必须**查自己 venv 当前端口(端口每次重启会变)
- **跟本机 hermes 切割**:文枢不读 `~/.hermes/hermes-agent/`,不复用本机 hermes 任何数据(用户装机 = 全新文枢环境)

## 8. 阶段门控(0.0.x / 0.1.x / 0.2.x 节点)

| 阶段 | 节点 | 验收标准 |
|------|------|---------|
| **0.0.0** | AIF 3 文档落档 | README/AGENTS/CLAUDE 跟本项目根,本地 commit |
| **0.0.1** | LICENSE 合规 | 4 文件改完(packjson / LICENSE / README / About),build 出 .app,About 显示 "文枢 v0.0.1 · 基于 WenShu Agent v0.19.0 (MIT) 修改",push origin main |
| **0.0.2** | 品牌重塑 | 全 monorepo "Hermes" → "文枢" 字符串替换,Settings/About/启动页/logo/启动 banner/CLI 文案 全部到位 |
| **0.0.3** | 砍 4-tier ladder rung 1-4 | rung 1-4 砍,只留 rung 5 = 自包含内核,启动不再检测本机 hermes |
| **0.0.4** | build 跑通 | `pnpm install` + `pnpm build` + `electron-builder --mac` 出 `文枢.app` + `文枢.dmg` |
| **0.0.5** | 装机启动验证 | cp 到 /Applications/文枢.app + 启动,自包含内核起来,About 正确 |
| **0.1.0** | PM↔CC 单 loop 跑加功能 | 第一个 PM↔CC 闭环功能 |
| **0.2.0+** | 跟上游漂移 | hermes 0.20.0 release → PM 三方 merge,文枢 0.2.0 release |

**反馈包** = 产品截图(`.app` 跑起来)+ 一句话 + 下一步方向(禁止文档截图)

## 9. Active vs Archive 区分(必读)

```
/Volumes/ANAN/Engineering/
├── wenshu/                        ← ACTIVE 工作区(文枢),CC 在这里干活
├── novel-platform/                ← V0.5.3 era 留档(本机不动,不 push)
└── .archive/
    ├── novel-platform/            ← V0.5.3 frozen snapshot,只读
    └── ...                        ← 历史归档
```

**规则**:
- ✅ 改 active 的 `src/**` / `apps/**` / `package.json` / docs
- ❌ **绝对不动** `/Volumes/ANAN/Engineering/.archive/novel-platform/`
- ❌ **不动** `/Volumes/ANAN/Engineering/novel-platform/`(本机历史包袱,不 push 但保留)
- ❌ 不把 archive 文件拷回 active(项目重启就是为了清干净,搬回去 = 回滚)
- ❌ 不参考 archive 的方法论 / 字典 / CHANGELOG 内容(协议已重起)

## 10. 风险与缓解

| 风险 | 缓解 |
|------|------|
| PM 不主动 LOOP | AIF 主动 loop 派活方(7/10 13:05 拍板)+ 5 分钟内回 PM feedback |
| token 撞 429 | 等 5h 重置(7/10 10:00 拍板)+ PM-direct + claude -p |
| 打包 .app 卡首页报错 | PM 自测 .app 主流程无核心阻断 |
| 老板想改方向 | loop 一头一尾决策(7/10 11:20 拍板)+ AIF 自决 |
| 文枢 ladder 砍 rung 1-4 装内核失败 | PM-direct 查 bootstrap-installer 网络 / Python 版本;fallback 用 env override 强制装文枢版本 |
| 文枢 app 跟原 Hermes app 撞 macOS Gatekeeper | appId = `com.wenshu.app` 区分 |
| **跟上游漂移 — 小版本落后** | PM-direct 三方 merge,ours/theirs/wenshu-patches 自动化;滞后 1-3 周 |
| **跟上游漂移 — 大版本 breaking change** | 老板拍是否合,滞后 1-2 月;About 显示当前内核版本,用户知情 |
| **文枢品牌字符串替换遗漏** | CC 跑 `grep -r "Hermes" --include="*.py" --include="*.ts" --include="*.tsx" --include="*.json" --include="*.cjs" --include="*.md" .` 验证 = 0 命中(在 hermes-agent 仓库名 / GitHub URL / commit hash / 上游引用 之外的代码区) |
| **文枢装用户机器后 2 份 hermes 混淆** | 文枢 = `~/.wenshu/`,本机 hermes = `~/.hermes/`,完全隔离。About 明确显示两个路径 |
| **自包含 venv 占盘大**(~1GB+) | 装到 `~/.wenshu/hermes-agent/`,跟本机 `~/.hermes/hermes-agent/` 完全隔离;卸载文枢 = `rm -rf ~/.wenshu/`,干净 |
| **LICENSE 标识错漏** | 0.0.1 工单 PM-direct 验 commit + grep 验证 "Nous Research" / "MIT" 全部出现 |

### 跟上游漂移的真实成本预估

hermes 上游节奏实测(GitHub Releases 7/23 实测数据):
- v0.18.1 (2026.7.7) → v0.18.2 (2026.7.7.2)= **1 天**
- v0.18.2 → v0.19.0 (2026.7.20)= **12 天**
- v0.17.0 (2026.6.19) → v0.18.0 (2026.7.1)= **12 天**
- v0.15.1 (2026.5.29) → v0.15.2 (2026.5.29.2)= **1 天**
- **平均 1-3 次 release / 月,小版本热补(1-7 天),大版本月度**

PM↔CC 投入(实测估算):
- 小版本(0.x.y → 0.x.y+1):PM-direct 4-8h + CC 0-8h
- 大版本(0.x → 0.x+1):PM-direct 1-3 天 + CC 1-3 天
- 文字冲突(API 改名 / schema 变):通常 1-3 处/版本,人工调

**关键设计决策**:`wenshu-patches/` 目录 = 我们所有改动的 patch series,每次上游 release → PM 三方 merge(ours / theirs / wenshu-patches)。CC 跑 `git format-patch` + `git am` 自动化。

## 11. 升级路径

- 内环治不好 → 升级 AIF
- 外环治不好 → 升级老板(出资方拍板换方向/停/改 PM 模式)
- 升级 ≠ 甩锅 = 带当前进度 + 让对方能决策 + 不解释超过 3 行

## 11.5 小单快跑 + CC 并发 ≤ 3 协议 (出资方 7/23 拍,文枢 v0.6.1)

### 拍板真意
- PM-direct 默认 = 拆小单快跑,不是单张工单塞所有事
- CC **必须**并发派 ≤ 3 张(禁止串行 1 张)
- 大单 (AC > 5 / 文件 > 3 / 跑 > 10 分钟无进展) → 拆

### Rule 1: 小单快跑 (AC ≤ 5 + 文件 ≤ 3)
- 每个工单 AC 列表 ≤ 5 条,改文件 ≤ 3 个
- 不达标 → 拆多张工单
- 例: 文枢 0.0.2 "全 monorepo 品牌字符串替换" 拆成 3 张:
  - WO-N+1: `apps/desktop/package.json` build 块 (1 文件, 4-6 字段 patch)
  - WO-N+2: 全 monorepo 字符串显示替换 (n 文件, 每文件 < 5 处 patch)
  - WO-N+3: `npm run dist:mac` 出 .app + cp /Applications/文枢.app + open

### Rule 2: CC 并发上限 ≤ 3
- 文件互不冲突 → 并发派 ≤ 3 张
- 文件冲突 (同一文件) → 串行 (或拆到不冲突)
- 依赖关系 (WO-N 等 WO-N-1 跑完) → 串行

### Rule 3: 派单姿势 (PM-direct CC fire)
- nohup + disown + </dev/null + setsid 4 件套(压制 session-detach 杀进程)
- 派单前 prompt 写到 `/tmp/cc-out/<wo-id>-prompt.md`
- 然后 `os.setsid()` + fork exec fire
- 详细 Pitfall 见 `novel-platform-pm-workflow` SKILL v1.85 GD / GB

### Rule 4: 大单兜底
- CC fire 跑超 10 分钟没 stdout 进展 (size 卡 0 字节) → PM-direct 主动 abort + 拆小单重派
- 不允许"派完等 30 分钟才察觉死" (7/23 文枢 0.0.2 实战反例: 30 分钟 0 字节才发现死)

### Pitfall (GD-1): 派单前先自检
"这张 WO AC > 5 / 文件 > 3 / 跑 > 10 分钟" 任一, 拆。
出资方拍板"少做选择", 不接受"一锅端派单"。

### Pitfall (GD-2): 并发派单写明文件作用域
CC 跨 WO 不会撞 working tree。
例: WO-004 限定 "只改 apps/desktop/package.json build 块",
WO-005 限定 "不改 package.json build 块, 只改 n 个 src 文件 + README.md"。

## 12. 跨边界红线

| 边界 | 红线 |
|------|------|
| AIF → PM | 替 PM 派工单 / 验收 |
| AIF → CC | 直接调 CC(必须走 PM) |
| PM → AIF | 替 AIF 定方向 / 推动阶段门 |
| PM → CC | 替 CC 执行 |
| 任何 → 同时多项目 | 派多项目并行 |
| PM → `/Users/anbaiqiang/.hermes/` | 越界!hermes 端是出资方 7/9 §11 边界外 |
| **PM → 文枢改名工单** | 0.0.1 LICENSE 完成后才能派 0.0.2 品牌重塑(禁止无 LICENSE 情况下发布 .app) |
| **CC → 改 LICENSE 文本** | 严禁 CC 改 LICENSE 内容,改 = 走 PM 升级老板 |
| **CC → 砍 4-tier ladder rung** | 仅 0.0.3 工单内允许,其他工单内改 = 越界 |

## 13. 项目基线上下文(2026-07-23 18:55)

出资方拍项目基线 0.0.0:
- **基线 = NousResearch/hermes-agent v0.19.0**(tag `v2026.7.20`,commit `3ef6bbd20`,fetch + checkout 完成)
- **项目根 = `/Volumes/ANAN/Engineering/wenshu/`**(7/23 16:34 PM 重建,fetch ~547MB,`v2026.7.20` tag 拿到)
- **仓库 = `github.com/ZIYU-FUI/wenshu`**(取代 `gitee.com/zi-yu1983/novel-platform`,7/23 18:55 配 origin)
- **upstream = `git@github.com:NousResearch/hermes-agent.git`**(fork 关系,跟版本漂移)
- **3 文档已落档** = 本文件(AGENTS.md v0.1)+ README.md v0.1 + CLAUDE.md v0.1
- **下步** = 派 0.0.1 LICENSE 合规工单给 PM(详见 README.md §4)

**CC 接到任务必读本节**:
- 不要带 novel-platform Tauri / Rust / SQLite / Vue 3 痕迹。文枢 = Hermes monorepo 深度改 fork
- 不要带 sparse clone 假设(apps/desktop 单子目录)— 现在是完整 monorepo fork
- 不要复用 hermes 上游 4-tier ladder rung 1-4(本机检测)— 0.0.3 工单砍,只留 rung 5
- 不要带 novel-craft / Hermes-Slate-Desk 旧 V0.5.1/V0.5.4 协议
- 不要在 0.0.1 LICENSE 工单外改 LICENSE 文本
- 不要在 0.0.3 工单外改 4-tier ladder rung 数量
- 不动 `/Users/anbaiqiang/.hermes/`(hermes 端边界外)

---

*AGENTS.md v0.1 · 2026-07-23 18:55 项目基线 0.0.0 · 改自 NousResearch/hermes-agent v0.19.0 (tag v2026.7.20) · 真理源:本文件*
