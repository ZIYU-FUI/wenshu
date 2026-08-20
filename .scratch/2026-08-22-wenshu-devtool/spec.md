# Spec — Tools/wenshu-devtool (Hermes tui_gateway 范式 remote dev tool)

> Date: 2026-08-22
> 老板 2026-08-22 拍: "你能在文枢应用内部内嵌一个工具不, 能获取到界面状态的, 发布的时候我们再去掉, 就单独起一个远程开发工具的东西, 真正发布我们去掉"

## 业务语言 (老板懂)

老板的需求: 在 wenshu app runtime 能拿到界面状态 (screenshot + UI 状态 + window list), 用来远程调 试 (= hermes 这边看 macOS 上 wenshu 长 啥 样, 不 用 每 次都让老 板 截 图 发 过 来)。

老板的 原 话 也 是 "就单独起一个远程开发工具的东西" = **单独 进 程 dev tool, 不 内 嵌 wenshu**。 老板自己 也 知道 "真正发布我们去掉" = 这个 tool 不 上 wenshu 包, 只是 dev 时 用。

## 修法 (5 原则 1 + 3 + 4 满 足, Hermes tui_gateway 范式)

`Tools/wenshu-devtool/` (wenshu 仓 库 内, wenshu release bundle **不 包 含** (= Package.swift 不 import `Tools/`, build-app.sh 不 cp `Tools/`)):

1. `Tools/wenshu-devtool/wenshu_devtool.py` (Python 3.9+ 标 准库, 零 依 赖):
   - `cmd_list_windows`: 用 `osascript -e 'tell application "System Events" to tell process "WenshuApp" to get ...'` 列 出 NSWindow 真 值 (title / frame / visible / id)
   - `cmd_screenshot <window_id>`: `screencapture -l <window_id> <output_path>` (老板 8/19 真 值 = macOS `screencapture -l` window 真值)
   - `cmd_ui_dump`: 用 `osascript` + System Events dump 当 前 frontmost window 的 UI 元 素 (button / text / menu item 真 值)
   - `cmd_menu_dump`: dump 当 前 NSMenu 树 (Apple / 文枢 / 文件 / 编辑 / 显 示 / 窗 口 / 帮 助 真 值)
   - `cmd_settings_dump`: 读 UserDefaults 显 wenshu.llm.* 真 值 (= provider / model / base_url 真 值)
   - `cmd_keychain_list`: 列 出 ProviderKeychain 已存 的 providers
   - `cmd_keychain_get <provider_slug>`: 返 provider 的 key (最 后 8 字 显 示, 不 入 log)
   - 主 入 口: `python3 wenshu_devtool.py <subcommand> [args...]`
2. `Tools/wenshu-devtool/README.md` (用法 + 警 告 + 老板 8/19 真 值 = "不 内 嵌 wenshu core")
3. `Tools/wenshu-devtool/.gitignore` (key cache 不入 git, 如 果有 临 时 文 件)

**Package.swift 不 改**: `Tools/` 不 在 Swift package sources 里 (= 不 编 译 进 wenshu binary)。
**Scripts/build-app.sh 不 改**: 不 cp `Tools/` 进 `build/Wenshu.app/Contents/Resources/` (= 不 进 release bundle)。

## 真值 (老 板 8/19 真 值 基 线 不 被 违 反)

- ✅ **wenshu core 代 码 不 改** (Package.swift / Sources/WenshuApp/ / Sources/ 不 改)
- ✅ **wenshu build script 不 改** (Scripts/build-app.sh 不 改)
- ✅ **wenshu release bundle 不 含 devtool** (build/Wenshu.app/ 不 加 devtool 文 件)
- ✅ **devtool 是 独立 Python 进 程**, 跑 在 Hermes 这 边, 不 进 wenshu 进 程 (= 不 改 wenshu UI / state 真 值)
- ✅ devtool 用 Apple 标 准 API (`osascript` + `screencapture` + `NSUserDefaults` 读), 不 inject 不 hook 不 patch wenshu
- ✅ 老 板 自己 拍 "真正发布我们去掉" = TODO 加 README, 发 布 时 删 `Tools/` 目录 即 可 (= 不 需 要 修 wenshu core)

## 接 口 真 值 (7 个 subcommand)

```
python3 Tools/wenshu-devtool/wenshu_devtool.py list_windows
python3 Tools/wenshu-devtool/wenshu_devtool.py screenshot <window_id> <output_path>
python3 Tools/wenshu-devtool/wenshu_devtool.py ui_dump
python3 Tools/wenshu-devtool/wenshu_devtool.py menu_dump
python3 Tools/wenshu-devtool/wenshu_devtool.py settings_dump
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_list
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_get <provider_slug>
```

## 验 收 标 准

- [ ] `Tools/wenshu-devtool/wenshu_devtool.py` 创建 (7 个 subcommand)
- [ ] `Tools/wenshu-devtool/README.md` (用法 + 警 告)
- [ ] Package.swift 不 改 (= Swift sources 不 include `Tools/`)
- [ ] build/Wenshu.app/Contents/Resources/ 不 含 devtool
- [ ] swift build exit 0 (Package.swift 仍 compile 干净)
- [ ] swift test exit 0
- [ ] 老 板 macOS 真 验: 跑 `list_windows` 返 wenshu NSWindow 真值

## 不 动 (Q20 硬 约 束)

- Package.swift (不动)
- Sources/WenshuApp/ (不动)
- Scripts/build-app.sh (不动)
- AppIcon.icon/ (不动)

## Apple 真 值 引用

- https://developer.apple.com/library/archive/qa/qa1519/_index.html (AppleScript System Events GUI 真值)
- https://developer.apple.com/documentation/security/keychain_services (security 命 令 行真 值)
- https://ss64.com/mac/screencapture.html (`screencapture -l` 真值)
- Hermes tui_gateway/server.py (Hermes 真 值 范 式 = 独立 dev tool 进 程)

## 关联

- 依赖: 无
- 被依赖: 无 (独立 dev tool, 不 影 响 wenshu 真 值)
