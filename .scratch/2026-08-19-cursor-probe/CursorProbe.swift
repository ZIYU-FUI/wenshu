// 老板 2026-08-19 拍 "查官方文档确认 macOS 27 修法"
// 真因报告 v2 推荐: 最小 SwiftUI case 验证 .pointerStyle 是否 work
// 完整路径: /Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-19-cursor-probe/CursorProbe.swift
//
// 跑法:
//   swift /Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-19-cursor-probe/CursorProbe.swift
// 鼠标 hover 6 PT 透明 strip:
//   ✅ cursor 切到 ↔ 双箭头 → 候选 A 可行
//   ❌ cursor 不切 → 走候选 D NSWindow 子类化

import SwiftUI

@main
struct CursorProbe: App {
    var body: some Scene {
        WindowGroup { CursorProbeView() }
            .windowStyle(.titleBar)
            .defaultSize(width: 800, height: 400)
    }
}

struct CursorProbeView: View {
    @State private var offset: CGFloat = 200
    var body: some View {
        HStack(spacing: 0) {
            Color.red.frame(width: offset, height: 400)
            Color.clear
                .frame(width: 6, height: 400)
                .pointerStyle(.columnResize())
                .onContinuousHover { phase in
                    print("hover phase: \(phase)")
                }
            Color.blue.frame(maxWidth: .infinity, maxHeight: 400)
        }
    }
}