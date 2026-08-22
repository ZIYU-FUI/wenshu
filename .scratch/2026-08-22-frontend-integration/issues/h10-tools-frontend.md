# h10 — Agent toolkit dispatch (FileTools + ProcessTools + WebTools + VisionTools)

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend (all 4 done, v0.18 tickets 07/08/09/10):
>   - `Sources/WenshuApp/Core/Tools/FileTools.swift`
>   - `Sources/WenshuApp/Core/Tools/ProcessTools.swift`
>   - `Sources/WenshuApp/Core/Tools/WebTools.swift`
>   - `Sources/WenshuApp/Core/Tools/VisionTools.swift`
> 1 commit (consolidated). Leaf-level change only. **No UI** — agent toolkit dispatch.

Boss拍: "模块之间是有关联关系的, 不是每个模块都需要有前端入口, 有可能只是后端服务和调度". These 4 tools are services called by `WenshuConductor.invokeTool(name, input)` — user invokes via chat ("read this file"), agent dispatches. No UI affordance needed.

## What to build

Wire 4 tools into `WenshuConductor.invokeTool()` dispatch table.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — add 4 tool properties + dispatch:
   ```swift
   public func invokeTool(name: String, input: String) async throws -> String {
       switch name {
       case "file":    return try await fileTools.handle(input)
       case "process": return try await processTools.handle(input)
       case "web":     return try await webTools.handle(input)
       case "vision":  return try await visionTools.handle(input)
       default: throw WenshuLLMError.unknownTool(name)
       }
   }
   ```

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] WenshuConductor exposes `invokeTool(name, input)` 
- [ ] All 4 tools dispatchable
- [ ] `swift build` exit 0
- [ ] `swift test` 338 + new tests pass
- [ ] Code-review 2 axes

## Risks

- None — pure backend wiring