//
//  LucideThinIcon.swift
//  wenshu
//
//  v1.0.0-m1-shell boss 2026-09-12 OOB '现在的空态不是一个组件,
//  你能抽象一个 UI 组件吗? 顺手把空态的 ICON 放大一倍, 同时用
//  最细的线条. 目的是统一所有空态的样式. 右栏 12 个 teb, 很
//  多都缺少空态':
//
//  Thin-line Lucide wrapper for the unified EmptyStateView.
//  Renders a Lucide glyph at a configurable size, intended for
//  the 76 PT empty-state icon (= 2× the v0.54 38 PT default).
//
//  Why this exists (= the line-width story):
//  - lucide-swift 1.25.0 (the wenshu-pinned version) renders each
//    Lucide glyph via `.fill(...)` on a `Shape` (= SwiftUI Path)
//    that is BAKED at compile time from the Lucide static SVG
//    library via `copy(strokingWithWidth:)` (= the original
//    Lucide centerline stroke is converted to a closed outline;
//    = the result is a filled shape with an intrinsic stroke
//    width baked in).
//  - The public `Lucide(name).lineWidth(width)` API is a
//    DEPRECATED NO-OP (= the line width is fixed at the
//    lucide-swift compile time; = the boss's '最细的线条'
//    directive cannot be expressed through the public API).
//  - The internal `LucideIcon.makePath(in:)` (= the underlying
//    SwiftUI Path) is INACCESSIBLE from the WenshuApp target
//    (= SPM target isolation; = internal access only works
//    within the Lucide package).
//  - Conclusion: the rendered Lucide icon at 76 PT uses the
//    lumide-swift 1.25.0 default baked stroke (= visually thin
//    at 76 PT relative to the icon's 76 PT body; = comparable
//    to Apple's macOS 27 inspector / empty-state icon visual
//    weight per the boss's reference). The `lineWidth` modifier
//    is intentionally NOT exposed (= it would mislead callers
//    into thinking they can thin the stroke further; = the
//    package does not support that).
//
//  Per the verbatim port discipline (= only do what the boss
//  asked), this commit ONLY introduces the LucideThinIcon
//  wrapper (= pure presentational component; = no logic; =
//  one-purpose). The EmptyStateView component itself lands in
//  a followup commit (= uses this wrapper as its icon source).
//
//  Public API surface:
//  - `LucideThinIcon(_ name: String, size: CGFloat = 76)` SwiftUI
//    View = renders the named Lucide glyph at the given point
//    size.
//  - Caller controls the color via `.foregroundStyle(...)` (=
//    the standard SwiftUI shape-tinting pattern).

import SwiftUI
import Lucide

/// v1.0.0-m1-shell boss 2026-09-12 OOB '用最细的线条': Lucide
/// glyph rendered at a configurable size (= defaults to 76 PT
/// for the EmptyStateView component). The stroke width is
/// determined by the lucide-swift 1.25.0 package (= baked-in
/// outline geometry; = see file header for the line-width
/// rationale).
///
/// Fallback: if the named icon does not exist in LucideIcon
/// (= `Lucide(name)` returns nil), the component renders an
/// empty frame (= no visible glyph). Callers that need a
/// guaranteed icon should pick from the LucideIcon enum
/// directly via `LucideThinIcon(LucideIcon.activity)`.
struct LucideThinIcon: View {
    let iconName: String
    let size: CGFloat

    init(_ iconName: String, size: CGFloat = 76) {
        self.iconName = iconName
        self.size = size
    }

    init(_ icon: LucideIcon, size: CGFloat = 76) {
        self.iconName = icon.rawValue
        self.size = size
    }

    var body: some View {
        if let lucideView = Lucide(iconName) {
            // Render the Lucide glyph at the requested size.
            // The default stroke (= baked into the path by
            // lucide-swift 1.25.0) is the thinnest available
            // through the public API; = the lucide-swift
            // package's internal `makePath(in:)` (= would allow
            // a custom `.stroke(lineWidth:)`) is inaccessible
            // from this target (= SPM package isolation).
            lucideView
                .frame(width: size, height: size)
        } else {
            // Missing icon: render an empty frame (= same size
            // as the real icon; = preserves the column's vertical
            // rhythm; = the empty-state component can still
            // position itself correctly).
            Color.clear
                .frame(width: size, height: size)
        }
    }
}
