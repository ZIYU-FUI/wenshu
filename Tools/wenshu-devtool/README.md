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

## Front-end measurement

A separate tool, because it measures the app's own source tree instead of
the running app.

```bash
# 8. Measure the front end's parameter drilling (= dead parameters + heaviest initializers)
python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp

# 8b. Only the heaviest N call sites
python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp --top 10
```

It reads the Swift source, strips comments and string literals, and
reports the initializer parameters that are declared, passed down through
their call sites, and never read. Its own test suite runs on fixtures:

```bash
python3 Tools/wenshu-devtool/tests/test_measure_drill.py
```

## Ticket difficulty tier

Another separate tool, because it measures a card body instead of the
source tree. It derives a card's difficulty tier (T1 trivial / T2 standard /
T3 deep) from the work the body describes, and prints the runtime cap, the
retry budget and the gate that tier buys.

```bash
# 9. The tier contract (= the caps, the budgets, the gates)
python3 Tools/wenshu-devtool/ticket_tier.py --plan

# 9b. Rate a card body before dispatching it
python3 Tools/wenshu-devtool/ticket_tier.py --body card.md

# 9c. Check every card on the board against the tier it earns
python3 Tools/wenshu-devtool/ticket_tier.py --board wenshu-par --check
```

Its test suite runs on fixture bodies:

```bash
python3 Tools/wenshu-devtool/tests/test_ticket_tier.py
```

The tier's contract and the measurements behind its numbers are in
`docs/agents/ticket-tiers.md`.

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