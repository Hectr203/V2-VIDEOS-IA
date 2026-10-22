// CustomFirmwareMicrophoneArrayTests.swift — no guest claims a microphone array.
//
// `withoutMicrophoneArrayClaims` (the Preboot repair) and
// `DeviceTreePatcher.removeMicrophoneArrayClaims` (what `fw patch` runs for
// every guest's tree) take `supports-spatial-audio-capture` and
// `supports-audio-mix` out of `/product/audio`: a VM's microphone is the Mac's,
// one or two channels, not the array those answers stand for. The trees here
// are built in the flat format the restored tree uses, so the parse, the edit
// and the serialization all run.

@testable import FirmwarePatcher
import Foundation
import Testing

@Suite("Microphone array claims removal")
struct CustomFirmwareMicrophoneArrayTests {
    private typealias Node = FlatDeviceTreeNode

    /// A tree whose `/product/audio` holds `properties`, between two siblings.
    private static func tree(audio properties: [(String, Data)]?) -> Data {
        let product = Node(
            "product",
            [("product-name", Data("iPhone\0".utf8))],
            children: [Node("maps", [("regulatory", Node.uint32(1))])]
                + (properties.map { [Node("audio", $0)] } ?? [])
                + [Node("util", [("ramdisk", Node.uint32(0))])],
        )
        return Node("device-tree", [("model", Data("iPhone99,11\0".utf8))], children: [product]).serialized
    }

    /// The claims among the properties around them on the D47 node.
    private static let claimed: [(String, Data)] = [
        ("acoustic-id", Node.uint32(8018)),
        ("stereo-sound-recording", Node.uint32(1)),
        ("supports-audio-mix", Node.uint32(1)),
        ("supports-auto-mic-mode", Node.uint32(1)),
        ("supports-spatial-audio-capture", Node.uint32(1)),
        ("supports-spatial-facetime", Node.uint32(1)),
    ]

    private static let unclaimed = claimed.filter {
        !DeviceTreePatcher.microphoneArrayProperties.contains($0.0)
    }

    // MARK: - Tests

    @Test func `removes both claims and nothing else`() throws {
        let original = Self.tree(audio: Self.claimed)
        let (patched, changes, delta) = try CustomFirmwarePostRestoreDeviceTree.withoutMicrophoneArrayClaims(original)
        #expect(changes.map(\.property) == [
            "product/audio/supports-spatial-audio-capture",
            "product/audio/supports-audio-mix",
        ])
        #expect(changes.allSatisfy { $0.after == "absent" })
        // Each entry is a 32-byte name, a length, flags and a 4-byte value.
        #expect(delta == -2 * 40)
        #expect(patched.count == original.count + delta)
        // The other properties survive, in order, with the siblings around the node.
        #expect(patched == Self.tree(audio: Self.unclaimed))
    }

    @Test func `removes the one claim a tree has`() throws {
        let original = Self.tree(audio: Self.claimed.filter { $0.0 != "supports-audio-mix" })
        let (patched, changes, delta) = try CustomFirmwarePostRestoreDeviceTree.withoutMicrophoneArrayClaims(original)
        #expect(changes.map(\.property) == ["product/audio/supports-spatial-audio-capture"])
        #expect(delta == -40)
        #expect(patched == Self.tree(audio: Self.unclaimed))
    }

    @Test func `a tree with no claims is left alone`() throws {
        for original in [Self.tree(audio: Self.unclaimed), Self.tree(audio: nil)] {
            let (patched, changes, delta) = try CustomFirmwarePostRestoreDeviceTree.withoutMicrophoneArrayClaims(original)
            #expect(changes.isEmpty)
            #expect(delta == 0)
            #expect(patched == original)
        }
    }

    @Test func `removing twice changes nothing the second time`() throws {
        let (once, _, _) = try CustomFirmwarePostRestoreDeviceTree.withoutMicrophoneArrayClaims(Self.tree(audio: Self.claimed))
        let (twice, changes, _) = try CustomFirmwarePostRestoreDeviceTree.withoutMicrophoneArrayClaims(once)
        #expect(changes.isEmpty)
        #expect(twice == once)
    }

    @Test func `an audio node outside product is not touched`() throws {
        let original = Node(
            "device-tree",
            [("model", Data("iPhone99,11\0".utf8))],
            children: [Node("product"), Node("arm-io", children: [Node("audio", Self.claimed)])],
        ).serialized
        let (patched, changes, _) = try CustomFirmwarePostRestoreDeviceTree.withoutMicrophoneArrayClaims(original)
        #expect(changes.isEmpty)
        #expect(patched == original)
    }

    @Test func `a truncated tree is refused`() {
        let original = Self.tree(audio: Self.claimed)
        #expect(throws: (any Error).self) {
            try CustomFirmwarePostRestoreDeviceTree.withoutMicrophoneArrayClaims(original.prefix(original.count - 4))
        }
    }
}
