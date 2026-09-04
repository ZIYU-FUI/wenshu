// SmartQueryView.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Saved-search UI (= FCP Library Smart Collection analogue).
// v0.26 ships a static placeholder UI (= list + add/edit/delete);
// v0.27+ implements the actual search engine that evaluates the
// SmartQuery.queryJSON predicates against the library's entities.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 017.

import SwiftUI

struct SmartQueryView: View {
    /// All known saved searches (= loaded from
    /// <reference-library>/indexes/saved-searches/).
    @State private var queries: [SmartQuery] = []
    @State private var showCreateSheet: Bool = false
    @State private var newQueryName: String = ""

    /// Functional-injection: parent decides where to load/save
    /// (= ticket 019 BookStore @Environment; v0.26 uses a closure
    /// pattern since the storage layer is part of the future
    /// SmartQueryParser + LibraryIndexer work).
    var onLoadAll: (() -> [SmartQuery])?
    var onSave: ((SmartQuery) -> Void)?
    var onDelete: ((UUID) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("智能查询")
                    .font(.headline)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Label("新建", systemImage: "plus")
                }
                .controlSize(.small)
            }
            .padding()
            Divider()
            if queries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(minWidth: 280, minHeight: 200)
        .onAppear(perform: reload)
        .sheet(isPresented: $showCreateSheet) {
            createSheet
        }
    }

    @ViewBuilder
    private var list: some View {
        List(queries) { query in
            HStack {
                // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical.
                LucideIconSystemFallback("magnifyingglass.circle", size: 18)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(query.name)
                        .font(.headline)
                    Text("v0.27+ 启用")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .contextMenu {
                Button("删除", role: .destructive) {
                    delete(query)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical.
            LucideIconSystemFallback("magnifyingglass.circle", size: 48)
                .foregroundStyle(.tertiary)
            Text("还没有智能查询")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("v0.27+ 将启用搜索功能")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var createSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("新建智能查询")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                Section("名称") {
                    TextField("查询名称", text: $newQueryName)
                        .textFieldStyle(.roundedBorder)
                }
                Section {
                    Text("v0.27+ 将提供查询结构定义 (实体类型 + 名称匹配 + 关联过滤)。\nv0.26 阶段智能查询为占位功能。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消", role: .cancel) { showCreateSheet = false }
                Spacer()
                Button("保存") { create() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newQueryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 280, idealHeight: 340)
    }

    // MARK: - Actions

    private func reload() {
        queries = onLoadAll?() ?? []
    }

    private func create() {
        let trimmedName = newQueryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let query = SmartQuery(name: trimmedName)
        onSave?(query)
        showCreateSheet = false
        newQueryName = ""
        reload()
    }

    private func delete(_ query: SmartQuery) {
        onDelete?(query.id)
        reload()
    }
}