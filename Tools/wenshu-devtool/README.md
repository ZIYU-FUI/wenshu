# wenshu-devtool

Remote dev tool for wenshu macOS app. Hermes `tui_gateway` pattern: a standalone Python process that uses Apple standard APIs (`osascript` / `screencapture` / `defaults` / `security`) to read wenshu NSWindow + UI state.

**Core principles (老板 8/19 truth source):**
- Does not embed wenshu core (does not modify `Sources/WenshuApp/`)
- Does not modify `Package.swift` (Tools/ is not part of Swift sources)
- Does not modify `Scripts/build-app.sh`
- Does not enter the wenshu release bundle (`build/Wenshu.app/Contents/Resources/` does not contain devtool)
- At release: simply delete the `Tools/wenshu-devtool/` directory, no need to change wenshu core

## Usage

```bash
# 1. List wenshu NSWindow truth source
python3 Tools/wenshu-devtool/wenshu_devtool.py list_windows

# 2. Screenshot a specific wenshu NSWindow
python3 Tools/wenshu-devtool/wenshu_devtool.py screenshot <window_id> <output.png>

# 3. Dump frontmost window UI tree (System Events UI elements)
python3 Tools/wenshu-devtool/wenshu_devtool.py ui_dump

# 4. Dump menu bar (Apple / 文枢 / File / Edit / View / Window / Help)
python3 Tools/wenshu-devtool/wenshu_devtool.py menu_dump

# 5. Dump UserDefaults (provider / model / appearance)
python3 Tools/wenshu-devtool/wenshu_devtool.py settings_dump

# 6. List ProviderKeychain's stored providers
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_list

# 7. Return provider key (masked, only first 4 + last 4 shown)
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_get openrouter
```

## Requirements

- macOS (uses `osascript`, `screencapture`, `defaults`, `security`)
- Python 3.9+ (no third-party deps, stdlib only)
- WenshuApp running (for `list_windows` / `screenshot` / `ui_dump` / `menu_dump`)

## Security

- `keychain_get` output only shows the first 4 + last 4 characters (does not expose the full key)
- No log writes (= `print(json.dumps(...))` is not persisted)
- Does not modify any file (= read-only)
- Requires macOS Screen Recording / Accessibility permission (System Settings → Privacy & Security → Screen Recording / Accessibility)

## Release

老板 拍 "for real release we remove it" themselves:
- Delete the `Tools/wenshu-devtool/` directory
- No need to change `Sources/WenshuApp/` / `Package.swift` / `Scripts/build-app.sh`
- wenshu release bundle auto-excludes devtool