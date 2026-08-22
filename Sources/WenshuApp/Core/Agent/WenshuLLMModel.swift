//
//  WenshuLLMModel.swift · Wenshu · v0.21 ticket 04 (Settings 模型配置)
//

import Foundation

/// MiniMax 模型枚举 (老板 2026-08-21 拍 '设置里加模型配置', 3 个 default model, 老板可后改)
public enum WenshuLLMModel: String, CaseIterable, Sendable {
    case m3 = "MiniMax-M3"
    case m2 = "MiniMax-M2"
    case reasoning = "MiniMax-Reasoning"

    /// Settings Picker 显示的 label (= rawValue, 配完不显, 老板原话)
    public var label: String { rawValue }

    /// v0.23 ticket 010.001: provider slug for routing.
    /// Maps each model to its provider's slug (used by WenshuVerifier.resolveCredentials
    /// to look up the correct apiKey + baseURL from Keychain + ProviderCatalog).
    /// Boss 2026-08-23 拍: 用户切 model 时主 + 子 agent 同步切,否则 mismatch 卡死.
    public var providerSlug: String {
        switch self {
        case .m3, .m2, .reasoning:
            return "minimax-cn"
        }
    }
}