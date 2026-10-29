import WenshuMobileKit

/// The flow's side of the pairing code.
///
/// The wire type is the kit's; this is how the app makes a code and how
/// it reads one back. A code is read aloud to the Mac's companion and
/// typed in there, so it is made of plain digits.
extension PairingCode {
    /// A fresh code: six digits a person can read aloud.
    static func make() -> PairingCode {
        let digits = (0..<6).map { _ in String(Int.random(in: 0...9)) }.joined()
        return PairingCode(value: digits)
    }

    /// Whether the code is one the flow can use: the kit's six-digit
    /// shape, in the plain digits a person reads aloud.
    ///
    /// The kit's own check takes any numeral, a fraction or a digit from
    /// another script included; a code a person reads aloud and types on
    /// the Mac is plain digits.
    var isPlainDigits: Bool {
        isWellFormed && value.allSatisfy(\.isASCII)
    }
}
