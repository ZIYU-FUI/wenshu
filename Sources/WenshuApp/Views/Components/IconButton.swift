// IconButton.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-11
//
// Global ICON button component — wraps `.buttonStyle(.plain) + SF Symbol +
// frame(28×22) + .help + .disabled` so every tab/toggle across the app
// (5 ProjectManagementTab + 4 ChatPanelTab + 2 InspectorTab + 3 macOS
// title bar toolbar ICONs) reads/writes through one place. Replaces ~48
// lines of duplicated `Button { ... } label: { Image(systemName:) ...
// }` boilerplate across LayoutShellView + ChatPanelView + InspectorView.
//
// V0-fix-11 (装机 user 8/11 14:35 红字 "以后界面上所有的按钮都这么处理"):
//   - size 13 (V0-fix-10.1 真值, 修真 V0-fix-8 修真 size 14 → 13)
//   - weight .medium
//   - frame(width: 28, height: 22) — hit area 28×22 = 616pt² ≥ 24×24
//     HIG minimum, 比 V0-fix-10.1 修真 28×20 = 560pt² 大
//   - .buttonStyle(.plain) — no background, no border, no hover (macOS
//     native plain style, 仿 FCP 范式)
//   - foregroundStyle(isActive ? Color.accentColor : .secondary)
//   - .contentShape(Rectangle()) — ensure hit area matches visible frame
//   - .help(label) — tooltip
//   - .disabled(isDisabled)
//
// API:
//   IconButton(systemImage:label:isActive:isDisabled:action:)

import SwiftUI

/// A plain-style ICON button used for every tab/toggle in the app.
///
/// All tab/toggle UI in 文枢 (5 project tab + 4 chat tab + 2 inspector
/// tab + 3 macOS title bar toolbar ICONs) should go through this
/// component so they stay visually consistent and any future tweak
/// (different ICON size, different active color, etc.) lands in one
/// place instead of N.
///
/// The default `frame(width: 28, height: 22)` gives a hit area of
/// 616pt² — above the 24×24 = 576pt² macOS HIG minimum — so it's
/// comfortable to click even though the visible ICON is only 13pt.
struct IconButton: View {

    /// SF Symbol name (usually `IconLibrary.tab(_:)` /
    /// `IconLibrary.panel(_:)` / `IconLibrary.Action.<case>.rawValue`).
    let systemImage: String

    /// Accessibility label + SwiftUI `.help(label)` tooltip.
    let label: String

    /// When `true`, the ICON renders in `Color.accentColor`; otherwise
    /// it falls back to `.secondary`.
    let isActive: Bool

    /// When `true`, the button is disabled (`.disabled` modifier) and
    /// ignores taps. SwiftUI grays the ICON out automatically.
    let isDisabled: Bool

    /// Tap handler. Not invoked while `isDisabled` is true.
    let action: () -> Void

    init(
        systemImage: String,
        label: String,
        isActive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .disabled(isDisabled)
    }
}
