//
//  CharacterRelationshipsViewState.swift · Wenshu
//
//  @Observable mirror for CharacterRelationshipsView. Mirrors
//  the per-view business state (= `relationships`,
//  `inconsistencies`, `characters`, `status`, `errorText`) so
//  the View holds a single @State binding. Form picker + input
//  drafts stay on the View per ADR-0009 §11.3.
//

import Foundation
import Observation

/// Business state mirror for `CharacterRelationshipsView`.
@Observable
final class CharacterRelationshipsViewState {
    var relationships: [CharacterRelationship] = []
    var inconsistencies: [RelationshipInconsistency] = []
    var characters: [Character] = []
    var status: SpecializedToolLoadStatus = .idle
    var errorText: String?

    init(
        relationships: [CharacterRelationship] = [],
        inconsistencies: [RelationshipInconsistency] = [],
        characters: [Character] = [],
        status: SpecializedToolLoadStatus = .idle,
        errorText: String? = nil
    ) {
        self.relationships = relationships
        self.inconsistencies = inconsistencies
        self.characters = characters
        self.status = status
        self.errorText = errorText
    }
}