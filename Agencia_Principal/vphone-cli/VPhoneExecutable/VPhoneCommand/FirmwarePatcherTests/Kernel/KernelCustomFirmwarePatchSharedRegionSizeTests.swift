// KernelCustomFirmwarePatchSharedRegionSizeTests.swift — The shared region
// size patch against the block as it exists in both vphone600 26.4 variants.
//
// The five words below are the kernel's own bytes (verified against the
// research kernel at 0xfffffe0008e134e8 and the release kernel at
// 0xfffffe0008d0b4e8, byte-identical in both): the 26.4 compiler materialised
// 0x180000000 as an ORR logical-immediate alias (`mov x22, #0x180000000` — one
// movz cannot spell it, bits 31 and 32 straddle two 16-bit lanes), splatted it
// into the nesting pair with `dup v0.2d, x22`, stored the pair and
// re-materialised the same constant for the base register.
//
// The replacement words are keystone 0.9.2 (Homebrew `kstool`, outside this
// repository), the same provenance as the ARM64Encoder keystone-parity cases:
//
//     movz x22, #0xc000, lsl #16  = 16 00 b8 d2   (size low lane)
//     movk x22, #0x1, lsl #32     = 36 00 c0 f2   (size high lane → 0x1C0000000)
//     stp  x26, x22, [sp, #0x70]  = fa 5b 07 a9   (nesting pair {base, size})
//
// The third replacement word is not listed there: it is the kernel's own base
// instruction, copied verbatim by the patch. The trailing `b` is preserved
// too, so the test pins it.

@testable import FirmwarePatcher
import Foundation
import Testing
import VPhonePatchKit

@Suite("kernel-boot-shared_region_size")
struct KernelCustomFirmwarePatchSharedRegionSizeTests {
    // MARK: - Synthetic kernel

    /// `mov x22/x26, #0x180000000` — the ORR logical-immediate alias, exactly
    /// as the kernel encodes it (keystone: the same word with any other Rd
    /// differs only in bits 4:0).
    static let movRegionConstantX22: [UInt8] = [0xF6, 0x07, 0x61, 0xB2]
    static let movRegionConstantX26: [UInt8] = [0xFA, 0x07, 0x61, 0xB2]
    static let dupV0x22: [UInt8] = [0xC0, 0x0E, 0x08, 0x4E]
    static let strQ0Sp70: [UInt8] = [0xE0, 0x1F, 0x80, 0x3D]
    /// `b .+0x60` — closes the block; the patch must leave it alone.
    static let branchForward: [UInt8] = [0x18, 0x00, 0x00, 0x14]

    /// The four words the patch writes over the block: the size's two lanes
    /// (into the block's own size register), the kernel's own base word, and
    /// the pair store. Every word keystone-verified.
    static func expectedReplacement(sizeLo: [UInt8], sizeHi: [UInt8], baseInsn: [UInt8], stp: [UInt8]) -> [UInt8] {
        sizeLo + sizeHi + baseInsn + stp
    }

    /// A minimal arm64 kernel image: header + one `__TEXT_EXEC` segment whose
    /// text holds the shared region block. `blockOff` is where the block lands.
    static func kernel(withBlock block: [UInt8]) -> (data: Data, blockOff: Int) {
        let textStart = 0x100
        var text = [UInt8](repeating: 0xD4, count: 0x20) // UDF padding before
        let blockOff = textStart + text.count
        text += block
        text += [UInt8](repeating: 0xD4, count: 0x20) // UDF padding after
        while text.count % 0x100 != 0 {
            text.append(0xD4)
        }

        var image = Data()
        func append32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { image.append(contentsOf: $0) }
        }
        func append64(_ value: UInt64) {
            withUnsafeBytes(of: value.littleEndian) { image.append(contentsOf: $0) }
        }

        append32(0xFEED_FACF) // magic
        append32(0x0100_000C) // cputype: arm64
        append32(2) // cpusubtype: arm64e
        append32(2) // filetype
        append32(1) // ncmds
        append32(72) // sizeofcmds
        append32(0) // flags
        append32(0) // reserved
        // LC_SEGMENT_64 __TEXT_EXEC
        append32(0x19)
        append32(72)
        var segname = Data("__TEXT_EXEC".utf8).prefix(16)
        segname.append(contentsOf: [UInt8](repeating: 0, count: 16 - segname.count))
        image.append(segname)
        append64(0xFFFF_FE00_0700_4000) // vmaddr
        append64(UInt64(text.count)) // vmsize
        append64(UInt64(textStart)) // fileoff
        append64(UInt64(text.count)) // filesize
        append32(5) // maxprot r-x
        append32(5) // initprot r-x
        append32(0) // nsects
        append32(0) // flags

        image.append(contentsOf: [UInt8](repeating: 0, count: textStart - image.count))
        image.append(contentsOf: text)
        return (image, blockOff)
    }

    /// The block as the 26.4 kernel ships it.
    static var stockBlock: [UInt8] {
        movRegionConstantX22 + dupV0x22 + strQ0Sp70 + movRegionConstantX26 + branchForward
    }

    // MARK: - The patch

    @Test func `rewrites the block and preserves the branch`() throws {
        let (data, blockOff) = Self.kernel(withBlock: Self.stockBlock)
        let patcher = KernelCustomFirmwarePatcher(data: data, verbose: false)
        patcher.parseMachO()

        #expect(patcher.patchSharedRegionSize())

        let records = patcher.patches
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.patchID == "kernel-boot-shared_region_size")
        #expect(record.fileOffset == blockOff)

        // movz x22, #0xc000, lsl #16 and movk x22, #0x1, lsl #32 build the
        // 0x1C0000000 size; the kernel's own base word follows unchanged;
        // stp x26, x22, [sp, #0x70] stores the nesting pair {base, size}.
        let expected = Self.expectedReplacement(
            sizeLo: [0x16, 0x00, 0xB8, 0xD2],
            sizeHi: [0x36, 0x00, 0xC0, 0xF2],
            baseInsn: Self.movRegionConstantX26,
            stp: [0xFA, 0x5B, 0x07, 0xA9],
        )
        #expect(Array(patcher.patchedData[blockOff ..< (blockOff + 16)]) == expected)
        // The branch that closes the block is untouched.
        #expect(Array(patcher.patchedData[(blockOff + 16) ..< (blockOff + 20)]) == Self.branchForward)
    }

    @Test func `does not match a second time over patched bytes`() {
        let (data, _) = Self.kernel(withBlock: Self.stockBlock)
        let patcher = KernelCustomFirmwarePatcher(data: data, verbose: false)
        patcher.parseMachO()
        #expect(patcher.patchSharedRegionSize())

        // A fresh patcher over the patched image: the `dup` that carried the
        // single constant into both lanes is gone, so there is nothing to find.
        let second = KernelCustomFirmwarePatcher(data: patcher.patchedData, verbose: false)
        second.parseMachO()
        #expect(!second.patchSharedRegionSize())
        #expect(second.patches.isEmpty)
    }

    @Test func `refuses a block whose constant is not the stock region`() {
        // movz x22, #0x7000, lsl #16 (0xD2AE0016): a different constant, so the
        // window must not match even though the dup and the store are present.
        let other: [UInt8] = [0x16, 0x00, 0xAE, 0xD2]
        let block = other + Self.dupV0x22 + Self.strQ0Sp70 + Self.movRegionConstantX26 + Self.branchForward
        let (data, _) = Self.kernel(withBlock: block)
        let patcher = KernelCustomFirmwarePatcher(data: data, verbose: false)
        patcher.parseMachO()

        #expect(!patcher.patchSharedRegionSize())
        #expect(patcher.patches.isEmpty)
    }

    @Test func `follows the registers and displacement of the block`() {
        // The same shape with a different register allocation and pair slot —
        // x19 size, x20 base, pair at [sp, #0x80] — so the matcher cannot be
        // pinned to x22/x26/0x70. All words keystone-verified:
        //   mov x19, #0x180000000 / dup v1.2d, x19 / str q1, [sp, #0x80] /
        //   mov x20, #0x180000000 / stp x20, x19, [sp, #0x80]
        let block: [UInt8] = [
            0xF3, 0x07, 0x61, 0xB2,
            0x61, 0x0E, 0x08, 0x4E,
            0xE1, 0x23, 0x80, 0x3D,
            0xF4, 0x07, 0x61, 0xB2,
        ] + Self.branchForward
        let (data, blockOff) = Self.kernel(withBlock: block)
        let patcher = KernelCustomFirmwarePatcher(data: data, verbose: false)
        patcher.parseMachO()

        #expect(patcher.patchSharedRegionSize())
        #expect(patcher.patches.count == 1)
        // The size lanes follow x19 (movz x19, #0xc000, lsl #16 = 13 00 b8 d2,
        // movk x19, #0x1, lsl #32 = 33 00 c0 f2), the pair store keeps the
        // block's own registers and slot, and the kernel's base word is
        // copied verbatim.
        let expected = Self.expectedReplacement(
            sizeLo: [0x13, 0x00, 0xB8, 0xD2],
            sizeHi: [0x33, 0x00, 0xC0, 0xF2],
            baseInsn: [0xF4, 0x07, 0x61, 0xB2],
            stp: [0xF4, 0x4F, 0x08, 0xA9],
        )
        #expect(Array(patcher.patchedData[blockOff ..< (blockOff + 16)]) == expected)
    }

    // MARK: - The real kernel

    /// Runs the patch over a real vphone600 kernelcache (IM4P or raw) and
    /// pins the one record it must produce. Gated on `VPHONE_VP600_KERNEL`
    /// because the kernel is 30-odd MB of machine-local firmware; a machine
    /// without it skips. Both variants qualify — the block is byte-identical:
    ///
    ///     VPHONE_VP600_KERNEL=~/.vphone/machines/<vm>/FirmwareOriginals/\
    ///     <restore>/kernelcache.research.vphone600 xcodebuild … test
    @Test(.enabled(
        if: ProcessInfo.processInfo.environment["VPHONE_VP600_KERNEL"] != nil,
        "VPHONE_VP600_KERNEL is not set; point it at a kernelcache.*.vphone600 to run",
    ))
    func `patches a real vphone600 kernel`() throws {
        let path = try #require(ProcessInfo.processInfo.environment["VPHONE_VP600_KERNEL"])
        let (payload, _) = try IM4PHandler.load(contentsOf: URL(fileURLWithPath: path))

        let patcher = KernelCustomFirmwarePatcher(data: payload, verbose: true)
        patcher.parseMachO()
        #expect(patcher.patchSharedRegionSize())

        let record = try #require(patcher.patches.first)
        #expect(record.patchID == "kernel-boot-shared_region_size")

        // The record covers the whole four-instruction block: size low lane,
        // size high lane, the kernel's own base word, the pair store. The
        // original bytes are a `Data` slice whose indices may not start at 0,
        // so they are rebased through an Array before indexing; the base word
        // is the fourth original word — the rewrite moves it up one slot.
        let originalWords = Array(record.originalBytes)
        #expect(originalWords.count == 16)
        let expected = Self.expectedReplacement(
            sizeLo: [0x16, 0x00, 0xB8, 0xD2],
            sizeHi: [0x36, 0x00, 0xC0, 0xF2],
            baseInsn: Array(originalWords[12 ..< 16]),
            stp: [0xFA, 0x5B, 0x07, 0xA9],
        )
        #expect(Array(record.patchedBytes) == expected)
        // And the branch after the block survived untouched, byte for byte
        // against the payload as loaded. `payloadBytes` is an Array so the
        // absolute file offsets index it directly.
        let payloadBytes = Array(payload)
        let patched = Array(patcher.patchedData)
        let after = patched[(record.fileOffset + 16) ..< (record.fileOffset + 20)]
        #expect(after == payloadBytes[(record.fileOffset + 16) ..< (record.fileOffset + 20)])
    }
}
