// EnvironmentEntries.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Environment
// Responsibilities: 6 个 Service protocol 的 SwiftUI EnvironmentValues 注入点
// Inputs: (由 .environment(\.xxx, value) 注入)
// Outputs: 6 个可选 any-Protocol 字段
// Dependencies: 6 个 Service Protocol
// Threading: 任意 (SwiftUI EnvironmentValue 是值类型,跨 thread 安全)

import SwiftUI

/// B+ 重 (沿 DECISION §4.2 #5): SwiftUI Environment 注入 6 Service。
/// @Entry macro 是 macOS 14+/Swift 5.9+ Observation 框架提供。
/// 当前 Package.swift 平台 .macOS(.v27) ≥ 14,@Entry 可用。
///
/// 6 字段全部可选 (默认 nil),调用方需自己 unwrap — 保持现状的
/// 单例/顶层 @State 路径不变 (红线 #3 不破),只是新增薄包装。
extension EnvironmentValues {
    @Entry var projectService: (any ProjectService)? = nil
    @Entry var inspectorService: (any InspectorService)? = nil
    @Entry var chatService: (any ChatService)? = nil
    @Entry var layoutService: (any LayoutService)? = nil
    @Entry var selectionService: (any SelectionService)? = nil
    @Entry var llmService: (any LLMCompletionService)? = nil
}