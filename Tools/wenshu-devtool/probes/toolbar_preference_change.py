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

IT OWNS ONLY THE PROCESS IT STARTS. LaunchServices resolves `open -g`
by BUNDLE ID, so the app that comes up is not necessarily the bundle
path this script was given, and `pgrep -f <path>` matches any command
line that merely CONTAINS that path (= a LaunchServices helper, or
another session's instance built from the same bundle). The script
therefore identifies the instance it started by PID (the process whose
executable is exactly this bundle's binary and which was not running
before the launch) and it NEVER kills anything else: no `pkill` by
name, no `pkill -f`. It refuses to run at all when the bundle id is
already taken, because LaunchServices would activate the existing
instance instead of starting a fresh one.

Usage:
  python3 toolbar_preference_change.py <app-bundle> [rounds]

Exit: 0 = survived with no new crash report, 1 = crashed, 2 = harness
error.
"""
import json
import os
import re
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


def instances(executable):
    """Every running process whose executable is exactly this path.

    `pgrep -f` matches any command line that CONTAINS the path (= a
    LaunchServices helper, or a second instance of the same bundle), so
    it can name a process that is not the app this script launched.
    `ps -o comm=` gives the executable path, which makes the match
    exact.
    """
    out = subprocess.run(["ps", "-axo", "pid=,comm="],
                         capture_output=True, text=True).stdout
    pids = []
    for line in out.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2 and parts[1] == executable:
            pids.append(int(parts[0]))
    return pids


def bundle_id(app):
    """The bundle id of an app bundle (= the key LaunchServices uses)."""
    plist = os.path.join(app, "Contents", "Info.plist")
    out = subprocess.run(["/usr/libexec/PlistBuddy", "-c",
                          "Print :CFBundleIdentifier", plist],
                         capture_output=True, text=True).stdout.strip()
    return out or None


def instances_of_bundle(bundle_id):
    """Every running pid that owns this bundle id.

    LaunchServices resolves `open -g` by BUNDLE ID, so an instance built
    from a different path still owns the id, and `open` then activates
    that instance instead of starting a fresh one. Matching by executable
    path (= or `pgrep -f`) cannot see that, which is why the probe used
    to report "the app did not launch" while an app was plainly running.
    """
    text = subprocess.run(["lsappinfo", "list"],
                          capture_output=True, text=True).stdout
    pids = []
    current = None
    for line in text.splitlines():
        found = re.search(r'bundleID="([^"]+)"', line)
        if found:
            current = found.group(1)
            continue
        found = re.search(r"pid = (\d+)", line)
        if found and current == bundle_id:
            pids.append(int(found.group(1)))
    return pids


def alive(pid):
    """Whether this exact pid is still running."""
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, PermissionError):
        return False


def stop(pid):
    """Stop only this pid (= never another session's instance)."""
    try:
        os.kill(pid, 15)
    except ProcessLookupError:
        return
    for _ in range(40):
        if not alive(pid):
            return
        time.sleep(0.25)
    try:
        os.kill(pid, 9)
    except ProcessLookupError:
        pass


def launch(app, executable):
    """Start the app in the background and return OUR pid.

    Returns (pid, None) on success and (None, reason) on failure.
    """
    bid = bundle_id(app)
    owners = instances_of_bundle(bid) if bid else []
    if owners:
        return None, ("bundle id %s is already running (pid %s); LaunchServices "
                      "would activate that instance instead of starting a fresh "
                      "one, so the probe cannot isolate itself. Stop it first."
                      % (bid, ", ".join(str(p) for p in sorted(owners))))
    before = set(instances(executable))
    subprocess.run(["open", "-g", app], check=False)
    deadline = time.time() + 30.0
    while time.time() < deadline:
        new = [p for p in instances(executable) if p not in before]
        if new:
            return new[0], None
        time.sleep(0.5)
    return None, "the app did not launch (= no new process with this executable)"


def persisted_pane():
    """The group the Settings scene currently shows (= the preference
    that the group switch writes)."""
    r = subprocess.run(["defaults", "read", BUNDLE_ID, SETTINGS_TAB_KEY],
                       capture_output=True, text=True)
    return r.stdout.strip()


def switch_groups(executable, pid, rounds):
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
        ["swift", driver, executable, str(pid), str(rounds)],
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

    before = crash_reports()

    pid, reason = launch(app, executable)
    if pid is None:
        print("FAIL: %s" % reason)
        return 2
    time.sleep(12.0)
    print("pid: %s" % pid)
    print("pane_before: %s" % persisted_pane())

    result = switch_groups(executable, pid, rounds)
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
    still_alive = alive(pid)
    faults, max_count, loops = read_log(pid, max(3, rounds // 5 + 4))
    new_reports = sorted(crash_reports() - before)

    print("-" * 70)
    print("survived: %s" % ("yes" if still_alive else "no"))
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

    stop(pid)

    if new_reports or not still_alive:
        return 1
    if faults:
        print("GATE: FAILED (the app logged %d unresolvable symbol names)"
              % faults)
        return 1
    print("GATE: PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
