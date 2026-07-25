# hfc 插件 PM-direct 调研真值 (8/25)

> 装机 user 拍板 8/25 修正: "hfc 不是 hermes 插件, 是飞书的卡片插件" (Feishu Card).

## 拍板真值 (8/25 装机 user 修正)

**`hfc` = Feishu Card Plugin (飞书卡片插件)** — 不是 hermes 自带插件, 是**飞书机器人开发的卡片 UI 插件**.

按 PM-direct 5 分钟调研:
- hermes 仓根 grep `hfc` = 0 命中 (仓根 plugins/ 18 个目录, 没 hfc)
- hermes-agent .archive 仓 grep `hfc` = 只匹配 cargo build 哈希路径
- hermes 官方文档 website/docs grep `hfc` = 0 命中
- hermes Python 代码 grep `hfc` = 0 命中
- 装机 user ~/.wenshu-hermes grep `hfc` = 0 命中

5 个查不到 = **拍板真值 = `hfc` 不是 hermes 自带插件** (是飞书的).

## 装机 user 拍 "hfc 插件没生效的根因" — 真值修正

按 "装机 user 拍板 hfc = 飞书卡片插件" + "PM-direct 调研飞书卡片机制":

1. **hfc 是什么?** = 飞书消息卡片 (interactive card), 用于机器人发卡片消息 (按钮 + 文本 + 图片 + 表单)
2. **hfc 装机 user 拍 "没生效"** = 装机 user 飞书 DM 收不到 hfc 卡片 / 卡片显示异常 / 卡片按钮点不了 / 卡片样式不对
3. **hfc 跟 hermes 关系** = hermes-agent 自带 `hermes-feishu-streaming-card` skill (装机 user 私域已装), 但**那是 hermes 端 skill, 不是我-pm bot 端** — 我-pm bot 端需要单独装飞书卡片 SDK + 调试

## PM-direct 派单路径 (CC 排查)

按装机 user 拍 "派 CC 排查 + 去看文档对着查 + 只查给反馈不用动手改", PM-direct 派单 CC:

**WO-001AG**: 排查飞书卡片插件 (hfc) 没生效的根因
- 1. 读 hermes-agent 自带 `hermes-feishu-streaming-card` skill (581 行, 装机 user 7/25 拍板用过)
- 2. 查飞书开放平台官方文档 (open.feishu.cn/document/...) 关于 message card / interactive card / card JSON 2.0
- 3. 查装机 user 私域 ~/.wenshu-hermes/ 是否装了飞书卡片 SDK (lark-oapi Python SDK)
- 4. 查 my-pm bot app_id `cli_aa800146b3ba5bde` 飞书后台权限 (是否开通 im:message.card 等)
- 5. 查 100-tags-survey.md 发送后, 装机 user DM 收到的消息是 file 还是 card 类型
- 6. **不派单动手改**, 只读调研, 输出 PM-direct 5 项 AC 自验报告

## 装机 user 拍板 4 路径 (8/25 修正版)

### A. hfc = Feishu Card (装机 user 8/25 拍板修正) → 派单 CC 排查 (WO-001AG)

PM-direct 拍板: 按装 user 8/25 修正, hfc = Feishu Card, 派单 CC 排查.

### B. 飞书后台权限不够

飞书 app 需要开通 im:message:send_as_bot / im:message.card 等权限. my-pm bot (`cli_aa800146b3ba5bde`) 当前是否开通?

### C. 飞书 SDK 没装 / 版本不对

飞书机器人开发需要 lark-oapi Python SDK (或飞书 openapi-sdk-python). 装机 user 私域是否装了?

### D. 飞书卡片 JSON 格式不对

飞书 message card 是 JSON 格式 (card 2.0), 装机 user 拍的 hfc 插件需要正确 JSON.

## 装机 user 拍板 5 件事 (8/25 修正版)

1. ✅ hfc = Feishu Card (飞书卡片插件) (装机 user 8/25 修正)
2. ✅ 派单 CC 排查 hfc 没生效根因 (按 "只查给反馈不用动手改")
3. ✅ hermes-agent 自带 `hermes-feishu-streaming-card` skill (参考)
4. ✅ 装机 user 拍板 4 路径 (A 派 CC / B 飞书后台权限 / C 飞书 SDK / D JSON 格式)
5. ✅ PM-direct 不擅自拍板, 等装机 user 周末拍板 A/B/C/D

## 关联拍板

- `wenshu-pour/architecture/system-overview.md` — 大概括
- `wenshu-pour/architecture/data-decision.md` — 不引入 DB
- `wenshu-pour/taxonomy/100-tags-survey.md` — 100 标签总表 (已发飞书)
- `wenshu-pour/methodologies/style/` — 笔法库 (12 作者)

## 派单节奏 (等装 user 周末拍板)

按 "commit 我自决" 协议, PM-direct 派单 WO-001AG (CC 排查 hfc 没生效根因), 装机 user 周末审改.

## 装机 user 拍板: 装机 user 后续提需求

按 8/25 拍板真值 "这些是文枢需要补的功能 hermes 没有, 不用调研, 我之后会提需求", PM-direct 不擅自调研 hermes 自带的 feishu-streaming-card (那是 hermes-agent skill, 跟 my-pm bot 无关).

PM-direct 等装机 user 周末拍板 A/B/C/D 之一.