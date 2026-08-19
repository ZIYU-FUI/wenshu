//
//  GraphBuilder.swift · Wenshu · v0.19 ticket 14 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  全 vault 节点关系图构建 + 简单力导向布局.
//  跟 Obsidian Graph view 行为对齐 (https://obsidian.md/help/plugins/graph).
//  Apple HIG: 简单 spring force 算法, 跟 Apple HIG 物理仿真一致.
//

import Foundation

/// 图节点 (1 个 note)
public struct GraphNode: Equatable, Sendable, Identifiable {
    public var id: String       // docId
    public var label: String    // 显示名 (从 DocumentIndexing 拿)
    public var x: Double        // 布局坐标 (force-directed 输出)
    public var y: Double
    public var links: Int        // 链接数 (degree)

    public init(id: String, label: String, x: Double = 0, y: Double = 0, links: Int = 0) {
        self.id = id
        self.label = label
        self.x = x
        self.y = y
        self.links = links
    }
}

/// 图边 (1 条 [[source → target]] 链接)
public struct GraphEdge: Equatable, Sendable, Identifiable {
    public var id: String       // 唯一 id
    public var sourceId: String // source docId
    public var targetId: String // target docId (resolved)

    public init(id: String, sourceId: String, targetId: String) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
    }
}

/// Graph: 整图 (nodes + edges)
public struct Graph: Equatable, Sendable {
    public var nodes: [GraphNode]
    public var edges: [GraphEdge]

    public init(nodes: [GraphNode] = [], edges: [GraphEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
}

/// GraphBuilder: 从 LinkIndex + DocumentIndexing 构建图 + 力导向布局
/// Apple HIG: 简单 spring force, 跟 Apple HIG 物理仿真一致
public enum GraphBuilder {

    /// 构建图 (nodes + edges)
    /// - 从 LinkIndex 拿所有 links (resolved target_doc_id)
    /// - 收集 doc_ids 作 nodes, 计算 degree
    public static func build(
        links: [Link],
        documentIndex: DocumentIndexing
    ) async -> Graph {
        // 收集所有 source + target doc_ids
        var docIds = Set<String>()
        var edgePairs: [(String, String)] = []  // (sourceId, targetId)
        var degree: [String: Int] = [:]

        for link in links {
            guard let target = link.targetDocId else { continue }  // skip unresolved
            docIds.insert(link.sourceDocId)
            docIds.insert(target)
            edgePairs.append((link.sourceDocId, target))
            degree[link.sourceDocId, default: 0] += 1
            degree[target, default: 0] += 1
        }

        // 拿每个 doc_id 的显示名
        var nodes: [GraphNode] = []
        for docId in docIds {
            let name = await documentIndex.name(forDocId: docId) ?? docId
            nodes.append(GraphNode(id: docId, label: name, links: degree[docId] ?? 0))
        }

        // 构建 edges (去重 source+target pair)
        var seenEdgePairs = Set<String>()
        var edges: [GraphEdge] = []
        for (sourceId, targetId) in edgePairs {
            let pair = "\(sourceId)->\(targetId)"
            if seenEdgePairs.contains(pair) { continue }
            seenEdgePairs.insert(pair)
            edges.append(GraphEdge(id: pair, sourceId: sourceId, targetId: targetId))
        }

        return Graph(nodes: nodes, edges: edges)
    }

    /// 简单力导向布局 (spring force)
    /// Apple HIG: 物理仿真算法
    /// - 排斥力: 节点间距离 < 阈值, 互相排斥
    /// - 吸引力: 有边连接的节点间距离 > 阈值, 互相吸引
    /// - 中心引力: 节点往中心拉
    public static func layout(_ graph: Graph, iterations: Int = 50) -> Graph {
        var nodes = graph.nodes
        guard nodes.count > 1 else { return graph }

        let width: Double = 1000
        let height: Double = 1000
        let repulsion: Double = 5000  // 排斥力强度
        let springLength: Double = 100  // 吸引目标距离
        let springK: Double = 0.05  // 吸引力强度
        let centerK: Double = 0.01  // 中心引力强度
        let damping: Double = 0.85  // 阻尼

        // 初始化: 随机位置 (确定性 seed 0)
        var rng = SeededRandom(seed: 0)
        for i in 0..<nodes.count {
            nodes[i].x = Double(rng.next() % UInt64(width))
            nodes[i].y = Double(rng.next() % UInt64(height))
        }

        // 构建 id → index 映射
        var indexMap: [String: Int] = [:]
        for (i, node) in nodes.enumerated() {
            indexMap[node.id] = i
        }

        // 边集合 (source, target)
        let edges = graph.edges.compactMap { edge -> (Int, Int)? in
            guard let s = indexMap[edge.sourceId], let t = indexMap[edge.targetId] else { return nil }
            return (s, t)
        }

        // 力导向迭代
        var velocities: [(Double, Double)] = Array(repeating: (0, 0), count: nodes.count)
        for _ in 0..<iterations {
            var forces: [(Double, Double)] = Array(repeating: (0, 0), count: nodes.count)

            // 排斥力
            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let dx = nodes[j].x - nodes[i].x
                    let dy = nodes[j].y - nodes[i].y
                    let distSq = dx * dx + dy * dy + 1  // +1 避免除零
                    let dist = sqrt(distSq)
                    let force = repulsion / distSq
                    let fx = force * dx / dist
                    let fy = force * dy / dist
                    forces[i].0 -= fx
                    forces[i].1 -= fy
                    forces[j].0 += fx
                    forces[j].1 += fy
                }
            }

            // 吸引力 (spring)
            for (s, t) in edges {
                let dx = nodes[t].x - nodes[s].x
                let dy = nodes[t].y - nodes[s].y
                let dist = sqrt(dx * dx + dy * dy + 1)
                let displacement = dist - springLength
                let force = springK * displacement
                let fx = force * dx / dist
                let fy = force * dy / dist
                forces[s].0 += fx
                forces[s].1 += fy
                forces[t].0 -= fx
                forces[t].1 -= fy
            }

            // 中心引力
            let centerX = width / 2
            let centerY = height / 2
            for i in 0..<nodes.count {
                forces[i].0 += centerK * (centerX - nodes[i].x)
                forces[i].1 += centerK * (centerY - nodes[i].y)
            }

            // 更新位置 + 阻尼
            for i in 0..<nodes.count {
                velocities[i].0 = (velocities[i].0 + forces[i].0) * damping
                velocities[i].1 = (velocities[i].1 + forces[i].1) * damping
                nodes[i].x += velocities[i].0
                nodes[i].y += velocities[i].1
                // 限制在画布内
                nodes[i].x = max(0, min(width, nodes[i].x))
                nodes[i].y = max(0, min(height, nodes[i].y))
            }
        }

        return Graph(nodes: nodes, edges: graph.edges)
    }

    /// Local Graph: 给当前 docId, 拿 1-hop / 2-hop 子图
    public static func localGraph(fullGraph: Graph, centerId: String, depth: Int = 1) -> Graph {
        guard depth >= 1 else { return Graph() }

        var visited = Set<String>([centerId])
        var frontier = Set<String>([centerId])
        for _ in 0..<depth {
            var next = Set<String>()
            for edge in fullGraph.edges {
                if frontier.contains(edge.sourceId) && !visited.contains(edge.targetId) {
                    next.insert(edge.targetId)
                }
                if frontier.contains(edge.targetId) && !visited.contains(edge.sourceId) {
                    next.insert(edge.sourceId)
                }
            }
            visited.formUnion(next)
            frontier = next
        }

        let nodes = fullGraph.nodes.filter { visited.contains($0.id) }
        let edges = fullGraph.edges.filter { visited.contains($0.sourceId) && visited.contains($0.targetId) }
        return Graph(nodes: nodes, edges: edges)
    }
}

/// Apple HIG: 简易确定性随机数 (用于 layout seed)
private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
