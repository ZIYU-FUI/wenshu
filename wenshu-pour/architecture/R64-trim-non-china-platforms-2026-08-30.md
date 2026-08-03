# R64: 砍非国内平台 (用户范围缩到国内中文用户)

[装机 user 8/30 拍板真值]
- 保留: cli / feishu / dingtalk / wecom / wecom_callback / weixin / qqbot / yuanbao (8 个)
- 砍: telegram / discord / slack / whatsapp / whatsapp_cloud / signal / bluebubbles / email / homeassistant / mattermost / matrix / webhook / api_server / cron (14 个)
- 用户范围: 国内中文用户

[改动 (7 文件, 54+/334-)]
- wenshu_cli/platforms.py -15 行 (PLATFORMS 22→8)
- toolsets.py -121 行 (删 13 wenshu-* toolset)
- wenshu_cli/gateway.py -121 行 (删 mattermost/signal/bluebubbles blocks)
- wenshu_cli/tools_config.py -21 行 (删 homeassistant/discord/_DEFAULT_OFF_TOOLSETS)
- tools/delegate_tool.py -2 行
- tools/discord_tool.py -2 行
- cli-config.yaml.example -106 行

[保留 8 国内平台]
1. cli (基础)
2. dingtalk (钉钉)
3. feishu (飞书)
4. wecom (企业微信)
5. wecom_callback (企业微信回调)
6. weixin (微信)
7. qqbot (QQ)
8. yuanbao (元宝)

[未完成]
- i18n zh.ts/en.ts/types.ts 删 14 平台 key (CC 撞 max-turns 100 退出)
- docs/ AGENTS.md README.md 删 14 平台引用 (CC 未跑)
- 后续 R65 子单: i18n + docs 清理 (如果装机 user 要)

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork
- node_modules/
- MIT 版权

[AGENTS.md §15 CC 调研约束已落档]
- CC 调研前必看官方 docs, 不准反推拍板, 时间盒 ≤ 1h
