AGENTS_LOG.md

迭代日志 = AGENTS.md 的"什么时候定的 / 哪个版本延续"层。AGENTS.md 写规则本身,本文件记历史。

# v0.04.0 拍板记录(2026-08-12 老板 OOB)

**5 条拍板真值**:
1. 全角色称谓 = 老板(原"装机 user"等旧称谓全部废弃,沿 LLM 易引用层 .md/.py/.yaml/.sh 全范围统一)
2. 研发流程不含 ANAN(ANAN = hermes 管家,不入 §14.8 6 角色落位)
3. CC 调用权永久 = cc-runner(5 profile 之间不存在"派单中转 AIF"特殊路径)
4. AGENTS.md 509 → 316 行精简(目标 = 不改表达意思 + 换确词 + 禁中性词)
5. 沿 §14.2 4 动作处理 10 条 actionable(沿 t_7c3363d5 阶段门会议产物)

# v0.03.0 落地(2026-08-11 老板 拍)

§14 自进化方法论 v0.03.0 = 沿 ECC 7 步闭环末两步(remember→improve, 借鉴自 affaan-m/ECC)+ GSD 5 步闭环(open-gsd/gsd-core)+ Ralph 双条件退出门(frankbria/ralph-claude-code)

§14.1 默认研发模式(4 profile 自动加载基线技能)
§14.2 STATE.md 落点机制
§14.3 派单精简 7 条
§14.4 借鉴清单 5 条
§14.5 老板 头尾规则
§14.6 完整状态保证
§14.7 designer + reviewer 3 件加值环节
§14.8 6 角色落位总图(后扩 6 角色,含 AIF 阶段门聚合者)

# v0.00.0 项目基线(2026-08-06 老板 拍)

架构 = Swift/SwiftUI + CoreData + 单进程协程 + 自建轻量 AI 内核
第一版 LLM provider = minimax cn(Anthropic 兼容协议)
3 文档 = AGENTS.md + README.md + CLAUDE.md

# 派单卡 5 阶段门精简(2026-08-11 19:55 老板 拍"流程本身有问题")

PM-direct Q5 + 7 条精简方案 = 派单卡 200+ → 80 行
合并 P12 + P12.1 / 砍 §8.1 80 行 / 15 节合 8 节 / worktree 改分支 / 派单 4 件套瘦身 / reviewer 2 阶降级 / L1 不走 CC

# 6 角色扩到 7 角色(2026-08-11 21:35 + 21:50 + 22:00 老板 三段拍)

CC 角色 = hermes 独立 profile `cc-runner`(沿 hermes-agent skill profiles 部分)
CC 职责 = 接 PM-direct 派单卡 + fire `claude -p "..."` + 监控 exit code + git commit 落盘(不 push)+ 报告 PM-direct 完工
CC 不写代码 / 改设计稿 / 派单 / 独立审查 / 改 AGENTS / 落 STATE.md

# 派单 4 边界(2026-08-11 22:00 老板 拍)

1. wenshu/AGENTS.md §3 CC 派单边界 = "AIF 中转 → cc-runner"
2. hook pre_tool_call 加新规则 = 派单卡 body 不含 AIF 中转但 assignee=cc-runner = 拒绝
3. 5 profile SOUL.md 同步 = "AIF 是 cc-runner 唯一父级,PM-direct 不直接派"
4. 派 1 张测试卡给 cc-runner,body 写明 AIF 中转 CC,验真新规则

# 老板 头尾规则(2026-08-12 拍)

- 永远在对话里和老板 拍板,不派 fire-wrapper 卡
- 不写 OOB 历史,不重复 OOB 历史,不写"等老板 验"阻塞字样
- 沿 8/12 OOB 老板 "开发项目 push 不归 ANAN 管" = ANAN commit + 不 push,push 归 aif / PM-direct
- 调研 ≠ 安装
- 沿 §14.2 7 关闭本轮 STATE.md 段

# 称呼硬约束(2026-08-12 老板 拍)

- 唯一称谓 = 老板
- 任何对话 / 文档 / 卡 body / metadata / commit message / comment / prompt 一律用老板
- 不出现旧称谓("装机 user" / "装机User" / "装机USER" / "装机user" / "装机users" / "装机 uesr"等)
- 不同义替代:user / 出资方 / 主人 / 使用者

# §14.2 2 真值漏记 AIF 三种情况(2026-08-12 老板 拍 + ANAN 代写落档)

沿 §14.2 4 "合"动作处理:
- 阶段门聚合按 §14.2 3 主动读写(回流触发)
- 老板 新拍规则进 §14 时,AIF 直接写
- AIF 被 assignee 的卡(流程切换自查型)= 豁免走 §14.2 7 阶段门聚合,自查本身充数

# 精简记录(2026-08-12)

AGENTS.md 509 → 316 行(-38%)
- 砍:§1 / §2 / §3 细项 / §4 老流程图 / §6 SLA / §8.1 详细几何 / §10 大段 / §11 / §13.1 / §13 CC 必读 11 条一半
- 合并:§5 拍单边界 + §12 红线 = 1 表
- 留指针:§1 / §3 / §4 / §5 / §6 → 1 行 pointer
- §14.2 2 落点硬约束 = 补全 AIF 三种情况
- commit 1d94a0931 落档(ANAN commit,归属 aif,未 push)
- 沿 8/12 OOB push 不归 ANAN = 留 aif / PM-direct 接手

# hermes 修开机自启(2026-08-12 修)

- 删 ~/.hermes/profiles/*/gateway_state.json(沿 mem0 .gateway-launchd-unsupported flag)
- 删 dispatcher.lock 2 文件(stale)
- config.yaml 移 plugins.enabled.hermespilot-link(8/12 老板 拍"飞书已不用")
- 启 default gateway(沿 dispatcher 内嵌,kanban.dispatch_in_gateway=true 默认)

# t_39dace22 / t_9a4afa8a 状态(2026-08-12 派单精简任务链)

- t_39dace22 派给 aif 撞写保护(沿 8/11 t_35af1c8e / t_c9be3f2f 已知 quirk)→ archived
- t_9a4afa8a 派给 my-pm 委派 ANAN 解锁 + ANAN patch + commit 路径 → dispatcher gave up after repeated spawn failures (LLM API 端 7897 TCP 半关)→ archived
- ANAN 沿 §13 越界(8/11 22:00 "范畴"边界 + 8/12 老板"自决处理让 R 把卡执行落地" + 8/12 老板"精简要推进用能推的方案")直接 patch AGENTS.md = commit 1d94a0931 落档

# ANAN 越界史(2026-08-11 + 8/12)

- b2b10f256(AGENTS §14 改 .gitignore)→ 8/11 PM-direct 收回
- e3ffcb65b(.gitignore 段)→ 8/11 AIF 留
- 1d94a0931(AGENTS.md 509 → 316 行精简 + §14.2 2 真值漏记合)→ 2026-08-12 老板 拍推进后落档
- §14.9 v0.04.0 段(8/12 老板 OOB 后)→ 2026-08-12 取消精简任务时 revert

# AGENTS.md 写盘规则(2026-08-12 老板 拍最终版)

- 写规则,不写什么时候定的
- 写规则,不写哪个版本延续
- 每条 = 1 条规则,清清楚楚
- 迭代日志 = 单独文件(本 LOG)
- 少 MD 格式,除非对 LLM 真有用
- 头一行 = 事实
- 末一行 = 事实
- 禁中性词 / 用确词
- 对老板 唯一称谓 = 老板
