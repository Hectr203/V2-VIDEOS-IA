// VPhonePatchSetPrincipal.swift — The class a `.vphonepatchset` exposes.
//
// This is the whole code-side contract between the tool and an out-of-tree patch
// set. The set is a loadable macOS bundle exporting one C symbol,
// ``vphonePatchSetPrincipalSymbol``, which returns a ``VPhonePatchSetPrincipal``;
// the loader calls it and asks the result for one patcher per firmware component
// the set has an enabled patch for.
//
// Why an exported symbol and not `NSPrincipalClass`, which is how a macOS loadable
// bundle normally names its entry point: PatchKit is built for library evolution,
// so a class inheriting from ``VPhonePatchSetPrincipal`` has a resilient
// superclass and its metadata is initialized at first use rather than at image
// load. Such a class is not registered with the ObjC runtime when the bundle is
// mapped, so `NSClassFromString` — which is what `Bundle.principalClass` resolves
// `NSPrincipalClass` with — cannot find it, and `Bundle.principalClass` silently
// falls back to whichever class *was* registered. A `@_cdecl` symbol has none of
// that: it is a plain C entry point, and the metadata it needs is realized inside
// the set's own code where it belongs.
//
// Why one patcher per component rather than a list: the pipeline runs patchers in
// sequence over the same buffer, and it decides *which* components to ask about
// from the manifest, not from the code. A set whose patches the preset turned off
// is never asked, which mirrors the rule the bundled sets follow — a patcher whose
// whole set is out of the plan is not constructed, because its records would be
// declared by nothing and an undeclared record applies (see ``VPhonePatchGate``).
//
// The honest limit on all of this: a loaded set is code running in the patching
// process. ``VPhonePatchSetContext/gate`` is how its patches become blockable, and
// a patcher that ignores the gate applies regardless — nothing here can stop it,
// and no warning will fire, because its records *are* declared. The boundary that
// does hold is the signature check at load and the rule that root `cfw install`
// loads no external set at all.

import Foundation

// MARK: - Context

/// What a patch set is told about the firmware it is being run against.
public struct VPhonePatchSetContext: Sendable {
    /// The iPhone base `ProductVersion`, or nil when it could not be read.
    public let iOSBase: VPhoneVersion?
    /// The cloudOS `ProductVersion`, or nil when it could not be read.
    public let cloudOS: VPhoneVersion?
    /// Which patches the resolved plan turned on. A patcher assigns this to its
    /// own ``Patcher/gate`` so a per-VM checkmark reaches its patch sites.
    public let gate: VPhonePatchGate
    /// The preset's knobs, for a set that reads one.
    public let parameters: [String: String]
    /// Whether the run is printing per-patch detail.
    public let verbose: Bool

    public init(
        iOSBase: VPhoneVersion?,
        cloudOS: VPhoneVersion?,
        gate: VPhonePatchGate,
        parameters: [String: String] = [:],
        verbose: Bool = false,
    ) {
        self.iOSBase = iOSBase
        self.cloudOS = cloudOS
        self.gate = gate
        self.parameters = parameters
        self.verbose = verbose
    }
}

// MARK: - Principal

/// The symbol a `.vphonepatchset` exports, and the only name the loader looks for.
///
/// A set defines it once, at file scope:
///
///     @_cdecl("vphone_patch_set_principal")
///     public func makeExamplePatchSetPrincipal() -> UnsafeMutableRawPointer {
///         VPhonePatchSetPrincipal.export(VPhoneExamplePatchSet())
///     }
public let vphonePatchSetPrincipalSymbol = "vphone_patch_set_principal"

/// The base class a `.vphonepatchset` subclasses.
///
/// Subclasses add no initializer, so they inherit `init()`. Nothing here is
/// ObjC — see the file comment on why the entry point is a C symbol.
open class VPhonePatchSetPrincipal {
    public required init() {}

    /// Hand a principal to the loader, which takes ownership of the reference.
    ///
    /// The set's exported function returns a raw pointer because that is what a C
    /// entry point can return. Retaining here and releasing on the loader's side is
    /// the whole ownership story: the principal lives as long as the run, and the
    /// bundle is never unloaded anyway.
    public static func export(_ principal: VPhonePatchSetPrincipal) -> UnsafeMutableRawPointer {
        Unmanaged.passRetained(principal).toOpaque()
    }

    /// The patcher this set runs over `component`.
    ///
    /// Called once per component the set declares an enabled patch for, with the
    /// component's bytes as they stand after every earlier patcher. The returned
    /// patcher must hand its result back through ``BufferedPatcher/patchedData``;
    /// the pipeline cannot read a buffer it has no type for.
    ///
    /// The default throws, so a set that declares a patch for a component its code
    /// does not handle is a loud mismatch rather than a component silently left
    /// alone.
    open func makePatcher(
        for component: VPhoneFirmwareComponent,
        data _: Data,
        context _: VPhonePatchSetContext,
    ) throws -> any BufferedPatcher {
        throw VPhonePatchSetError.componentUnsupported(
            principal: String(describing: type(of: self)),
            component: component.rawValue,
        )
    }
}
