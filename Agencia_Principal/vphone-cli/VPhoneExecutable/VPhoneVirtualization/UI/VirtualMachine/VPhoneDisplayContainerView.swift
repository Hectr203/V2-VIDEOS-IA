import AppKit
import QuartzCore
import VPhoneCoreKit

// MARK: - Display Container

/// The window's content view. It holds the VM view turned to the guest's
/// interface orientation, at the panel's aspect ratio, as large as fits.
///
/// The VM view keeps its portrait bounds under the turn, so touch mapping,
/// which converts window points into those bounds, needs no change: AppKit's
/// conversion undoes the rotation.
final class VPhoneDisplayContainerView: NSView {
    let displayView: NSView
    /// The guest panel's size in points, portrait.
    var panelSize: NSSize = .zero {
        didSet { needsLayout = true }
    }

    private(set) var orientation: VPhoneDisplayOrientation = .portrait
    /// The drawn turn, counterclockwise in degrees. It differs from
    /// `orientation.viewRotation` only during a turn, and may leave 0...360.
    private var angle: CGFloat = 0
    private var turn: Turn?
    private var displayLink: CADisplayLink?

    private static let turnDuration: CFTimeInterval = 0.35

    /// One animated turn: the panel's angle and the window frame move
    /// together, so the window reshapes as the panel turns.
    private struct Turn {
        let fromAngle: CGFloat
        let toAngle: CGFloat
        let fromFrame: NSRect?
        let toFrame: NSRect?
        let start: CFTimeInterval
    }

    init(displayView: NSView) {
        self.displayView = displayView
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        displayView.autoresizingMask = []
        addSubview(displayView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Turning

    /// Turns to `orientation`, moving the window to `windowFrame` alongside.
    /// A turn already running continues from where it is drawn.
    func turn(to orientation: VPhoneDisplayOrientation, windowFrame: NSRect?, animated: Bool) {
        self.orientation = orientation
        let target = VPhoneDisplayOrientation.turnTarget(from: angle, to: orientation.viewRotation)
        guard animated, window?.isVisible == true else {
            finishTurn(angle: target, windowFrame: windowFrame)
            return
        }
        turn = Turn(
            fromAngle: angle,
            toAngle: target,
            fromFrame: windowFrame == nil ? nil : window?.frame,
            toFrame: windowFrame,
            start: CACurrentMediaTime(),
        )
        if displayLink == nil {
            let link = displayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let turn else {
            stopDisplayLink()
            return
        }
        let progress = (link.targetTimestamp - turn.start) / Self.turnDuration
        guard progress < 1 else {
            self.turn = nil
            stopDisplayLink()
            finishTurn(angle: turn.toAngle, windowFrame: turn.toFrame)
            return
        }
        let eased = CGFloat(VPhoneDisplayOrientation.easedProgress(progress))
        angle = turn.fromAngle + (turn.toAngle - turn.fromAngle) * eased
        if let from = turn.fromFrame, let to = turn.toFrame, let window {
            window.setFrame(Self.interpolate(from, to, eased), display: false)
        }
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func finishTurn(angle target: CGFloat, windowFrame: NSRect?) {
        angle = target.truncatingRemainder(dividingBy: 360)
        if angle < 0 {
            angle += 360
        }
        if let windowFrame, let window {
            window.setFrame(windowFrame, display: true)
        }
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private static func interpolate(_ from: NSRect, _ to: NSRect, _ t: CGFloat) -> NSRect {
        NSRect(
            x: (from.minX + (to.minX - from.minX) * t).rounded(),
            y: (from.minY + (to.minY - from.minY) * t).rounded(),
            width: (from.width + (to.width - from.width) * t).rounded(),
            height: (from.height + (to.height - from.height) * t).rounded(),
        )
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        let size = panelSize.width > 0
            ? VPhoneDisplayOrientation.fittedSize(panel: panelSize, angle: angle, in: bounds.size)
            : bounds.size
        // Sized unturned, then turned about its center.
        displayView.frameCenterRotation = 0
        displayView.frame = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height,
        )
        displayView.frameCenterRotation = angle
    }
}
