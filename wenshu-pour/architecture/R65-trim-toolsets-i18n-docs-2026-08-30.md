# R65: 砍 5 个国外 toolset + R64 撞 max-turns 遗留 i18n + docs 清理

[装机 user 8/30 拍板真值]
- 第三方集成 (国外平台 5 个 #20-24) 国内都用不到, 一刀不留
- 砍: x_search / homeassistant / spotify / discord / discord_admin (5 个第三方集成 toolset)
- 保留 20 个: web / browser / terminal / file / code_execution / vision / video / image_gen / video_gen / tts / skills / todo / memory / context_engine / session_search / clarify / delegation / cronjob / yuanbao / computer_use

[5 项 AC 真值]
1. ✅ `wenshu_cli/tools_config.py:95-116` CONFIGURABLE_TOOLSETS = 20 行 (AST 校验通过)
   - 删 5 行: x_search (line 105) / homeassistant (line 115) / spotify (line 116) / discord (line 117) / discord_admin (line 118)
2. ✅ `apps/desktop/src/i18n/zh.ts:1520-1529` platformIntro 块 = 7 个国内 key (sms/dingtalk/feishu/wecom/wecom_callback/weixin/qqbot)
   - 删 12 个: telegram / discord / slack / mattermost / matrix / signal / whatsapp / bluebubbles / homeassistant / email / api_server / webhook
3. ✅ `apps/desktop/src/i18n/zh.ts:1626-1628` deliveryLabels 块 = 仅 `local: '此桌面'`
   - 删 4 个: telegram / discord / slack / email
4. ✅ `apps/desktop/src/i18n/en.ts:1458-1460` deliveryLabels 块 = 仅 `local: 'This desktop'`
   - 删 4 个: telegram / discord / slack / email
   - 注: en.ts `platformIntro` 原本就是 `{}` 空块, 0 命中
5. ✅ `apps/desktop/src/i18n/types.ts` = 0 命中 (R64 后已无 toolset name 绑 type)
6. ✅ docs/ AGENTS.md / README.md / CLAUDE.md / docs/setup/wenshu-installer-quickstart.md = 全 0 命中
7. ✅ commit 没跑 (CC 落档后 PM-direct 自决)
8. ✅ 落档完成 (本文件)

[3 文件改动 (3+/30-)]
- apps/desktop/src/i18n/zh.ts   -16 行 (12 platformIntro + 4 deliveryLabels)
- apps/desktop/src/i18n/en.ts   -4 行 (4 deliveryLabels)
- wenshu_cli/tools_config.py    -5 行 (5 CONFIGURABLE_TOOLSETS)

`git diff --shortstat`: 3 files changed, 3 insertions(+), 30 deletions(-)

[grep 真值 (跑中撞的坑)]

坑 1: types.ts 全 0 命中 (任务说"实际查下来可能 0 命中, 落档说明即可" - 验证正确)
- CC 跑过 types.ts 后确认: i18n type 不绑 toolset name, R64 后已清干净
- 不需要改 types.ts

坑 2: en.ts platformIntro 已经是 `{}` 空块
- R64 没填 en.ts platformIntro, 任务说"删"实际是 0 改
- CC 验证: `grep -nE "platformIntro" apps/desktop/src/i18n/en.ts` → 1 hit (line 1362, 空块)
- 保留 en.ts platformIntro: {} 行结构 (R64 拍板格式)

坑 3: docs/ 子目录其他文件仍有引用
- `docs/relay-connector-contract.md` / `docs/session-lifecycle.md` / `docs/profile-routing.md` 等有 discord/telegram/slack/whatsapp 引用
- 但这些是技术合约文档 (relay-connector-contract, session-lifecycle) 描述 adapter 接口和 session key 格式, 不是 R65 范围
- R65 任务明确只查 AGENTS.md / README.md / CLAUDE.md / docs/setup/wenshu-installer-quickstart.md → 4 个全 0 命中
- 不动其他 docs/ 文件 (避免越界)

坑 4: tools_config.py 其他位置仍含 5 toolset 引用 (非任务范围)
- `_DEFAULT_OFF_TOOLSETS` (line 148) 仍有 `spotify` / `x_search` / `video` / `video_gen`
- `_TOOLSET_PLATFORM_RESTRICTIONS` (line 186-187) 仍有 discord / discord_admin
- line 468-573 仍有 x_search / homeassistant / spotify 的 schema 块
- line 1436-1463 仍有 `wenshu auth spotify` flow
- 这些都是 toolsets.py 实际实现 + auth flow, R64 已删 13 个 toolset 实现, R65 任务明确"CONFIGURABLE_TOOLSETS 删 5 行" → 不动其他
- 完整清理 5 toolset 实现应另开 R66 子单, 不在 R65 范围

坑 5: zh-hant.ts / ja.ts 也有 platformIntro / deliveryLabels 块
- `apps/desktop/src/i18n/zh-hant.ts:1244 platformIntro: {}` (空) + line 1340-1346 deliveryLabels
- `apps/desktop/src/i18n/ja.ts:1289 platformIntro: {}` (空) + line 1386-1392 deliveryLabels
- R65 任务明确只列 zh.ts + en.ts → 不动 zh-hant.ts / ja.ts
- 实际 zh-hant.ts / ja.ts 跟 en.ts 一样, platformIntro 已空, 仅 deliveryLabels 残留 (R66 子单可清)

[白名单保留 (不删)]
- `apps/bootstrap-installer/src/routes/welcome.tsx` 致谢语
- `hermes-agent.nousresearch.com` URL
- 上游仓 fork / node_modules/ / MIT 版权
- 20 个保留 toolset 的代码 / i18n / types / docs
- `cron` tool (R65 拍板保留) 跟 `cron` messaging platform (R64 已删) 切割
- `homeassistant` toolset (R65 删) 跟 `homeassistant` messaging platform (R64 已删) 切割 — 各删一次

[派单姿势改进 (R65 = R38 校准后)]

R38 → R65 校准: 跑多文件 i18n 任务是否高效?

1. **范围收紧有效**: 任务列具体 4 文件 (zh.ts / en.ts / types.ts / 4 docs) + 预期 0 命中 → CC 不增不减
2. **grep 真值先于改**: R64 撞 max-turns 是因为 R64 一开始没限定 i18n 范围, CC 看到 287 key 全要译就乱跑
3. **空白确认有效**: 任务写"实际查下来可能 0 命中, 落档说明即可" → CC 跑完不焦虑, 落档即可
4. **单工单时间盒**: R65 4 文件改动 + 1 落档 = 1 步可验收, 没撞 max-turns

R65 工单时长: < 5 分钟 (跑通调研 + 3 文件 edit + 1 落档)

R66 待办 (PM-direct 自决开):
- 删 tools_config.py 5 toolset 实现 (line 148 _DEFAULT_OFF_TOOLSETS + line 186-187 _TOOLSET_PLATFORM_RESTRICTIONS + line 468-573 schema 块 + line 1436-1463 auth flow)
- 删 wenshu_cli/auth.py spotify provider (line 145 + 2555-3050)
- 删 wenshu_cli/console_engine.py spotify commands (line 763-773)
- 删 zh-hant.ts / ja.ts deliveryLabels 残留
- 删 docs/relay-connector-contract.md / docs/session-lifecycle.md / docs/profile-routing.md 14 platform 引用 (技术合约层)
- 删 apps/desktop/src/i18n/ 字段块残留 (MATTERMOST_URL, MATRIX_HOMESERVER, SIGNAL_ACCOUNT, WHATSAPP_*, BLUEBUBBLES_* 等)

[验收 grep 复读]
```bash
# CONFIGURABLE_TOOLSETS 行数 (期望 20)
awk 'NR>=95 && NR<=121' wenshu_cli/tools_config.py | grep -cE '^\s+\("'

# 4 文件 0 命中
grep -cE "x_search|homeassistant|spotify|discord|discord_admin|telegram|slack|whatsapp|signal|bluebubbles|mattermost|matrix|webhook|api_server" \
  apps/desktop/src/i18n/zh.ts \
  apps/desktop/src/i18n/en.ts \
  apps/desktop/src/i18n/types.ts \
  AGENTS.md README.md CLAUDE.md docs/setup/wenshu-installer-quickstart.md
# zh.ts: 残留 5 (MATTERMOST_URL/MATRIX_HOMESERVER/SIGNAL_ACCOUNT/wecom 4 fields 块 + wecom_intro) — 字段块不在 R65 范围
# en.ts: 残留 4 (同 zh.ts 字段块)
# types.ts: 0
# 4 docs: 全 0
```

[commit / push 状态]
- CC 改完没 commit (任务硬约束)
- 落档完成
- 通知 PM-direct 自决 commit + push
