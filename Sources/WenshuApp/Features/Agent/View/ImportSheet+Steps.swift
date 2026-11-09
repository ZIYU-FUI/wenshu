// ImportSheet+Steps.swift · The two enums the import sheet's four-step
// wizard is built from. They live in an extension of `ImportSheet` (= the
// same nested types the sheet has always had), = = so `ImportSheet.WizardStep`
// and `ImportSheet.ImportDestination` keep naming exactly what they named
// before this file existed.
import SwiftUI

extension ImportSheet {
    /// The four-step wizard. Each step is a page the user can go back to in order
    /// to fix a setting, or forward from when they are ready.
    enum WizardStep: Int, CaseIterable, Identifiable {
        case configure = 0 // Step 1: pick the target (= source dir + file type + destination + book + AI level + concurrency)
        case running = 1 // Step 2: progress (= ProgressView + progressLabel + per-file strip)
        case results = 2 // Step 3: results (= per-file list + a retry per row + a way to re-research every failure)
        case done = 3 // Step 4: done (= a summary + a done button)

        var id: Int {
            rawValue
        }

        var label: String {
            switch self {
            case .configure: return "选目标"
            case .running: return "导入中"
            case .results: return "处理结果"
            case .done: return "完成"
            }
        }

        /// Apple HIG canonical: a SF Symbol per step (= the dot indicator uses a dot,
        /// and the current step uses the symbol with its tint).
        var iconName: String {
            switch self {
            case .configure: return "1.circle.fill"
            case .running: return "2.circle.fill"
            case .results: return "3.circle.fill"
            case .done: return "4.circle.fill"
            }
        }
    }

    /// The import destination. The reference library is one of them, and when the
    /// user names a library every file goes there.
    enum ImportDestination: String, CaseIterable, Identifiable, Sendable {
        /// Every file in the batch lands in the reference library (= the user picks
        /// the reference library, so there is no classification to do; the LLM just
        /// produces the title, the summary and the tags).
        case referenceLibrary
        /// Every file in the batch lands in the selected book's five folders (= the
        /// world, the characters, the outline, the chapters and the drafts).
        case book

        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .referenceLibrary: return "导入到资料库"
            case .book: return "导入到书"
            }
        }
    }
}
