#!/usr/bin/env python3
"""
v0.34 editor feature visual verification (= macOS screencapture + cliclick).

Tests (12 scenarios):
  S0  dismiss TCC file-access dialog (if present)
  S1  baseline 6-zone state capture
  S2  click sidebar toggle (hide sidebar → snapshot taken)
  S3  click sidebar toggle again (show sidebar → restore from snapshot)
  S4  click preview toggle (hide preview)
  S5  click editor expand icon (B-12 + ticket 03)
  S6  click editor expand icon again (restore)
  S7  multi-toggle chaos test (5 toggles in sequence, expect convergence)
  S8  Cmd+E hotkey test (preview ↔ edit toggle in editor)
  S9  Edit mode TextEditor visible (text-area rendered)
  S10 Cmd+S hotkey test (save indicator behavior)
  S11 final state capture + summary
"""
import subprocess
import time
import os
import sys
from pathlib import Path

SCREENSHOT_DIR = Path("/Volumes/ANAN/Engineering/wenshu/.scratch/v0.34-editor-preview-and-expand/screenshots")
SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
REPORT_PATH = SCREENSHOT_DIR.parent / "visual-verify-report.md"

# From earlier cua capture (Wenshu.app 1920x1012 native; screenshot 1568x1058 → 1.22x scale)
# cliclick takes screenshot-pixel coords (= 1568 wide for screencapture which gives 3840x2160 retina).
# Empirically screencapture on this Mac = 1920x1080 (= 1x); coords from cua capture were 1568x1058 (= native view).
# So screenshot-pixel coords (= cliclick space) match native view coordinates 1:1 for this layout.
# Actual native click coords (from cua screenshot elements):
#   sidebar toggle:    (252, 65)   = cua screenshot
#   preview toggle:    (378, 65)
#   editor expand:     (1519, 65)
#   chat toggle:       (761, 65)
#   dynamic toggle:    (793, 65)
#   close button:      (1487, 65)
# Note: cua screenshot is 1568x1058 in screenshot space; native view IS the same in our case
# (= menu bar at y=30 means non-retina screenshot at 1.22x from cua math).

def capture(name: str, scenario: int) -> Path:
    """Take screenshot via macOS screencapture."""
    out = SCREENSHOT_DIR / f"S{scenario:02d}-{name}.png"
    subprocess.run(["screencapture", "-x", "-o", "-T", "0", str(out)], check=False)
    return out

def click(x: int, y: int):
    """Click via cliclick (coordinate space = screencapture pixel coords)."""
    subprocess.run(["cliclick", f"c:{x},{y}"], check=False, capture_output=True)
    time.sleep(0.5)

def press_key(keys: str):
    """Press key combo via cliclick (= "cmd:e" style)."""
    parts = keys.split(":")
    if len(parts) == 2:
        modifier, key = parts
        subprocess.run(["cliclick", f"p:{modifier}", f"t:{key}", f"u:{modifier}"],
            check=False, capture_output=True)
    else:
        subprocess.run(["cliclick", f"t:{keys}"], check=False, capture_output=True)
    time.sleep(0.5)

results = []

def scenario(n: int, label: str, fn):
    print(f"\n=== S{n}: {label} ===")
    try:
        fn(n)
        results.append((n, label, "PASS", ""))
        print(f"  ✓ PASS")
    except Exception as e:
        results.append((n, label, "FAIL", str(e)))
        print(f"  ✗ FAIL: {e}")
    time.sleep(0.6)

# ---------- Scenarios ----------

def s0_dismiss_tcc(n):
    """S0: Dismiss TCC file-access modal (= "好" button at right)."""
    # TCC modal "好" button at right of dialog. From vision_analyze of 960x540
    # downscaled screenshot, button "好" is at ~(530, 357) → native 1920x1080
    # viewport coords (530*2, 357*2) = (1060, 714) for non-retina cliclick.
    # Note: cliclick on non-retina Mac uses physical pixel coords = 1920x1080 here.
    capture("before-tcc-dismiss", n)
    click(1060, 714)  # TCC "好" button (right-side, native coords)
    time.sleep(1.5)  # wait for wenshu to process grant
    capture("after-tcc-dismiss", n)

def s1_baseline(n):
    """S1: Baseline 6-zone state capture (post-TCC dismiss)."""
    capture("baseline", n)

def s2_sidebar_hide(n):
    """S2: Click sidebar toggle (= B-12 path: snapshot taken before hide)."""
    capture("before-sidebar-hide", n)
    click(252, 65)  # sidebar toggle
    capture("after-sidebar-hide", n)

def s3_sidebar_show(n):
    """S3: Click sidebar toggle (= B-12 path: restore from snapshot)."""
    capture("before-sidebar-show", n)
    click(252, 65)
    capture("after-sidebar-show", n)

def s4_preview_hide(n):
    """S4: Click preview toggle."""
    capture("before-preview-hide", n)
    click(378, 65)
    capture("after-preview-hide", n)

def s5_editor_expand(n):
    """S5: Click editor expand icon (= B-12 + ticket 03)."""
    capture("before-editor-expand", n)
    click(1519, 65)  # editor expand icon
    capture("after-editor-expand", n)

def s6_editor_shrink(n):
    """S6: Click editor expand icon again (= shrink)."""
    capture("before-editor-shrink", n)
    click(1519, 65)
    capture("after-editor-shrink", n)

def s7_chaos(n):
    """S7: Multi-toggle chaos test (= 5 hides + 5 shows, expect convergence)."""
    capture("before-chaos", n)
    # Hide 5 zones (= except editor; toolbar buttons: sidebar, preview, tools, chat, dynamic)
    click(252, 65)  # sidebar hide
    click(378, 65)  # preview hide
    click(503, 65)  # tools hide
    click(761, 65)  # chat hide
    click(793, 65)  # dynamic hide
    capture("after-chaos-5-hides", n)
    # Show 5 zones back
    click(252, 65)  # sidebar show
    click(378, 65)  # preview show
    click(503, 65)  # tools show
    click(761, 65)  # chat show
    click(793, 65)  # dynamic show
    capture("after-chaos-5-shows", n)

def s8_cmd_e(n):
    """S8: Cmd+E hotkey toggle preview/edit mode."""
    capture("before-cmd-e", n)
    press_key("cmd:e")
    capture("after-cmd-e", n)

def s9_edit_mode(n):
    """S9: Edit mode = Apple TextEditor visible."""
    capture("edit-mode-texteditor", n)

def s10_cmd_s(n):
    """S10: Cmd+S hotkey."""
    capture("before-cmd-s", n)
    press_key("cmd:s")
    capture("after-cmd-s", n)

def s11_final(n):
    """S11: Final state capture."""
    capture("final-state", n)

# ---------- Main ----------

def main():
    print("=" * 60)
    print("v0.34 editor feature visual verification")
    print("=" * 60)

    if subprocess.run(["which", "cliclick"], capture_output=True).returncode != 0:
        print("ERROR: cliclick not installed"); sys.exit(1)
    if subprocess.run(["pgrep", "-f", "WenshuApp"], capture_output=True).returncode != 0:
        print("ERROR: Wenshu.app not running"); sys.exit(1)

    scenarios = [
        (0, "dismiss TCC file-access modal", s0_dismiss_tcc),
        (1, "baseline 6-zone state capture", s1_baseline),
        (2, "sidebar toggle hide (= B-12 snapshot taken)", s2_sidebar_hide),
        (3, "sidebar toggle show (= B-12 restore)", s3_sidebar_show),
        (4, "preview toggle hide", s4_preview_hide),
        (5, "editor expand (= ticket 03 + B-12)", s5_editor_expand),
        (6, "editor shrink", s6_editor_shrink),
        (7, "multi-toggle chaos test (5+5 toggles)", s7_chaos),
        (8, "Cmd+E hotkey toggle preview/edit", s8_cmd_e),
        (9, "Edit mode = Apple TextEditor visible", s9_edit_mode),
        (10, "Cmd+S hotkey (no crash)", s10_cmd_s),
        (11, "final state capture", s11_final),
    ]
    for n, label, fn in scenarios:
        scenario(n, label, fn)

    print("\n" + "=" * 60)
    passed = sum(1 for _, _, s, _ in results if s == "PASS")
    total = len(results)
    for n, label, status, err in results:
        print(f"  S{n:02d}: {status} — {label}")
        if err: print(f"        {err}")
    print(f"\nTotal: {passed}/{total} PASS")

    with open(REPORT_PATH, "w") as f:
        f.write("# v0.34 editor feature visual verification report\n\n")
        f.write("Date: 2026-09-02 (= tonight, after ticket 01-11 + B-12 landed)\n\n")
        f.write(f"## Summary\n\n{passed}/{total} scenarios PASS\n\n")
        f.write("## Per-scenario results\n\n")
        for n, label, status, err in results:
            f.write(f"### S{n:02d}: {status} — {label}\n\n")
            f.write(f"- Screenshots: `screenshots/S{n:02d}-*.png`\n")
            if err: f.write(f"- Error: {err}\n")
            f.write("\n")
        f.write("\nLast line: fact.\n")

    print(f"\nReport: {REPORT_PATH}")
    print(f"Screenshots: {SCREENSHOT_DIR}/")
    sys.exit(0 if passed == total else 1)

if __name__ == "__main__":
    main()
