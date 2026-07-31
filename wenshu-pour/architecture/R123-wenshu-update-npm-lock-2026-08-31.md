# WO-001BI-R123: 修 wenshu update 流程 npm install 失败 (lock file 旧)

[装机 user 8/31 反馈]
- "更新跑不完"
- 装包器 副文案 "wenshu update failed (exit Some(1))..."

[真根因]
- bootstrap-installer.log 末 5 行:
  - "npm error Invalid: lock file's assistant-stream@0.3.24 does not satisfy assistant-stream@0.3.31"
  - "npm error Missing: nanoid@6.0.0 from lock file"
  - "npm error No workspaces found: --workspace=legacy-terminal-ui --workspace=web"
- 仓根 package-lock.json 7/29 10:02 旧 lock file (R113 之后 8 commit 改 code 没 npm install)
- wenshu_cli/main.py _update_node_dependencies 硬编码 --workspace legacy-terminal-ui --workspace web
- 装包器 wenshu fork package.json 只声明 apps/* + tests-js - 没 legacy-terminal-ui / web workspaces

[修法 R123 - 2 层]
1. apps/desktop/package-lock.json 重生 (npm install 跑后 commit lock file)
2. wenshu_cli/main.py _run_npm_install_deterministic 删 --no-save (旧 --no-save 保留坏 lock file)
3. wenshu_cli/main.py _update_node_dependencies 移除硬编码 --workspace legacy-terminal-ui --workspace web

[验证]
- npm install 跑通 ✅
- npm ci 跑通 ✅
- 仓根 package-lock.json 重生 (assistant-stream 0.3.31 + nanoid 6.0.0 加进)

[装机 user 必走 4 步]
1. 装 pnpm: brew install pnpm (PATH 没 pnpm)
2. 跑新 DMG 装包器 (PM-direct 重 build 拷 ~/Downloads)
3. 装包器 stale check + 自动调 wenshu update - 跑通
4. 验 4 件 + 反馈

[版本号]
0.1.0 (装 user 拍 "基础版本不 bump")
