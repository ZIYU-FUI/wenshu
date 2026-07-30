# WO-001BI-R70: 中文覆盖度 audit + 默认中文真值

[装机 user 8/30 拍板]
- (1) 排查中文语言包是否覆盖所有 UI 文案
- (2) 安装开始默认中文, 不需设置切换

[真值 (PM-direct 自查 + R70 audit)]

### Part A: 中文覆盖度

| i18n 文件 | en.ts keys | zh.ts keys | 差 |
|---|---|---|---|
| apps/desktop/src/i18n/zh.ts vs en.ts | 2125 | 2161 | +36 (国内平台 dead key 反向加) |
| apps/bootstrap-installer/src/i18n | 22 行 en | 25 行 zh | 完整 |
| wenshu_cli/ | **无 i18n 系统** | 3352 个英文 print 语句 | ❌ |

**31 个 zh.ts 缺的 en.ts key**:
- 全部是 R64 砍的国外平台 (Discord/BlueBubbles/Matrix/Mattermost/WhatsApp) fieldCopy 残留
- 全部是 R47c 砍的 dead tool titles (browser_snapshot / session_search_recall / Fireworks/OpenRouter)
- 处理: **删不译** (R71+ 范围)

**21 个 zh==en** (zh.ts 等于 en.ts 没真译):
- 全部是产品名 (URL / YOLO / Pro / MCP / 文枢 Cloud 等)
- 不需要译

**CLI 严重缺译 (3352 英文 print)**:
- main.py: 572
- setup.py: 331
- gateway.py: 320
- cli_commands_mixin.py: 239
- model_setup_flows.py: 201
- kanban.py: 154
- skills_hub.py: 129
- tools_config.py: 125
- cli_billing_mixin.py: 109
- ...
- CLI 端没 i18n 系统, 装机 user 跑 `wenshu setup` 等命令看到全英文

### Part B: 默认中文

| 入口 | 当前状态 |
|---|---|
| apps/desktop/src/i18n/languages.ts DEFAULT_LOCALE | ✅ 'zh' |
| apps/bootstrap-installer/src/i18n/languages.ts DEFAULT_LANGUAGE | ✅ 'zh' |
| scripts/install.sh 写 `display.language` | ❌ 未写 |
| scripts/install.ps1 写 `display.language` | ❌ 未写 |

**结论**: 桌面 APP 端默认中文已对. 装机脚本没强制写 display.language=zh, 装机 user 装后可能落 en fallback.

[装机 user 必看]
1. desktop APP UI 已全中文 ✓
2. 装包器 UI 已全中文 ✓
3. CLI 端 3352 英文 print 是大坑, 需派 R71 专项翻译 (或留英文 / 给关键 user-facing strings 加 zh)
4. install.sh 加 `display.language: zh` (R71 派单修)

[不修范围]
- zh-hant.ts 不删 (装机 user 暂不删, 但不要切换到繁体)
- desktop i18n 31 缺 key 全是 R64 砍的 dead key, 建议 R71 删
- 21 zh==en 全是产品名, 不需要译

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
