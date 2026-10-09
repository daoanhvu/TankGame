import SpriteKit

/// The glyphs on the command bar, drawn as paths.
///
/// Images would be the obvious thing, but UI overlays in this game are drawn in
/// code so they retheme with `BoardTheme` and never go missing from a bundle.
/// Each icon is built inside a circle of `radius`, centred on (0, 0), so the
/// bar can lay them out without measuring.
public enum CommandIcon: Sendable {
    /// Firing: a reticle.
    case attack
    /// Holding position: a clock face.
    case wait
    /// Dropping the plan: a cross.
    case cancel
    /// Skipping the turn: a double chevron.
    case pass

    /// The icon as a stroked node in one color, since a command's icon and its
    /// caption always read as a single unit.
    @MainActor
    public func node(radius: CGFloat, color: SKColor, lineWidth: CGFloat = 1.6) -> SKNode {
        let group = SKNode()

        func stroke(_ path: CGPath, width: CGFloat = lineWidth) {
            let shape = SKShapeNode(path: path)
            shape.strokeColor = color
            shape.lineWidth = width
            shape.lineCap = .round
            shape.lineJoin = .round
            shape.fillColor = .clear
            group.addChild(shape)
        }

        let ring = CGMutablePath()
        ring.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))

        switch self {
        case .attack:
            stroke(ring)
            // Ticks breaking the ring at the four compass points, plus a pip.
            let marks = CGMutablePath()
            for (dx, dy) in [(0.0, 1.0), (0.0, -1.0), (1.0, 0.0), (-1.0, 0.0)] {
                marks.move(to: CGPoint(x: radius * 0.55 * dx, y: radius * 0.55 * dy))
                marks.addLine(to: CGPoint(x: radius * 1.35 * dx, y: radius * 1.35 * dy))
            }
            stroke(marks)
            let pip = SKShapeNode(circleOfRadius: radius * 0.16)
            pip.fillColor = color
            pip.lineWidth = 0
            group.addChild(pip)

        case .wait:
            stroke(ring)
            let hands = CGMutablePath()
            hands.move(to: CGPoint(x: 0, y: radius * 0.5))
            hands.addLine(to: .zero)
            hands.addLine(to: CGPoint(x: radius * 0.42, y: 0))
            stroke(hands)

        case .cancel:
            stroke(ring)
            let cross = CGMutablePath()
            let arm = radius * 0.42
            cross.move(to: CGPoint(x: -arm, y: -arm))
            cross.addLine(to: CGPoint(x: arm, y: arm))
            cross.move(to: CGPoint(x: -arm, y: arm))
            cross.addLine(to: CGPoint(x: arm, y: -arm))
            stroke(cross)

        case .pass:
            stroke(ring)
            let chevrons = CGMutablePath()
            for offset in [-radius * 0.34, radius * 0.1] {
                chevrons.move(to: CGPoint(x: offset, y: radius * 0.34))
                chevrons.addLine(to: CGPoint(x: offset + radius * 0.34, y: 0))
                chevrons.addLine(to: CGPoint(x: offset, y: -radius * 0.34))
            }
            stroke(chevrons)
        }

        return group
    }
}
