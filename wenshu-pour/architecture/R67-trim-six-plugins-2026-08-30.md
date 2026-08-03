# WO-001BI-R67: 砍 6 plugin (google_meet/spotify/teams_pipeline/observability/wenshu-achievements 5 + kanban 保留)

[装机 user 8/30 拍板]
- 砍 6 个: google_meet / spotify / teams_pipeline / observability / wenshu-achievements
- 保留 13 个: context_engine / cron_providers / memory / model-providers / image_gen / video_gen / web / platforms / browser / dashboard_auth / disk-cleanup / security-guidance / kanban

[改动真值 (CC R67 + PM-direct 兜底)]
R67 CC 撞 max-turns 100 没 commit, PM-direct 兜底 commit 114 文件:

- plugins/ (48 文件):
  - 删 plugins/google_meet/ 全部 (17 文件)
  - 删 plugins/spotify/ 全部 (4 文件)
  - 删 plugins/teams_pipeline/ 全部 (8 文件)
  - 删 plugins/observability/langfuse/ (3 文件)
  - 删 plugins/observability/nemo_relay/ (3 文件)
  - 删 plugins/wenshu-achievements/ 全部 (8 文件 + LICENSE + README)
- wenshu_cli/ (10 文件):
  - tools_config.py / platforms.py / plugins.py / auth.py / console_engine.py 删 5 plugin 引用
- website/ (30 文件):
  - docs/ + zh-Hans/ 删 5 plugin 整页
- tests/ (12 文件):
  - 删 5 plugin 专用测试
- apps/ (6 文件):
  - desktop embeds/providers/ spotify.ts + spotify-embed.tsx 删除
- docs/ (2 文件): middleware/README.md + observability/README.md
- agent/ (2 文件): coding_context.py + conversation_loop.py
- toolsets.py: 1 文件
- skills/ 1 文件
- pyproject.toml: 1 文件

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权

[验证 (PM-direct 自查)]
- AC1 plugins/ 剩 13 个子目录 (context_engine/cron_providers/memory/model-providers/image_gen/video_gen/web/platforms/browser/dashboard_auth/disk-cleanup/security-guidance/kanban) ✓
- AC2 i18n zh.ts/en.ts/types.ts 不含 5 plugin key ✓
- AC3 tools_config.py/platforms.py/plugins.py/auth.py/console_engine.py 不引用 5 plugin ✓

[CC 撞 max-turns 100 退出]
R67 CC max-turns 100 没 commit + 没落档, PM-direct 兜底 commit 114 文件 + 落档本文档.
