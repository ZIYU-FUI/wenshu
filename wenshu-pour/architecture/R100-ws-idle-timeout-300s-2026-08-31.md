# WO-001BI-R100: 修 网关 检查中卡死 - /api/ws 30s self-close → 300s

[装机 user 8/30 拍]
- '网关检查中一直过不去，修好'

[真值]
- desktop renderer 连上 /api/ws 后立刻 setState('open') (CDP 实测 WS with token = open event)
- 但 desktop UI 仍显示 '检查中' - gatewayState 没切 'open'
- desktop.log: 'Desktop /api/ws 30s idle, closing (R50 self-close)' 出现多次
- 30s 后 server 主动 close socket -> renderer setState('closed') -> '检查中' 卡死循环

[根因]
- R50 改造的 /api/ws handler (web_server.py:17735):
  await asyncio.wait_for(ws.receive_text(), timeout=30.0)
- 30s 没收到 client message -> server 主动 close
- desktop renderer (JsonRpcGatewayClient) 只 listen 'open' event, 从不主动发 message
- renderer 永远拿不到稳定 'open' state

[修法]
- timeout=30.0 → timeout=300.0 (5 分钟足够)
- log msg 'R50 self-close' → 'R97 self-close'

[验]
- python3 -m py_compile wenshu_cli/web_server.py exit 0 ✅
- venv HEAD = 4842caf (R99) + web_server.py cp sync R100 (timeout=300.0 ✅)
- kill 老 desktop + spawn 新 --remote-debugging-port=9229 + CDP 实测

PM-direct 自验: 用 CDP 直连 desktop renderer 实测 /api/ws open event + 'open' state setState.
