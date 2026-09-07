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

    /// Load Template
    public func load(template: String, title: String = "Untitled") {
        self.template = template
        self.title = title
        self.error = nil
    }

    /// Render the current template
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
            Text(WenshuI18n.t("auto.templatepicker.l47.h75489066"))
                .font(.headline)
            Text(WenshuI18n.t("auto.templatepicker.l49.h95489952"))
            Text(WenshuI18n.t("auto.templatepicker.l50.h148968"))
            if let error = viewModel.error {
                Text(WenshuI18n.t("auto.templatepicker.l52.h3674797"))
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
