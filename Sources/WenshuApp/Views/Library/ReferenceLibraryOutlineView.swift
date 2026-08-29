// ReferenceLibraryOutlineView.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Second-column card grid for the library's ReferenceLibrary. Library-
// public (= per boss 2026-08-26 OOB: '明代调研可以跨书复用'; 1 single
// research source backs many books via cross-references).
//
// Implements the LLM Wiki 4-layer pattern (= raw / entities /
// abstracts / indexes per spec v5 L100-103 + boss 8/26 OOB 'LLM Wiki
// 格式'). v0.26 ships the raw + entities layer (user-facing); abstracts
// + indexes are LLM-derived hidden layers (v0.27+).
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 012.

import SwiftUI

struct ReferenceLibraryOutlineView: View {
    let store: ReferenceStoring

    @State private var selectedLayer: ReferenceLayer = .layerEntities
    @State private var references: [Reference] = []
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            layerTabs
            Divider()
            content
        }
        .frame(minWidth: 280, minHeight: 200)
        .onAppear(perform: reload)
        .onChange(of: selectedLayer) { _, _ in reload() }
    }

    // MARK: - Layer tabs

    @ViewBuilder
    private var layerTabs: some View {
        HStack(spacing: 0) {
            ForEach(ReferenceLayer.allCases.filter { $0.isUserFacing }, id: \.self) { layer in
                Button {
                    selectedLayer = layer
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: layer.icon)
                            .font(.body)
                        Text(layer.displayName)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .background(
                    selectedLayer == layer
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .foregroundStyle(selectedLayer == layer ? Color.accentColor : Color.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        Group {
            if let error = loadError {
                errorState(error)
            } else if references.isEmpty {
                emptyState
            } else {
                grid
            }
        }
    }

    @ViewBuilder
    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 12)],
                spacing: 12
            ) {
                ForEach(references) { reference in
                    ReferenceCard(reference: reference)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedLayer.icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(emptyText)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("用户导入的资料会出现在这里 (原始资料 层)。\n实体 层会显示 LLM 自动整理的实体 (v0.27+)")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("无法加载资料库")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyText: String {
        switch selectedLayer {
        case .layerRaw: return "资料库还没有原始资料"
        case .layerEntities: return "资料库还没有实体"
        default: return "该层暂无内容"
        }
    }

    private func reload() {
        do {
            references = try store.loadReferences(layer: selectedLayer)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct ReferenceCard: View {
    let reference: Reference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: reference.layer.icon)
                    .foregroundStyle(.tint)
                Text(reference.layer.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let source = reference.source, !source.isEmpty {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Text(reference.title)
                .font(.headline)
                .lineLimit(2)
            if !reference.summary.isEmpty {
                Text(reference.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if let url = reference.url, !url.isEmpty {
                Text(url)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.clear)
        )
    }
}