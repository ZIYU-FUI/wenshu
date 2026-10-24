#!/usr/bin/env python3
"""editor_chat_arrangement.py = where the editor and the chat are, on screen.

WHAT IT MEASURES
  ONE subject: the editor/chat zone's ARRANGEMENT = which pane is where.
  It reports the three native coordinates that decide it, read from the
  running app's ACCESSIBILITY TREE:
    * the chat's COMPOSER   (the AXTextField whose placeholder is the
      app's "input a message" string),
    * the editor's TOOLBAR  (the AXButton labelled "bold"),
    * the editor's BODY     (the AXTextArea = the editor's text view).
  From those it names the arrangement (= the chat's composer is LEFT of
  the editor's toolbar = side by side; = the editor's body is ABOVE the
  chat's composer = stacked) and says whether the arrangement on screen
  is the one the layout mode asked for.

HOW IT MEASURES
  Through the AX API (ctypes; = no PyObjC on this machine). The tree is
  read by PID, and the window id is resolved FROM the process (= its
  AXWindowNumber), so another session running the same app cannot make
  the probe read the wrong window.

  It prints the tree's HEAD at run time, so a re-run on a later commit
  prints that later commit.

THE TRAPS THIS SCRIPT AVOIDS
  1. A SCREENSHOT IS NOT A MEASUREMENT of this subject. A downscaled
     capture of a 1920-point window makes a panel unreadable, and a
     vision model then reads the document in the middle and describes it
     as the panel. The tree's own coordinates have no such failure.
  2. The CRASH-REPORT COUNT IS NOT THE ARRANGEMENT. A death without a
     crash report is a kill, and a report without a tree read is a
     crash. They are different subjects.
  3. A PROBE THAT MEASURES A SHAPE THE APP NO LONGER DRAWS MUST REFUSE
     TO REPORT A NUMBER. So every production fragment this probe
     reproduces is checked against the live source FIRST (= the
     preference key, the three modes, the width rule's two thresholds,
     the two autosave names). If a fragment disagrees, this prints NO
     number and says which fragment disagreed.

USAGE
  python3 Tools/wenshu-devtool/probes/editor_chat_arrangement.py --pid <pid>
  python3 Tools/wenshu-devtool/probes/editor_chat_arrangement.py --exec WenshuApp
  python3 Tools/wenshu-devtool/probes/editor_chat_arrangement.py --source-only

EXIT CODE
  0 = the arrangement was read (and agrees with the requested mode),
  1 = the arrangement was read and DISAGREES with the requested mode,
  2 = no number was reported (= the source moved, or there is no tree).
"""

from __future__ import annotations

import argparse
import ctypes
import os
import plistlib
import subprocess
import sys

# --- the app's own strings, so the composer is found by what it says -----
# The zh-Hans and the en strings of the chat's composer placeholder, and
# the editor's "bold" button label (the same string in both languages).
COMPOSER_LABELS = ("\u8f93\u5165\u6d88\u606f...", "Input a message...")
BOLD_LABELS = ("bold",)
LAYOUT_MODE_KEY = "wenshu.editor.layoutMode"

# --- the production fragments this probe reproduces ----------------------
# Each one is a (file, needle) pair, checked against the live source
# before any number is printed.
FRAGMENTS = (
    ("Features/Agent/Service/UserDefaultsStore.swift",
     'case editorLayoutMode    = "%s"' % LAYOUT_MODE_KEY),
    ("Shared/State/WorkspaceUIState.swift",
     "case automatic"),
    ("Shared/State/WorkspaceUIState.swift",
     "case stacked"),
    ("Shared/State/WorkspaceUIState.swift",
     "case sideBySide"),
    ("Features/Editor/View/EditorChatNSController.swift",
     "static let sideBySideMinimumWidth: CGFloat = 1000"),
    ("Features/Editor/View/EditorChatNSController.swift",
     "static let stackedMaximumWidth: CGFloat = 920"),
    ("Features/Editor/View/EditorChatNSController.swift",
     'private static let autosaveName = "wenshu.editor.split.autosave"'),
    ("Features/Editor/View/EditorChatNSController.swift",
     'private static let sideAutosaveName = "wenshu.editor.split.autosave.side"'),
)

UTF8 = 0x08000100
AX_VALUE_CG_POINT = 1
AX_VALUE_CG_SIZE = 2


# --------------------------------------------------------------- the source --

def source_root():
    here = os.path.dirname(os.path.abspath(__file__))
    # probes/ -> wenshu-devtool/ -> Tools/ -> the repo root
    return os.path.dirname(os.path.dirname(os.path.dirname(here)))


def tree_commit(root):
    """The commit this tree is at, printed so a number is never orphaned."""
    try:
        out = subprocess.run(["/usr/bin/git", "-C", root, "rev-parse", "--short=12", "HEAD"],
                             capture_output=True, text=True, timeout=10)
        text = (out.stdout or "").strip()
        return text if text else "unknown"
    except Exception:
        return "unknown"


def check_fragments(root):
    """The fragments this probe reproduces, checked against the live
    source. Returns the list of disagreements."""
    problems = []
    base = os.path.join(root, "Sources", "WenshuApp")
    for relative, needle in FRAGMENTS:
        path = os.path.join(base, relative)
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except OSError as exc:
            problems.append("%s: %s" % (relative, exc))
            continue
        if needle not in text:
            problems.append("%s does not contain %r" % (relative, needle))
    return problems


# ------------------------------------------------------------------- the AX --

class Point(ctypes.Structure):
    _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]


class Size(ctypes.Structure):
    _fields_ = [("width", ctypes.c_double), ("height", ctypes.c_double)]


class AX:
    """The slice of the AX API this probe needs."""

    def __init__(self):
        cf = ctypes.cdll.LoadLibrary(
            "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
        ax = ctypes.cdll.LoadLibrary(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
        cf.CFStringCreateWithCString.restype = ctypes.c_void_p
        cf.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
        cf.CFStringGetCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32]
        cf.CFArrayGetCount.restype = ctypes.c_long
        cf.CFArrayGetCount.argtypes = [ctypes.c_void_p]
        cf.CFArrayGetValueAtIndex.restype = ctypes.c_void_p
        cf.CFArrayGetValueAtIndex.argtypes = [ctypes.c_void_p, ctypes.c_long]
        cf.CFNumberGetValue.restype = ctypes.c_bool
        cf.CFNumberGetValue.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
        ax.AXUIElementCreateApplication.restype = ctypes.c_void_p
        ax.AXUIElementCreateApplication.argtypes = [ctypes.c_int]
        ax.AXUIElementCopyAttributeValue.restype = ctypes.c_int
        ax.AXUIElementCopyAttributeValue.argtypes = [
            ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
        ax.AXValueGetValue.restype = ctypes.c_bool
        ax.AXValueGetValue.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
        self.cf, self.ax = cf, ax

    def _cstr(self, text):
        return self.cf.CFStringCreateWithCString(None, text.encode("utf-8"), UTF8)

    def attr(self, element, name):
        if not element:
            return None
        value = ctypes.c_void_p()
        err = self.ax.AXUIElementCopyAttributeValue(
            element, self._cstr(name), ctypes.byref(value))
        if err != 0 or not value.value:
            return None
        return value.value

    def text(self, element, name):
        raw = self.attr(element, name)
        if not raw:
            return None
        buf = ctypes.create_string_buffer(4096)
        if self.cf.CFStringGetCString(raw, buf, 4096, UTF8):
            return buf.value.decode("utf-8", "replace")
        return None

    def array(self, element, name):
        raw = self.attr(element, name)
        if not raw:
            return []
        out = []
        for index in range(self.cf.CFArrayGetCount(raw)):
            child = self.cf.CFArrayGetValueAtIndex(raw, index)
            if child:
                out.append(child)
        return out

    def point(self, element):
        raw = self.attr(element, "AXPosition")
        if not raw:
            return None
        value = Point()
        if not self.ax.AXValueGetValue(raw, AX_VALUE_CG_POINT, ctypes.byref(value)):
            return None
        return (value.x, value.y)

    def size(self, element):
        raw = self.attr(element, "AXSize")
        if not raw:
            return None
        value = Size()
        if not self.ax.AXValueGetValue(raw, AX_VALUE_CG_SIZE, ctypes.byref(value)):
            return None
        return (value.width, value.height)

    def number(self, element, name):
        raw = self.attr(element, name)
        if not raw:
            return None
        value = ctypes.c_longlong(0)
        if self.cf.CFNumberGetValue(raw, 9, ctypes.byref(value)):
            return int(value.value)
        return None


# ---------------------------------------------------------- the app's own --

def find_pid(exec_name):
    out = subprocess.run(["pgrep", "-f", exec_name], capture_output=True, text=True)
    pids = [line.strip() for line in out.stdout.split() if line.strip()]
    return pids[0] if pids else None


def bundle_id_of(pid):
    out = subprocess.run(["ps", "-o", "command=", "-p", str(pid)],
                         capture_output=True, text=True)
    command = out.stdout.strip()
    if not command:
        return None, None
    path = command.split(" ", 1)[0]
    if "/Contents/MacOS/" not in path:
        return None, command
    bundle_dir = path.split("/Contents/MacOS/")[0]
    try:
        with open(os.path.join(bundle_dir, "Contents", "Info.plist"), "rb") as handle:
            info = plistlib.load(handle)
    except Exception:
        return None, command
    return info.get("CFBundleIdentifier"), command


def requested_mode(bundle_id):
    if not bundle_id:
        return None
    out = subprocess.run(["defaults", "read", bundle_id, LAYOUT_MODE_KEY],
                         capture_output=True, text=True)
    return out.stdout.strip() or None


# ---------------------------------------------------------------- the tree --

def walk(ax, element, depth=0, max_depth=14):
    if depth > max_depth:
        return
    yield element, ax.text(element, "AXRole") or ""
    for child in ax.array(element, "AXChildren"):
        yield from walk(ax, child, depth + 1, max_depth)


def label_of(ax, element):
    for name in ("AXTitle", "AXDescription", "AXValue", "AXPlaceholderValue", "AXHelp"):
        text = ax.text(element, name)
        if text:
            return text, name
    return None, None


def find_window(ax, pid):
    """The app's own window, by pid. The window id is resolved FROM the
    process (= its AXWindowNumber), never guessed."""
    app = ax.ax.AXUIElementCreateApplication(int(pid))
    candidates = []
    for window in ax.array(app, "AXWindows"):
        if (ax.text(window, "AXRole") or "") != "AXWindow":
            continue
        candidates.append((ax.number(window, "AXWindowNumber"),
                           ax.size(window) or (0, 0), window))
    if not candidates:
        return None, None
    candidates.sort(key=lambda item: item[1][0] * item[1][1])
    number, size, window = candidates[-1]
    return window, number


def collect(ax, window):
    composer = toolbar = body = None
    for element, role in walk(ax, window):
        if not role:
            continue
        if composer is None and role == "AXTextField":
            text, source = label_of(ax, element)
            if text in COMPOSER_LABELS:
                composer = (element, text, source)
        if toolbar is None and role == "AXButton":
            text, source = label_of(ax, element)
            if text in BOLD_LABELS:
                toolbar = (element, text, source)
        if body is None and role == "AXTextArea":
            body = (element, "AXTextArea", "AXRole")
    return composer, toolbar, body


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, default=None, help="the running app's pid")
    parser.add_argument("--exec", dest="exec_name", default="WenshuApp",
                        help="the executable name to find the pid of")
    parser.add_argument("--source-only", action="store_true",
                        help="check the production fragments and stop")
    parser.add_argument("--source-root", default=None, help="the repo root")
    args = parser.parse_args()

    root = args.source_root or source_root()
    commit = tree_commit(root)
    print("probe: editor_chat_arrangement")
    print("source_commit: %s" % commit)

    # The fragments first: a probe that measures a shape the app no
    # longer draws must refuse to report a number.
    problems = check_fragments(root)
    if problems:
        print("the production source no longer matches what this probe reproduces:")
        for problem in problems:
            print("  %s" % problem)
        print("NO NUMBER REPORTED (= the source moved)")
        return 2
    print("source_fragments: %d/%d match" % (len(FRAGMENTS), len(FRAGMENTS)))

    if args.source_only:
        return 0

    pid = args.pid or find_pid(args.exec_name)
    if not pid:
        print("pid: NOT FOUND (= the app is not running; = nothing to measure)")
        return 2
    bundle_id, command = bundle_id_of(pid)
    mode = requested_mode(bundle_id)
    print("pid: %s" % pid)
    print("bundle_id: %s" % (bundle_id or "(unknown)"))
    print("requested_mode: %s" % (mode or "(unset)"))

    ax = AX()
    window, window_id = find_window(ax, pid)
    if window is None:
        print("window: NOT FOUND (= the app has no window; = nothing to measure)")
        print("NO NUMBER REPORTED")
        return 2
    print("window_id: %s" % (window_id if window_id is not None else "(unknown)"))

    composer, toolbar, body = collect(ax, window)
    if composer is None:
        print("composer: NOT FOUND (= the chat's composer is not in the tree)")
        print("NO NUMBER REPORTED")
        return 2
    if toolbar is None:
        print("editor_toolbar: NOT FOUND (= the editor's toolbar is not in the tree)")
        print("NO NUMBER REPORTED")
        return 2

    composer_point = ax.point(composer[0]) or (0, 0)
    toolbar_point = ax.point(toolbar[0]) or (0, 0)
    print("composer_x: %.0f" % composer_point[0])
    print("composer_y: %.0f" % composer_point[1])
    print("editor_toolbar_x: %.0f" % toolbar_point[0])
    print("editor_toolbar_y: %.0f" % toolbar_point[1])
    if body is not None:
        body_point = ax.point(body[0]) or (0, 0)
        print("editor_body_x: %.0f" % body_point[0])
        print("editor_body_y: %.0f" % body_point[1])
    else:
        body_point = None
        print("editor_body: NOT FOUND")

    if composer_point[0] < toolbar_point[0]:
        arrangement = "sideBySide"
    elif body_point is not None and body_point[1] < composer_point[1]:
        arrangement = "stacked"
    else:
        arrangement = "unknown"
    print("arrangement: %s" % arrangement)

    agree = None
    if mode and mode != "automatic":
        agree = (arrangement == mode)
        print("agreement: %s (asked %s, on screen %s)" % ("yes" if agree else "NO", mode, arrangement))
    elif mode:
        print("agreement: the automatic mode follows the width (= no fixed arrangement)")

    print("GATE: %s" % ("PASSED" if agree in (True, None) else "FAILED"))
    return 0 if agree in (True, None) else 1


if __name__ == "__main__":
    sys.exit(main())
