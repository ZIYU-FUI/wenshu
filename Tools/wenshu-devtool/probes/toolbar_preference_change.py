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
  * whether a NEW crash report of this app appeared.

WHICH INSTANCE IT MEASURES
An app bundle is not an identity on macOS: every build of this app ships
the same bundle id, and the system held 87 registered bundles with that
id on this machine, so a path does not name an instance. The probe
therefore names the instance three ways and requires them to agree:

  * the bundle id comes from the bundle's own Info.plist,
  * the instance is located through LaunchServices' own table
    (`lsappinfo`), and the copy it resolved to is checked against the
    path that was asked for; a copy at another path is reported as
    "another copy", never as a missing app,
  * the process is identified by its REAL executable path (the process
    table's `comm`, compared whole) and by the PID that owns it. A
    pattern match over the command line cannot do this: a relative
    path such as "build/Wenshu.app/Contents/MacOS/WenshuApp" is a
    SUFFIX of every other worktree's build, so `pgrep -f` names
    another build's process,
  * a crash report counts as this run's only when the report names this
    run's PID, so another session's crash is never read as this run's.

WHEN THE INSTANCE IS NOT THERE
The probe names the other copies instead of reporting a missing app:
the running instances of the same bundle id that sit at another path,
and the copies the system has registered for that id. A probe that says
"the app did not launch" without naming the copy the system resolved to
is a harness error, not a measurement.

IT STOPS ONLY THE PROCESS IT STARTED.
The copy at the requested path is reused when it is already running, so
the probe drives that instance and leaves it running, and it says so
("instance_owned"). No kill by name and no kill by pattern, so an
instance another session is using survives the run. Before the probe
signals a pid it checks that the pid still runs this bundle's binary,
because a pid the system handed to another process in the meantime is
not the probe's to stop.

It launches the app in the BACKGROUND (plain `open -g`, never `-n`: a
second instance of the same bundle id restores the same saved window
geometry and trips AppKit's own update-constraints guard on its own),
and it never raises, activates, or focuses the app.

Usage:
  python3 toolbar_preference_change.py <app-bundle> [rounds]
  python3 toolbar_preference_change.py --selftest

Exit: 0 = survived with no crash report of this app and no unresolvable
symbol name, 1 = crashed, died, or logged an unresolvable symbol name,
2 = the probe could not put the driver in front of a known instance.
"""
import json
import os
import plistlib
import re
import subprocess
import sys
import time

DIAG = os.path.expanduser("~/Library/Logs/DiagnosticReports")
SETTINGS_TAB_KEY = "wenshu.settingsTab"
LAUNCH_TIMEOUT = 30.0
STOP_GRACE = 10.0
LSREGISTER = ("/System/Library/Frameworks/CoreServices.framework/Frameworks/"
              "LaunchServices.framework/Support/lsregister")


# ------------------------------------------------------------- identity --


def repo_root():
    """The repo root, derived from this file's own location.

    The probe lives at ``<repo>/Tools/wenshu-devtool/probes/``, so the
    root is three directories up. Deriving it means the probe names no
    checkout path of its own: a copy of that path is a copy that goes
    stale the moment the repo moves or is checked out somewhere else.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(os.path.dirname(os.path.dirname(here)))


def realpath(path):
    """The path the system reports for a file, symlinks resolved."""
    return os.path.realpath(path)


def bundle_identity(bundle):
    """The bundle id and the executable name the bundle declares."""
    with open(os.path.join(bundle, "Contents", "Info.plist"), "rb") as handle:
        plist = plistlib.load(handle)
    name = plist.get("CFBundleExecutable")
    if not name:
        raise ValueError("%s declares no CFBundleExecutable" % bundle)
    return plist.get("CFBundleIdentifier"), name


def bundle_executable(bundle, name):
    """The real path of the binary inside this bundle.

    The path is resolved, so a relative bundle path names one build
    and not every build whose path ends with the same suffix.
    """
    return realpath(os.path.join(bundle, "Contents", "MacOS", name))


def process_table():
    """Every running process, as pid -> real executable path."""
    out = subprocess.run(["ps", "-Aww", "-o", "pid=,comm="],
                         capture_output=True, text=True).stdout
    table = {}
    for line in out.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2 and parts[0].isdigit():
            table[int(parts[0])] = parts[1]
    return table


def pids_with_executable(table, executable):
    """The pids whose executable is exactly this path.

    The comparison is whole, so a path that is a SUFFIX of another
    build's path does not match it.
    """
    return sorted(pid for pid, comm in table.items() if comm == executable)


def launchservices_instances():
    """Every running application instance LaunchServices knows about.

    Each entry carries the bundle id the instance claims, the bundle
    path it was launched from, its executable path and its pid. An
    entry whose bundle id the system does not know carries none, and it
    inherits nothing from the entry above it. An entry whose path the
    system does not know carries no path, and the probe cannot say
    where that instance lives.
    """
    text = subprocess.run(["lsappinfo", "list"],
                          capture_output=True, text=True).stdout
    instances = []
    current = {}
    for line in text.splitlines():
        header = re.match(r'^\s*\d+\)\s+"(.*)"\s+ASN:', line)
        if header:
            current = {"name": header.group(1), "bundle_id": None,
                       "bundle_path": None, "executable_path": None,
                       "pid": None}
            continue
        if not current:
            continue
        found = re.match(r'^\s*bundleID="([^"]*)"', line)
        if found:
            current["bundle_id"] = found.group(1)
            continue
        if re.match(r"^\s*bundleID=\[", line):
            current["bundle_id"] = None
            continue
        found = re.match(r'^\s*bundle path="([^"]*)"', line)
        if found:
            current["bundle_path"] = found.group(1)
            continue
        if re.match(r"^\s*bundle path=\[", line):
            current["bundle_path"] = None
            continue
        found = re.match(r'^\s*executable path="([^"]*)"', line)
        if found:
            current["executable_path"] = found.group(1)
            continue
        found = re.match(r"^\s*pid = (\d+)", line)
        if found:
            current["pid"] = int(found.group(1))
            instances.append(dict(current))
            current = {}
    return instances


def classify(instances, bundle_id, bundle_path):
    """Split the instances of a bundle id into ours, the other copies and
    the ones the system cannot place.

    Ours is the instance launched from the path that was asked for. An
    instance of the same bundle id at another path is a different copy
    of the same app, and it is reported as such. An instance of the
    same bundle id whose path the system does not report is neither:
    the probe knows it runs, and it knows not where it lives.
    """
    ours, others, unplaced = [], [], []
    for instance in instances:
        if instance["bundle_id"] != bundle_id:
            continue
        path = instance["bundle_path"]
        if not path:
            unplaced.append(instance)
        elif realpath(path) == realpath(bundle_path):
            ours.append(instance)
        else:
            others.append(instance)
    return ours, others, unplaced


def registered_copies(bundle_id):
    """Every bundle path the system has registered under this bundle id.

    The registry is what the system resolves a bundle id against, so it
    is where the other copies of an app live.
    """
    out = subprocess.run([LSREGISTER, "-dump"],
                         capture_output=True, text=True).stdout
    copies = []
    for block in re.split(r"\n-{10,}\n", out):
        path = identifier = None
        for line in block.splitlines():
            found = re.match(r"^path:\s+(.*?)\s*$", line)
            if found and path is None:
                path = re.sub(r"\s*\(0x[0-9a-fA-F]+\)$", "", found.group(1))
            found = re.match(r"^identifier:\s+(.*?)\s*$", line)
            if found and identifier is None:
                identifier = found.group(1)
        if identifier == bundle_id and path:
            copies.append(path)
    return sorted(set(copies))


# --------------------------------------------------------------- process --


def alive(pid):
    """Whether this exact pid is still running."""
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, PermissionError):
        return False


def owns_executable(table, pid, executable):
    """Whether this pid runs this executable, per a process table.

    A pid the system handed to another process in the meantime is not
    the process the probe started, and it is not the probe's to stop.
    """
    return table.get(pid) == executable


def owns(pid, executable):
    """Whether this pid still runs this executable."""
    return owns_executable(process_table(), pid, executable)


def stop(pid, executable):
    """Stop this pid, and nothing else.

    The pid is stopped only while it still runs the executable the
    probe started, so a recycled pid is left alone.
    """
    if not owns(pid, executable):
        return False
    try:
        os.kill(pid, 15)
    except (ProcessLookupError, PermissionError):
        return False
    deadline = time.time() + STOP_GRACE
    while time.time() < deadline and alive(pid):
        time.sleep(0.25)
    if alive(pid):
        try:
            os.kill(pid, 9)
        except (ProcessLookupError, PermissionError):
            pass
    return True


def launch(bundle):
    """Start the bundle in the background; the launch's own report."""
    return subprocess.run(["open", "-g", bundle],
                          capture_output=True, text=True)


# ---------------------------------------------------------------- reports --


def crash_report_files():
    """Every crash report on the machine, by file name."""
    if not os.path.isdir(DIAG):
        return set()
    return {f for f in os.listdir(DIAG) if f.endswith(".ips")}


def crash_report_body_from_text(raw):
    """The parsed body of a crash report, or None when it will not parse.

    A report is one metadata line followed by the body, so the body
    starts on the second line.
    """
    try:
        return json.loads("\n".join(raw.split("\n")[1:]))
    except ValueError:
        return None


def crash_report_body(name):
    """The parsed body of a crash report on disk."""
    try:
        raw = open(os.path.join(DIAG, name), encoding="utf-8",
                   errors="replace").read()
    except OSError:
        return None
    return crash_report_body_from_text(raw)


def crash_report_pid(name):
    """The pid a crash report names (= the process that crashed)."""
    body = crash_report_body(name)
    return body.get("pid") if body else None


def crash_report_bundle_id(name):
    """The bundle id a crash report names."""
    body = crash_report_body(name)
    if not body:
        return None
    return (body.get("bundleInfo") or {}).get("CFBundleIdentifier")


def persisted_pane(bundle_id):
    """The group the Settings scene currently shows (= the preference
    that the group switch writes)."""
    r = subprocess.run(["defaults", "read", bundle_id, SETTINGS_TAB_KEY],
                       capture_output=True, text=True)
    return r.stdout.strip()


def switch_groups(pid, bundle_id, rounds):
    """Drive the Settings scene's group rows through the accessibility
    tree and switch them N times.

    SwiftUI's List(selection:) rows do not answer AXPress, so the
    driver sets the row's AXSelected attribute (= the standard AX way
    to select a list row) and verifies every switch against the
    persisted key, so a driver that silently did nothing cannot pass.
    The driver is given the pid and the bundle id, and it checks that
    the running instance claims that id before it reads anything.
    """
    driver = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "toolbar_preference_change.swift")
    return subprocess.run(
        ["swift", driver, str(pid), bundle_id, str(rounds)],
        capture_output=True, text=True, timeout=1800,
    )


def read_log(pid, minutes):
    """The fault counts the app's own log holds for this pid."""
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


def source_commit():
    """The commit the probe's own tree sits at."""
    root = os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))))
    try:
        out = subprocess.run(["/usr/bin/git", "-C", root, "rev-parse",
                              "--short=12", "HEAD"],
                             capture_output=True, text=True,
                             timeout=30).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return "unknown"
    return out or "unknown"


# -------------------------------------------------------------- selftest --


def selftest():
    """Prove the identity rules on fixtures that used to break them.

    Every case calls the function the probe itself calls, so a case
    fails when that function regresses, not when a copy of its logic
    written inside this test regresses. The cases are the ways the
    probe used to name the wrong process: a relative path that is a
    SUFFIX of every other build's path, an instance of the same bundle
    id that lives at another path, an instance of the same bundle id
    whose path the system does not report, a crash report that belongs
    to another process, and a pid the system handed to another process.
    """
    failures = []

    def check(name, got, want):
        if got != want:
            failures.append("%s: got %r, want %r" % (name, got, want))

    # The paths are DERIVED from this file's own location, so the probe
    # carries no hardcoded checkout path: a copy of that path is a copy
    # that goes stale the moment the repo moves. What the cases need is
    # two DIFFERENT app bundles that share a suffix (= the repo's own
    # build and a sibling worktree's build), and the repo root names
    # both.
    root = repo_root()
    ours_path = os.path.join(root, "build", "Wenshu.app")
    other_path = os.path.join(root, ".worktrees", "t_x", "build", "Wenshu.app")
    ours_exe = ours_path + "/Contents/MacOS/WenshuApp"
    other_exe = other_path + "/Contents/MacOS/WenshuApp"

    # The probe is told a RELATIVE path, and every worktree's build sits
    # under a directory that ends with the same "build/Wenshu.app". A
    # pattern match over the command line therefore finds the other
    # build's process too, and the resolved whole-path match does not.
    relative = "build/Wenshu.app/Contents/MacOS/WenshuApp"
    table = {101: other_exe, 202: ours_exe}
    check("a pattern match names both builds",
          sorted(pid for pid, comm in table.items() if relative in comm),
          [101, 202])
    check("the whole-path match names only our build",
          pids_with_executable(table, ours_exe), [202])

    # The path the probe matches against is the RESOLVED one, so a
    # relative bundle path cannot degrade into a suffix match.
    check("a resolved path is absolute",
          os.path.isabs(realpath("build/Wenshu.app")), True)
    check("a resolved relative path still names one build",
          pids_with_executable(table,
                               realpath(ours_path) + "/Contents/MacOS/WenshuApp"),
          [202])

    # Two instances of one bundle id: ours is the one at our path.
    instances = [
        {"name": "Wenshu", "bundle_id": "com.wenshu.app",
         "bundle_path": other_path, "executable_path": None, "pid": 101},
        {"name": "Wenshu", "bundle_id": "com.wenshu.app",
         "bundle_path": ours_path, "executable_path": None, "pid": 202},
        {"name": "Other", "bundle_id": "com.example.other",
         "bundle_path": "/Applications/Other.app", "executable_path": None,
         "pid": 303},
    ]
    mine, others, unplaced = classify(instances, "com.wenshu.app", ours_path)
    check("our instance is the one at our path",
          [i["pid"] for i in mine], [202])
    check("the other copy is reported separately",
          [i["pid"] for i in others], [101])
    check("an instance the system cannot place is reported apart",
          [i["pid"] for i in unplaced], [])

    # An instance whose bundle id the system does not know is not ours,
    # and such an entry inherits no id from the entry above it.
    mixed = [
        {"name": "A", "bundle_id": None, "bundle_path": "/tmp/a.app",
         "executable_path": None, "pid": 1},
        {"name": "B", "bundle_id": "com.wenshu.app",
         "bundle_path": ours_path, "executable_path": None, "pid": 2},
    ]
    mine, others, unplaced = classify(mixed, "com.wenshu.app", ours_path)
    check("an entry without a bundle id is not ours",
          ([i["pid"] for i in mine], [i["pid"] for i in others],
           [i["pid"] for i in unplaced]), ([2], [], []))

    # An instance of our bundle id whose path the system does not report
    # cannot be named as another copy, and it is not ours either.
    hidden = [
        {"name": "Wenshu", "bundle_id": "com.wenshu.app",
         "bundle_path": None, "executable_path": None, "pid": 404},
    ]
    mine, others, unplaced = classify(hidden, "com.wenshu.app", ours_path)
    check("an instance without a path is not ours and not a named copy",
          ([i["pid"] for i in mine], [i["pid"] for i in others],
           [i["pid"] for i in unplaced]), ([], [], [404]))

    # A crash report belongs to the process it names, so another
    # session's crash is never read as this run's crash.
    ours = crash_report_body_from_text(
        '{"app_name":"WenshuApp","timestamp":"2026-10-24 08:00:00.00"}\n'
        '{"pid":202,"procName":"WenshuApp",'
        '"bundleInfo":{"CFBundleIdentifier":"com.wenshu.app"}}') or {}
    theirs = crash_report_body_from_text(
        '{"app_name":"WenshuApp","timestamp":"2026-10-24 08:00:00.00"}\n'
        '{"pid":101,"procName":"WenshuApp",'
        '"bundleInfo":{"CFBundleIdentifier":"com.wenshu.app"}}') or {}
    check("a crash report names its own pid", ours.get("pid"), 202)
    check("a crash report names the app's bundle id",
          (ours.get("bundleInfo") or {}).get("CFBundleIdentifier"),
          "com.wenshu.app")
    check("another session's crash is not this run's crash",
          theirs.get("pid") == ours.get("pid"), False)

    # A pid the system handed to another process is not the probe's to
    # stop, even though the number is the one the probe launched.
    check("the probe's own pid is owned",
          owns_executable(table, 202, ours_exe), True)
    check("a recycled pid is not owned",
          owns_executable({202: other_exe}, 202, ours_exe), False)

    for failure in failures:
        print("FAIL  %s" % failure)
    if failures:
        print("%d case(s) failed" % len(failures))
        return 1
    print("PASS  every identity case")
    return 0


# ------------------------------------------------------------------ main --


def report_missing_instance(bundle, bundle_id, launched):
    """Name the copies the system holds, so a missing instance reads as
    a copy the probe did not get, not as an app that would not start."""
    _, others, unplaced = classify(launchservices_instances(),
                                   bundle_id, bundle)
    if others:
        print("FAIL: the system resolved another copy of %s: %s (pid %s)"
              % (bundle_id,
                 ", ".join(str(i["bundle_path"]) for i in others),
                 ", ".join(str(i["pid"]) for i in others)))
        return
    copies = registered_copies(bundle_id)
    present = [path for path in copies
               if os.path.isdir(path) and realpath(path) != realpath(bundle)]
    if present:
        print("FAIL: no instance of %s started at %s, and the system holds "
              "another copy of that id: %s" % (bundle_id, bundle,
                                               ", ".join(present[:8])))
        if len(present) > 8:
            print("      (%d further registered copies)" % (len(present) - 8))
        return
    if unplaced:
        print("FAIL: no instance of %s started at %s, and %d instance(s) of "
              "that id run at a path the system does not report"
              % (bundle_id, bundle, len(unplaced)))
        return
    if launched.returncode != 0:
        print("FAIL: open refused to launch the bundle: %s"
              % (launched.stderr.strip() or launched.stdout.strip()))
        return
    print("FAIL: no instance of %s started at %s" % (bundle_id, bundle))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        return selftest()
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    app = sys.argv[1]
    rounds = int(sys.argv[2]) if len(sys.argv) > 2 else 10

    bundle = realpath(app)
    try:
        bundle_id, name = bundle_identity(bundle)
        executable = bundle_executable(bundle, name)
    except (OSError, ValueError) as error:
        print("FAIL: no app bundle at %s (%s)" % (app, error))
        return 2
    if not bundle_id:
        print("FAIL: %s declares no bundle id" % bundle)
        return 2

    print("bundle: %s" % bundle)
    print("bundle_id: %s" % bundle_id)
    print("executable: %s" % executable)
    print("source_commit: %s" % source_commit())

    before_reports = crash_report_files()
    before_pids = set(pids_with_executable(process_table(), executable))

    launched = launch(bundle)
    pid = None
    owned = False
    deadline = time.time() + LAUNCH_TIMEOUT
    while time.time() < deadline:
        running = pids_with_executable(process_table(), executable)
        fresh = [p for p in running if p not in before_pids]
        if fresh:
            pid = fresh[0]
            owned = True
            break
        if running:
            # The copy at this path was already up, so the launch
            # reused it. It is this run's subject, but this run did not
            # start it and will not stop it.
            pid = running[0]
            break
        if launched.returncode != 0:
            break
        time.sleep(0.5)

    if pid is None:
        report_missing_instance(bundle, bundle_id, launched)
        return 2

    time.sleep(12.0)
    print("pid: %s" % pid)
    print("instance_owned: %s" % ("yes" if owned else "no"))
    print("pane_before: %s" % persisted_pane(bundle_id))

    result = switch_groups(pid, bundle_id, rounds)
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

    new_files = sorted(crash_report_files() - before_reports)
    app_reports = [name for name in new_files
                   if crash_report_bundle_id(name) == bundle_id]
    mine_reports = [name for name in app_reports
                    if crash_report_pid(name) == pid]
    other_reports = [name for name in app_reports
                     if name not in mine_reports]

    print("-" * 70)
    print("survived: %s" % ("yes" if still_alive else "no"))
    print("pane_after: %s" % persisted_pane(bundle_id))
    print("unresolvable_symbol_faults: %d" % faults)
    print("max_update_constraints_count: %d" % max_count)
    print("layout_loop_warnings: %d" % loops)
    print("new_crash_reports: %s" % (mine_reports if mine_reports else "none"))
    print("other_crash_reports: %s" % (other_reports if other_reports else "none"))
    for name in mine_reports:
        body = crash_report_body(name) or {}
        exc = body.get("exception", {})
        print("  %s type=%s signal=%s" % (name, exc.get("type"),
                                           exc.get("signal")))
    for name in other_reports:
        print("  %s (another copy of %s)" % (name, bundle_id))

    if owned:
        stop(pid, executable)

    if mine_reports or not still_alive:
        return 1
    if faults:
        print("GATE: FAILED (the app logged %d unresolvable symbol names)"
              % faults)
        return 1
    print("GATE: PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
