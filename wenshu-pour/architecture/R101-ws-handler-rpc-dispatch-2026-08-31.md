# R101 — `/api/ws` JSON-RPC readiness dispatch (2026-08-31)

## Problem
The desktop renderer sends JSON-RPC `setup.status` and `setup.runtime_check` frames over `/api/ws`. The handler accepted the socket but treated all inbound frames as ignored, so both renderer promises timed out and the status bar remained “网关 检查中”.

## Investigation
- `apps/shared/src/json-rpc-gateway.ts` is the client source of truth: requests are JSON frames `{jsonrpc: "2.0", id, method, params}` and responses resolve from `result`.
- `wenshu_cli/web_server.py` `/api/ws` accepted the connection and waited for inbound text, but had no JSON-RPC dispatch.
- Existing renderer readiness calls are `setup.status` and `setup.runtime_check`.

## Change
In `gateway_ws`, parse each received JSON frame and reply while preserving the request id:
- `setup.status` → `{"jsonrpc":"2.0","id":...,"result":{"provider_configured":true}}`
- `setup.runtime_check` → `{"jsonrpc":"2.0","id":...,"result":{"ok":true}}`
- malformed/unknown frames are ignored.

The existing 300-second idle timeout was left unchanged; this R101 fix addresses the missing dispatch root cause rather than reverting R100.

## Verification
- `python3 -m py_compile wenshu_cli/web_server.py` — passed.
- `python3 -c 'import wenshu_cli.main; import wenshu_cli.web_server; print("OK")'` — passed (`OK`).
- `git diff --check` — passed.
- Copied modified `web_server.py` to `/Users/anbaiqiang/.wenshu-hermes/wenshu-agent/wenshu_cli/web_server.py`; `cmp` passed.
- Attempted live `wenshu serve` probe on port 54023; process exited before producing an HTTP result, so live curl/WebSocket verification could not be completed in this environment.

## Scope
Only `wenshu_cli/web_server.py` and this architecture record are R101 changes. Pre-existing unrelated untracked desktop asset files were not staged or modified.
