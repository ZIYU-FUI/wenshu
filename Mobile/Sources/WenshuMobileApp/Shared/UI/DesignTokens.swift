import SwiftUI

/// The one place a visual value is written down.
///
/// A view asks the token file for a spacing, a radius, a font or a
/// colour. A literal in a view is a defect the design sweep reports.
enum DesignTokens {
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 12
    static let spacingLarge: CGFloat = 20

    static let cornerRadiusCard: CGFloat = 8
    static let cornerRadiusControl: CGFloat = 6

    static let bodyFont = Font.system(.body)
    static let captionFont = Font.system(.caption)
    static let titleFont = Font.system(.title2, design: .default)
    static let glyphFont = Font.system(.largeTitle)

    static let accentColor = Color.accentColor
    static let primaryTextColor = Color.primary
    static let secondaryTextColor = Color.secondary
    static let errorColor = Color.red
}
