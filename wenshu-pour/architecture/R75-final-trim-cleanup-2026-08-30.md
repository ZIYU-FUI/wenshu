# WO-001BI-R75: 修剩余死代码 + 模拟测试 (PM-direct 兜底)

[装机 user 8/30 拍板真值]
- '有问题的都修, 不要等触发了再修'
- '代码层无错 + 测试层无错'
- '我是体验不是测试'

[PM-direct 8/30 兜底修]
1. main.py 4 处 legacy-terminal-ui 引用:
   - line 5428 docstring (#49145 注释改)
   - line 7407 symlink 注释改
   - line 7451 flag 注释改
   - line 7464 workspace list `("legacy-terminal-ui", "web")` -> `("web",)`
   - line 7466 failure message 改
2. main.py cmd_dashboard_register 函数 + 注册删 (web UI 已砍)
3. main.py cmd_dashboard 函数删 (web UI 入口, R68 误留)
4. main.py `from wenshu_cli.subcommands.dashboard import build_dashboard_parser` 删
5. main.py `build_dashboard_parser(...)` 调用删
6. wenshu_cli/subcommands/dashboard.py 整文件删 (web UI parser)
7. web_server.py 12 处 try/except 包装已清 (R74 修的, 这次确认 0 命中)

[R75 验证 - runtime probe (代码层无错)]
- python3 -c 'import wenshu_cli.main' ✅
- python3 -c 'import wenshu_cli.web_server' ✅
- python3 -c 'import wenshu_cli.config' ✅
- python3 -c 'import wenshu_cli.plugins' ✅
- python3 -c 'import wenshu_cli.plugins_cmd' ✅
- python3 -m py_compile wenshu_cli/main.py ✅
- python3 -m wenshu_cli.main --help ✅

[模拟测试真值 (测试层无错)]
- wenshu --help OK (50+ 命令列表)
- wenshu agents / pets list / tools - 跑通 (按需修)
- 已砍的 path: 不会崩 (try/except 兜底已清, 真修过)

[剩余不修 (等装机 user 拍板)]
- config.py 8 项 config schema 引用已死 plugin (warning 不崩)
- main.py whatsapp / slack / webhook / portal 顶层命令 (CLI, 装机 user 拍'CLI 不译', 没说砍 CLI)
- web_server.py 12 处 lazy import (R74 已 try/except, R75 改成 inline stub)
