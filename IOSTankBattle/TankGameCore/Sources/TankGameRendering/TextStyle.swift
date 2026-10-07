import SpriteKit

#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
#endif

/// Resolves a font name from a list of candidates, so the game can ask for a
/// condensed military face and still render if the device does not ship it.
///
/// `SKLabelNode(fontNamed:)` silently falls back to an unpredictable default
/// when the name is unknown, which is how a careful layout turns into mush on
/// one device and not another. Asking the platform first keeps that honest.
public enum BoardFonts {

    /// Condensed, stencil-ish faces for headings, the turn banner and buttons.
    public static let display = [
        "DINCondensed-Bold",
        "AvenirNextCondensed-Bold",
        "HelveticaNeue-CondensedBold",
        "Helvetica-Bold",
    ]

    /// Technical numerals for HP, ammo and the round counter.
    public static let readout = [
        "DINAlternate-Bold",
        "AvenirNextCondensed-DemiBold",
        "HelveticaNeue-Medium",
        "Helvetica",
    ]

    @MainActor private static var resolved: [String: String] = [:]

    /// The first candidate this platform actually has, or the last one as a
    /// last resort.
    @MainActor public static func resolve(_ candidates: [String]) -> String {
        let key = candidates.joined(separator: "|")
        if let hit = resolved[key] { return hit }
        let name = candidates.first { PlatformFont(name: $0, size: 12) != nil }
            ?? candidates.last
            ?? "Helvetica"
        resolved[key] = name
        return name
    }
}

/// One piece of typography: a face, a size, a color, letter spacing and
/// whether the text is set in caps.
///
/// Every label in the game is built or updated through a `TextStyle`, which is
/// what keeps the HUD, the buttons and the end screen looking like one game
/// rather than four. Letter spacing needs `attributedText`, so this is also the
/// one place that knows about that trade-off (an attributed label ignores
/// `fontSize` and `fontColor`).
@MainActor
public struct TextStyle {
    public var fontCandidates: [String]
    public var size: CGFloat
    public var color: SKColor
    /// Extra points between glyphs. Wide tracking is what makes short caps
    /// labels read as stencilled markings rather than body text.
    public var tracking: CGFloat
    public var uppercase: Bool

    public init(fontCandidates: [String] = BoardFonts.display,
                size: CGFloat,
                color: SKColor,
                tracking: CGFloat = 0,
                uppercase: Bool = false) {
        self.fontCandidates = fontCandidates
        self.size = size
        self.color = color
        self.tracking = tracking
        self.uppercase = uppercase
    }

    public var fontName: String { BoardFonts.resolve(fontCandidates) }

    /// A copy at a different size, for the same voice at another scale.
    public func sized(_ newSize: CGFloat) -> TextStyle {
        var copy = self
        copy.size = newSize
        return copy
    }

    public func colored(_ newColor: SKColor) -> TextStyle {
        var copy = self
        copy.color = newColor
        return copy
    }

    public func makeLabel(_ text: String = "") -> SKLabelNode {
        let label = SKLabelNode(fontNamed: fontName)
        apply(to: label, text: text)
        return label
    }

    /// Sets `text` on an existing label in this style. Safe to call on every
    /// frame of a HUD refresh and safe to mix with styles that do not track.
    public func apply(to label: SKLabelNode, text: String) {
        let shown = uppercase ? text.uppercased() : text
        guard tracking != 0 else {
            // Plain text path: clear any attributed string a previous style set,
            // or the font/color below would be ignored.
            label.attributedText = nil
            label.fontName = fontName
            label.fontSize = size
            label.fontColor = color
            label.text = shown
            return
        }
        label.attributedText = attributed(shown)
    }

    public func attributed(_ text: String) -> NSAttributedString {
        let shown = uppercase ? text.uppercased() : text
        let font = PlatformFont(name: fontName, size: size)
            ?? PlatformFont.boldSystemFont(ofSize: size)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        if tracking != 0 { attributes[.kern] = tracking }
        return NSAttributedString(string: shown, attributes: attributes)
    }
}
