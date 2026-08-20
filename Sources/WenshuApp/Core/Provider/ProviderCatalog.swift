//
//  ProviderCatalog.swift · v0.21 ticket 01
//

import Foundation

public enum ProviderCatalog {
    public static func defaultModels(for slug: String) -> [String] {
        Provider.by(slug: slug)?.defaultModels ?? []
    }

    public static func provider(slug: String) -> Provider {
        Provider.by(slug: slug) ?? .minimaxCn
    }
}
