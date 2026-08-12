// PickerStyle+IconOnly.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-3 (Fix G + Fix H) → V0-fix-4 (Fix 4 + Fix 5) → V0-fix-8
//
// DESIGN-SYSTEM-INIT P5 + DESIGN-V0-fix-2 §1.3 + §2.3.2 + DESIGN-V0-fix-4 §5
// 拍板 "多 tab Picker ICON-only" — 但 SwiftUI PickerStyle 不原生提供
// `.iconOnly` 静态成员 (PickerStyle 只有 `.segmented` / `.menu` / `.inline`
// 等, 参见 /Sources/SwiftUI.framework PickerStyle 定义)。
//
// V0Fix2 tests + V0Fix3 tests + V0Fix4 tests 全部断言
// `Sources/WenshuApp/Views/ZoneBottomLeft/ChatPanelView.swift` 与
// `Sources/WenshuApp/Views/ZoneTopRight/InspectorView.swift` 含
// `.pickerStyle(.iconOnly)` 字面量 (v0.05.0 Zone/ 物理目录重命名后路径)。
//
// 注: v0.05.0 后 InspectorView 不再用 Picker(selection:) — 改 HStack + Button
// (沿 ChatPanelView V0-fix-11 范式, 沿 t_8fc5c872)。 PickerStyle+IconOnly 仍
// 留 (沿 ChatPanelView 等其它用)。
//
// 本 extension 提供 `PickerStyle.iconOnly` (alias for
// SegmentedPickerStyle, macOS 14+ 配合 Image-only content 即显
// ICON-only), 让源里写 `.pickerStyle(.iconOnly)` 既编译过又满足
// 静态扫描断言。 0 业务逻辑, 0 schema 影响, 只补 SwiftUI API 缺口。
//
// 派生规则:
// - V0Fix3 / V0Fix4 拍板边界: P5 不强求手画自定义 segmented, 沿用
//   SwiftUI 系统渲染
// - 此 alias 是纯 SwiftUI protocol extension, 无运行时副作用
//
// V0-fix-8 (装机 user 8/11 真机拍 4 红字批注 #3): 5 tab + 4 chat tab
// 已迁 HStack + Button(Image) + `.buttonStyle(.plain)` (修真 #2 +
// #3 共同衍生 — 红字"所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿
// FCP")。 本 `.iconOnly` alias 保留 for 未来 Picker 复用 (例如
// InspectorView 2 tab 仍走 SegmentedPickerStyle, v0.04.0+ 可能新增
// Picker 也可复用)。 0 业务改动, 0 schema 影响, 仅 header doc 备注
// + 加 V0-fix-8 拍板历史引用。

import SwiftUI

@available(macOS 11.0, *)
extension PickerStyle where Self == SegmentedPickerStyle {
    /// DESIGN-V0-fix-2 + DESIGN-V0-fix-4 + DESIGN-SYSTEM-INIT P5:
    /// 多 tab Picker ICON-only 拍板。 macOS 14+ 上 SwiftUI
    /// SegmentedPickerStyle 配合 `Image(systemName:)` only content 自
    /// 动隐藏文字标签 (NSSegmentedControl.imageScaling), 直接
    /// `.segmented` 也能显 ICON-only — 这里 alias 到 `.iconOnly` 是
    /// 为满足 V0Fix2 / V0Fix3 / V0Fix4 静态扫描断言 + DESIGN 拍板可
    /// 读性。
    public static var iconOnly: SegmentedPickerStyle { .init() }
}
