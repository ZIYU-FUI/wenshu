// App.swift · Wenshu (Wenshu) · v0.01.0 7-zone layout shell (v12 = real NativeSplitterView)
//
// Source of truth: @wenshu-pour/architecture/CONTEXT.md + SPEC-v0.01.0.md
//
// v0.01.0 scaffold v12 (= boss 19:00 fix + boss 19:05 "原来写的代码你删了吗? 可以去看看
// 参考下之前怎么写的"):
//
// History check (= honest): the real NativeSplitterView was at commit 11e2c1390
// (LT-01-fix15, by 8/7 装机 user = the original feature boss拍 "上次的功能就实现了").
// I deleted it in commit d6360e4e5 and kept trying self-rolls (v5/v7/v8/v9/v10/v11)
// without checking git first. v12 = use the real NativeSplitterView from git history,
// minus v0.02.0's AGENTS §8.1 extras (CoreData persistence, panel collapse, full VM).
// v0.01.0 needs only: hover state ✓ + cursor change ✓ + no drag flicker ✓ (NSEvent drag,
// not SwiftUI DragGesture). All three bugs boss拍'd = fixed by using NSView + NSEvent
// (= Apple AppKit standard, not SwiftUI gesture host).
//
// v0.01.0 layout (= owner 18:00, "A 你参考 FCP 做"):
//   Upper band: Library (Shelf+Project nested) | Editor | Inspector
//   Lower band: Chat | (Console | Status nested)
//   5 splitters (3 upper horizontal + 1 band + 2 lower horizontal), all NativeSplitter
//
// FCP-measured default proportions (1440x900 baseline, owner 18:35):
//   Library 12.5% / Editor 50% / Inspector 25% (upper band splits 0.125/0.625/0.25)
//   Chat 25% / (Console 50% / Status 50%) (lower band)
//   Lower band height = 50% of total
//
// Out of scope: Wenshu assistant / smart context picker / CoreData / LLM / markdown
// rendering (= owner-deferred per CONTEXT.md §7).

import SwiftUI
import AppKit

@main
struct WenshuApp: App {
    @State private var vm = LayoutShellViewModel()

    var body: some Scene {
        WindowGroup("文枢") {
            LayoutShellView(vm: vm)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

struct LayoutShellView: View {
    let vm: LayoutShellViewModel

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height
            let lowerH = totalH * vm.lowerBandRatio

            VStack(spacing: 0) {
                upperBand(width: totalW, height: totalH - lowerH)
                    .frame(height: totalH - lowerH)

                NativeSplitter(orientation: .vertical) { delta in
                    vm.adjustLowerBandHeight(delta: delta, totalHeight: totalH)
                }
                .frame(height: NativeSplitterView.hitAreaThickness)

                lowerBand(width: totalW, height: lowerH)
                    .frame(height: lowerH)
            }
        }
        .frame(minWidth: 1280, idealWidth: 1452, minHeight: 800, idealHeight: 984)
    }

    @ViewBuilder
    private func upperBand(width: CGFloat, height: CGFloat) -> some View {
        let upperW = width
        let r = vm.upperRatios
        let libraryW = upperW * r[0]
        let editorW = upperW * r[1]
        let inspectorW = upperW * r[2]

        HStack(spacing: 0) {
            // Library (Shelf + Project vertical split inside, hardcoded 30/70)
            LibraryScaffold()
                .frame(width: libraryW)

            // NativeSplitter between Library and Editor
            NativeSplitter(orientation: .horizontal) { delta in
                vm.adjustUpperColumn(splitterIndex: 0, delta: delta, totalWidth: upperW)
            }
            .frame(width: NativeSplitterView.hitAreaThickness)

            ZoneScaffoldView(name: "EDITOR")  // background from defaultBackground(= "EDITOR" → black)
                .frame(width: editorW)

            // NativeSplitter between Editor and Inspector
            NativeSplitter(orientation: .horizontal) { delta in
                vm.adjustUpperColumn(splitterIndex: 1, delta: delta, totalWidth: upperW)
            }
            .frame(width: NativeSplitterView.hitAreaThickness)

            ZoneScaffoldView(name: "INSPECTOR")
                .frame(width: inspectorW)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func lowerBand(width: CGFloat, height: CGFloat) -> some View {
        let lowerW = width
        let r = vm.lowerRatios
        let chatW = lowerW * r[0]
        let rightW = lowerW * r[1]

        HStack(spacing: 0) {
            ZoneScaffoldView(name: "CHAT")
                .frame(width: chatW)

            NativeSplitter(orientation: .horizontal) { delta in
                vm.adjustLowerColumn(delta: delta, totalWidth: lowerW)
            }
            .frame(width: NativeSplitterView.hitAreaThickness)

            // Right side: Console | Status nested split
            consoleStatusSplit(width: rightW)
                .frame(width: rightW)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func consoleStatusSplit(width: CGFloat) -> some View {
        let r = vm.consoleStatusRatio
        let consoleW = width * r
        let statusW = width * (1.0 - r)

        HStack(spacing: 0) {
            ZoneScaffoldView(name: "CONSOLE")
                .frame(width: consoleW)

            NativeSplitter(orientation: .horizontal) { delta in
                vm.adjustConsoleStatus(delta: delta, totalWidth: width)
            }
            .frame(width: NativeSplitterView.hitAreaThickness)

            ZoneScaffoldView(name: "STATUS")
                .frame(width: statusW)
        }
    }
}

// MARK: - Library (Shelf + Project nested horizontal split, left/right)
// Boss 19:10: "项目管理区的分隔有问题, 不是左右结构" → HStack (left=Shelf, right=Project).
struct LibraryScaffold: View {
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()
            HStack(spacing: 0) {
                ZoneScaffoldView(name: "SHELF")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ZoneScaffoldView(name: "PROJECT")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            parentLabel
        }
    }

    private var parentLabel: some View {
        Text("LIBRARY")
            .font(.system(size: 18, weight: .semibold, design: .default))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
    }
}

// MARK: - Zone scaffold (dim watermark + FCP-measured background color per zone)
//
// Boss 19:10 "各区颜色, 在截图里精准测量" → FCP screenshot PIL measurement:
//   Library  RGB(32, 32, 32)   深灰  (panel background, slight off-black)
//   Editor   RGB(0,  0,  0)    纯黑  (FCP Viewer convention)
//   Inspector RGB(45, 45, 45)  浅灰  (slightly lighter than Library)
struct ZoneScaffoldView: View {
    let name: String
    let background: Color

    init(name: String, background: Color? = nil) {
        self.name = name
        self.background = background ?? Self.defaultBackground(for: name)
    }

    /// FCP-measured zone-specific background colors (= boss 19:10 "精准测量").
    static func defaultBackground(for name: String) -> Color {
        switch name {
        case "EDITOR":
            return Color.black                              // FCP Viewer: RGB(0,0,0)
        case "INSPECTOR":
            return Color(red: 45/255, green: 45/255, blue: 45/255)   // FCP: RGB(45,45,45)
        case "LIBRARY", "SHELF", "PROJECT", "CHAT", "CONSOLE", "STATUS":
            return Color(red: 32/255, green: 32/255, blue: 32/255)   // FCP: RGB(32,32,32)
        default:
            return Color(NSColor.windowBackgroundColor)
        }
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            watermark
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var watermark: some View {
        Text(name)
            .font(.system(size: 72, weight: .bold, design: .default))
            .foregroundStyle(.secondary.opacity(0.18))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsHitTesting(false)
    }
}