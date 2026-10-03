//
//  TagManagerViewState.swift · Wenshu
//
//  @Observable mirror for TagManagerView. Mirrors the per-view
//  business state (= `tags`, `applications`, `cloud`,
//  `filterMatches`, `status`, `errorText`) so the View holds a
//  single @State binding instead of N independent @State fields.
//  Form draft state (= picker text, draft label, etc.) stays on
//  the View as transient UI state per ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `TagManagerView`. The View's transient
/// form drafts (= `draftLabel`, `draftFilterTarget`, etc.) stay on
/// the View (= per §11.3 = binding resets, not business rules).
@Observable
final class TagManagerViewState {
    var tags: [Tag] = []
    var applications: [TagApplication] = []
    var cloud: [TagCloudEntry] = []
    var filterMatches: [UUID] = []
    var status: SpecializedToolLoadStatus = .idle
    var errorText: String?

    init(
        tags: [Tag] = [],
        applications: [TagApplication] = [],
        cloud: [TagCloudEntry] = [],
        filterMatches: [UUID] = [],
        status: SpecializedToolLoadStatus = .idle,
        errorText: String? = nil
    ) {
        self.tags = tags
        self.applications = applications
        self.cloud = cloud
        self.filterMatches = filterMatches
        self.status = status
        self.errorText = errorText
    }
}