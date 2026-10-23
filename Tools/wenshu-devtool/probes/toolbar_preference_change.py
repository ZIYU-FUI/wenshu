#!/usr/bin/env python3
"""
toolbar_preference_change.py = the main window's toolbar survives an app
preference change.

WHAT IT PROVES
The main window used to abort the process (EXC_BREAKPOINT / SIGTRAP)
when the app's preferences changed. AppKit raises the exception when a
window asks for another "Update Constraints in Window" pass more times
than it has views, so the abort means the window's layout never settled
while the preference change re-rendered the toolbar.

The script drives the app's OWN Settings scene and switches the group
rows N times (= N app-preference changes, each one writing the persisted
"wenshu.settingsTab" key) and then reports:

  * whether the process survived,
  * the number of unresolvable SF Symbol names the app logged (an
    unresolvable name is re-resolved on every toolbar render, which is
    what keeps the toolbar's layout from settling),
  * whether a NEW crash report appeared.

It launches the app in the BACKGROUND (plain `open -g`, never `-n`: a
second instance of the same bundle id restores the same saved window
geometry and trips AppKit's own update-constraints guard on its own), and
it never raises, activates, or focuses the app.

Usage:
  python3 toolbar_preference_change.py <app-bundle> [rounds]

Exit: 0 = survived with no new crash report, 1 = crashed, 2 = harness
error.
"""
import json
import os
import subprocess
import sys
import time

DIAG = os.path.expanduser("~/Library/Logs/DiagnosticReports")
BUNDLE_ID = "com.wenshu.app"
SETTINGS_TAB_KEY = "wenshu.settingsTab"


def crash_reports():
    """Every crash report the app has produced so far."""
    if not os.path.isdir(DIAG):
        return set()
    return {f for f in os.listdir(DIAG)
            if f.startswith("WenshuApp") and f.endswith(".ips")}


def app_pid(executable):
    out = subprocess.run(["pgrep", "-f", executable],
                         capture_output=True, text=True).stdout.split()
    return out[0] if out else None


def persisted_pane():
    """The group the Settings scene currently shows (= the preference
    that the group switch writes)."""
    r = subprocess.run(["defaults", "read", BUNDLE_ID, SETTINGS_TAB_KEY],
                       capture_output=True, text=True)
    return r.stdout.strip()


def switch_groups(executable, rounds):
    """Drive the Settings scene's group rows through the accessibility
    tree and switch them N times.

    SwiftUI's List(selection:) rows do not answer AXPress, so the
    driver sets the row's AXSelected attribute (= the standard AX way
    to select a list row) and verifies every switch against the
    persisted key, so a driver that silently did nothing cannot pass.
    """
    driver = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "toolbar_preference_change.swift")
    return subprocess.run(
        ["swift", driver, executable, str(rounds)],
        capture_output=True, text=True, timeout=1800,
    )


def read_log(pid, minutes):
    cmd = ["log", "show", "--last", "%dm" % minutes,
           "--predicate", "processIdentifier == %d" % int(pid),
           "--style", "compact"]
    text = subprocess.run(cmd, capture_output=True, text=True,
                          timeout=600).stdout
    faults = 0
    max_count = 0
    loops = 0
    for line in text.splitlines():
        if "No symbol named" in line:
            faults += 1
        if "continued for 300 iterations" in line:
            loops += 1
        if "update constraints count" in line:
            try:
                max_count = max(max_count,
                                int(line.split("count (was ")[1].split(")")[0]))
            except (IndexError, ValueError):
                pass
    return faults, max_count, loops


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    app = sys.argv[1]
    rounds = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    executable = os.path.join(app, "Contents/MacOS/WenshuApp")

    if not os.path.exists(executable):
        print("FAIL: no app bundle at %s" % app)
        return 2

    subprocess.run(["pkill", "-x", "WenshuApp"], check=False)
    time.sleep(2.0)
    before = crash_reports()

    subprocess.run(["open", "-g", app], check=False)
    time.sleep(12.0)
    pid = app_pid(executable)
    if not pid:
        print("FAIL: the app did not launch")
        return 2
    print("pid: %s" % pid)
    print("pane_before: %s" % persisted_pane())

    result = switch_groups(executable, rounds)
    for line in result.stdout.splitlines():
        print(line.strip())
    if result.returncode not in (0, 1):
        print("DRIVER FAILED rc=%d" % result.returncode)
        print(result.stderr.strip()[:600])
        return 2
    # A driver that printed nothing did not run (= a compile error in the
    # Swift driver makes `swift` exit 1, which is also the "the app died"
    # code, so the output is checked as well as the exit code).
    if "SURVIVED" not in result.stdout:
        print("DRIVER PRODUCED NO VERDICT")
        print(result.stderr.strip()[:600])
        return 2

    time.sleep(3.0)
    alive = app_pid(executable) is not None
    faults, max_count, loops = read_log(pid, max(3, rounds // 5 + 4))
    new_reports = sorted(crash_reports() - before)

    print("-" * 70)
    print("survived: %s" % ("yes" if alive else "no"))
    print("pane_after: %s" % persisted_pane())
    print("unresolvable_symbol_faults: %d" % faults)
    print("max_update_constraints_count: %d" % max_count)
    print("layout_loop_warnings: %d" % loops)
    print("new_crash_reports: %s" % (new_reports if new_reports else "none"))
    for name in new_reports:
        raw = open(os.path.join(DIAG, name), encoding="utf-8",
                   errors="replace").read()
        try:
            body = json.loads("\n".join(raw.split("\n")[1:]))
            exc = body.get("exception", {})
            print("  %s type=%s signal=%s" % (name, exc.get("type"),
                                               exc.get("signal")))
        except Exception:  # noqa: BLE001
            print("  %s (unparsed)" % name)

    subprocess.run(["pkill", "-x", "WenshuApp"], check=False)

    if new_reports or not alive:
        return 1
    if faults:
        print("GATE: FAILED (the app logged %d unresolvable symbol names)"
              % faults)
        return 1
    print("GATE: PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
