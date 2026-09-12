//
// BaseView.swift · Wenshu · v0.19 ticket 18 (Obsidian replica,)
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

    /// YAML load
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

/// BaseView: SwiftUI View, show .base placeholder
/// LayoutShellView, standalone wait macOS
public struct BaseView: View {
    @State private var viewModel: BaseViewModel

    public init(viewModel: BaseViewModel = BaseViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("auto.baseview.l42.h20177652"))
                .font(.headline)
            Text(WenshuI18n.t("baseview.views_count"))
            Text(WenshuI18n.t("baseview.formulas_count"))
            if let error = viewModel.error {
                Text(WenshuI18n.t("auto.baseview.l47.h33472306"))
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
