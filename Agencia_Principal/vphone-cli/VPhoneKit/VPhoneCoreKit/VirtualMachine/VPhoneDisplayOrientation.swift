import CoreGraphics
import Foundation

// MARK: - Display Orientation

/// The guest interface orientation, and how the window shows it.
///
/// The guest frame buffer is always the portrait panel; a rotated interface
/// is drawn sideways into it, as on a real iPhone. The window turns the panel
/// the way the device was turned so the interface reads upright, and takes
/// the turned panel's aspect ratio.
public enum VPhoneDisplayOrientation: Int, CaseIterable, Sendable {
    case portrait = 0
    /// Interface landscape-left: the device turned clockwise.
    case landscapeLeft = 90
    case upsideDown = 180
    /// Interface landscape-right: the device turned counterclockwise.
    case landscapeRight = 270

    /// `degrees` as vphoned's `display.orientation` and `display.rotation`
    /// report it, clockwise from portrait. Any other value is nil.
    public init?(degrees: Int) {
        let normalized = ((degrees % 360) + 360) % 360
        self.init(rawValue: normalized)
    }

    /// The panel's rotation on the Mac, counterclockwise in degrees, as
    /// `NSView.frameCenterRotation` takes it: the device's clockwise turn.
    public var viewRotation: CGFloat {
        CGFloat((360 - rawValue) % 360)
    }

    /// The orientation after turning the device a quarter turn, as the
    /// Simulator's Rotate Left (⌘←) and Rotate Right (⌘→) do.
    public func turned(clockwise: Bool) -> VPhoneDisplayOrientation {
        VPhoneDisplayOrientation(degrees: rawValue + (clockwise ? 90 : -90)) ?? .portrait
    }

    public var isSideways: Bool {
        self == .landscapeLeft || self == .landscapeRight
    }

    /// The panel's size as the window shows it.
    public func displayedSize(panel: CGSize) -> CGSize {
        isSideways ? CGSize(width: panel.height, height: panel.width) : panel
    }

    // MARK: - Screen and Panel

    /// The orientation a view turned by `rotation` degrees counterclockwise
    /// shows, to the nearest quarter turn: the inverse of `viewRotation`.
    public init(viewRotation rotation: CGFloat) {
        let quarters = Int((rotation / 90).rounded())
        self = VPhoneDisplayOrientation(degrees: -quarters * 90) ?? .portrait
    }

    /// A direction as the window shows it, x right and y up, in the panel's
    /// own portrait coordinates, also y up. A trackpad gesture or a swipe
    /// described on screen goes through here before it moves a finger on the
    /// panel, or a vertical swipe on a sideways panel runs across it.
    public func panelVector(fromScreen vector: CGPoint) -> CGPoint {
        switch self {
        case .portrait: vector
        case .landscapeRight: CGPoint(x: vector.y, y: -vector.x)
        case .upsideDown: CGPoint(x: -vector.x, y: -vector.y)
        case .landscapeLeft: CGPoint(x: -vector.y, y: vector.x)
        }
    }

    /// A panel direction as the window shows it: the inverse of
    /// `panelVector(fromScreen:)`.
    public func screenVector(fromPanel vector: CGPoint) -> CGPoint {
        switch self {
        case .portrait: vector
        case .landscapeRight: CGPoint(x: -vector.y, y: vector.x)
        case .upsideDown: CGPoint(x: -vector.x, y: -vector.y)
        case .landscapeLeft: CGPoint(x: vector.y, y: -vector.x)
        }
    }

    /// A point on a `panel`-sized portrait panel, origin bottom left, as the
    /// window shows it, in `displayedSize(panel:)`'s coordinates.
    public func screenPoint(fromPanel point: CGPoint, panel: CGSize) -> CGPoint {
        let screen = displayedSize(panel: panel)
        let turned = screenVector(fromPanel: CGPoint(x: point.x - panel.width / 2, y: point.y - panel.height / 2))
        return CGPoint(x: turned.x + screen.width / 2, y: turned.y + screen.height / 2)
    }

    /// The panel point the window shows at `point`: the inverse of
    /// `screenPoint(fromPanel:panel:)`.
    public func panelPoint(fromScreen point: CGPoint, panel: CGSize) -> CGPoint {
        let screen = displayedSize(panel: panel)
        let turned = panelVector(fromScreen: CGPoint(x: point.x - screen.width / 2, y: point.y - screen.height / 2))
        return CGPoint(x: turned.x + panel.width / 2, y: turned.y + panel.height / 2)
    }

    // MARK: - Turning

    /// The largest size with the panel's aspect ratio whose box, turned by
    /// `angle` degrees, fits in `bounds`. Mid-turn the panel shrinks to stay
    /// inside the window, as a phone turned in front of you does.
    public static func fittedSize(panel: CGSize, angle: CGFloat, in bounds: CGSize) -> CGSize {
        guard panel.width > 0, panel.height > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let radians = angle * .pi / 180
        let cosine = abs(cos(radians)), sine = abs(sin(radians))
        let boxWidth = panel.width * cosine + panel.height * sine
        let boxHeight = panel.width * sine + panel.height * cosine
        let scale = min(bounds.width / boxWidth, bounds.height / boxHeight)
        return CGSize(width: panel.width * scale, height: panel.height * scale)
    }

    /// The angle to animate to from `current` so the panel takes the shorter
    /// way round to `target`; a half turn goes counterclockwise.
    public static func turnTarget(from current: CGFloat, to target: CGFloat) -> CGFloat {
        var delta = (target - current).truncatingRemainder(dividingBy: 360)
        if delta > 180 {
            delta -= 360
        }
        if delta <= -180 {
            delta += 360
        }
        return current + delta
    }

    /// Ease-in-out progress for a turn, 0 at the start and 1 at the end.
    public static func easedProgress(_ progress: Double) -> Double {
        let p = min(1, max(0, progress))
        return p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
    }

    /// The window content rect after turning to this orientation: the current
    /// rect's long side becomes the side this orientation makes long, around
    /// the same center, scaled down to fit `visible` when it would not.
    public func contentRect(from current: CGRect, panel: CGSize, within visible: CGRect) -> CGRect {
        let target = displayedSize(panel: panel)
        guard target.width > 0, target.height > 0 else { return current }
        let longSide = max(current.width, current.height)
        var scale = longSide / max(target.width, target.height)
        if visible.width > 0, visible.height > 0 {
            scale = min(scale, visible.width / target.width, visible.height / target.height)
        }
        let size = CGSize(width: (target.width * scale).rounded(), height: (target.height * scale).rounded())
        var rect = CGRect(x: current.midX - size.width / 2, y: current.midY - size.height / 2, width: size.width, height: size.height)
        if visible.width > 0, visible.height > 0 {
            rect.origin.x = min(max(rect.minX, visible.minX), visible.maxX - rect.width)
            rect.origin.y = min(max(rect.minY, visible.minY), visible.maxY - rect.height)
        }
        return rect
    }
}
