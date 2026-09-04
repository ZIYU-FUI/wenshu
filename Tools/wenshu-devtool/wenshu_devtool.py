#!/usr/bin/env python3
"""
wenshu-devtool — remote dev tool for wenshu macOS app.

Hermes tui_gateway pattern: standalone process that uses Apple standard APIs (osascript / screencapture / NSUserDefaults / security) to read wenshu NSWindow + UI state.

Does not embed wenshu core (老板 8/19 truth source), does not modify Package.swift / Sources/, does not enter the wenshu release bundle.

At release, simply delete Tools/wenshu-devtool/ (= no need to change wenshu core).
"""

import argparse
import json
import os
import subprocess
import sys


WENSHU_PROCESS = "WenshuApp"
WENSHU_BUNDLE_ID = "com.wenshu.app"


def _run_osascript(script: str) -> str:
    """Run an osascript snippet, return stdout, raise if non-zero exit."""
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        timeout=10,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise RuntimeError(f"osascript failed (rc={result.returncode}): {stderr}")
    return (result.stdout or "").strip()


def _run_cmd(cmd: list, timeout: int = 30) -> tuple:
    """Run a subprocess, return (stdout, stderr, returncode)."""
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return (result.stdout or "", result.stderr or "", result.returncode)


def cmd_list_windows(_args) -> dict:
    """List all wenshu NSWindows (title, frame, visible, id)."""
    # AppleScript: use multiple -e args + delimiter (avoid single-line long-string bug)
    script_lines = [
        f'tell application "System Events"',
        f'  tell process "{WENSHU_PROCESS}"',
        '    set windowList to every window',
        '    set output to ""',
        '    repeat with w in windowList',
        '      set winTitle to title of w',
        '      set winPos to position of w',
        '      set winSize to size of w',
        '      set winVisible to visible of w',
        '      set output to output & winTitle & "|" & (item 1 of winPos as string) & "," & (item 2 of winPos as string) & "|" & (item 1 of winSize as string) & "," & (item 2 of winSize as string) & "|" & winVisible & linefeed',
        '    end repeat',
        '    return output',
        '  end tell',
        'end tell',
    ]
    raw = _run_osascript('\n'.join(script_lines))
    windows = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        if len(parts) != 5:
            continue
        title, pos, size, vis = parts[0], parts[1], parts[3], parts[4]
        try:
            x, y = (int(v) for v in pos.split(","))
            w, h = (int(v) for v in size.split(","))
        except ValueError:
            continue
        windows.append({
            "title": title,
            "frame": {"x": x, "y": y, "width": w, "height": h},
            "visible": vis.lower() == "true",
            "process": WENSHU_PROCESS,
        })
    return {"process": WENSHU_PROCESS, "window_count": len(windows), "windows": windows}


def cmd_screenshot(args) -> dict:
    """Screenshot a specific wenshu NSWindow (screencapture -l window_id)."""
    if not args.window_id or not args.output:
        raise ValueError("usage: screenshot <window_id> <output_path>")
    window_id = int(args.window_id)
    output_path = os.path.abspath(args.output)
    parent = os.path.dirname(output_path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    cmd = ["screencapture", "-l", str(window_id), "-o", output_path]
    stdout, stderr, rc = _run_cmd(cmd)
    if rc != 0:
        raise RuntimeError(f"screencapture failed (rc={rc}): {stderr.strip()}")
    size = os.path.getsize(output_path) if os.path.exists(output_path) else 0
    return {"window_id": window_id, "output_path": output_path, "size_bytes": size}


def _dump_tree(obj_script_prefix: str, depth: int = 6) -> list:
    """Walk the UI tree (System Events UI elements), returns [{role, name, value, position}]. Uses recursive osascript."""
    script = (
        f'tell application "System Events" to tell process "{WENSHU_PROCESS}"\n'
        f'  set output to ""\n'
        f'  set indent to ""\n'
        f'  set maxDepth to {depth}\n'
        f'  on recurse(elt, lvl)\n'
        f'    if lvl > maxDepth then return\n'
        f'    set output to output & indent & (role of elt) & "|" & (description of elt) & "|" & (value of elt) & linefeed\n'
        f'    repeat with child in (entire contents of elt)\n'
        f'      set indent to repeatString("  ", lvl)\n'
        f'      recurse(child, lvl + 1)\n'
        f'    end repeat\n'
        f'  end recurse\n'
        f'  try\n'
        f'    set frontWin to front window\n'
        f'    recurse(frontWin, 1)\n'
        f'  end try\n'
        f'  return output\n'
    )
    raw = _run_osascript("\n".join(script_lines))
    items = []
    for line in raw.splitlines():
        line = line.rstrip()
        if not line:
            continue
        stripped = line.lstrip()
        indent_level = (len(line) - len(stripped)) // 2
        parts = stripped.split("|", 2)
        if len(parts) < 3:
            parts = parts + [""] * (3 - len(parts))
        items.append({"indent": indent_level, "role": parts[0], "name": parts[1], "value": parts[2]})
    return items


def cmd_ui_dump(_args) -> dict:
    """Dump the frontmost window UI tree."""
    items = _dump_tree("", depth=5)
    return {"window": "frontmost", "element_count": len(items), "elements": items}


def cmd_menu_dump(_args) -> dict:
    """Dump the menu bar (Apple / 文枢 / File / Edit / View / Window / Help)."""
    script_lines = [
        f'tell application "System Events"',
        f'  tell process "{WENSHU_PROCESS}"',
        '    set mb to menu bar 1',
        '    set output to ""',
        '    set mIdx to 1',
        '    repeat with m in (menu bar items of mb)',
        '      set mName to name of m',
        '      set output to output & "[" & mIdx & "] " & mName & linefeed',
        '      set iIdx to 1',
        '      repeat with mi in (menu items of m)',
        '        set miName to name of mi',
        '        set miEnabled to enabled of mi',
        '        set output to output & "  [" & iIdx & "] " & miName & " enabled=" & miEnabled & linefeed',
        '        set iIdx to iIdx + 1',
        '      end repeat',
        '      mIdx to mIdx + 1',
        '    end repeat',
        '    return output',
        '  end tell',
        'end tell',
    ]
    raw = _run_osascript("\n".join(script_lines))
    menus = []
    current_menu = None
    for line in raw.splitlines():
        if not line.strip():
            continue
        if line.startswith("[") and not line.startswith("  ["):
            current_menu = {"name": line.split("] ", 1)[1], "items": []}
            menus.append(current_menu)
        elif line.startswith("  [") and current_menu is not None:
            content = line[2:].split("] ", 1)[1]
            if " enabled=" in content:
                name, enabled = content.rsplit(" enabled=", 1)
                current_menu["items"].append({"name": name, "enabled": enabled.lower() == "true"})
            else:
                current_menu["items"].append({"name": content, "enabled": None})
    return {"process": WENSHU_PROCESS, "menu_count": len(menus), "menus": menus}


def _defaults_read(key: str) -> str:
    stdout, _, rc = _run_cmd(["defaults", "read", WENSHU_BUNDLE_ID, key])
    if rc != 0:
        return None
    return stdout.strip() if stdout else ""


def cmd_settings_dump(_args) -> dict:
    """Dump wenshu UserDefaults truth source (provider / model / appearance)."""
    keys = [
        "wenshu.llm.provider",
        "wenshu.llm.model",
        "appearanceMode",
    ]
    values = {key: _defaults_read(key) for key in keys}
    return {"bundle_id": WENSHU_BUNDLE_ID, "defaults": values}


def cmd_keychain_list(_args) -> dict:
    """List ProviderKeychain's stored providers.

    v0.24 fix: was using 'security dump-keychain' which doesn't show
    generic password account names. Switch to iterating known provider
    slugs via 'find-generic-password' (returns non-zero if absent = skip).
    """
    # v0.24: iterate known provider slugs (hardcoded to avoid Swift import).
    slugs = [
        "minimax-cn", "minimax", "anthropic", "openai-codex",
        "openrouter", "nous-portal", "github-copilot",
        "github-copilot-acp", "xai-oauth", "minimax-cn-mirror"
    ]
    providers = []
    for slug in slugs:
        stdout, stderr, rc = _run_cmd(
            ["security", "find-generic-password",
             "-s", "com.wenshu.app.provider",
             "-a", f"{slug}.api.key"],
            timeout=5
        )
        if rc == 0:
            providers.append(slug)
    return {"service": "com.wenshu.app.provider", "providers": sorted(providers)}



def cmd_keychain_get(args) -> dict:
    """Return the provider key (only show last 8 chars, not logged)."""
    if not args.provider_slug:
        raise ValueError("usage: keychain_get <provider_slug>")
    slug = args.provider_slug
    stdout, stderr, rc = _run_cmd([
        "security", "find-generic-password",
        "-s", "com.wenshu.app.provider",
        "-a", f"{slug}.api.key",
        "-w",
    ], timeout=10)
    if rc != 0:
        return {"provider": slug, "found": False}
    key = stdout.strip()
    masked = key[:4] + "..." + key[-4:] if len(key) > 8 else "***"
    return {"provider": slug, "found": True, "key_preview": masked, "length": len(key)}


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="wenshu_devtool",
        description="Remote dev tool for wenshu macOS app (Hermes tui_gateway pattern). Does not embed wenshu core, does not modify Package.swift / Sources/, does not enter release bundle.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list_windows", help="List wenshu NSWindow truth source")

    p_screenshot = sub.add_parser("screenshot", help="Screenshot a specific wenshu NSWindow")
    p_screenshot.add_argument("window_id", help="NSWindow id (fetch from list_windows)")
    p_screenshot.add_argument("output", help="Output PNG path")

    sub.add_parser("ui_dump", help="Dump the frontmost window UI tree")

    sub.add_parser("menu_dump", help="Dump the menu bar")

    sub.add_parser("settings_dump", help="Dump UserDefaults")

    sub.add_parser("keychain_list", help="List ProviderKeychain's stored providers")

    p_keyget = sub.add_parser("keychain_get", help="Return provider key (masked)")
    p_keyget.add_argument("provider_slug")

    args = parser.parse_args()

    handlers = {
        "list_windows": cmd_list_windows,
        "screenshot": cmd_screenshot,
        "ui_dump": cmd_ui_dump,
        "menu_dump": cmd_menu_dump,
        "settings_dump": cmd_settings_dump,
        "keychain_list": cmd_keychain_list,
        "keychain_get": cmd_keychain_get,
    }
    try:
        result = handlers[args.command](args)
    except (RuntimeError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
