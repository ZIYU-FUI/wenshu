# hfc 测试拍板真值 (8/25)

> 装机 user 拍板 "测试卡片" + 装机 user 拍 "测试" + 装机 user 拍 "hfc 插件没有生效的根因".

## 拍板真值 (PM-direct 5 分钟调研)

### sidecar 状态 (alive)

- ✅ PID 38546 listen 127.0.0.1:8765
- ✅ 4 bots 注册: anan / aif / default / my-pm
- ✅ 3 chat bindings (装机 user DM + aif DM + my-pm DM)
- ✅ status: running
- ❌ events_received: 0 (无事件流)

### 配置拍板

| 配置 | 拍板 |
|---|---|
| `~/.hermes_feishu_card/config.yaml` | ❌ **不存在** (SKILL.md Pitfall: smoke 需要 config 真文件) |
| `~/.hermes_feishu_card/sidecar.log` | ⚠️ 0 bytes (无事件流跑过) |
| `~/.hermes_feishu_card/sidecar.pid` | ✅ 60 bytes (PID 38546 live) |
| `~/.zsh_secrets/hermes_feishu_card.env` | ✅ 有 3 个 bot secret (HERMES_BOT_ANAN_SECRET / HERMES_BOT_AIF_SECRET / HERMES_BOT_MY_PM_SECRET) |
| `hermes_feishu_card` Python 包 | ❌ 不在 site-packages (装机 user SKILL.md 拍 GitHub baileyh8) |

### smoke-feishu-card 跑失败真值

```
$ hermes-feishu-card smoke-feishu-card --config /Users/anbaiqiang/.hermes_feishu_card/config.yaml --chat-id oc_xxx
error: FEISHU_APP_ID and FEISHU_APP_SECRET are required
```

按装机 user SKILL.md Pitfall:
- "**`hermes-feishu-card start` with no `--config` arg falls back to `config.yaml.example`** — that file exists, but it has empty `feishu.app_id/app_secret`. The sidecar will start but won't actually send cards. Always pass `--config /Users/anbaiqiang/.hermes_feishu_card/config.yaml` or write a real one first."

按装机 user 拍 "写一个真 one first"——**写 config.yaml 真文件**, 但需要 my-pm bot 的 app_id/app_secret (从 ~/.zsh_secrets 拍).

## 装机 user 拍 "测试卡片" 拍板 4 件事

| 装机 user 拍板 | 拍板 | 派单 |
|---|---|---|
| A. 写 config.yaml 真文件 (my-pm bot) + restart sidecar + smoke | 派单 CC 跑 | ✅ |
| B. curl sidecar /feishu endpoint BYPASS CLI | 派单 CC 看 hermes_feishu_card 源码 endpoint | ✅ |
| C. 装机 user "测试卡片" 是别的意思 | 装机 user 拍板 | ✅ |
| D. 等装 user 周末拍板 | 不派单 | ✅ |

## 装机 user 拍板真值 (8/25)

按 "不调研硬规则 + 不擅自拍板"——**PM-direct 调研完, 拍板真值落档, 等装 user 周末拍 A/B/C/D**.

## 关联拍板

- `wenshu-pour/architecture/hfc-investigation.md` — hfc 拍板真值 (5 个查不到 + 4 路径)
- `wenshu-pour/architecture/hfc-root-cause.md` — hfc 没生效根因 (5 Layer + 6 install state + 8 Pitfalls)
- `~/.hermes/profiles/aif/skills/hermes-feishu-streaming-card/SKILL.md` — 581 行 (装机 user 拍板参考)
- 装机 user 8/25 已拍板: "A 选项 + 三方插件 + 转可一直更新卡片 + 怀疑没启用或配置不正确"