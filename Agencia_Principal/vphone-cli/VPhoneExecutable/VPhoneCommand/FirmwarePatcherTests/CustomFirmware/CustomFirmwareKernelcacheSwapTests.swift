@testable import FirmwarePatcher
import Foundation
import Img4tool
import Testing
import VPhonePatchKit

/// Swapping a Preboot kernelcache's IM4P while keeping its signed IM4M, the
/// basis of `cfw update-kernel`. The pure function makes no disk or mount
/// assumptions, so it is tested directly with built IMG4/IM4P fixtures
/// (DERTestEncoder lives in CustomFirmwarePlistPatchTests.swift, same target).
@Suite("Preboot kernelcache swap")
struct CustomFirmwareKernelcacheSwapTests {
    private func im4p(_ fourcc: String, _ payload: [UInt8]) throws -> Data {
        try IM4P(fourcc: fourcc, description: "test", payload: Data(payload)).data
    }

    private func img4(im4p: Data, manifest: Data, restoreInfo: Data? = nil) -> Data {
        var elements = [DERTestEncoder.ia5String("IMG4"), im4p, DERTestEncoder.element(tag: 0xA0, value: manifest)]
        if let restoreInfo {
            elements.append(DERTestEncoder.element(tag: 0xA1, value: restoreInfo))
        }
        return DERTestEncoder.sequence(elements)
    }

    @Test
    func `the IM4P is replaced and the manifest and restore info are kept byte for byte`() throws {
        let manifest = Data((0 ..< 96).map { UInt8(truncatingIfNeeded: $0 * 7 + 3) })
        let restoreInfo = Data((0 ..< 32).map { UInt8(truncatingIfNeeded: $0 * 11 + 5) })
        let old = try im4p("krnl", Array(repeating: 0xAA, count: 4096))
        let new = try im4p("krnl", Array(repeating: 0xBB, count: 4096))
        let preboot = img4(im4p: old, manifest: manifest, restoreInfo: restoreInfo)

        let output = try #require(try CustomFirmwarePostRestoreDeviceTree.kernelcacheReplacingPayload(
            prebootIMG4: preboot, patchedKernelcache: new,
        ))
        let children = try DERTestEncoder.children(of: output)
        #expect(children.count == 4)
        #expect(children[0] == DERTestEncoder.ia5String("IMG4"))
        #expect(children[1] == new) // the patched IM4P, verbatim
        #expect(children[2] == DERTestEncoder.element(tag: 0xA0, value: manifest))
        #expect(children[3] == DERTestEncoder.element(tag: 0xA1, value: restoreInfo))
    }

    @Test
    func `an IMG4 source is accepted and only its IM4P is taken`() throws {
        let old = try im4p("krnl", Array(repeating: 0xAA, count: 2048))
        let new = try im4p("krnl", Array(repeating: 0xCC, count: 2048))
        let preboot = img4(im4p: old, manifest: Data(repeating: 1, count: 32))
        // The source is itself an IMG4 with a different manifest; its IM4P wins,
        // its manifest is ignored.
        let sourceIMG4 = img4(im4p: new, manifest: Data(repeating: 9, count: 48))

        let output = try #require(try CustomFirmwarePostRestoreDeviceTree.kernelcacheReplacingPayload(
            prebootIMG4: preboot, patchedKernelcache: sourceIMG4,
        ))
        let children = try DERTestEncoder.children(of: output)
        #expect(children[1] == new)
        #expect(children[2] == DERTestEncoder.element(tag: 0xA0, value: Data(repeating: 1, count: 32)))
    }

    @Test
    func `an identical kernelcache is a no-op`() throws {
        let kc = try im4p("krnl", Array(repeating: 0xAA, count: 1024))
        let preboot = img4(im4p: kc, manifest: Data(repeating: 2, count: 16))
        #expect(try CustomFirmwarePostRestoreDeviceTree.kernelcacheReplacingPayload(
            prebootIMG4: preboot, patchedKernelcache: kc,
        ) == nil)
    }

    @Test
    func `a non-kernel source is refused`() throws {
        let preboot = try img4(im4p: im4p("krnl", [1, 2, 3, 4]), manifest: Data(repeating: 3, count: 16))
        #expect(throws: PatcherError.self) {
            _ = try CustomFirmwarePostRestoreDeviceTree.kernelcacheReplacingPayload(
                prebootIMG4: preboot, patchedKernelcache: im4p("dtre", [1, 2, 3, 4]),
            )
        }
    }

    @Test
    func `a bare IM4P target is refused`() throws {
        let bare = try im4p("krnl", [1, 2, 3, 4])
        #expect(throws: PatcherError.self) {
            _ = try CustomFirmwarePostRestoreDeviceTree.kernelcacheReplacingPayload(
                prebootIMG4: bare, patchedKernelcache: im4p("krnl", [5, 6, 7, 8]),
            )
        }
    }
}
