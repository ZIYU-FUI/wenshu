# WO-001BI-R129: ELECTRON_MIRROR 注入 + resolveCacheMode 真相

[装机 user 8/3 反馈]
- 装 user 8/3 跑 wenshu update 报 "Cannot read properties of undefined (reading 'ReadWrite')"
- 在 electron-builder 26.15.3 的 app-builder-lib/out/util/electronGet.js:131 resolveCacheMode()

[真根因 - PM-direct 排查]
- app-builder-lib@26.15.3 期望 `@electron/get` 导出 ElectronDownloadCacheMode enum
- 但 @electron/get@3.0.0 (或 v2.0.0) 都**不导出**这个 enum (只有 Cache class)
- electronGet.js:60-72:
  ```js
  function resolveCacheMode() {
    const cacheOverride = process.env["ELECTRON_DOWNLOAD_CACHE_MODE"]?.trim();
    if (cacheOverride && Number(cacheOverride) in get_1.ElectronDownloadCacheMode) {
      return Number(cacheOverride);
    }
    return get_1.ElectronDownloadCacheMode.ReadWrite;  // <-- undefined.ReadWrite
  }
  ```
- @electron/get 是 app-builder-lib@26.15.3 的 deps, version=^3.0.0
- 装 user venv 仓 @electron/get@3.0.0 真不导出 enum → 报错

[PM-direct 手动验]
1. pnpm install 装包 (成功)
2. ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ + @electron/get downloadArtifact(electron 40.10.2 darwin-arm64)
   - 成功下载到 ~/Library/Caches/electron/<hash>/electron-v40.10.2-darwin-arm64.zip
3. 手动 ditto -xk 解压到 apps/desktop/node_modules/electron/dist/Electron.app
4. 重跑 pnpm dist:mac → .app build 成功 (136MB), DMG build 时**dmg-builder 又调** downloadBuilderToolset 拉 dmgbuild → 同样踩 undefined.ReadWrite

[网络问题]
- ELECTRON_MIRROR (npmmirror) → github 直连 timeout (装 user 网络被屏蔽 github)
- dmgbuild tarball 在 https://github.com/electron-userland/electron-builder-binaries/releases/download/dmg-builder@1.2.5/dmgbuild-bundle-arm64-75c8a6c.tar.gz
- 装 user 跑 wenshu update 6min 内 timeout

[修法 - 待装 user 拍板]
A. PM-direct 自家跑 build (PM-direct 网络可能也一样不通)
B. 装 user 网络开 GitHub 代理 (proxychains 或 git:// → https://)
C. 让 PM-direct 跑 build 在仓根 /Volumes/ANAN/Engineering/wenshu + 拷 DMG 到 ~/Downloads

[R129 PM-direct commit]
- wenshu_cli/subcommands/update.py 加 ELECTRON_MIRROR 注入 (解决 pnpm dist:mac 早期阶段 ELECTRON 下载)
- 不修 resolveCacheMode (electron-builder 26.15.3 内部 bug, 需要装 user 网络或 build 在 PM-direct 端)

[验证]
- python3 -m py_compile wenshu_cli/subcommands/update.py exit 0
- diff stat: 1 file, +10 行

[装 user 必走]
- wenshu update 流程:
  1. PM-direct 跑 build + 拷 DMG (网络通)
  2. 装 user 用 DMG 装回新 .app
  3. 验 sidebar 顶部 SegmentedControl + dock LOGO 加背景色 + 不再 timeout

[版本号]
0.1.0 (装 user 拍 "基础版本不 bump")
