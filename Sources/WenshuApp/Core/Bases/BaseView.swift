//
//  BaseView.swift · Wenshu · v0.19 ticket 18 (Obsidian replica, 前端做但不接入核心项目)
//

import Foundation
import SwiftUI

/// BaseViewModel: @MainActor Observable
@MainActor
@Observable
public final class BaseViewModel {
    public private(set) var document: BaseDocument = BaseDocument()
    public private(set) var yamlSource: String = ""
    public private(set) var error: String? = nil

    public init() {}

    /// 从 YAML 字符串加载
    public func load(yaml: String) {
        self.yamlSource = yaml
        do {
            self.document = try BaseParser.parse(yaml)
            self.error = nil
        } catch {
            self.error = "\(error)"
            self.document = BaseDocument()
        }
    }
}

/// BaseView: SwiftUI View, 显示 .base 文档 placeholder
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct BaseView: View {
    @State private var viewModel: BaseViewModel

    public init(viewModel: BaseViewModel = BaseViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Base")
                .font(.headline)
            Text("view 数: \(viewModel.document.viewCount)")
            Text("formula 数: \(viewModel.document.formulas.count)")
            if let error = viewModel.error {
                Text("错误: \(error)")
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
