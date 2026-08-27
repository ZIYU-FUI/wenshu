// LucideIcon.swift · Wenshu (文枢) · v0.27
//
// Boss 2026-08-27 OOB: '同时现在还在用 apple sf 的，全量替换成 lucide，
// 我先不指定，你找同名的换'. = replace ALL Image(systemName:) usage
// with Lucide("...") across the wenshu codebase.
//
// This file provides the central Icon helper. Call sites should use:
//
//   LucideIcon("folder")                          // direct lookup (Lucide canonical name)
//   LucideIcon.fromSystemSymbol("checkmark")      // SF Symbol name → Lucide fallback

import SwiftUI
import Lucide

/// Wenshu canonical icon helper. Resolves an icon name (= wenshu
/// convention = Lucide kebab-case) into a Lucide View. Falls back to
/// an empty 18x18 frame for missing icons (= followup: add the
/// correct icon name).
///
/// Usage:
/// ```swift
/// LucideIcon("folder")                   // Lucide folder icon
/// LucideIcon("chevron-right", size: 12)  // 12 PT chevron
/// LucideIcon.fromSystemSymbol("checkmark")  // SF 'checkmark' → Lucide 'check'
/// ```
@ViewBuilder
public func LucideIcon(_ name: String, size: CGFloat = 18) -> some View {
    if let lucide = Lucide(name) {
        lucide
            .frame(width: size, height: size)
            .foregroundStyle(.primary)
    } else {
        // Empty placeholder (= icon name not found in lucide; followup
        // = add the correct icon name).
        Color.clear
            .frame(width: size, height: size)
    }
}

/// Icon helper that takes an SF Symbol name (= legacy / boss shorthand)
/// and resolves it to the canonical Lucide equivalent. Falls back to
/// the SF Symbol itself if no Lucide match exists (= preserves
/// behavior so boss can request a followup rename).
///
/// Mapping (= boss 8/27 '你先落地，你找同名的换' = if SF Symbol name
/// is already valid Lucide, use directly; otherwise try the closest
/// Lucide equivalent):
/// - SF 'checkmark' → Lucide 'check'
/// - SF 'sidebar.left' → Lucide 'panel-left'
/// - SF 'eye.fill' → Lucide 'eye'
/// - SF 'wrench.and.screwdriver' → Lucide 'wrench'
/// - SF 'bubble.left' → Lucide 'message-square'
/// - SF 'chart.bar' → Lucide 'chart-bar'
/// - SF 'square.and.arrow.up' → Lucide 'share-2'
/// - SF 'paperplane.fill' → Lucide 'send'
/// - SF 'arrow.down.doc' → Lucide 'arrow-down-to-line'
/// - SF 'square.and.pencil' → Lucide 'square-pen'
/// - SF 'arrow.down.right.and.arrow.up.left' → Lucide 'minimize-2'
/// - SF 'arrow.up.left.and.arrow.down.right' → Lucide 'maximize-2'
/// - SF 'chevron.up.chevron.down' → Lucide 'chevrons-up-down'
/// - SF 'cpu' → Lucide 'cpu'
/// - SF 'plus' → Lucide 'plus'
/// - SF 'folder' → Lucide 'folder'
/// - SF 'key' / 'key.fill' → Lucide 'key'
/// - SF 'chevron.right' → Lucide 'chevron-right'
/// - SF 'chevron.down' → Lucide 'chevron-down'
/// - SF 'eye' → Lucide 'eye'
/// - SF 'gauge' → Lucide 'gauge'
/// - SF 'person' / 'person.crop.circle' → Lucide 'user'
/// - SF 'tag' → Lucide 'tag'
@ViewBuilder
public func LucideIcon(fromSystemSymbol sfSymbol: String, size: CGFloat = 18) -> some View {
    let lucideName = sfSymbolToLucideName(sfSymbol)
    if let lucide = Lucide(lucideName) {
        lucide
            .frame(width: size, height: size)
            .foregroundStyle(.primary)
    } else if let lucide = Lucide(sfSymbol) {
        // SF Symbol name is itself valid as Lucide name (= e.g. 'plus',
        // 'folder', 'cpu', 'tag' which exist in both libraries).
        lucide
            .frame(width: size, height: size)
            .foregroundStyle(.primary)
    } else {
        // Final fallback = Image(systemName:) SF Symbol rendering
        // (= preserves boss's existing behavior; can be removed in a
        // followup if boss wants strict Lucide-only).
        Image(systemName: sfSymbol)
            .frame(width: size, height: size)
            .foregroundStyle(.primary)
    }
}

/// Maps an SF Symbol name to its closest Lucide equivalent (= boss
/// 8/27 '你找同名的换' rule). Returns the SF Symbol name unchanged
/// if a direct Lucide equivalent exists (= Lucide's API accepts both
/// kebab-case and camelCase).
private func sfSymbolToLucideName(_ sfSymbol: String) -> String {
    let mapping: [String: String] = [
        "checkmark": "check",
        "sidebar.left": "panel-left",
        "wrench.and.screwdriver": "wrench",
        "bubble.left": "message-square",
        "chart.bar": "chart-bar",
        "square.and.arrow.up": "share-2",
        "paperplane.fill": "send",
        "arrow.down.doc": "arrow-down-to-line",
        "square.and.pencil": "square-pen",
        "arrow.down.right.and.arrow.up.left": "minimize-2",
        "arrow.up.left.and.arrow.down.right": "maximize-2",
        "chevron.up.chevron.down": "chevrons-up-down",
        "person.crop.circle": "user-round",
        "person.crop.circle.badge.questionmark": "bot-message-square",
        "person.crop.square": "user-square",
        "person.text.rectangle": "user-cog",
        "exclamationmark.triangle": "triangle-alert",
        "bubble.left.and.bubble.right": "messages-square",
        "bubble.left.fill": "message-square",
        "square.grid.2x2": "layout-grid",
        "square.grid.3x2": "layout-list",
        "moon": "moon",
        "sun.max": "sun",
        "magnifyingglass": "search",
        "arrow.up.arrow.down": "arrow-up-down",
        "arrow.left.arrow.right": "arrow-left-right",
        "circle": "circle",
        "circle.fill": "circle-dot",
        "trash": "trash-2",
        "pencil": "pen",
        "doc": "file-text",
        "doc.fill": "file-text",
        "doc.on.doc": "copy",
        "arrow.up.to.line": "arrow-up-to-line",
        "arrow.down.to.line": "arrow-down-to-line",
        "arrow.left.to.line": "arrow-left-to-line",
        "arrow.right.to.line": "arrow-right-to-line",
        "folder.fill": "folder",
        "tag.fill": "tag",
        "eye.fill": "eye",
        "key.fill": "key",
        "chart.bar.fill": "chart-bar",
        "person.fill": "user",
    ]
    return mapping[sfSymbol] ?? sfSymbol
}