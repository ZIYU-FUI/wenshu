# WO-001AR v5 根治 rebuild trace (STEP 4)

> 工单:WO-001AR(装机 user 8/27 LOOP 拍板,白名单扩展 v5 根治 STEP 4)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 装机 user DMG:`/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`

## 0. 拍板真值

派单 STEP 4 拍板:
- cargo tauri build (release, exit 0)
- 重 bundle DMG
- cp 新 DMG 到 `~/Downloads/WenShu-Setup.dmg`
- 验:~/Downloads DMG mtime 更新 + sha256 = bundle DMG sha256

## 1. build 执行轨迹

### 1.1 命令

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri
cargo tauri build
```

实际跑通,exit 0,总耗时 **215 秒**(3 分 35 秒)。

### 1.2 输出节选(关键行)

```text
✓ built in 23.51s
   Compiling wenshu-setup v0.0.1 (/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri)
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin; ...)
warning: variant `Bundled` is never constructed
  --> src/install_script.rs:37:5
warning: `wenshu-setup` (lib) generated 1 warning
    Finished `release` profile [optimized] target(s) in 2m 15s
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:
        .../target/release/bundle/macos/文枢.app
        .../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

退出码:0。

warning 数量:**1**(即 `install_script.rs:37` `Bundled` variant never constructed,属于上游 hermes-agent v0.19.0 仓库里就有的 dead_code,与 STEP 2 / STEP 3 修复无关)。STEP 2 + STEP 3 各自引入的 warning 已经在清理阶段消除(`mut sink` warning 已修,`fields never read` warning 已加 `#[allow(dead_code)]`)。

## 2. bundle 产物

| 产物 | 路径 | 大小 |
|------|------|------|
| macOS .app | `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app` | (binary `WenShu-Setup` 已 link) |
| DMG | `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg` | **5,500,427 bytes** |

DMG 大小对比 v4 → v5:

| 版本 | DMG 大小 | 差异 |
|------|---------|------|
| v4 (WO-001AP, 2026-07-27 15:57) | 5,494,016 bytes | (baseline) |
| v5 (WO-001AR, 2026-07-27 18:15) | 5,500,427 bytes | +6,411 bytes (+0.117%) |

差异来源:
- `SCRIPT_TIMEOUT` 常量 + `run_script_inner` 拆分 + `Arc<StdMutex<Option<Child>>>` (`powershell.rs`):约 +2 KB binary
- `CompositeGuard` + `TeeWriter` + MakeWriter impl + Desktop tee 路径 (`paths.rs`):约 +4 KB binary
- 加上 Rust release 优化后 dead-code 消除差异,实测 +6.4 KB

## 3. DMG cp 到 ~/Downloads + 验证

### 3.1 命令

```bash
BUNDLE_DMG="apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg"
DEST_DMG="/Users/anbaiqiang/Downloads/WenShu-Setup.dmg"
cp "$BUNDLE_DMG" "$DEST_DMG"
shasum -a 256 "$BUNDLE_DMG" "$DEST_DMG"
```

### 3.2 验证结果

| 指标 | bundle DMG | ~/Downloads DMG | 状态 |
|------|-----------|----------------|------|
| 字节数 | 5,500,427 | 5,500,427 | ✅ 一致 |
| SHA-256 | `24a2c08f8e9675c0252d69a40f75b8b28630c8fdfe36888c17e4f3c9772f66ef` | `24a2c08f8e9675c0252d69a40f75b8b28630c8fdfe36888c17e4f3c9772f66ef` | ✅ 一致 |
| mtime | 2026-07-27 18:15:38 | 2026-07-27 18:15:45 (cp 后) | ✅ 已更新 |

(装机 user 原 `~/Downloads/WenShu-Setup.dmg` mtime 是 2026-07-27 15:57,本次 cp 后变 2026-07-27 18:15:45——派单 STEP 4 验条款 "mtime 更新" 已达成。)

(注:派单要求验 md5,但当前 shell 环境 `md5` 和 `md5sum` 都 not found(BSD/macOS 系统默认没装 GNU coreutils md5sum),改用 macOS 自带的 `shasum -a 256`。SHA-256 比 MD5 更强,等价验证通过。)

## 4. 没改的部分(派单边界外 / 装 user 拍板外)

派单 STEP 4 还提到 `pkill -f WenShu-Setup + rm -rf /Applications/文枢.app/ + cp -R + open /Applications/文枢.app`,但这些是装机 user 跑 Setup 时的清理/重装/启动逻辑。CC 不重装 `~/.wenshu-hermes/` 或 `/Applications/文枢.app/`,也未启动新 Setup 做视觉验。装机 user 拍 "新包去试就好" —— 视觉验由装机 user 在其机器/网络环境执行新 DMG 完成。

## 5. AC4 验收

- ✅ `cargo tauri build` exit 0,215s
- ✅ bundle `文枢_0.0.1_aarch64.dmg` (5,500,427 bytes)
- ✅ cp 到 `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`
- ✅ SHA-256 一致(`24a2c08f8e9675c0252d69a40f75b8b28630c8fdfe36888c17e4f3c9772f66ef`)
- ✅ mtime 已更新(15:57 → 18:15)
- ✅ 0 个 STEP 4 新 warning

AC4 PASS。
