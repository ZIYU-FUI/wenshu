import SwiftUI

struct ProjectDetailView: View {
    let projectId: UUID
    @State private var selectedTab = 0
    var body: some View {
        VStack {
            Picker("", selection: $selectedTab) {
                Text("项目").tag(0); Text("章节").tag(1); Text("设定").tag(2); Text("资料").tag(3); Text("看板").tag(4)
            }.pickerStyle(.segmented).padding()
            if selectedTab < 2 {
                Text(selectedTab == 0 ? "项目 \(projectId.uuidString)" : "暂无章节").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { Text("此功能将在后续阶段开放").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.navigationTitle("项目详情")
    }
}
