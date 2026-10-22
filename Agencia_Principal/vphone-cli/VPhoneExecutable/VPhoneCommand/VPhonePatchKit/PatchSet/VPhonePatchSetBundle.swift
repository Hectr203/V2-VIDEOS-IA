// VPhonePatchSetBundle.swift — Opening a `.vphonepatchset`.
//
// The layout, which is an ordinary macOS loadable bundle:
//
//     Example.vphonepatchset/
//       Contents/
//         Info.plist              CFBundleExecutable names the binary below
//         MacOS/Example           exports vphone_patch_set_principal,
//                                 linked against @rpath/VPhonePatchKit.framework
//         Resources/Manifest.plist
//         _CodeSignature/
//
// Everything a plan needs is in the manifest, and the manifest is read *before*
// any code from the set is loaded — so a set that conflicts, requires something
// absent or needs a newer PatchKit is refused without ever being mapped.
//
// The checks, in the order they run:
//
//   1. The path is a bundle with a readable `Contents/Resources/Manifest.plist`.
//   2. The manifest declares the identifier the preset pinned. A preset names both
//      identifier and path so that swapping the file at that path is an error
//      rather than a silent change of which patches apply.
//   3. This PatchKit is new enough for `MinimumPatchKitVersion`.
//   4. Every declared patch targets the boot chain. A guest-side patch would have
//      to run inside `cfw install`, which is the one privileged step — and it
//      loads no external set at all. Declaring one would promise a patch that
//      never runs.
//   5. The code signature is valid, strictly and including nested code. Ad hoc
//      counts: this proves the bundle has not changed since it was signed, not
//      who wrote it. `vphone-cli patchset import` is what ad hoc signs an
//      unsigned set, deliberately as a separate, explicit step.
//
// Only then is the executable mapped and its exported factory called.

import Foundation
import Security

// MARK: - Errors

public enum VPhonePatchSetError: Error, CustomStringConvertible, Sendable, Hashable {
    case notABundle(path: String)
    case manifestUnreadable(path: String, reason: String)
    case identifierMismatch(path: String, expected: String, found: String)
    case patchKitTooOld(patchSet: String, required: VPhoneVersion, available: VPhoneVersion)
    case notBootChainOnly(patchSet: String, patch: String, target: String)
    case signatureInvalid(path: String, reason: String)
    case unsigned(path: String)
    case principalMissing(path: String, symbol: String)
    case principalWrongType(path: String, type: String)
    case executableUnloadable(path: String, reason: String)
    case componentUnsupported(principal: String, component: String)

    public var description: String {
        switch self {
        case let .notABundle(path):
            "\(path) is not a .\(VPhonePatchSetBundle.pathExtension) bundle"
        case let .manifestUnreadable(path, reason):
            "\(path) has no readable \(VPhonePatchSetManifest.resourceName): \(reason)"
        case let .identifierMismatch(path, expected, found):
            "\(path) declares patch set \(found); the preset pinned \(expected)"
        case let .patchKitTooOld(patchSet, required, available):
            "Patch set \(patchSet) needs PatchKit \(required); this is \(available)"
        case let .notBootChainOnly(patchSet, patch, target):
            "Patch set \(patchSet) declares \(patch) for \(target). A loaded patch set can only"
                + " patch the boot chain: the guest half of an install runs as root and loads no"
                + " external set."
        case let .signatureInvalid(path, reason):
            "\(path) has an invalid code signature: \(reason)."
                + " Re-import it with `vphone-cli patchset import`."
        case let .unsigned(path):
            "\(path) is not signed. Run `vphone-cli patchset import \(path)` to ad hoc sign it."
        case let .principalMissing(path, symbol):
            "\(path) exports no \(symbol). A patch set defines it once with @_cdecl;"
                + " see VPhonePatchSetPrincipal."
        case let .principalWrongType(path, type):
            "\(path) returned a \(type), which is not a VPhonePatchSetPrincipal."
                + " It was probably built against a different VPhonePatchKit."
        case let .executableUnloadable(path, reason):
            "\(path) has no loadable executable: \(reason)"
        case let .componentUnsupported(principal, component):
            "\(principal) declares a patch for \(component) but builds no patcher for it"
        }
    }
}

// MARK: - Bundle

/// A patch set on disk, with its manifest read and nothing loaded yet.
public struct VPhonePatchSetBundle: Sendable {
    /// The extension a patch set carries.
    public static let pathExtension = "vphonepatchset"

    public let url: URL
    public let manifest: VPhonePatchSetManifest

    private init(url: URL, manifest: VPhonePatchSetManifest) {
        self.url = url
        self.manifest = manifest
    }

    // MARK: Inspect

    /// Read the manifest at `url` without loading any code.
    ///
    /// `~` is expanded, so a preset can name a set under the user's home without
    /// hardcoding it.
    public static func inspect(at url: URL) throws -> VPhonePatchSetBundle {
        let resolved = URL(
            fileURLWithPath: (url.path as NSString).expandingTildeInPath,
            isDirectory: true,
        )
        guard resolved.pathExtension == pathExtension,
              Bundle(url: resolved) != nil
        else {
            throw VPhonePatchSetError.notABundle(path: resolved.path)
        }
        do {
            return try VPhonePatchSetBundle(
                url: resolved,
                manifest: VPhonePatchSetManifest.read(fromBundle: resolved),
            )
        } catch {
            throw VPhonePatchSetError.manifestUnreadable(
                path: resolved.path,
                reason: "\(error)",
            )
        }
    }

    // MARK: Validate

    /// Every check that can be made before the executable is mapped.
    ///
    /// - Parameters:
    ///   - identifier: What the preset pinned, or nil when nothing pinned one
    ///     (`patchset info` on a file the user named directly).
    ///   - patchKitVersion: The API version to check the set against.
    ///   - requireSignature: False only for a set being examined *in order to*
    ///     sign it — `patchset import` reads the manifest of an unsigned bundle
    ///     before it signs one. Loading never passes false.
    public func validate(
        expecting identifier: String?,
        patchKitVersion: VPhoneVersion = .currentPatchKit,
        requireSignature: Bool = true,
    ) throws {
        if let identifier, manifest.identifier != identifier {
            throw VPhonePatchSetError.identifierMismatch(
                path: url.path,
                expected: identifier,
                found: manifest.identifier,
            )
        }
        guard manifest.minimumPatchKitVersion <= patchKitVersion else {
            throw VPhonePatchSetError.patchKitTooOld(
                patchSet: manifest.identifier,
                required: manifest.minimumPatchKitVersion,
                available: patchKitVersion,
            )
        }
        for patch in manifest.patches where !patch.target.isBootChain {
            throw VPhonePatchSetError.notBootChainOnly(
                patchSet: manifest.identifier,
                patch: patch.identifier,
                target: patch.target.description,
            )
        }
        if requireSignature {
            try requireValidSignature()
        }
    }

    /// The firmware components this set has an enabled patch for, in declared
    /// order and without repeats.
    ///
    /// The manifest decides which components the set's code is asked about, so a
    /// set whose patches are all off contributes no patcher at all — the same rule
    /// the bundled sets follow, and for the same reason: a patcher built anyway
    /// would emit records and an undeclared record applies.
    public func enabledComponents(in plan: VPhonePatchPlan) -> [VPhoneFirmwareComponent] {
        var components: [VPhoneFirmwareComponent] = []
        for patch in manifest.patches where plan.isEnabled(patch.identifier) {
            guard case let .firmware(component) = patch.target,
                  !components.contains(component)
            else { continue }
            components.append(component)
        }
        return components
    }

    // MARK: Signature

    /// Refuse anything but a signature that still matches the bytes on disk.
    ///
    /// Strict and nested, the same flags the Launchpad helper uses on a release
    /// bundle. Ad hoc passes: no designated requirement is checked, because a
    /// researcher's own patch set has no team to check it against. What this does
    /// prove is that the set has not been altered since it was signed, which is
    /// what makes `patchset import`'s pinned cdhash mean something.
    public func requireValidSignature() throws {
        var code: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(url as CFURL, [], &code)
        guard created == errSecSuccess, let code else {
            throw VPhonePatchSetError.unsigned(path: url.path)
        }
        let flags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode,
        )
        var failure: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(code, flags, nil, &failure)
        guard status != errSecSuccess else { return }
        let reason = failure.map { "\($0.takeRetainedValue())" }
            ?? "OSStatus \(status)"
        if status == errSecCSUnsigned {
            throw VPhonePatchSetError.unsigned(path: url.path)
        }
        throw VPhonePatchSetError.signatureInvalid(path: url.path, reason: reason)
    }

    /// The bundle's code-directory hash, hex, for pinning at import.
    public func codeDirectoryHash() throws -> String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code
        else {
            throw VPhonePatchSetError.unsigned(path: url.path)
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information,
        ) == errSecSuccess,
            let entries = information as? [String: Any],
            let hash = entries[kSecCodeInfoUnique as String] as? Data
        else {
            throw VPhonePatchSetError.unsigned(path: url.path)
        }
        return hash.hex
    }

    // MARK: Load

    /// Map the executable and call the set's exported factory.
    ///
    /// Call ``validate(expecting:patchKitVersion:requireSignature:)`` first. This
    /// is the step after which the set's own code is running, and there is no step
    /// after it that can take that back — a bundle is never unloaded, because Swift
    /// metadata from a dlclosed image would outlive the mapping. `dlopen` is
    /// therefore never paired with a `dlclose`, and a second call on an image
    /// already mapped simply returns its handle.
    public func loadPrincipal() throws -> VPhonePatchSetPrincipal {
        guard let bundle = Bundle(url: url),
              let executable = bundle.executableURL
        else {
            throw VPhonePatchSetError.notABundle(path: url.path)
        }
        guard let handle = dlopen(executable.path, RTLD_LAZY | RTLD_LOCAL) else {
            throw VPhonePatchSetError.executableUnloadable(
                path: executable.path,
                reason: dlerror().map { String(cString: $0) } ?? "dlopen failed",
            )
        }
        guard let symbol = dlsym(handle, vphonePatchSetPrincipalSymbol) else {
            throw VPhonePatchSetError.principalMissing(
                path: url.path,
                symbol: vphonePatchSetPrincipalSymbol,
            )
        }
        typealias Factory = @convention(c) () -> UnsafeMutableRawPointer
        let made = unsafeBitCast(symbol, to: Factory.self)()
        // Taken retained: the set's side handed over its reference. Checked rather
        // than assumed, because a set built against a different PatchKit would
        // return an object of a class this framework knows nothing about.
        let object = Unmanaged<AnyObject>.fromOpaque(made).takeRetainedValue()
        guard let principal = object as? VPhonePatchSetPrincipal else {
            throw VPhonePatchSetError.principalWrongType(
                path: url.path,
                type: String(reflecting: type(of: object)),
            )
        }
        return principal
    }
}
