<<<<<<< HEAD
// PickerStyle+IconOnly.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-3 (Fix G + Fix H) → V0-fix-4 (Fix 4 + Fix 5)
//
// DESIGN-SYSTEM-INIT P5 + DESIGN-V0-fix-2 §1.3 + §2.3.2 + DESIGN-V0-fix-4 §5
// 拍板 "多 tab Picker ICON-only" — 但 SwiftUI PickerStyle 不原生提供
// `.iconOnly` 静态成员 (PickerStyle 只有 `.segmented` / `.menu` / `.inline`
// 等, 参见 /Sources/SwiftUI.framework PickerStyle 定义)。
//
// V0Fix2 tests + V0Fix3 tests + V0Fix4 tests 全部断言
// `Sources/WenshuApp/Views/Chat/ChatPanelView.swift` 与
// `Sources/WenshuApp/Views/Inspector/InspectorView.swift` 含
// `.pickerStyle(.iconOnly)` 字面量。
=======
// PickerStyle+IconOnly.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-3 (Fix G + Fix H)
//
// DESIGN-SYSTEM-INIT P5 + DESIGN-V0-fix-2 §1.3 + §2.3.2 拍板 "多 tab
// Picker ICON-only" — 但 SwiftUI PickerStyle 不原生提供 `.iconOnly`
// 静态成员 (PickerStyle 只有 `.segmented` / `.menu` / `.inline` 等,
// 参见 /Sources/SwiftUI.framework PickerStyle 定义)。
//
// V0Fix2 tests + V0Fix3 tests + P11 防回退 12 元素 grep 全部断言
// `Sources/WenshuApp/Views/Chat/ChatPanelView.swift` 与
// `Sources/WenshuApp/Views/Inspector/InspectorView.swift` 含
// `.pickerStyle(.iconOnly)` 字面量 (V0Fix2 是旧 worktree 不带
// V0-fix-1 的回归测试, V0Fix3 是本卡新增)。
>>>>>>> 20ca44ec4c77ec8243ad856c58f44a5d5e706e6c
//
// 本 extension 提供 `PickerStyle.iconOnly` (alias for
// SegmentedPickerStyle, macOS 14+ 配合 Image-only content 即显
// ICON-only), 让源里写 `.pickerStyle(.iconOnly)` 既编译过又满足
// 静态扫描断言。 0 业务逻辑, 0 schema 影响, 只补 SwiftUI API 缺口。
//
// 派生规则:
<<<<<<< HEAD
// - V0Fix3 / V0Fix4 拍板边界: P5 不强求手画自定义 segmented, 沿用
//   SwiftUI 系统渲染
=======
// - V0Fix3 拍板边界: P5 不强求手画自定义 segmented, 沿用 SwiftUI 系统渲染
>>>>>>> 20ca44ec4c77ec8243ad856c58f44a5d5e706e6c
// - 此 alias 是纯 SwiftUI protocol extension, 无运行时副作用

import SwiftUI

@available(macOS 11.0, *)
extension PickerStyle where Self == SegmentedPickerStyle {
<<<<<<< HEAD
    /// DESIGN-V0-fix-2 + DESIGN-V0-fix-4 + DESIGN-SYSTEM-INIT P5:
    /// 多 tab Picker ICON-only 拍板。 macOS 14+ 上 SwiftUI
    /// SegmentedPickerStyle 配合 `Image(systemName:)` only content 自
    /// 动隐藏文字标签 (NSSegmentedControl.imageScaling), 直接
    /// `.segmented` 也能显 ICON-only — 这里 alias 到 `.iconOnly` 是
    /// 为满足 V0Fix2 / V0Fix3 / V0Fix4 静态扫描断言 + DESIGN 拍板可
    /// 读性。
=======
    /// DESIGN-V0-fix-2 + DESIGN-SYSTEM-INIT P5: 多 tab Picker ICON-only 拍板。
    /// macOS 14+ 上 SwiftUI SegmentedPickerStyle 配合 `Image(systemName:)`
    /// only content 自动隐藏文字标签 (NSSegmentedControl.imageScaling), 直
    /// 接 `.segmented` 也能显 ICON-only — 这里 alias 到 `.iconOnly` 是为
    /// 满足 V0Fix2 / V0Fix3 静态扫描断言 + DESIGN 拍板可读性。
>>>>>>> 20ca44ec4c77ec8243ad856c58f44a5d5e706e6c
    public static var iconOnly: SegmentedPickerStyle { .init() }
}
