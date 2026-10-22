import CoreGraphics
import Testing
@testable import VPhoneCoreKit

struct DisplayOrientationTests {
    static let panel = CGSize(width: 393, height: 852)
    static let screen = CGRect(x: 0, y: 0, width: 1512, height: 944)

    // MARK: - Degrees

    @Test func `vphoned degrees map to orientations`() {
        #expect(VPhoneDisplayOrientation(degrees: 0) == .portrait)
        #expect(VPhoneDisplayOrientation(degrees: 90) == .landscapeLeft)
        #expect(VPhoneDisplayOrientation(degrees: 180) == .upsideDown)
        #expect(VPhoneDisplayOrientation(degrees: 270) == .landscapeRight)
        #expect(VPhoneDisplayOrientation(degrees: -90) == .landscapeRight)
        #expect(VPhoneDisplayOrientation(degrees: 450) == .landscapeLeft)
        #expect(VPhoneDisplayOrientation(degrees: 45) == nil)
    }

    /// The Mac repeats the device's clockwise turn; NSView rotation counts
    /// counterclockwise.
    @Test func `the view turns the way the device turned`() {
        #expect(VPhoneDisplayOrientation.portrait.viewRotation == 0)
        #expect(VPhoneDisplayOrientation.landscapeLeft.viewRotation == 270)
        #expect(VPhoneDisplayOrientation.upsideDown.viewRotation == 180)
        #expect(VPhoneDisplayOrientation.landscapeRight.viewRotation == 90)
    }

    @Test func `rotate right turns clockwise and rotate left undoes it`() {
        #expect(VPhoneDisplayOrientation.portrait.turned(clockwise: true) == .landscapeLeft)
        #expect(VPhoneDisplayOrientation.landscapeLeft.turned(clockwise: true) == .upsideDown)
        #expect(VPhoneDisplayOrientation.landscapeRight.turned(clockwise: true) == .portrait)
        #expect(VPhoneDisplayOrientation.portrait.turned(clockwise: false) == .landscapeRight)
        for orientation in VPhoneDisplayOrientation.allCases {
            #expect(orientation.turned(clockwise: true).turned(clockwise: false) == orientation)
        }
    }

    @Test func `only landscape swaps the panel's sides`() {
        #expect(VPhoneDisplayOrientation.portrait.displayedSize(panel: Self.panel) == Self.panel)
        #expect(VPhoneDisplayOrientation.upsideDown.displayedSize(panel: Self.panel) == Self.panel)
        let sideways = CGSize(width: 852, height: 393)
        #expect(VPhoneDisplayOrientation.landscapeLeft.displayedSize(panel: Self.panel) == sideways)
        #expect(VPhoneDisplayOrientation.landscapeRight.displayedSize(panel: Self.panel) == sideways)
    }

    // MARK: - Screen and Panel

    @Test func `a view's turn reads back as its orientation`() {
        for orientation in VPhoneDisplayOrientation.allCases {
            #expect(VPhoneDisplayOrientation(viewRotation: orientation.viewRotation) == orientation)
        }
        // Mid-turn, the nearest quarter turn.
        #expect(VPhoneDisplayOrientation(viewRotation: 80) == .landscapeRight)
        #expect(VPhoneDisplayOrientation(viewRotation: -95) == .landscapeLeft)
        #expect(VPhoneDisplayOrientation(viewRotation: 350) == .portrait)
    }

    /// Landscape right: the panel is turned a quarter turn counterclockwise,
    /// so the interface's top is the panel's right edge.
    @Test func `an upward swipe on a sideways panel runs toward its top edge`() {
        let up = CGPoint(x: 0, y: 10)
        #expect(VPhoneDisplayOrientation.portrait.panelVector(fromScreen: up) == up)
        #expect(VPhoneDisplayOrientation.landscapeRight.panelVector(fromScreen: up) == CGPoint(x: 10, y: 0))
        #expect(VPhoneDisplayOrientation.landscapeLeft.panelVector(fromScreen: up) == CGPoint(x: -10, y: 0))
        #expect(VPhoneDisplayOrientation.upsideDown.panelVector(fromScreen: up) == CGPoint(x: 0, y: -10))
    }

    @Test func `screen and panel directions undo each other`() {
        let vector = CGPoint(x: 3, y: -7)
        for orientation in VPhoneDisplayOrientation.allCases {
            #expect(orientation.screenVector(fromPanel: orientation.panelVector(fromScreen: vector)) == vector)
        }
    }

    /// Landscape right shows the panel's right edge as the window's top, and
    /// its bottom edge as the window's right.
    @Test func `panel points land where the turned window shows them`() {
        let panel = CGSize(width: 1032, height: 1376)
        let landscape = VPhoneDisplayOrientation.landscapeRight
        #expect(landscape.screenPoint(fromPanel: CGPoint(x: 1032, y: 688), panel: panel) == CGPoint(x: 688, y: 1032))
        #expect(landscape.screenPoint(fromPanel: CGPoint(x: 516, y: 0), panel: panel) == CGPoint(x: 1376, y: 516))
        #expect(landscape.panelPoint(fromScreen: CGPoint(x: 0, y: 516), panel: panel) == CGPoint(x: 516, y: 1376))
        for orientation in VPhoneDisplayOrientation.allCases {
            let point = CGPoint(x: 100, y: 300)
            #expect(orientation.panelPoint(fromScreen: orientation.screenPoint(fromPanel: point, panel: panel), panel: panel) == point)
        }
        #expect(VPhoneDisplayOrientation.portrait.screenPoint(fromPanel: CGPoint(x: 5, y: 9), panel: panel) == CGPoint(x: 5, y: 9))
    }

    // MARK: - Turning

    @Test func `the panel fills the window at rest`() {
        let upright = VPhoneDisplayOrientation.fittedSize(panel: Self.panel, angle: 0, in: Self.panel)
        #expect(abs(upright.width - 393) < 1e-6 && abs(upright.height - 852) < 1e-6)
        let sideways = VPhoneDisplayOrientation.fittedSize(
            panel: Self.panel, angle: 90, in: CGSize(width: 852, height: 393),
        )
        #expect(abs(sideways.width - 393) < 1e-6 && abs(sideways.height - 852) < 1e-6)
    }

    @Test func `mid-turn the panel shrinks to stay inside and keeps its shape`() {
        let bounds = CGSize(width: 622, height: 622)
        let size = VPhoneDisplayOrientation.fittedSize(panel: Self.panel, angle: 45, in: bounds)
        let root = 0.5.squareRoot()
        #expect((size.width + size.height) * root <= 622 + 1e-6)
        #expect(abs(size.width / size.height - 393.0 / 852.0) < 1e-9)
    }

    @Test func `turns take the short way round`() {
        #expect(VPhoneDisplayOrientation.turnTarget(from: 0, to: 270) == -90)
        #expect(VPhoneDisplayOrientation.turnTarget(from: 0, to: 90) == 90)
        #expect(VPhoneDisplayOrientation.turnTarget(from: 270, to: 0) == 360)
        #expect(VPhoneDisplayOrientation.turnTarget(from: 0, to: 180) == 180)
        // A turn redirected halfway continues from where it is drawn.
        #expect(VPhoneDisplayOrientation.turnTarget(from: -45, to: 90) == 90)
    }

    @Test func `easing starts and ends at rest`() {
        #expect(VPhoneDisplayOrientation.easedProgress(0) == 0)
        #expect(VPhoneDisplayOrientation.easedProgress(1) == 1)
        #expect(VPhoneDisplayOrientation.easedProgress(0.5) == 0.5)
        #expect(VPhoneDisplayOrientation.easedProgress(-1) == 0)
        #expect(VPhoneDisplayOrientation.easedProgress(2) == 1)
        #expect(VPhoneDisplayOrientation.easedProgress(0.1) < 0.1)
    }

    // MARK: - Window

    @Test func `turning keeps the long side and the center`() {
        let portrait = CGRect(x: 400, y: 50, width: 393, height: 852)
        let rect = VPhoneDisplayOrientation.landscapeLeft.contentRect(
            from: portrait, panel: Self.panel, within: Self.screen,
        )
        #expect(rect.size == CGSize(width: 852, height: 393))
        #expect(abs(rect.midX - portrait.midX) <= 0.5 && abs(rect.midY - portrait.midY) <= 0.5)
    }

    @Test func `turning back restores portrait`() {
        let landscape = CGRect(x: 170, y: 280, width: 852, height: 393)
        let rect = VPhoneDisplayOrientation.portrait.contentRect(
            from: landscape, panel: Self.panel, within: Self.screen,
        )
        #expect(rect.size == CGSize(width: 393, height: 852))
    }

    @Test func `a turned window too large for the screen shrinks to fit`() {
        let tall = CGRect(x: 0, y: 0, width: 800, height: 1734)
        let small = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let rect = VPhoneDisplayOrientation.landscapeRight.contentRect(from: tall, panel: Self.panel, within: small)
        #expect(rect.width <= 1200 && rect.height <= 800)
        #expect(abs(rect.width / rect.height - 852.0 / 393.0) < 0.01)
        #expect(small.contains(rect))
    }

    @Test func `a turned window stays on the screen`() {
        let nearEdge = CGRect(x: 0, y: 0, width: 393, height: 852)
        let rect = VPhoneDisplayOrientation.landscapeLeft.contentRect(
            from: nearEdge, panel: Self.panel, within: Self.screen,
        )
        #expect(Self.screen.contains(rect))
    }

    @Test func `a portrait window left portrait is unchanged`() {
        let portrait = CGRect(x: 400, y: 50, width: 393, height: 852)
        let rect = VPhoneDisplayOrientation.portrait.contentRect(from: portrait, panel: Self.panel, within: Self.screen)
        #expect(rect == portrait)
    }
}
