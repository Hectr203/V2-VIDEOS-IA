@testable import FirmwarePatcher
import Foundation
import Testing
import VPhonePatchKit

/// LLB's `/chosen/display-scale` store, on a fragment shaped like the
/// cloudOS 26.4 (23E5207q) `LLB.vresearch101.RELEASE` site at 0xB9C8.
@Suite("LLB display scale")
struct IBootDisplayScaleTests {
    /// Little-endian words, each checked against Capstone:
    ///
    ///     0x1000  adrp x8, #0x2000
    ///     0x1004  add  x8, x8, #0x10       ; "display-scale" at 0x2010
    ///     0x1008  nop
    ///     0x100c  ubfx w8, w20, #0x10, #8   ; the three words LLB has at 0xB9C8
    ///     0x1010  add  w8, w8, #1
    ///     0x1014  str  w8, [x0]
    static func image(storeIncrement: UInt32 = 0x1100_0508) -> Data {
        var data = Data(count: 0x3000)
        let words: [UInt32] = [0xB000_0008, 0x9100_4108, 0xD503_201F, 0x5310_5E88, storeIncrement, 0xB900_0008]
        for (index, word) in words.enumerated() {
            withUnsafeBytes(of: word.littleEndian) { data.replaceSubrange(0x1000 + index * 4 ..< 0x1004 + index * 4, with: $0) }
        }
        let name = Data("display-scale\0".utf8)
        data.replaceSubrange(0x2010 ..< 0x2010 + name.count, with: name)
        return data
    }

    @Test func `the increment becomes the guest's scale`() throws {
        let patcher = IBootPatcher(data: Self.image(), mode: .llb, verbose: false)
        patcher.patchDisplayScale(2)
        let record = try #require(patcher.patches.first)
        #expect(patcher.patches.count == 1)
        #expect(record.patchID == "llb-cfw-display_scale")
        #expect(record.fileOffset == 0x1010)
        #expect(record.patchedBytes == ARM64Encoder.encodeMovzW(rd: 8, imm16: 2))
    }

    @Test func `a different computation is left alone`() {
        // `add w8, w8, #2` is not the scale-minus-one encoding the patch knows.
        let patcher = IBootPatcher(data: Self.image(storeIncrement: 0x1100_0908), mode: .llb, verbose: false)
        patcher.patchDisplayScale(2)
        #expect(patcher.patches.isEmpty)
    }

    @Test func `the patch is declared`() {
        let declared = FirmwareBootChainPatchSet.manifest.patches.map(\.identifier)
        #expect(declared.contains("llb-cfw-display_scale"))
    }
}
