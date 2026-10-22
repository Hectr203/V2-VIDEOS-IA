import AppKit
import ObjectiveC.runtime
import os

// MARK: - Frame Rate Meter

/// Counts the frames the guest presents to the host window.
///
/// Virtualization hands every guest frame to its framebuffer view through
/// `-[_VZFramebufferView presenter:didUpdateFrame:]`. The meter wraps that
/// method once, counts the call and passes it on unchanged, so the count is the
/// number of frames that reached the window, not a host refresh rate.
enum VPhoneFrameRateMeter {
    /// The frame update is a C++ `shared_ptr` the wrapper never looks at. Two
    /// pointer-sized arguments carry it whether the ABI passes it by reference
    /// or in a register pair.
    private typealias FrameUpdateIMP = @convention(c) (
        AnyObject, Selector, AnyObject, UnsafeRawPointer?, UnsafeRawPointer?,
    ) -> Void
    private typealias FrameUpdateBlock = @convention(block) (
        AnyObject, AnyObject, UnsafeRawPointer?, UnsafeRawPointer?,
    ) -> Void

    private static let frames = OSAllocatedUnfairLock(initialState: 0)

    private static var frameUpdateMethod: Method? {
        NSClassFromString("_VZFramebufferView").flatMap {
            class_getInstanceMethod($0, NSSelectorFromString("presenter:didUpdateFrame:"))
        }
    }

    /// False when this macOS has no such method. Looking does not install anything.
    static var isSupported: Bool {
        frameUpdateMethod != nil
    }

    /// Installs the counter on first use, so a window that never shows the rate
    /// leaves the framework untouched.
    static let isAvailable: Bool = {
        guard let method = frameUpdateMethod else {
            print("[display] Frame rate unavailable: no framebuffer frame callback on this macOS")
            return false
        }
        let selector = method_getName(method)
        let original = unsafeBitCast(method_getImplementation(method), to: FrameUpdateIMP.self)
        let block: FrameUpdateBlock = { view, presenter, update, control in
            frames.withLock { $0 += 1 }
            original(view, selector, presenter, update, control)
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
        return true
    }()

    /// The frames presented since the last call.
    static func takeFrameCount() -> Int {
        frames.withLock { count in
            defer { count = 0 }
            return count
        }
    }
}

/// Whether the window shows the guest's frame rate. Off unless asked for.
enum VPhoneFrameRateDisplay {
    private static let enabledKey = "frameRateDisplayEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}
