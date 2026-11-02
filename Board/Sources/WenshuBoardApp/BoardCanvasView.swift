//
//  BoardCanvasView.swift
//  WenshuBoard
//
//  The infinite canvas, assembled from the pieces Apple ships.
//
//  Apple ships the canvas surface (`SwiftUICore.Canvas`), the magnify gesture,
//  the drag gesture, the scroll geometry, `zIndex` and `drawingGroup`. It does
//  not ship the product: there is no public infinite canvas on macOS, and
//  `PKCanvasView` is not in the macOS SDK at all, so Freeform's ink layer is
//  its own private classes. This view is the product.
//
//  The shape of it: a world coordinate space, a viewport that maps it to the
//  screen (`BoardViewport`), and the items placed in the world. The world
//  layer is scaled and offset as one transform, so the items keep their
//  positions relative to each other, and SwiftUI hit tests them in the
//  transformed space for free.
//
//  What this view does NOT do yet, and what each omission costs, is in
//  Board/docs/board-plan.md.
//

import SwiftUI
import WenshuBoardKit

/// The canvas's own metrics.
///
/// The client's design token layer is an open decision (AGENTS.md 5.3), so the
/// values live here, named, until it lands. Nothing in this file spells a
/// bare number into a layout call.
private enum CanvasMetrics {
    static let cardWidth: CGFloat = 180
    static let cardHeight: CGFloat = 120
    static let cardInset: CGFloat = 12
    static let cardCornerRadius: CGFloat = 12
    static let cardBorderWidth: CGFloat = 1
    static let stackSpacing: CGFloat = 4
    static let gridCell: CGFloat = 40
    static let dotDiameter: CGFloat = 2
}

/// A board's canvas: an infinite plane of cards, pannable and zoomable.
struct BoardCanvasView: View {

    /// The items on the canvas.
    let elements: [BoardElement]
    /// The world-space size of one grid cell. Milanote calls this `gridSize`.
    let gridSize: CGFloat
    /// The size of one card, in world units.
    let cardSize: CGSize

    @State private var viewport: BoardViewport
    @State private var dragAnchor: CGPoint?

    init(
        elements: [BoardElement],
        gridSize: CGFloat = CanvasMetrics.gridCell,
        cardSize: CGSize = CGSize(width: CanvasMetrics.cardWidth, height: CanvasMetrics.cardHeight),
        viewport: BoardViewport = BoardViewport()
    ) {
        self.elements = elements
        self.gridSize = gridSize
        self.cardSize = cardSize
        _viewport = State(initialValue: viewport)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                gridLayer(in: geometry.size)
                worldLayer(in: geometry.size)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(panGesture)
            .gesture(zoomGesture)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - The world layer

    /// The items, in world coordinates, under the viewport's transform.
    private func worldLayer(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(visibleElements(in: size)) { element in
                card(for: element)
                    .position(worldPosition(of: element))
            }
        }
        .frame(width: worldExtent.width, height: worldExtent.height, alignment: .topLeading)
        .scaleEffect(viewport.scale, anchor: .topLeading)
        .offset(x: viewport.offset.x, y: viewport.offset.y)
    }

    /// One card. A fixed size in world units, so the transform scales it.
    private func card(for element: BoardElement) -> some View {
        VStack(alignment: .leading, spacing: CanvasMetrics.stackSpacing) {
            Text(element.content.title ?? element.id)
                .font(.headline)
                .lineLimit(1)
            Text(element.content.body ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(CanvasMetrics.cardInset)
        .frame(width: cardSize.width, height: cardSize.height, alignment: .topLeading)
        .background {
            // The card is opaque: a translucent one lets the grid show
            // through it, which reads as a rendering fault rather than as a
            // card.
            RoundedRectangle(cornerRadius: CanvasMetrics.cardCornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: CanvasMetrics.cardCornerRadius)
                        .fill(Color.accentColor.opacity(0.08))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: CanvasMetrics.cardCornerRadius)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: CanvasMetrics.cardBorderWidth)
        }
        .zIndex(Double(element.location.position.score ?? 0))
    }

    /// The dot grid, drawn in the visible part of the world only.
    private func gridLayer(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let visible = viewport.visibleWorldRect(in: canvasSize)
            let firstColumn = Int(floor(visible.minX / gridSize))
            let lastColumn = Int(ceil(visible.maxX / gridSize))
            let firstRow = Int(floor(visible.minY / gridSize))
            let lastRow = Int(ceil(visible.maxY / gridSize))
            for column in firstColumn...lastColumn {
                for row in firstRow...lastRow {
                    let world = CGPoint(x: CGFloat(column) * gridSize, y: CGFloat(row) * gridSize)
                    let screen = viewport.screenPoint(for: world)
                    let dot = Path(ellipseIn: CGRect(
                        x: screen.x - CanvasMetrics.dotDiameter / 2,
                        y: screen.y - CanvasMetrics.dotDiameter / 2,
                        width: CanvasMetrics.dotDiameter,
                        height: CanvasMetrics.dotDiameter
                    ))
                    context.fill(dot, with: .color(.secondary))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Gestures

    /// Panning: dragging the background drags the world.
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let anchor = dragAnchor ?? value.startLocation
                dragAnchor = anchor
                viewport = viewport.panned(by: CGSize(
                    width: value.location.x - anchor.x,
                    height: value.location.y - anchor.y
                ))
            }
            .onEnded { _ in
                dragAnchor = nil
            }
    }

    /// Zooming: a magnify gesture keeps the world point under the cursor under
    /// the cursor.
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                viewport = viewport.zoomed(to: value.magnification, about: value.startLocation)
            }
    }

    // MARK: - Geometry

    /// The world position of an item.
    private func worldPosition(of element: BoardElement) -> CGPoint {
        CGPoint(
            x: element.location.position.x ?? 0,
            y: element.location.position.y ?? 0
        )
    }

    /// The items on the visible part of the world.
    ///
    /// The cull: an item that is off screen is not drawn and not hit tested.
    /// A board with thousands of items is only fast because most of them are
    /// off screen.
    private func visibleElements(in size: CGSize) -> [BoardElement] {
        elements.filter { element in
            let position = worldPosition(of: element)
            let rect = CGRect(origin: position, size: cardSize)
            return viewport.isVisible(rect, in: size)
        }
    }

    /// The world extent the layer covers: enough to hold every item.
    private var worldExtent: CGSize {
        let maximumX = elements.map { $0.location.position.x ?? 0 }.max() ?? 0
        let maximumY = elements.map { $0.location.position.y ?? 0 }.max() ?? 0
        return CGSize(width: maximumX + cardSize.width, height: maximumY + cardSize.height)
    }
}
