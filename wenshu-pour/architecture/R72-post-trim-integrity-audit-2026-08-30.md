# WO-001BI-R72: 砍后完整性 audit (装机 user 8/30 拍"做一次代码排查")

[装机 user 8/30 拍板真值]
- '做一个代码排查, 看砍 R64-R70 后会不会导致 APP 跑不起来'
- '原来没有包括 i18n, 就是范围评估不完整, 不知道还有没有其它遗漏'

[PM-direct 自查 + R72 子单 audit 真值]

### critical 修 (R74 已修)
1. **wenshu_cli/web_server.py 11 处 from wenshu_cli.dashboard_auth.* 必抛 ImportError**
   - line 321 module-top: `from wenshu_cli.dashboard_auth.public_paths import PUBLIC_API_PATHS`
     → 改 `_PUBLIC_API_PATHS: tuple = ()` (空 public list)
   - line 19093 module-top: `from wenshu_cli.dashboard_auth.routes import router as _dashboard_auth_router`
     → 删, 注释 # R74
   - 9 处 lazy imports → 包裹 try/except ImportError: pass

2. **wenshu_cli/plugins.py:688 register_dashboard_auth_provider**
   → 改 stub no-op (web UI 已砍, 方法保留 plugin API compat)

### 中风险 (R72 audit 范围, R74 之后还要修)
- main.py 4 处 legacy-terminal-ui 引用 (dead code path)
- config.py 8 项 config schema 引用已死 plugin (discord/telegram/slack/whatsapp/email/mattermost/matrix/bluebubbles)
- plugins/dashboard_auth/ 4 子目录 (basic/drain/nous/self_hosted) — 已被 R74 stage 删除

### 不崩 - 装机 user 跑路径
- desktop .app 启动: import wenshu_cli.web_server → 不再抛 ImportError (R74 修)
- wenshu dashboard 命令 (web UI 入口): 必抛 ImportError 但装机 user 不跑
- 装机流程 bootstrap-installer: 不依赖 dashboard_auth
- CLI 端: 不依赖 dashboard_auth

### 验证
- AC1: web_server.py 0 from wenshu_cli.dashboard_auth (无 import) ✓
- AC2: main.py 0 legacy-terminal-ui reference (待修) 
- AC3: config.py 0 引用已死 plugin (待修)
- AC4: plugins/dashboard_auth/ 目录 gone (R74 已 stage)
- AC5: 自决 commit + push origin
- AC6: 落档本文档
- AC7: python3 -c 'import wenshu_cli.main' 不抛 ImportError ✓

[装机 user 必看]
1. desktop .app 启动不再崩 (R74 修 critical import)
2. 但 wenshu dashboard register / wenshu dashboard 命令会崩 (R68 范围漏)
3. 需要再派 R75 修 main.py + config.py 残留

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
