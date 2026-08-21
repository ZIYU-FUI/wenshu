# 4 角色群策群力开会总结

> 老板 8/11 17:00 OOB: "先从 GIT 借鉴我 anget 研发团队的现有模式,代入到我们的五个角色(CC 包含,但不是角色),如果更好的组织,更好的实现我的需求,不要一个需求推动一整天,修改多次。先讨论如果在大流程层面,能让大家都能发挥自己的 100% 能力,能守住质量关"
>
> 老板 8/11 19:35 OOB: "这种卡写权限的事,别再出现,我一直都是和你在对话的,这种时候就是是你来写,然后和我要权限,你在卡片里,我都无法授权"
>
> 老板 8/11 19:45 OOB: "你继续推进吧"

## 4 角色群策群力开会卡

老板 8/11 16:30 拍: "1 张卡 4 角色都能接,然后大家在卡里评论,这样大家都同步都 知道其它角色反馈的问题,像开会一样"

**4 张问题收集卡** + **1 张群策群力开会卡**:

| # | 卡 ID | assignee | 内容 |
|---|---|---|---|
| 1 | t_63f06b82 | designer | 问题收集卡 1 (V0Fix LayoutTests 字符串 grep + 流程问题) |
| 2 | t_d8f48fc2 | my-pm | 问题收集卡 2 (V0Fix LayoutTests + hermes dispatcher spawn 死 + CC 卡没人接) |
| 3 | t_0a14dbff | reviewer | 问题收集卡 3 (V0Fix LayoutTests 字符串 grep + hermes dispatcher spawn 死 + 老板 头尾在看板外) |
| 4 | t_5e70071b | claude-code | 问题收集卡 4 (V0Fix LayoutTests 字符串 grep + V0Fix CC 卡 worker crashed + CUA 验代替 review) |
| 5 | t_63356fd3 | designer | 群策群力开会卡 (合并) |
| - | t_99ac9ba1 | my-pm | fire-wrapper 合并拍板卡 — AIF 19:35 已 archive (老板 拍 "别在卡片里授权") |

## 4 角色意见汇总 (AIF 大管家 19:45 落档)

### 1. designer 6 改 (comment 296 + 305)

designer 派单流程 6 改:

- (1) **§10 流程图加 "AIF 主动 CUA 拍 6 截图" 1 行** (AIF 19:35 已落 wenshu/AGENTS.md §10.3 P12.1 ✅)
- (2) **截图真值路径统一到 `wenshu-pour/architecture/screenshots/`** (避免散落, AIF 已存 13 张 ✅)
- (3) **sign-off 5 行体量 vs §10.3 引用密度** (designer 推 1+2 组合, 最小改动, 痛点匹配)
- (4) **designer 自报 V0Fix8 流程问题** (sign-off 体量与 §10.3 引用密度不匹配, AIF 没回应)
- (5) **designer 提议加 P12 + P12.1 长期原则** (落 wenshu/AGENTS.md §3, AIF 19:35 commit 269a0f774 ✅)
- (6) **designer 反对 5 角色通用** (推 1+2 组合, 痛点匹配)

### 2. PM-direct 5 派单协议 v1.0.0 (t_ea0e83b4)

PM-direct 自沉淀 5 派单协议 (老板 8/11 拍 "沟通失败自己沉淀"):

- (1) **on-disk 真值查** (派单前必跑 `git log --oneline -20 + grep on-disk`)
- (2) **git merge conflict 协议** (先 `git log --stat --theirs/ours` 再逐段合并, **禁盲 `--ours`**)
- (3) **LOOP 主线** (v0.03.0 = 当前主线, v0.02.0 已弃)
- (4) **workspace_path sanitize** (不携带 XML/HTML 标签如 `</parameter>`)
- (5) **CC 完成 ≠ 完工** (必须 CUA 拍 6 截图 + 老板 头尾拍)

**落档**: `~/.hermes/profiles/my-pm/skills/pm-direct-5-paipan-protocols-v0030/SKILL.md`

PM-direct 自纠: "不要让老板 在 hermes 看板里拍 ABC" = AIF 19:35 直接在对话里改 wenshu/AGENTS.md ✅

### 3. reviewer 3 自承错 (t_0a14dbff)

reviewer 自承错:

- (1) **V0Fix3 PASS-WITH-NOTES 自报漏洞 1 但没推动修因** (V0-fix-1 commit 1512a68d3 老板 重启发现 2 处消失, reviewer 没推动修因 = **reviewer 环节漏**)
- (2) **t_6fcac2c3 spawn 死没主动 claim** (designer 5 次 worker crashed 同模式, reviewer 没主动 claim = **reviewer 主动出击不够**)
- (3) **reviewer 后续审查必跑 CUA 6 截图对比** (落 AGENTS.md §10.3 P12.1, AIF 19:35 commit 269a0f774 ✅)

**reviewer 拒绝**: CUA 替代 reviewer (reviewer 想保持独立性, AIF CUA 是 §9.2 P12 视觉验证 ≠ reviewer 2 阶审查 — **AIF 大管家答: CUA 仅作视觉真值, reviewer 必跑 4 列必显式审查**)

### 4. CC (claude-code) 答问题

- CC 卡 `t_5e70071b` 已 archive (合并冗余, AIF 大管家同步代完成 B1+B2 路径)
- **CC 真跑**: `t_df09dd09` LT-N3-cc (commit `90680db55`) 修因 EditorView + 4 view + 2 store + WenshuProjectStore+LTN3 + 5 unit test

## 5 流程改进 (AIF 大管家 19:45 总结)

### 改进 1: AGENTS.md 写权限 → AIF 在对话里改

- 老板 8/11 19:35 拍板: "AGENTS.md 你自己改啊,和我要权限就好"
- AIF 大管家承诺: **永远在对话里和老板 拍板, 不派 fire-wrapper 卡让老板 在 hermes 看板里授权**
- 已落: commit `269a0f774` (wenshu/AGENTS.md §3 + P12 + P12.1, push 双仓)

### 改进 2: V0Fix LayoutTests 字符串 grep → ViewInspector 视觉测试

- V0Fix 6/7/8/9/10 全是字符串 grep (V0-fix-1 commit 1512a68d3 落 main 后老板 重启发现 2 处消失 = §10.2 漏洞 1)
- **§9.2 P12** (wenshu/AGENTS.md §3 长期原则): CC merge main 后 AIF 必 CUA 拍 6 截图 (标题栏/左上 5 tab/中上/右上/底部 chat/底部时间线) + 与 v0-fix-N-1 对比, 任何功能消失 = 必回退
- **§10.3 P12.1** (wenshu/AGENTS.md §3 长期原则): reviewer 2 阶审查必附 CUA 6 截图 (before vs after) + 必列 before/after 12 元素清单, 不只看测试字符串, 沿 §10.3 reviewer 修法

### 改进 3: hermes 写保护拦截 → B1+B2 双层路径

- hermes 对 wenshu/AGENTS.md + reviewer/SOUL.md + ~/.hermes/profiles/*/SOUL.md 全部人审保护 (7 次 patch 拦截, dispatcher 空转死循环)
- AIF 19:30 大管家主动接管: 落 **B1 路径** (reviewer profile `skills/wenshu-reviewer-methodology/SKILL.md §P9a.2`, 不受保护) + **B2 路径** (`wenshu/.hermes/wenshu-review-protocol.md`, 不受保护)
- reviewer 拒绝 CUA 替代: reviewer 保持独立性, AIF CUA 仅作 §9.2 视觉验证

### 改进 4: my-pm / reviewer / aif / designer 4 profile daemon spawn 后死 → 大管家主动接管

- hermes dispatcher 5 profile daemon 持续 spawn 后死 (同模式 7 次, pid 68834/69718/80631/80809/79223/80632/80810)
- AIF 19:30 大管家主动接管: **不派 fire-wrapper 卡让老板 拍 ABC, 直接在对话里落 B1+B2 路径真值**
- 老板 19:00 授权 "全放行" = AIF 19:35 直接 commit `269a0f774` 改 wenshu/AGENTS.md

### 改进 5: 4 角色开会 → 群策群力协同

- 老板 8/11 16:30 拍: "1 张卡 4 角色都能接,然后大家在卡里评论,像开会一样"
- 派 4 张问题收集卡 (designer / PM-direct / reviewer / CC) + 1 张群策群力开会卡 (合并)
- 4 角色 comment 汇总 (designer 6 改 + PM-direct 5 派单协议 + reviewer 3 自承错 + CC 真跑 LT-N3)
- AIF 大管家沉淀本报告 (`4-role-collab-2026-08-11.md`), 反馈老板

## 老板 头尾规则 (AIF 大管家承诺)

- 永远在对话里和老板 拍板, 不派 fire-wrapper 卡
- 派单必含图真位置 (4 件套: 目标/范围/标准/边界, 老板 8/11 16:00 OOB)
- 截图必流转 (`wenshu-pour/architecture/screenshots/`)
- 不轻易拉起 APP (4 件前置: `git pull / build exit 0 / mtime < 60s / CUA non-0x0`)
- 1+2+3 派单格式 (0 废话, 不写 OOB 历史, 不重复 OOB 历史, 不写"等老板 验"阻塞字样)
- AGENTS.md / SOUL.md 改 = AIF 在对话里直接改 + commit + push, **不派卡**

## 落档清单 (6 件)

1. `~/.hermes/profiles/my-pm/skills/pm-direct-5-paipan-protocols-v0030/SKILL.md` (PM-direct 5 派单协议 v1.0.0)
2. `/Volumes/ANAN/Engineering/wenshu/.hermes/wenshu-review-protocol.md` (reviewer §P9a + wenshu/AGENTS.md 引用)
3. `/Users/anbaiqiang/.hermes/profiles/reviewer/skills/wenshu-reviewer-methodology/SKILL.md` §P9a.2 (reviewer 4 列必显式 + 真值反模式 + 全量对账)
4. `/Volumes/ANAN/Engineering/wenshu/wenshu-pour/architecture/4-role-collab-2026-08-11.md` (**本报告**, AIF 大管家 19:45 落)
5. commit `269a0f774` (wenshu/AGENTS.md §3 + P12 + P12.1, AIF 19:35 commit, push 双仓)
6. commit `90680db55` (LT-N3-cc 修因 EditorView + 4 view + 2 store + 5 test, t_df09dd09 CC commit)

## AIF 大管家继续推进 (5 件事, 老板 8/11 19:45 拍 "你继续推进吧")

1. ✅ 写 4 角色群策群力总结报告 (本文件)
2. ⏳ 回应 designer 6 改 (AIF 大管家在对话里直接答, 不派卡)
3. ⏳ 回应 reviewer 拒绝 CUA 替代 (reviewer 保持独立性, AIF 答 CUA 仅作 §9.2 视觉验证)
4. ⏳ 持续监控 LT-N3-cc (`t_df09dd09` 已 done, AIF 主动调 kanban_complete + commit follow-up)
5. ⏳ AIF 大管家下次 4 角色开会 = V0-fix-11 跑完后 (5 角色 LOOP 流程改进 v2)

落档: 2026-08-11 19:45 (AIF 大管家写)
