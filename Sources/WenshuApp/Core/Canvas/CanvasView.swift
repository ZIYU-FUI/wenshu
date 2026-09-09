//
// CanvasView.swift · Wenshu · v0.19 ticket 13 (Obsidian replica,)
// 2026-08-19 evening '.
//
// Standalone SwiftUI View + ViewModel, LayoutShellView, wait macOS.
// ViewModel + View placeholder (ticket 12 BacklinksPanel).
//

import Foundation
import SwiftUI

/// CanvasViewModel: @MainActor Observable
@MainActor
@Observable
public final class CanvasViewModel {
    public private(set) var document: CanvasDocument = CanvasDocument()
    public private(set) var isLoading: Bool = false
    public private(set) var error: String? = nil

    public init() {}

    /// .canvas filepathload
    public func load(path: String) async {
        self.isLoading = true
        self.error = nil
        defer { self.isLoading = false }

        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            self.document = try JSONCanvasCodec.decode(data)
        } catch {
            self.error = "\(error)"
            self.document = CanvasDocument()
        }
    }

    /// load (test)
    public func loadFromString(_ content: String) {
        self.error = nil
        do {
            self.document = try JSONCanvasCodec.decode(content)
        } catch {
            self.error = "\(error)"
            self.document = CanvasDocument()
        }
    }
}

/// CanvasView: SwiftUI View, show .canvas file (node + edge placeholder)
/// LayoutShellView, standalone wait macOS
public struct CanvasView: View {
    @State private var viewModel: CanvasViewModel

    public init(viewModel: CanvasViewModel = CanvasViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WenshuI18n.t("auto.canvasview.l61.h64266395"))
                .font(.headline)
            if viewModel.isLoading {
                Text(WenshuI18n.t("auto.canvasview.l64.h85778528"))
            } else if let error = viewModel.error {
                Text(WenshuI18n.t("auto.canvasview.l66.h21332939"))
                    .foregroundStyle(.red)
            } else {
                Text(WenshuI18n.t("canvasview.nodes_count"))
                Text(WenshuI18n.t("canvasview.edges_count"))
                ForEach(viewModel.document.nodes) { node in
                    Text(WenshuI18n.t("b5.canvasview.l72.h45596183"))
                        .font(.caption2)
                }
            }
        }
        .padding()
    }
}
