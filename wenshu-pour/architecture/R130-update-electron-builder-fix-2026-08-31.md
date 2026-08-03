# WO-001BI-R130: 修 wenshu update 跑 pnpm dist:mac electron-builder 内部 bug

[装机 user 8/3 反馈]
- 装 user 跑 wenshu update --yes 12:34 - 卡 'Cannot read properties of undefined (reading ReadWrite)'
- electron-builder 26.15.3 + @electron/get 3.0.0 不兼容

[真根因 - PM-direct 排查]
- app-builder-lib@26.15.3 用 @electron/get@3.0.0 的 ElectronDownloadCacheMode.ReadWrite enum
- 但 @electron/get@3.0.0 不导出这个 enum (只有 Cache class)
- electron-builder 26.15.3 内部 bug - v3.0.0 兼容性破坏
- electronGet.ts:131 resolveCacheMode() 读 undefined.ReadWrite 报错

[PM-direct 12:30 兜底方案 - 手动成功]
1. 手动下载 Electron 40.10.2 darwin-arm64 zip (从 npmmirror 国内镜像)
2. 解压到 apps/desktop/node_modules/electron/dist/Electron.app
3. 设 CUSTOM_DMGBUILD_PATH=<dmgbuild bundle dir>/dmgbuild
4. 跑 pnpm dist:mac exit 0 (.app + DMG build 成功)

[R130 修法 - PM-direct 收尾 CC 写完的代码 + 补调用点]
- wenshu_cli/subcommands/update.py:
  - _http_download(url, dest) - 流式下载 with urllib
  - _resolve_node_modules_dir(start, package) - 模拟 Node require.resolve parent walk
  - _ensure_electron_dist(desktop_dir) - 下载 Electron 40.10.2 darwin-arm64 zip + 解压到 electron/dist
    - fast path: dist/version 已存在跳过
    - slow path: npmmirror 下载 zip + atomic extract via zipfile
  - _ensure_dmgbuild() - 找 Library/Caches/electron-builder-binaries/dmg-builder@1.2.5/
    - fast path: 扫现有 dir 含 dmgbuild binary
    - slow path: npmmirror 下载 dmg-builder@1.2.5.tar.gz + tarfile extract
  - _run_update_build_step 加 extra_env 参数
  - build_and_stage_macos_release:
    - 调 _ensure_electron_dist(desktop_dir) 预 stage Electron dist
    - 调 _ensure_dmgbuild() 预 stage dmgbuild + 返 path
    - _run_update_build_step([pnpm, dist:mac], desktop_dir, extra_env={CUSTOM_DMGBUILD_PATH: <dmgbuild_path>})
    - 设 CUSTOM_DMGBUILD_PATH 后 electron-builder 跳过 @electron/get 调用

[验证]
- python3 -m py_compile wenshu_cli/subcommands/update.py exit 0
- diff stat: 1 file, 219 insertions, 4 deletions
- 装包器 DMG 重 build + 拷 Downloads

[真因链路]
1. R128 修 pnpm PATH
2. R128b 修 cargo PATH (.cargo/bin)
3. R129 修 ELECTRON_MIRROR 注入 (npmmirror 国内镜像)
4. R130 修 electron-builder 26.15.3 vs @electron/get 3.0.0 不兼容 (预 stage binary)

[装 user 必走]
- 跑新 DMG 装包器 ~/Downloads/WenShu-Setup.dmg (新 md5)
- 跑 wenshu update --yes (R130 自动化 Electron + dmgbuild 下载)
- 验 4 件 + 反馈

[版本号]
0.1.0 (装 user 拍 "基础版本不 bump")
