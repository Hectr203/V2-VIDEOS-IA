// CustomFirmwareVirtualAudioTests.swift — the no-default-VAD throw's anchor.

// The parity bar the other patcher suites hold — same bytes as a frozen
// reference on a pristine binary — needs `ipsws/ref_extract` fixtures this
// machine does not carry, so what is tested here is everything around that:
// the anchor refuses binaries that are not the shape it was told about, and
// the exception-size check is exactly the guard the patcher applies. The
// located-and-patched behaviour on both real builds (iPadOS 26.6.2 and
// iOS 27.0) was verified by hand while the patcher was written and is
// recorded in `Research/Guest/virtio_sound.md` — that covers the mute-set
// patch this suite's second half names.

@testable import FirmwarePatcher
import Foundation
import Testing
import VPhonePatchKit

@Suite("CustomFirmwareVirtualAudio")
struct CustomFirmwareVirtualAudioTests {
    /// Not a Mach-O at all.
    static let junk = Data(repeating: 0x41, count: 4096)

    @Test(
        arguments: [Self.junk, Data()],
    )
    func `a binary without the message is refused, not searched past`(_ input: Data) throws {
        var data = input
        #expect(throws: PatcherError.self) {
            try CustomFirmwareVirtualAudio.patch(
                &data,
                reattest: false,
                dryRun: true,
                log: nil,
            )
        }
    }

    @Test
    func `the message string is the anchor the records name`() {
        #expect(CustomFirmwareVirtualAudio.message == "No default VAD present")
        #expect(CustomFirmwareVirtualAudio.patchID == "system-virtualaudio-cfw-speaker_route_throws")
    }

    @Test(
        arguments: [Self.junk, Data()],
    )
    func `a binary without the mute-set log is refused, not searched past`(_ input: Data) throws {
        var data = input
        #expect(throws: PatcherError.self) {
            try CustomFirmwareVirtualAudio.patchMuteSet(
                &data,
                reattest: false,
                dryRun: true,
                log: nil,
            )
        }
    }

    @Test
    func `the mute-set anchor strings and record identity are stable`() {
        #expect(CustomFirmwareVirtualAudio.muteSetMessage == "Set mute value of %u on HAL device")
        #expect(CustomFirmwareVirtualAudio.muteSetException == "Unable to set property data.")
        #expect(CustomFirmwareVirtualAudio.muteSetPatchID == "system-virtualaudio-cfw-mute_set_throw")
    }

    @Test(
        arguments: [Self.junk, Data()],
    )
    func `a binary without the decline log is refused, not searched past`(_ input: Data) throws {
        var data = input
        #expect(throws: PatcherError.self) {
            try CustomFirmwareVirtualAudio.patchSpeakerProtectionGate(
                &data,
                reattest: false,
                dryRun: true,
                log: nil,
            )
        }
    }

    @Test
    func `the SP-gate anchor strings and record identity are stable`() {
        #expect(CustomFirmwareVirtualAudio.spGateMessage == "HAL Speaker Protection is missing. Failing route")
        #expect(CustomFirmwareVirtualAudio.spGateFile == "RoutingHandler_Playback_GenericConfig1.cpp")
        #expect(CustomFirmwareVirtualAudio.spGatePatchID == "system-virtualaudio-cfw-speaker_protection_gate")
    }

    @Test
    func `each SP-gate handler has its own file anchor and a record the declaration covers`() {
        typealias Handler = CustomFirmwareVirtualAudio.SPGateHandler
        #expect(Handler.allCases == [.playback, .playbackAndRecord])
        #expect(Handler.playback.file == CustomFirmwareVirtualAudio.spGateFile)
        #expect(Handler.playback.patchID == CustomFirmwareVirtualAudio.spGatePatchID)
        #expect(Handler.playbackAndRecord.file == "RoutingHandler_PlaybackAndRecord_GenericConfig1.cpp")
        // A site of the same declaration: only a dot starts one.
        #expect(Handler.playbackAndRecord.patchID
            == "system-virtualaudio-cfw-speaker_protection_gate.playback_and_record")
        // Neither file name may be found inside the other, or one handler's
        // anchor would qualify both.
        #expect(!Handler.playbackAndRecord.file.contains(Handler.playback.file))
        #expect(!Handler.playback.file.contains(Handler.playbackAndRecord.file))
    }

    @Test(
        arguments: [Self.junk, Data()],
    )
    func `a binary without the play-and-record decline is refused, not searched past`(_ input: Data) throws {
        var data = input
        #expect(throws: PatcherError.self) {
            try CustomFirmwareVirtualAudio.patchSpeakerProtectionGate(
                &data,
                handler: .playbackAndRecord,
                reattest: false,
                dryRun: true,
                log: nil,
            )
        }
    }

    @Test(
        arguments: [Self.junk, Data()],
    )
    func `a binary without the precondition decline is refused, not searched past`(_ input: Data) throws {
        var data = input
        #expect(throws: PatcherError.self) {
            try CustomFirmwareVirtualAudio.patchVolumeModePrecondition(
                &data,
                reattest: false,
                dryRun: true,
                log: nil,
            )
        }
    }

    @Test
    func `the volume-gate anchor strings and record identity are stable`() {
        #expect(CustomFirmwareVirtualAudio.volumePreconditionFormat == "PRECONDITION FAILURE (std::logic_error)")
        #expect(CustomFirmwareVirtualAudio.volumeModePackingMask == 0x1_FFFF_FFFF)
        #expect(CustomFirmwareVirtualAudio.volumeGatePatchID == "system-virtualaudio-cfw-volume_mode_precondition")
    }

    /// `tbz w21, #0, 0x136878` at 0x136620 — the real gate branch, read off
    /// the iPadOS 26.6.2 plugin binary this patch was written against (bytes
    /// d5 12 00 36 at that offset).
    @Test
    func `the conditional-branch decoder reads the real gate's target`() {
        #expect(
            CustomFirmwareVirtualAudio.decodeConditionalBranchTarget(
                insn: 0x3600_12D5,
                pc: 0x136620,
            ) == 0x136878,
        )
    }

    /// The 19-bit immediate must sign-extend, or a backward branch decodes
    /// up to 512 KB ahead instead of up to 256 KB back. The word is built
    /// from its fields — `b.eq` with every immediate bit set, i.e. −1 — not
    /// taken as a literal.
    @Test
    func `the 19-bit immediate sign-extends`() {
        let word: UInt32 = 0x5400_0000 | (0x7FFFF << 5) // b.eq, imm19 = −1
        #expect(
            CustomFirmwareVirtualAudio.decodeConditionalBranchTarget(
                insn: word,
                pc: 0x1000,
            ) == 0x0FFC,
        )
    }

    /// `tbz` reaches ±32 KB through a 14-bit immediate at bits 18-5, and a
    /// 64-bit `cbnz` proves the leading sf/b5 bit is not mistaken for part
    /// of the family. Both words are built from their fields.
    @Test
    func `the 14-bit and 64-bit families decode`() {
        // tbz w21, #0, imm14 = −1 (bits 30-25 = 011011, bit 24 = 0)
        let tbz: UInt32 = 0x3600_0000 | (0x3FFF << 5) | 21
        #expect(CustomFirmwareVirtualAudio.decodeConditionalBranchTarget(insn: tbz, pc: 0x1000) == 0x0FFC)
        // cbnz xzr, +0x40 (sf = 1, bit 24 = 1): top byte 1_011010_1
        let cbnz: UInt32 = 0xB500_0000 | (0x10 << 5) | 31
        #expect(CustomFirmwareVirtualAudio.decodeConditionalBranchTarget(insn: cbnz, pc: 0x2000) == 0x2040)
    }

    @Test
    func `the conditional-branch decoder refuses words outside its families`() {
        #expect(CustomFirmwareVirtualAudio.decodeConditionalBranchTarget(insn: 0xD503_201F, pc: 0) == nil)
        // A `b` — the family `ARM64Encoder.decodeBranchTarget` owns.
        #expect(CustomFirmwareVirtualAudio.decodeConditionalBranchTarget(insn: 0x1400_0002, pc: 0) == nil)
        // A PAUTH BC.cond — bit 24 set, a register operand, not an offset.
        #expect(CustomFirmwareVirtualAudio.decodeConditionalBranchTarget(insn: 0x5500_0FE0, pc: 0) == nil)
    }
}
