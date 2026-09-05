//
//  GraphBuilder.swift · Wenshu · v0.19 ticket 14 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
//  全 vault 节点关系图构建 + 简单力导向布局.
//  跟 Obsidian Graph view 行为对齐 (https://obsidian.md/help/plugins/graph).
//  Apple HIG: 简单 spring force 算法, 跟 Apple HIG 物理仿真一致.
//

import Foundation

/// Graph node (1 note)
public struct GraphNode: Equatable, Sendable, Identifiable {
    public var id: String       // docId
    public var label: String    // display name (from DocumentIndexing)
    public var x: Double        // 布局坐标 (force-directed 输出)
    public var y: Double
    public var links: Int        // link count (degree)

    public init(id: String, label: String, x: Double = 0, y: Double = 0, links: Int = 0) {
        self.id = id
        self.label = label
        self.x = x
        self.y = y
        self.links = links
    }
}

/// Graph edge (1 [[source → target]] link)
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

/// Graph: whole graph (nodes + edges)
public struct Graph: Equatable, Sendable {
    public var nodes: [GraphNode]
    public var edges: [GraphEdge]

    public init(nodes: [GraphNode] = [], edges: [GraphEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
}

/// GraphBuilder: build graph from LinkIndex + DocumentIndexing + force-directed layout
/// Apple HIG: simple spring force, consistent with Apple HIG physics simulation
public enum GraphBuilder {

    /// Build graph (nodes + edges)
    /// - Get all links from LinkIndex (resolved target_doc_id)
    /// - Collect doc_ids as nodes, compute degree
    public static func build(
        links: [Link],
        documentIndex: DocumentIndexing
    ) async -> Graph {
        // Collect all source + target doc_ids
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

        // Get display name for each doc_id
        var nodes: [GraphNode] = []
        for docId in docIds {
            let name = await documentIndex.name(forDocId: docId) ?? docId
            nodes.append(GraphNode(id: docId, label: name, links: degree[docId] ?? 0))
        }

        // Build edges (deduplicate source+target pair)
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

    /// Simple force-directed layout (spring force)
    /// Apple HIG: physics simulation algorithm
    /// - Exclusion: nodes with distance < threshold repel each other
    /// - Attraction: connected nodes with distance > threshold pull toward each other
    /// - Center gravity: nodes are pulled toward the center
    public static func layout(_ graph: Graph, iterations: Int = 50) -> Graph {
        var nodes = graph.nodes
        guard nodes.count > 1 else { return graph }

        let width: Double = 1000
        let height: Double = 1000
        let repulsion: Double = 5000  // repulsion force strength
        let springLength: Double = 100  // attraction target distance
        let springK: Double = 0.05  // attraction force strength
        let centerK: Double = 0.01  // center gravity strength
        let damping: Double = 0.85  // damping

        // Initialization: Random position (certainty seend 0)
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

        // Power-directed trajectories
        var velocities: [(Double, Double)] = Array(repeating: (0, 0), count: nodes.count)
        for _ in 0..<iterations {
            var forces: [(Double, Double)] = Array(repeating: (0, 0), count: nodes.count)

            // Exclusion
            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let dx = nodes[j].x - nodes[i].x
                    let dy = nodes[j].y - nodes[i].y
                    let distSq = dx * dx + dy * dy + 1  // +1 to avoid divide-by-zero
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

            // Attraction (spring)
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

            // Center gravity
            let centerX = width / 2
            let centerY = height / 2
            for i in 0..<nodes.count {
                forces[i].0 += centerK * (centerX - nodes[i].x)
                forces[i].1 += centerK * (centerY - nodes[i].y)
            }

            // Update Location + Block
            for i in 0..<nodes.count {
                velocities[i].0 = (velocities[i].0 + forces[i].0) * damping
                velocities[i].1 = (velocities[i].1 + forces[i].1) * damping
                nodes[i].x += velocities[i].0
                nodes[i].y += velocities[i].1
                // Limit to canvas
                nodes[i].x = max(0, min(width, nodes[i].x))
                nodes[i].y = max(0, min(height, nodes[i].y))
            }
        }

        return Graph(nodes: nodes, edges: graph.edges)
    }

    /// Local Graph: given current docId, get 1-hop / 2-hop subgraph
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

/// Apple HIG: simple deterministic RNG (used for layout seed)
private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
