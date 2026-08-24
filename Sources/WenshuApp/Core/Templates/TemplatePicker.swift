//
//  TemplatePicker.swift · Wenshu · v0.19 ticket 15 (Obsidian replica, 前端做但不接入核心项目)
//

import Foundation
import SwiftUI

/// TemplateViewModel: @MainActor Observable
@MainActor
@Observable
public final class TemplateViewModel {
    public private(set) var template: String = ""
    public private(set) var rendered: String = ""
    public private(set) var title: String = ""
    public private(set) var error: String? = nil

    public init() {}

    /// 加载模板
    public func load(template: String, title: String = "Untitled") {
        self.template = template
        self.title = title
        self.error = nil
    }

    /// 渲染当前模板
    public func render() {
        let context = TemplateContext(title: title)
        do {
            self.rendered = TemplateEngine.render(template, context: context)
            self.error = nil
        }
    }
}

/// TemplatePicker: SwiftUI View, 显示模板 + 渲染结果 placeholder
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct TemplatePicker: View {
    @State private var viewModel: TemplateViewModel

    public init(viewModel: TemplateViewModel = TemplateViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("模板")
                .font(.headline)
            Text("模板字符数: \(viewModel.template.count)")
            Text("渲染字符数: \(viewModel.rendered.count)")
            if let error = viewModel.error {
                Text("错误: \(error)")
                    .foregroundStyle(.red)
            }
            ScrollView {
                Text(viewModel.rendered.isEmpty ? "(未渲染)" : viewModel.rendered)
                    .font(.caption.monospaced())
            }
        }
        .padding()
    }
}
