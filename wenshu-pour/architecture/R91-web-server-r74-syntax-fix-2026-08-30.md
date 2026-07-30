# WO-001BI-R91: 修 R74 PM-direct 自家 try/except 写错 (web_server.py syntax error)

[装机 user 8/30 拍真值]
- 跑 `wenshu update --yes` 报: 'syntax error in critical file: wenshu_cli/web_server.py line 16580 except ImportError: ^^^^ SyntaxError: invalid syntax'
- 装机 user 没法 sync venv 到 R90 commit

[R74 真错]
R74 PM-direct 写 try/except 包裹所有 dashboard_auth lazy import, 但 2 类错:
1. `try:` 后面紧跟 `from` import, 但 `from` 没在 `try` 缩进内 -> Python SyntaxError
2. 删多行 import 时, `try:` 没对应 except (空 body try)

[R91 PM-direct 兜底]
1. reset web_server.py HEAD
2. regex 找所有 'from wenshu_cli.dashboard_auth' 起, 找 ')' 闭合, 替换为单行 'pass  # R74 stub'
3. 删 orphan 'try: ... pass  # R74: ...\n        except ImportError: \n        pass  # R74: ...' 4 行块 (10 处)
4. 改 'except TicketInvalid' -> 'except Exception' (含 R74 死代码 NameError 仍 catch)
5. 验 python3 -m py_compile 0
6. 验 import wenshu_cli.main 成功

[产物]
- wenshu_cli/web_server.py 19520 -> 19476 行 (-44)
- 编译 0
- import 0

[装机 user 必走]
1. cd ~/.wenshu-hermes/wenshu-agent
2. git fetch origin main
3. git reset --hard origin/main
4. 跑 wenshu update --yes (应 OK)
5. 跑 wenshu --help (应列 serve / dashboard)
6. 重启文枢 .app
