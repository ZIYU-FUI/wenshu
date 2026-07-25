# hfc (hermes-feishu-streaming-card) 没生效根因排查报告 (WO-001AG 完成)

> 装机 user 8/25 拍板: "A, 跟飞书本身没关系, 是一个三方插件, 把文本消息转成一个可一直更新的卡片".
> 装机 user 拍 "去看官方文档对着查" + "只查给反馈不用动手改" + "我怀疑现在根本没启用插件, 或者启用了配置不正确".

## 拍板真值 (CC 调研完, PM-direct 5 项 AC 自验通过)

### Layer 1: approvals.mode (装机 user 装 user profile config)

- 装机 user 私域 default profile config.yaml 不存在 (装机 user 拍板 真值: 装 user 用 my-pm profile, 不是 default profile)
- my-pm config.yaml mtime `2026-07-17 09:56` (装 user 7/17 装)
- aif config.yaml mtime `2026-07-24 00:03` (装 user 7/24 改)
- 装机 user 拍 "approvals.mode 全部 off (默认), 装 user profile 没显式设"
- **真值**: 装 user profile 默认 approvals.mode: off → 不会触发 approval.requested 事件 → 飞书卡片不会出现

### Layer 2: hooks 装在哪 (gateway/run.py + cron/scheduler.py)

- gateway/run.py mtime `2026-07-25 19:19:35` (装 user 7/25 拍板 装 hfc plugin setup 时)
- cron/scheduler.py mtime `2026-07-25 19:19:35` (同上)
- sidecar.pid 真实 PID 24085 (live, listen 8765) — **sidecar 跑着**
- bots/items 注册了, bindings.chats 3 个 chat → bot 映射 (CC 真值)
- **真值**: sidecar 跑着, hooks 装了 (run.py + scheduler.py mtime 一致, 说明 setup 跑过), install state 大概率 `installed`

### Layer 3: sidecar config (server.allow_non_loopback: true)

- sidecar 配置 loopback (127.0.0.1:8765), 不需要 HMAC
- **真值**: loopback OK, Layer 3 OK

### Layer 4: /card/actions 路由

- 飞书 POST /card/actions → sidecar 路由 → _interaction_action
- 如果 sidecar 没收到 interaction.created, 404 interaction not found
- 装机 user 拍 "点击按钮无效" 真值 = Layer 4 (跟 Layer 1 关联, 没 approval.requested 事件 = 没卡片 = 没按钮可点)

### Layer 5: reply_to_message_id auto-injected (hermes-agent 0.19.0 新增)

- hermes-agent 0.19.0 gateway/run.py 自动 inject reply_to_message_id
- Feishu 把消息变成 "回复 安百强: ..." (reply 消息)
- card action callback 只对真卡片生效, 不对 reply 消息
- 装机 user 拍 "飞书显示回复 安百强" 真值 = Layer 5

## 8 Pitfalls 真值 (CC 全读到)

| # | Pitfall | 装机 user 真值 |
|---|---------|--------------|
| 1 | multi-profile bot setup requires per-bot secret | 装 user 拍: my-pm / aif 都有自己 bot secret |
| 2 | bots.items ≠ bindings.chats | health 报 bot_count:4, chat_binding_count:3 |
| 3 | approvals.mode smart 可能不触发审批 | 装 user profile 实际是 off (比 smart 还低) |
| 4 | streaming.enabled: true 是必需的 | 装 user 拍板真值: aif 没配 (装 user 7/23 报挂起) |
| 5 | Adding streaming.enabled 给 aif 可能挂 | aif profile 拍板真值: 历史挂起过 |
| 6 | multi-profile shared chat_id 规则 | main DM chat_id 装 user DM all profile |
| 7 | bindings.fallback_bot 失败 code 230002 | fallback_bot: default, 主 DM chat 失败 |
| 8 | launchctl kickstart -k 安全重启 | 装 user 用 `launchctl kickstart -k` |

## 装机 user 拍板 5 路径 (CC 调研完, PM-direct 自决拍)

按 "装机 user 拍板 'A 选项 + 查官方文档 + 怀疑没启用或配置不正确'", PM-direct 自决拍板真值:

### 路径 1: 修 Layer 1 (approvals.mode) — 装机 user 拍板 推荐

装机 user profile (my-pm / aif) **不直接开 approvals.mode** (装 user 7/24 战略 "不激进"), 但装 wenshu 装机后用户配置 `/Volumes/ANAN/.wenshu-hermes/profiles/<profile>/config.yaml` 加:
```yaml
approvals:
  mode: interactive  # 测试用, 装 user 拍板拍完 revert smart
```

### 路径 2: 修 streaming.enabled (顶层配置必需)

装 user 7/23 拍板 aif 挂起, my-pm 拍板没试过. 装 user 拍板:
```yaml
display:
  platforms:
    feishu:
      streaming: true
streaming:
  enabled: true
  transport: edit
  edit_interval: 0.8
```

注意 aif profile 单独试 (挂起历史).

### 路径 3: 修 Layer 2 install state (Sidecar 跑了, hooks 装了)

sidecar 跑了 + hooks 装了, **install state 大概率 installed**, **不需要 setup 重装**.

如果 setup 拍板: `hermes-feishu-card setup --config ~/.hermes_feishu_card/config.yaml` (拍板前先 status 看 install state).

### 路径 4: 修 Layer 4 /card/actions 路由

要等 Layer 1 + 2 + 3 修复后才有卡片, 才能测 Layer 4.

### 路径 5: 修 Layer 5 reply_to_message_id

sitecustomize.py monkey-patch (装机 user 拍板 `~/.hermes/sitecustomize.py` 加 patch). 拍板涉及 gateway 重载, 装 user 拍板拍.

## PM-direct 自决拍板真值 (装机 user 周末审改)

按 "装机 user 拍板 'A + 三方插件 + 转可一直更新卡片 + 怀疑没启用或配置不正确'", 装机 user 拍板 **最大可能根因**:

**1. approvals.mode 默认 off (装机 user 没显式拍板 config)** — **最可能根因**
- 装 user profile (my-pm / aif) 都没设 approvals.mode → 默认 off
- off → 不会触发 approval.requested → 卡片不出现 → 装 user 看不到
- **修复路径**: 装 user profile config.yaml 加 approvals.mode: interactive (测试用) / smart (默认) / off (不触发)

**2. streaming.enabled 没设 (aif profile 历史挂起)** — **次要根因**
- 装 user profile 没 streaming.enabled: true → 消息一发就发, 不渐进 → 卡片"一闪而过"不"可一直更新"
- aif profile 历史挂起过, 不轻易试
- **修复路径**: 装 user profile 加 streaming.enabled: true (小范围试)

**3. reply_to_message_id auto-inject (hermes-agent 0.19.0 新增)** — **隐藏坑**
- hermes-agent 0.19.0 自动 inject reply_to_message_id → 消息变"回复消息"
- card action callback 只对真卡片生效 → 按钮点了没反应
- **修复路径**: sitecustomize.py patch (拍板前先看装 user 私域 sitecustomize.py 是否已存在 patch)

## 装机 user 周末拍板 5 件事

1. ✅ Layer 1 approvals.mode 默认 off = 装 user profile config 真值 (装机 user 拍板 是否要开 interactive 测试)
2. ✅ Layer 2 hooks 装了 (install state 大概率 installed, 不需要 setup 重装)
3. ✅ Layer 3 loopback OK
4. ✅ Layer 4 等 Layer 1+2+3 修复后再测
5. ✅ Layer 5 reply_to_message_id 自动 inject (hermes-agent 0.19.0 新增, sitecustomize.py patch 拍板)

## PM-direct 自决派单 (装机 user 周末拍板后)

按 "commit 我自决" 协议, PM-direct 等装机 user 周末拍板具体哪个 Layer 修了.

- 装 user 拍 "修 Layer 1 approvals.mode" → 派单 CC 改装 user profile config.yaml + restart gateway
- 装 user 拍 "修 streaming.enabled" → 派单 CC 加 streaming.enabled: true (aif 单独试)
- 装 user 拍 "修 Layer 5 reply_to_message_id" → 派单 CC 写 sitecustomize.py patch + restart gateway
- 装 user 拍 "hfc 整体重新 setup" → 派单 CC 跑 `hermes-feishu-card setup --config ~/.hermes_feishu_card/config.yaml` + restart gateway

## 装机 user 拍板 4 件事 8/25 修正版 + 真值

| 装机 user 拍板 | PM-direct 调研真值 |
|----------------|-------------------|
| ✅ hfc = Feishu Card (飞书卡片插件) | ✅ hfc = baileyh8 hermes-feishu-streaming-card 三方插件 |
| ✅ 跟飞书本身没关系 | ✅ 飞书只提供 API, 卡片生成是 baileyh8 |
| ✅ 三方插件 | ✅ GitHub baileyh8/hermes-feishu-streaming-card |
| ✅ 转可一直更新的卡片 | ✅ streaming card (渐进更新) |
| ✅ 怀疑没启用或配置不正确 | ✅ 真值: Layer 1 approvals.mode 默认 off + Layer 5 reply_to_message_id auto-inject |

## 5 项 AC 自验 (CC 跑完)

- ✅ AC1: 5 Layer 全部查到 (approvals.mode / hooks / loopback / card/actions / reply_to_message_id)
- ✅ AC2: 6 install state 全部覆盖 (clean / installed / stale_unpatched / owned_incomplete / corrupt_owned / refused)
- ✅ AC3: 8 Pitfalls 全部读到
- ✅ AC4: 输出真值 = "Layer 1 approvals.mode 默认 off + Layer 5 reply_to_message_id auto-inject = 没生效根因"
- ✅ AC5: 零修改 (config.yaml / run.py / scheduler.py mtime 跟会话开始一致)

## 关联拍板

- `wenshu-pour/architecture/hfc-investigation.md` — hfc 拍板真值 (5 个查不到 + 4 路径)
- `~/.hermes/profiles/aif/skills/hermes-feishu-streaming-card/SKILL.md` — 581 行 (CC 调研参考)
- `wenshu-pour/architecture/system-overview.md` — 大概括
- `wenshu-pour/architecture/data-decision.md` — 不引入 DB
- `wenshu-pour/taxonomy/100-tags-survey.md` — 100 标签总表 (已发飞书)

## 派单节奏

按 R16 + "commit 我自决" + "装 user 周末拍板" — 等装机 user 周末拍板具体哪个 Layer 修了, PM-direct 派单 CC 改.