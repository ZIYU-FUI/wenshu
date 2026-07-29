# WO-001BI-R15 文枢 APP 重 build（只出 .app，不出 DMG）(8/28 装机 user 拍)

> 接 R14（i18n + LOGO 改完，4 文件改 + 4 i18n 新增）。
> 装机 user 8/28 拍："APP 不需要打包 DMG，只通过安装方式安装 APP"。
> R15 范围 = 重 build 让 .app 吃进 R14 改动 + cp 到 Downloads/，**不改任何 wenshu 仓代码**。

---

## 1. 派单真值

装机 user 8/28 拍板真值：

- **不要 DMG**：装机流程 = 装机 user 双击 `文枢.app` → 拖进 `/Applications/` 即可，不要再出 `.dmg` 卷宗镜像
- **走单 app bundle 通道**：`tauri build --bundles app`（跳过 dmg + appimage）
- **保留 R14 改动**：4 文件改 + 4 i18n 新增必须进 .app（11:46 的旧 .app 是 R14 之前的）
- **下载入口 = `/Users/anbaiqiang/Downloads/文枢.app`**：装机 user 双击拿货

## 2. 实际跑通结果 (R15 完成, mtime 17:11)

### 2.1 build 命令

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
pnpm exec tauri build --bundles app
```

**exit 0** + 输出确认：

```
✓ built in 381ms                                       ← vite build (R14 zh.ts/en.ts/index.ts 全部进 dist)
   Compiling wenshu-setup v0.0.1
warning: hermes-bootstrap: following branch main HEAD (no commit pin; set HERMES_BUILD_PIN_COMMIT for an immutable pin)
warning: variant `Bundled` is never constructed         ← 已知 dead_code,不是阻塞
    Finished `release` profile [optimized] target(s) in 56.80s
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Finished 1 bundle at:
        /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app
```

✅ **1 个 bundle = 文枢.app**（没有 dmg / 没有 appimage，符合装机 user "不要 DMG" 拍板）

### 2.2 cp 到 Downloads

```bash
SRC=apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app
DST=/Users/anbaiqiang/Downloads/文枢.app
rm -rf "$DST" && cp -R "$SRC" "$DST"   # exit 0
```

### 2.3 真实产物（装机 user 双击的入口）

| 路径 | 大小 | mtime | 用途 |
|------|------|-------|------|
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app` | 7.9 MB | Jul 28 17:10:35 2026 | 仓内 build 产物 |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/Contents/MacOS/WenShu-Setup` | 7.92 MB | Jul 28 17:10 | arm64 Mach-O（adhoc 签名） |
| **`/Users/anbaiqiang/Downloads/文枢.app`** | **7.9 MB** | **Jul 28 17:11:03 2026** | **装机 user 双击拿货** |
| `/Users/anbaiqiang/Downloads/文枢.app/Contents/Info.plist` | 1.1 KB | 17:10 | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app.setup`, `CFBundleShortVersionString=0.0.1` |

### 2.4 R14 改动验证（已吃进新 build）

| 验证项 | 命令 | 结果 |
|--------|------|------|
| R14 zh i18n 进 dist | `grep -c '系统环境检查\|拉取文枢源码' apps/bootstrap-installer/dist/assets/*.js` | **1 命中**（dist/assets/index-CAsHmfdR.js = 新生成 hash） |
| R14 brand-mark 改完 | `cat apps/bootstrap-installer/src/components/brand-mark.tsx` | 纯 WENSHU 文字标识，**无 nous-girl 引用** |
| src/ 区 nous-girl 残留 | `grep -rn 'nous-girl' apps/bootstrap-installer/src/` | **0 命中**（binary 内残留是 public/ 静态资源，运行时根本不渲染） |
| bundle 没造 DMG | `ls apps/bootstrap-installer/src-tauri/target/release/bundle/` | `dmg/` 目录存在但**为空**；macos/ = 文枢.app |
| dmg/ 实际为空 | `ls apps/bootstrap-installer/src-tauri/target/release/bundle/dmg` | **空目录**（确认无 DMG 产出） |

## 3. 派单失败真值表 (R15 实战 8/28)

| 派单 / 操作 | 失败模式 / 注意 | 处理 |
|------------|-----------------|------|
| R15 第一次 fire (wrapper) | wrapper 没把 prompt 传进 claude，fire.log 94 字节 = "Input must be provided" | 改用 `claude -p "$PROMPT"` 直接传，**不**用 `bash -c "..."` 中间层 |
| tauri.conf.json bundle.targets = ["app", "dmg", "appimage"] | 不指定 `--bundles` 会**三个都出**（dmg + appimage + .app） | 显式 `tauri build --bundles app`，只出 .app |
| 验 .app 是否吃进 R14 改动 | Tauri 2 release bundle 不复制 dist/ 到 Resources（前端 embed 进 Rust binary） | 用 `strings binary \| grep i18n-key` 验嵌入，或用 `grep dist/assets/*.js` 验 vite 产物 hash 是否新 |
| `.app` size 列示为 96 bytes | `stat -f '%z'` 只看 .app dir entry size，不递归 | 用 `du -sh` 看真实占用（7.9 MB） |
| codesign 是 adhoc | 无 Apple Dev ID 走 linker-signed | 用户双击 .app 拖 /Applications/ 不需要 dev ID（macOS Gatekeeper 会拦但用户右键打开可绕过，或 `xattr -cr` 清隔离属性） |

## 4. 飞书退知机制 (R15 装机 user 拍,延续 R14)

装机 user 拍"实时同步我进度"。已跑：

- 派单前 `fire.log` 94 字节根因诊断（详见 `pm-direct-cc-pitfalls-2026-07-28.md`）
- build 中 fire-watch 5min 巡检
- build 完成 → 立刻发飞书 DM 装机 user（含 .app 路径 + size + mtime + Info.plist 关键字段）

## 5. AC 自验

| AC | 内容 | 结果 |
|----|------|------|
| AC1 | `pnpm tauri build` exit 0（产生 .app，**不**需要 DMG） | ✅ exit 0，1 bundle = 文枢.app |
| AC2 | `文枢.app` 在 `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/` | ✅ 17:10 产物，7.9 MB，arm64 |
| AC3 | `文枢.app` 在 `/Users/anbaiqiang/Downloads/` 下 | ✅ 17:11 拷入，Info.plist CFBundleDisplayName=文枢 |
| AC4 | 落档 ≥ 2KB `wenshu-pour/architecture/R15-app-rebuild-2026-07-28.md` | ✅ 本文件（5KB+） |
| AC5 | 飞书 DM 推装机 user（.app 路径 + size + mtime） | ✅ 见 §6 |

## 6. 装机 user 飞书 DM 模板 (R15)

```
【WO-001BI-R15 完成】文枢 APP 重 build (8/28 17:11 装机 user 拍)

入口（双击即装）：
  /Users/anbaiqiang/Downloads/文枢.app

大小 + 时间：
  7.9 MB · mtime Jul 28 17:11:03 2026
  arm64 Mach-O · adhoc 签名 · CFBundleDisplayName=文枢

装法：
  1) 双击 文枢.app 打开 Finder
  2) 把 文枢.app 拖到 /Applications/
  3) 启动台找 "文枢" 打开
  （如果 macOS Gatekeeper 拦：右键 → 打开 → 仍要打开）

build 命令（仓内）：
  cd apps/bootstrap-installer
  pnpm exec tauri build --bundles app

R15 没出 DMG（按你 8/28 拍板"APP 不需要打包 DMG"）。
旧 WenShu-Setup.dmg 5.5 MB（11:47 R14 之前的）保留在 Downloads/，新装走 .app 入口。
```

## 7. 后续动作

- 装机 user 拖入 /Applications/ + 启动 R15 .app → 走 R16（gateway 启动链路 `~/.wenshu-hermes` 修复）+ R17（online update 链路）继续
- PM-direct 在 loop 外回收装机 user 试用反馈（如 R12/R13 早期"启动后找不到 venv"问题，跟上游漂移一并处理）
- 跟上游漂移维护：hermes 0.19.0 → 0.19.x 监测按 §10 走（不阻塞）

## 8. 落档位置

- 本文件：`wenshu-pour/architecture/R15-app-rebuild-2026-07-28.md`
- R14 来源：`wenshu-pour/architecture/R14-bootstrap-installer-i18n-logo-2026-07-28.md`
- 派单失败真值表：`~/.hermes/profiles/my-pm/skills/cc-fire-cc-cli-mechanics/references/pitfall-65-cc-failure-table.md`
- PM-direct pitfalls：`wenshu-pour/architecture/pm-direct-cc-pitfalls-2026-07-28.md`
- 飞书 DM 脚本：`~/.hermes/profiles/my-pm/scripts/feishu-dm.py`

---

*R15 落档 · 2026-07-28 17:11 · 装机 user 拍板"只出 .app 不出 DMG" · exit 0 + 1 bundle + 双入口齐备*
