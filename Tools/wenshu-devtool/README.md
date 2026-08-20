# wenshu-devtool

Remote dev tool for wenshu macOS app. Hermes `tui_gateway` 范式: 独立 Python 进程, 用 Apple 标准 API (`osascript` / `screencapture` / `defaults` / `security`) 读 wenshu NSWindow + UI 状态.

**核心原则 (老板 8/19 真值):**
- 不内嵌 wenshu core (不修改 `Sources/WenshuApp/`)
- 不修改 `Package.swift` (Tools/ 不在 Swift sources 里)
- 不修改 `Scripts/build-app.sh`
- 不进 wenshu release bundle (`build/Wenshu.app/Contents/Resources/` 不含 devtool)
- 发布时: 直接删 `Tools/wenshu-devtool/` 目录即可, 不需要修 wenshu core

## 用法

```bash
# 1. 列出 wenshu NSWindow 真值
python3 Tools/wenshu-devtool/wenshu_devtool.py list_windows

# 2. 截 wenshu 某个 NSWindow 的图
python3 Tools/wenshu-devtool/wenshu_devtool.py screenshot <window_id> <output.png>

# 3. dump 前台 window UI 树 (System Events UI elements)
python3 Tools/wenshu-devtool/wenshu_devtool.py ui_dump

# 4. dump 菜单栏 (Apple / 文枢 / 文件 / 编辑 / 显示 / 窗口 / 帮助)
python3 Tools/wenshu-devtool/wenshu_devtool.py menu_dump

# 5. dump UserDefaults (provider / model / appearance)
python3 Tools/wenshu-devtool/wenshu_devtool.py settings_dump

# 6. 列 ProviderKeychain 已存 providers
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_list

# 7. 返 provider key (masked, 只显前4后4)
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_get openrouter
```

## 要求

- macOS (uses `osascript`, `screencapture`, `defaults`, `security`)
- Python 3.9+ (no third-party deps, stdlib only)
- WenshuApp running (for `list_windows` / `screenshot` / `ui_dump` / `menu_dump`)

## 安全

- `keychain_get` 输出只显前 4 + 后 4 字符 (不暴露完整 key)
- 不写入 log (= `print(json.dumps(...))` 不持久化)
- 不修改任何文件 (= 只读)
- 需要 macOS 屏幕录制 / 辅助功能权限 (System Settings → Privacy & Security → Screen Recording / Accessibility)

## 发布

老板自己拍 "真正发布我们去掉":
- 删除 `Tools/wenshu-devtool/` 目录
- 不需要改 `Sources/WenshuApp/` / `Package.swift` / `Scripts/build-app.sh`
- wenshu release bundle 自动不含 devtool
