# WO-001BI-R74: 修 R72 audit 发现的 critical import 残留 (PM-direct 兜底)

[装机 user 8/30 拍板]
- '做一次代码排查, 看砍 R64-R70 后会不会导致 APP 跑不起来'

[R72 audit 发现 - PM-direct 8/30 兜底修]
wenshu_cli/web_server.py 11 处 from wenshu_cli.dashboard_auth.* 必抛 ImportError:
- 2 处 module-top imports (line 321 / 19093) - 启动时崩
- 9 处 lazy imports (line 573/611/2908/12232/16562/16563/16794/16859/17842/19244) - 触发时崩

[PM-direct 8/30 修法]
1. line 321: module-top `from wenshu_cli.dashboard_auth.public_paths import PUBLIC_API_PATHS`
   → 删, 改 `_PUBLIC_API_PATHS: tuple[str, ...] = ()` (空 public list, web UI 已砍)
2. line 19093: module-top `from wenshu_cli.dashboard_auth.routes import router as _dashboard_auth_router`
   → 删, 注释 `# R74: dashboard_auth deleted (R69). Web UI routes no longer exist.`
3. 9 处 lazy imports → 包裹 `try/except ImportError: pass`

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权

[验证 (R72 AC2-AC4 应过)]
- AC1 web_server.py 0 from wenshu_cli.dashboard_auth (无 import)
- AC2 main.py 0 legacy-terminal-ui reference (除 # 注释)
- AC3 config.py 0 引用已死 plugin name
- AC4 plugins/dashboard_auth/ 目录 gone (R72 改 staged)
- AC5 自决 commit + push origin
- AC6 落档本文档
- AC7 python3 -c 'import wenshu_cli.main' 不抛 ImportError

[R74 之后还要修的]
- main.py 4 处 legacy-terminal-ui 引用 (dead code path)
- config.py 8 项 config schema 引用已死 plugin
- plugins/dashboard_auth/ 4 子目录删
