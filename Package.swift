// swift-tools-version: 6.4
//
// Package.swift · Wenshu (Wenshu) · v0.00.0 project baseline (2026-08-14 owner decision "bootstrap from 0.00.0")
//
// Source of truth: @AGENTS.md + @CLAUDE.md + @wenshu-pour/architecture/CONTEXT.md (= owner 11 decisions)
//
// Architecture: Swift/SwiftUI single-process macOS desktop app (= Apple ecosystem exclusive, v1 only macOS).
// v0.00.0 bootstrap = app entry point that opens a window; features follow via /to-tickets.

import PackageDescription

let package = Package(
    name: "Wenshu",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .executable(name: "WenshuApp", targets: ["WenshuApp"])
    ],
    dependencies: [
        // v0.00.0 bootstrap: no third-party deps. Add later via /to-tickets (LLM provider etc.)
    ],
    targets: [
        .executableTarget(
            name: "WenshuApp",
            path: "Sources/WenshuApp"
        )
        // v0.00.0 bootstrap: no testTarget (= /tdd added once 5-zone layout lands).
        // Owner 17:30: "minimal code". Tests added via /to-tickets + /tdd.
    ]
)