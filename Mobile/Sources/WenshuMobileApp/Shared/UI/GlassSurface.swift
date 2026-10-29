import SwiftUI

/// The surface a card is drawn on.
///
/// The system's own glass where the system offers it, and the system's
/// own material below that. One decision picks between the two, so every
/// surface in the app is drawn by the same rule.
enum GlassSurface: Equatable, Sendable {
    /// The system's own glass.
    case glass
    /// The system's own material.
    case material

    /// The surface for the given availability.
    ///
    /// The availability is the only input, so the decision is pure: both
    /// sides of the gate are provable without a device.
    static func decide(nativeAvailable: Bool) -> GlassSurface {
        nativeAvailable ? .glass : .material
    }

    /// Whether the system running the app offers the glass surface.
    ///
    /// The product ships on a floor below the system's glass, so the
    /// material is the surface on every system that does not offer it.
    static var nativeAvailable: Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        }
        return false
    }
}

extension View {
    /// Draws the surface behind the view.
    ///
    /// The system's own glass where the system offers it, the system's own
    /// material below that. One gate decides, so a card never picks a
    /// surface for itself.
    @ViewBuilder
    func glassSurface(_ shape: some Shape) -> some View {
        switch GlassSurface.decide(nativeAvailable: GlassSurface.nativeAvailable) {
        case .glass:
            // The compiler reaches the system's glass only through a
            // version check, so the check is repeated here; the gate
            // above already chose this branch, and the material below it
            // is the fallback if the two ever disagree.
            if #available(iOS 26.0, macOS 26.0, *) {
                glassEffect(.regular, in: shape)
            } else {
                background(.regularMaterial, in: shape)
            }
        case .material:
            background(.regularMaterial, in: shape)
        }
    }
}
