// DefaultInspectorService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Defaults
// Responsibilities: InspectorService 委派实现 — 透传到 InspectorViewModel.shared
// Inputs: 项目 id、AnnotationSnapshot
// Outputs: [AnnotationSnapshot]
// Dependencies: InspectorViewModel.shared (红线 #3)
// Threading: @MainActor (InspectorViewModel.shared 是 @MainActor)

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1 + 红线 #3): 委派不替代。 inspector
/// 标注的最小 stub — B+ 重阶段不实装 annotation 持久化,沿 inspector
/// VM 已暴露的 foreshadows + revisionCandidates 派生,直接返回空 list
/// 给 protocol 满足编译需要。
@MainActor
struct DefaultInspectorService: InspectorService {
    private let vm: InspectorViewModel

    init(vm: InspectorViewModel = .shared) {
        self.vm = vm
    }

    func loadAnnotations(projectId: UUID) async throws -> [AnnotationSnapshot] {
        // B+ 重 stub: 标注持久化不在本卡范围 (沿 AGENTS §5.2 schema = PM 拍)。
        // 触发 vm.loadForeshadows() 以满足 inspector tab 渲染依赖。
        await vm.loadForeshadows()
        return []
    }

    func saveAnnotation(_ annotation: AnnotationSnapshot) async throws {
        // B+ 重 stub: 等 PM 拍 annotation schema 后再实装。
        FileHandle.standardError.write(Data(
            "DefaultInspectorService.saveAnnotation: stub, ignored\n".utf8
        ))
    }
}