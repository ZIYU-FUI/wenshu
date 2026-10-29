//  toolbar_preference_change.swift · wenshu-devtool probe
//
//  Drives the app's OWN Settings scene and switches the group rows N
//  times (= N app-preference changes), then reports whether the process
//  survived.
//
//  RETIRED AS A GUI DRIVER (2026-10-29): the operator's rule is that the
//  flow never takes the human's mouse or keyboard, and an accessibility
//  PRESS does move the pointer and pull the app forward (= the old
//  "never raise, activate, or focus" claim below was wrong). The GUI drive
//  belongs to the CUA tool (`computer_use`, background delivery); this
//  driver's press path must not run. Keep the READ half (the persisted
//  preference key, the process watch, the crash reports) = the verification.
//  See wenshu-parallel-dev/references/ui-proof-without-taking-the-users-input.md
//
//  The driver matches no localized text. The Settings menu item is found
//  by its COMMAND CHARACTER (= the standard Settings shortcut is a comma)
//  inside the app's own menu (= the menu named after the running app),
//  and the Settings window is found by the fact that it APPEARED when
//  that item was pressed. The Settings window's own title follows the
//  group it shows, so its title cannot be used.
//
//  SwiftUI's List(selection:) rows do not answer AXPress, so the driver
//  sets the row's AXSelected attribute (= the standard accessibility way
//  to select a list row). Every switch is verified against the
//  persisted "wenshu.settingsTab" key, so a driver that silently did
//  nothing cannot report a pass.
//
//  THE PID IS THE IDENTITY. The probe that starts the app knows exactly
//  which instance it launched, and a path cannot name an instance on
//  this machine: every build of this app ships the same bundle id, so
//  several copies are registered at once, and a relative path is a
//  SUFFIX of every other build's path. The driver therefore drives the
//  pid it is given and never re-derives one from a path.
//
//  The bundle id travels with the pid because the preferences live in
//  the domain of that id, and the driver checks that the RUNNING
//  instance claims the id it was given. A pid that belongs to another
//  app would otherwise have its switches read against the wrong domain.
//
//  Usage: swift toolbar_preference_change.swift <pid> <bundle-id> [rounds]
//  Exit: 0 = every switch landed, 1 = the app died mid-run,
//        2 = the driver was handed a pid that is not the expected app.

import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 3, let pid = pid_t(arguments[1]), pid > 0 else {
    print("usage: toolbar_preference_change <pid> <bundle-id> [rounds]")
    exit(2)
}
let expectedBundleID = arguments[2]
let rounds = arguments.count >= 4 ? (Int(arguments[3]) ?? 10) : 10

func axString(_ element: AXUIElement, _ attribute: String) -> String {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == CFStringGetTypeID() else { return "" }
    return (value as! CFString) as String
}

func axRole(_ element: AXUIElement) -> String { axString(element, kAXRoleAttribute) }
func axTitle(_ element: AXUIElement) -> String { axString(element, kAXTitleAttribute) }
func axValue(_ element: AXUIElement) -> String { axString(element, kAXValueAttribute) }
func axCmdChar(_ element: AXUIElement) -> String { axString(element, "AXMenuItemCmdChar") }

func children(_ element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
          let array = value as? [AXUIElement] else { return [] }
    return array
}

func walk(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 22) -> [AXUIElement] {
    var found = [element]
    if depth >= maxDepth { return found }
    for child in children(element) {
        found.append(contentsOf: walk(child, depth: depth + 1, maxDepth: maxDepth))
    }
    return found
}

func perform(_ element: AXUIElement, _ action: String) -> Bool {
    AXUIElementPerformAction(element, action as CFString) == .success
}

func setSelected(_ element: AXUIElement, _ value: Bool) -> Bool {
    AXUIElementSetAttributeValue(
        element,
        kAXSelectedAttribute as CFString,
        value ? kCFBooleanTrue : kCFBooleanFalse
    ) == .success
}

func alive(_ pid: pid_t) -> Bool { kill(pid, 0) == 0 }

guard alive(pid) else {
    print("FAIL: the app is not running (pid \(pid))")
    exit(2)
}

/// The running instance's own bundle id. It must be the id the probe
/// asked for, because the preferences the driver reads live in the
/// domain of that id.
let running = NSRunningApplication(processIdentifier: pid)
guard let claimedID = running?.bundleIdentifier else {
    print("FAIL: the running instance (pid \(pid)) claims no bundle id")
    exit(2)
}
guard claimedID == expectedBundleID else {
    print("FAIL: the running instance (pid \(pid)) claims \(claimedID), not \(expectedBundleID)")
    exit(2)
}
let bundleID = claimedID
print("pid: \(pid)")
print("bundle_id: \(bundleID)")

/// The group the Settings scene shows. The scene persists it through
/// @AppStorage, so the persisted key IS the pane (= the preference the
/// group switch writes).
func persistedPane() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    process.arguments = ["read", bundleID, "wenshu.settingsTab"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

let app = AXUIElementCreateApplication(pid)

/// The running app's own name (= the title of its app menu).
var appName = ""
for running in NSWorkspace.shared.runningApplications
where running.processIdentifier == pid {
    appName = running.localizedName ?? ""
}

/// Every window the app currently exposes.
func windowList() -> [AXUIElement] {
    walk(app).filter { axRole($0) == kAXWindowRole }
}

/// The Settings scene's menu item, found by its command character inside
/// the app's own menu, so no localized title is matched.
func settingsMenuItem() -> AXUIElement? {
    for menuBar in children(app) where axRole(menuBar) == kAXMenuBarRole {
        for menu in children(menuBar) {
            guard !appName.isEmpty, axTitle(menu) == appName else { continue }
            for item in walk(menu) where axRole(item) == kAXMenuItemRole {
                if axCmdChar(item) == "," { return item }
            }
        }
    }
    return nil
}

guard let menuItem = settingsMenuItem() else {
    print("FAIL: the app's Settings menu item was not found")
    exit(2)
}

// The Settings scene is one window, and the menu item toggles it, so the
// window is identified by the fact that it APPEARED after the press. A
// press that instead REMOVED a window means the scene was already open
// and the press closed it, so the driver presses again.
var windowsBefore = windowList()
if !perform(menuItem, kAXPressAction as String) {
    print("FAIL: the app's Settings menu item did not respond")
    exit(2)
}
var settingsWindow: AXUIElement?
for _ in 0..<30 where settingsWindow == nil {
    Thread.sleep(forTimeInterval: 1.0)
    let current = windowList()
    settingsWindow = current.first { candidate in
        !windowsBefore.contains { $0 == candidate }
    }
    if settingsWindow == nil, current.count < windowsBefore.count {
        windowsBefore = current
        _ = perform(menuItem, kAXPressAction as String)
    }
}
guard let settingsWindow else {
    print("FAIL: the Settings window did not appear")
    exit(2)
}
print("opened_settings: yes")
print("settings_window_title: '\(axTitle(settingsWindow))'")

// The group rows live in an accessibility outline: AXRow > AXCell >
// AXStaticText, where the static text carries the row label in its value.
struct Row {
    let row: AXUIElement
    let text: AXUIElement
    let label: String
}
var rows: [Row] = []
for outline in walk(settingsWindow) where axRole(outline) == kAXOutlineRole {
    for row in children(outline) where axRole(row) == kAXRowRole {
        for cell in children(row) {
            for text in children(cell) where axRole(text) == kAXStaticTextRole {
                let label = axValue(text).isEmpty ? axTitle(text) : axValue(text)
                if !label.isEmpty { rows.append(Row(row: row, text: text, label: label)) }
            }
        }
    }
}
print("group_rows: \(rows.count)")
guard !rows.isEmpty else {
    print("FAIL: the Settings scene exposed no group rows")
    exit(2)
}

// Probe the selection strategies once and keep the one that actually
// changes the persisted pane.
var strategy = ""
func tryStrategies(_ row: Row) -> String? {
    let before = persistedPane()
    if setSelected(row.row, true) {
        Thread.sleep(forTimeInterval: 0.5)
        if persistedPane() != before { return "AXSelected" }
    }
    if perform(row.row, "AXSelect") {
        Thread.sleep(forTimeInterval: 0.5)
        if persistedPane() != before { return "row-AXSelect" }
    }
    if perform(row.text, kAXPressAction as String) {
        Thread.sleep(forTimeInterval: 0.5)
        if persistedPane() != before { return "text-press" }
    }
    return nil
}
strategy = tryStrategies(rows[0]) ?? ""
if strategy.isEmpty {
    for row in rows.dropFirst() {
        if let found = tryStrategies(row) { strategy = found; break }
    }
}
guard !strategy.isEmpty else {
    print("FAIL: no strategy moved the Settings scene's group")
    exit(2)
}
print("strategy: \(strategy)")

var changed = 0
for index in 0..<rounds {
    let row = rows[(index + 1) % rows.count]
    let before = persistedPane()
    switch strategy {
    case "AXSelected": _ = setSelected(row.row, true)
    case "row-AXSelect": _ = perform(row.row, "AXSelect")
    default: _ = perform(row.text, kAXPressAction as String)
    }
    Thread.sleep(forTimeInterval: 0.9)
    let now = persistedPane()
    if now != before { changed += 1 }
    if !alive(pid) {
        print("DIED at round \(index + 1) after '\(row.label)' pane=\(now)")
        exit(1)
    }
    if (index + 1) % 5 == 0 || index == 0 {
        print("round \(index + 1): '\(row.label)' pane=\(now)")
    }
}
print("switches_landed: \(changed)/\(rounds)")
if changed < rounds {
    print("FAIL: only \(changed) of \(rounds) group switches landed")
    exit(2)
}
print("SURVIVED")
