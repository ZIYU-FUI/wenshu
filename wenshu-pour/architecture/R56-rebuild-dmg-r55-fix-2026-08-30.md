# R56: 重 build WenShu-Setup.dmg 装包器 (含 R55 install.sh 修复)

[装机 user 8/30 实拍]
- R54 DMG 装包器装后报错 "退出码 1"
- bootstrap-installer.log 真根因: R53 install.sh line 50-57 加 UV_CACHE_DIR_DEFAULT=$WENSHU_HOME/cache/uv 时, WENSHU_HOME 还没设 → expand 出 /cache/uv (root 写不动)
- error: Failed to initialize cache at `/cache/uv`: Read-only file system

[装机 user 拍板 8/30]
"新的安装包不走镜像吗? 在没有外网的环境安装不流畅"

[R55 修复]
- scripts/install.sh: 把 UV_CACHE_DIR 块移到 WENSHU_HOME 设后 (line 64-66)
- bash -n 验过, 默认路径为 $HOME/.wenshu-hermes/cache/uv
- commit 6e9cbfb92 push origin main

[R56 重 build]
- pnpm tauri build (1m 00s) → release/bundle/dmg/文枢_0.1.0_aarch64.dmg
- /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
- 含 R53 + R55 install.sh 修复 + R52 version 0.1.0 + R30 install.sh 改名 + R35 清华源 + R25 中文致谢 + R23 LOGO 文枢毛笔字

[装机 user 必走 4 步]
1. 双击 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
2. 拖 文枢.app 到 /Applications/
3. 双击 文枢.app 启动
4. bootstrap 跑 10 步骤中文 → 装 ~/.wenshu-hermes (~800MB 浅克隆 R53)

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork
- node_modules/
- MIT 版权
