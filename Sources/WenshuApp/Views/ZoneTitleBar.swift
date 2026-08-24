//
//  ZoneTitleBar.swift · Wenshu · v0.24 boss验收
//
//  Boss 2026-08-24 拍 2 选 1 (对比法):
//  - 上半区 4 zone (projectSidebar / projectPreview / editor / specializedTools):
//    52 PT per-zone title bar (像 Pages/Excel 列标题, 显示当前 zone + selected tab)
//  - 下半区 2 zone (aiChat / aiDynamic): 用 macOS native 28 PT chrome (auto-rendered)
//
//  Title bar shows: "<Zone slot name> / <selected tab name>" (中文, Apple HIG)
//  - 'sidebar (项目侧栏)' + 大纲 tab selected → "项目侧栏 / 大纲"
//  - 'preview (项目预览)' + 预览 tab selected → "项目预览 / 预览"
//  - 'editor (编辑器)' + 编辑 tab selected → "编辑器 / 编辑"
//  - 'tools (专用工具)' + 画布 tab selected → "专用工具 / 画布"
//
//  Apple HIG: 52 PT HStack + zoneBackground color + bottom 1 PT splitter line

import SwiftUI

/// ZoneTitleBar: 52 PT per-zone title bar (Boss 8/24 拍 for upper band only).
public struct ZoneTitleBar: View {
    let slot: ZoneSlot

    public var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.leading, 18)
            Spacer()
        }
        .frame(height: 52)  // 老板 Sketch 真值 52 PT (per-zone sub-header, like Numbers/Excel)
        .frame(maxWidth: .infinity)
        .background(DesignColor.titleBar)
        // v0.15 ticket 008: 底 1 PT splitter line (zone 分隔)
        .overlay(alignment: .bottom) {
            DesignColor.splitterLine.frame(height: 1)
        }
    }

    /// Title text per zone (Boss 8/24 中文).
    private var title: String {
        switch slot {
        case .projectSidebar:
            return "项目侧栏"
        case .projectPreview:
            return "项目预览"
        case .editor:
            return "编辑器"
        case .specializedTools:
            return "专用工具"
        case .aiChat:
            return "对话"  // fallback (shouldn't show — chat zone has no ZoneTitleBar)
        case .aiDynamic:
            return "动态区"  // fallback
        }
    }
}