# PM-direct CC 派单失败真值表 (2026-07-28 拍)

> 落档真值：避免重蹈 8/27-8/28 派单失败 8 轮 R1-R8 撞 max-turns 0 改动的真值。
> 维护方：PM-direct 自家（wenshu 私域 = ~/.wenshu-hermes/ 不动；本文件落 wenshu-pour/architecture/ 是项目文档，由 PM-direct 维护；不是派 CC 写）。

## 1. CC 退知机制 (PM-direct 8/28 拍)

每次派单 CC 后，PM-direct 必须在 5 分钟内巡检 fire.log 状态 + PID 存活，并在 exit 后立即向装机 user 报结果（不再靠 memory 查）。

| 阶段 | 真值 |
|------|------|
| 派单前 | fire.sh 写明 `tee` 到 `/tmp/cc-out/wo-XXX-fire.log` + `date +%s > fire.start` |
| 跑中 | 5 分钟巡检 fire.log size + grep "CC DONE" |
| exit | exit=0 + "CC DONE" 命中 → 报装机 user "可装"；exit!=0 或缺 "CC DONE" → 报 "CC 失败" + grep fire.log 末 50 行 |
| 失败 3 次同任务 | 立即降级为 PM-direct 自家跑（python3 heredoc + Prettier + diff） |

## 2. 拍单姿势真值表 (PM-direct 8/28 拍)

| 任务类型 | 派单 | 落档 |
|---------|------|------|
| 改 wenshu 仓内文件（任何大小） | CC | 落档 wenshu-pour/architecture/ |
| 改 ~/.hermes/profiles/my-pm/ 下文件（skill / SOUL / AGENTS / memory） | **PM-direct 自家** | 落档 ~/.hermes/profiles/my-pm/ |
| build / install / commit + push / cp | CC | wenshu 仓 |
| 调研/读文档 | CC（限定范围） | /tmp/cc-out/ |
| 拍单失败 3 次同任务 | 立即降级 PM-direct 自家跑 | python3 heredoc |

## 3. CC 派单失败真值表 (PM-direct 8/28 拍)

R1-R8 4 派单 CC 跑全失败真值（max-turns 12/12/6/3），落档避免重蹈：

| 失败模式 | 真值 | 修法 |
|---------|------|------|
| 让 CC 自由探索 | 12 轮读完根 AGENTS.md + CLAUDE.md + 子目录 AGENTS.md 后 0 改动 | 派单前 PM-direct 锁定文件路径和需求，不在 prompt 给"先查再改" |
| max-turns 给 6/3 | 跑不完就强制退 | 单文件改 max-turns ≤4 + PM-direct 自家跑 fallback |
| 给 ~/ 目录权限 | CC 误读 ~/Documents 老项目 | --add-dir 只允许 /Volumes/ANAN/Engineering/wenshu |
| 派单 prompt 含模糊"5 步调研" | CC 真的跑 5 步调研，0 改动 | 派单 prompt 直接给"改哪个文件 + 改成什么" |

## 4. wenshu 私域路径真值

- 隔离 home：~/.wenshu-hermes (绝对路径) — 后端启动、配置、日志全部走这
- 禁止回退：~/.hermes (系统 Hermes) — 任何 default 分支禁止回退
- 隔离 home 中 hermes-agent 目录：~/.wenshu-hermes/hermes-agent/
- 当前已知违反：apps/desktop/electron/main.ts:479 resolveHermesHome() 默认仍返回 ~/.hermes (WO-001BI-R10 待派)

## 5. 拍板真值落档位置 (PM-direct 拍)

- wenshu 项目规则 (装 user 拍) → wenshu/AGENTS.md / CLAUDE.md / wenshu-pour/architecture/
- PM-direct 工作流规则 (PM-direct 自家拍) → ~/.hermes/profiles/my-pm/skills/ + mem0 + 本文件
- 装机 user 私域配置 → ~/.wenshu-hermes/ (wenshu 后端读这)

## 6. CC 跑完 PM-direct 5 件套自验

1. exit code == 0
2. fire.log 含 "CC DONE"
3. git diff 落档真实
4. 产物 mtime 新
5. 不出白名单目录

## 7. 单文件微改 vs 大整包派单判据 (PM-direct 8/28 拍)

装机 user 拍板（校正 8/28 边界）：
- wenshu 项目内任何文件改动 = 全部归 CC（无论大小）
- PM-direct 私域 = ~/.hermes/profiles/my-pm/ 下的方法论 / skill / memory / 拍板真值，由 PM-direct 自家搞定

派单粒度判据：

| 工单类型 | 派单 | 真值 |
|---------|------|------|
| 改 wenshu 仓内文件（任何大小） | CC | 装机 user 8/28 拍板 |
| 改 ~/.hermes/profiles/my-pm/ | **PM-direct 自家** | 装机 user 8/28 拍板 |
| 写 wenshu-pour/architecture/*.md 落档 | CC | 装机 user 8/28 拍板 |
| 跑 build / 装 / commit + push | CC | 装机 user 8/28 拍板 |
| 修 ~/.hermes/profiles/my-pm/skills/* | PM-direct 自家 | 装机 user 8/28 拍板 |
| mem0_add / skill_manage | PM-direct 自家 | 装机 user 8/28 拍板 |

## 8. 当前 LOOP 目标 (PM-direct 8/28 拍)

装机 user 拍板：LOOP 是为了让整个写作转得越来越快，效率和质量不断提升。

- 每张单跑完都做复盘
- 派单姿势和验证节奏逐步标准化
- 失败真值沉淀进 skill，下一张单复用
- 一段时间后单张单耗时应从几小时缩短到分钟级
- 质量从"能跑"提升到"鲁棒、文档齐全、可回滚"

复盘锚点段落（每张单派单 prompt 必加）：

```
[复盘锚点]
- 上一张单最花时间的环节：xxx
- 这次准备复用：xxx
- 跑完要落档到 wenshu-pour/architecture/RXX-*.md
- 落档内容：AC 真值 + 跑中撞的坑 + 派单姿势改进
```

跑完归档流程：
- 落档 wenshu-pour/architecture/RXX-*.md（AC / 坑 / 改进）
- 更新 cc-fire-cc-cli-mechanics v3.15+（派单失败真值表 + 复盘锚点段落）
- 立即把后续单按 RXX 模板套
- 第 3 张单完成后做一次小复盘，更新 skill 规则
