//
//  OutlineExtractor.swift · Wenshu · v0.19 ticket 21 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  Markdown heading 解析 (H1-H6). 跟 Obsidian Outline plugin 行为对齐 (https://obsidian.md/help/plugins/outline).
//  Apple HIG: NSRegularExpression 解析 # / ## / ### / #### / ##### / ###### 行首.
//

import Foundation

/// 1 个大纲条目 = 1 个 heading
public struct OutlineItem: Equatable, Sendable, Identifiable {
    public var id: String       // 行内容 hash (或 line+title 组合)
    public var level: Int       // 1-6 (H1-H6)
    public var title: String    // heading 文本 (去掉 # 前缀)
    public var line: Int        // 0-indexed 行号
    public var offset: Int      // 在 content 里的字符 offset

    public init(id: String, level: Int, title: String, line: Int, offset: Int) {
        self.id = id
        self.level = level
        self.title = title
        self.line = line
        self.offset = offset
    }
}

/// OutlineExtractor: 静态工具, 解析 markdown heading (H1-H6)
/// 跟 Obsidian Outline plugin 真值对齐
public enum OutlineExtractor {
    /// Markdown heading 正则: 行首 1-6 个 # + 空格 + 标题文字
    /// Apple HIG: NSRegularExpression
    private static let pattern: NSRegularExpression = {
        guard let re = try? NSRegularExpression(pattern: #"^(#{1,6})\s+(.+?)\s*$"#, options: [.anchorsMatchLines]) else {
            fatalError("OutlineExtractor pattern compile failed")
        }
        return re
    }()

    /// 解析 markdown content, 拿所有 heading
    public static func extract(_ content: String) -> [OutlineItem] {
        var items: [OutlineItem] = []
        let nsString = content as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let lines = content.components(separatedBy: "\n")

        for (lineIdx, line) in lines.enumerated() {
            let lineRange = NSRange(location: 0, length: (line as NSString).length)
            // 用 multiline 模式, ^ 匹配行首
            guard let match = pattern.firstMatch(in: line, range: lineRange) else { continue }
            guard match.numberOfRanges >= 3 else { continue }

            // group 1: hashes
            let hashesRange = match.range(at: 1)
            let hashesString = (line as NSString).substring(with: hashesRange)
            let level = hashesString.count

            // group 2: title
            let titleRange = match.range(at: 2)
            let title = (line as NSString).substring(with: titleRange)

            // 计算 offset 在 content 里的位置
            var offset = 0
            for i in 0..<lineIdx {
                offset += ((lines[i] as NSString).length + 1)  // +1 for \n
            }
            offset += hashesRange.location

            let id = "\(lineIdx)-\(title)-\(level)"
            items.append(OutlineItem(id: id, level: level, title: title, line: lineIdx, offset: offset))
        }
        return items
    }

    /// 给 outline items 树状结构 (parent → children)
    /// 算法: 维护栈, root 也入栈.
    /// Apple HIG: OutlineNode 用 class 引用, 树形 children append 立即生效.
    public static func tree(from items: [OutlineItem]) -> [OutlineNode] {
        var stack: [OutlineNode] = []  // 当前 parent chain (栈), root 也入栈

        for item in items {
            let node = OutlineNode(item: item, children: [])
            // 弹栈直到栈末 level < 当前 item level
            while let last = stack.last, last.item.level >= item.level {
                stack.removeLast()
            }
            if stack.isEmpty {
                // root: 直接入栈
                stack.append(node)
            } else {
                // 子节点: append 到栈末 (parent) 的 children
                stack.last?.children.append(node)
                stack.append(node)
            }
        }

        // 收集所有 root (level=1, 按出现顺序)
        var roots: [OutlineNode] = []
        for node in stack {
            if node.item.level == 1 && !roots.contains(node) {
                roots.append(node)
            }
        }
        return roots
    }
}

/// 大纲节点 (树状结构, class 引用保证 children 同步)
///
/// Swift HIG: struct 是 value type, 拷贝后 mutations 不影响其他副本. 树形结构需要引用语义,
/// 用 class 实现. Equatable / Hashable / Sendable 用 NSObject 子类化.
public final class OutlineNode: NSObject, @unchecked Sendable {
    public let item: OutlineItem
    public var children: [OutlineNode]
    public var id: String { item.id }

    public init(item: OutlineItem, children: [OutlineNode] = []) {
        self.item = item
        self.children = children
        super.init()
    }

    public static func == (lhs: OutlineNode, rhs: OutlineNode) -> Bool {
        lhs.id == rhs.id
    }
}
