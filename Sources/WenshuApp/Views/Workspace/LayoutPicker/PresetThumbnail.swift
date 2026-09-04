// PresetThumbnail.swift · Wenshu (文枢) · v0.28 ticket 028-007
//
// SwiftUI port of `TreeThumbnail` (= hermes `layout-picker.tsx:26-51`).
// Recursively renders a WorkspaceState as gray rectangles
// (= HStack for row splits, VStack for column splits) showing the
// pane layout at thumbnail scale. Leaf groups render as filled
// rectangles; splits render as nested containers.
//
// Per ticket 028-007 §"Acceptance criteria" #1: this is the
// `PresetThumbnail.swift` file referenced in the spec.
//
import SwiftUI

/// PresetThumbnail — recursive mini-render of a WorkspaceState for
/// use in the preset cards (= PresetCard).
struct PresetThumbnail: View {
    let workspace: WorkspaceState

    var body: some View {
        GeometryReader { geo in
            render(node: workspace.root, in: geo.size)
        }
    }

    @ViewBuilder
    private func render(node: LayoutNode, in size: CGSize) -> AnyView {
        AnyView(buildNode(node, in: size))
    }

    @ViewBuilder
    private func buildNode(_ node: LayoutNode, in size: CGSize) -> some View {
        switch node {
        case .split(let split):
            if split.orientation == .row {
                HStack(spacing: 1) {
                    ForEach(split.children.indices, id: \.self) { i in
                        render(node: split.children[i], in: CGSize(
                            width: max(0, size.width * CGFloat(split.weights[i]) / CGFloat(split.weights.reduce(0, +)) - 1),
                            height: size.height
                        ))
                    }
                }
            } else {
                VStack(spacing: 1) {
                    ForEach(split.children.indices, id: \.self) { i in
                        render(node: split.children[i], in: CGSize(
                            width: size.width,
                            height: max(0, size.height * CGFloat(split.weights[i]) / CGFloat(split.weights.reduce(0, +)) - 1)
                        ))
                    }
                }
            }
        case .group(let group):
            // Leaf: render as a single gray rectangle (= per
            // hermes `TreeThumbnail` — the group is a tab stack,
            // shown as one filled rectangle at thumbnail scale).
            ZStack {
                Color.secondary.opacity(0.15)
                // If the group has > 1 pane, show a small tab
                // indicator (= divider line at the top) to convey
                // that it's a tabbed group.
                if group.panes.count > 1 {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.tertiary)
                            .frame(height: max(1, size.height * 0.08))
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}