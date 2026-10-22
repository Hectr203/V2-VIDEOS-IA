// FirmwarePipelineOriginalsTests.swift — `fw patch` is re-runnable.
//
// The defect these cover: the pipeline patched each boot-chain file in place, so a
// second run fed the patchers the first run's output, they found none of the
// shapes they had already replaced, and the component failed with
// `Patch site not found: iBSS`. `fw prepare` refuses to re-extract over an
// existing restore tree, so a VM could be patched exactly once. See
// FirmwarePipelineOriginals.swift.
//
// The real boot chain needs firmware fixtures that are not in this repository, so
// these drive `patchComponents` over a synthetic component with a patcher whose
// behaviour is known: it rewrites one byte, and — like every real patcher — finds
// nothing once that byte is already rewritten. `noOriginals` reproduces the old
// behaviour from the same harness, so the test that proves the fix and the test
// that proves the defect differ only in the descriptor.

@testable import FirmwarePatcher
import Foundation
import Testing
import VPhonePatchKit

// MARK: - Harness

/// A patcher that flips `data[0]` from `0x00` to `0xAA`, and reports no site once
/// it has been flipped — the shape every real patcher has, and the reason patching
/// an already patched file fails instead of being a no-op.
private final class OnceOnlyBytePatcher: Patcher {
    let component = "iBSS"
    let verbose = false
    let data: Data

    init(data: Data) {
        self.data = data
    }

    func findAll() throws -> [PatchRecord] {
        guard data.first == 0x00 else { return [] }
        return [
            PatchRecord(
                patchID: "test-once",
                component: component,
                fileOffset: 0,
                originalBytes: Data([0x00]),
                patchedBytes: Data([0xAA]),
                description: "flip the first byte",
            ),
        ]
    }

    func apply() throws -> Int {
        1
    }
}

/// Bytes in, bytes out. The shipped loader repackages IM4P containers, which these
/// synthetic files are not.
private struct RawFirmwareLoader: FirmwarePipeline.FirmwareLoader {
    func load(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func save(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}

/// A VM directory holding one restore tree with one patchable file in it.
private struct FakeVM {
    let root: URL
    let restoreDir: URL
    let componentURL: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        restoreDir = root.appendingPathComponent("iPhone17,3_26.6.2_23G90_Restore")
        componentURL = restoreDir.appendingPathComponent("Firmware/dfu/iBSS.im4p")
        try FileManager.default.createDirectory(
            at: componentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try Data([0x00, 0x11, 0x22]).write(to: componentURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    var componentBytes: Data {
        (try? Data(contentsOf: componentURL)) ?? Data()
    }

    var stashURL: URL {
        root.appendingPathComponent(FirmwarePipeline.originalsDirectoryName)
            .appendingPathComponent("iPhone17,3_26.6.2_23G90_Restore/Firmware/dfu/iBSS.im4p")
    }

    func pipeline() -> FirmwarePipeline {
        FirmwarePipeline(vmDirectory: root, variant: .jb, verbose: false, loader: RawFirmwareLoader())
    }

    /// The descriptor under test. `patched` false leaves the component with no
    /// factories, which is what a preset that drops the whole boot-chain set does.
    func descriptor(patched: Bool = true, restorable: Bool = true) -> FirmwarePipeline.ComponentDescriptor {
        FirmwarePipeline.ComponentDescriptor(
            name: "iBSS",
            inRestoreDir: true,
            searchPatterns: ["Firmware/dfu/iBSS.im4p"],
            patcherFactories: patched ? [{ data, _ in OnceOnlyBytePatcher(data: data) }] : [],
            restorable: restorable,
        )
    }
}

// MARK: - Tests

struct FirmwarePipelineOriginalsTests {
    @Test func `patching twice succeeds and lands on the same bytes`() throws {
        let vm = try FakeVM()
        defer { vm.remove() }
        let pipeline = vm.pipeline()

        let first = try pipeline.patchComponents([vm.descriptor()], restoreDir: vm.restoreDir, plan: nil)
        let afterFirst = vm.componentBytes
        #expect(first.count == 1)
        #expect(afterFirst == Data([0xAA, 0x11, 0x22]))
        #expect(FileManager.default.fileExists(atPath: vm.stashURL.path))
        #expect(try Data(contentsOf: vm.stashURL) == Data([0x00, 0x11, 0x22]))

        // The run that used to die with `Patch site not found`.
        let second = try pipeline.patchComponents([vm.descriptor()], restoreDir: vm.restoreDir, plan: nil)
        #expect(second.map(\.patchID) == first.map(\.patchID))
        #expect(vm.componentBytes == afterFirst)

        let third = try pipeline.patchComponents([vm.descriptor()], restoreDir: vm.restoreDir, plan: nil)
        #expect(third.count == 1)
        #expect(vm.componentBytes == afterFirst)
    }

    @Test func `without an original the second run still fails`() throws {
        // Not a test of the old code: the same harness, with `restorable` off, is
        // how Filesystem and Manifest still behave, and it pins what the stash is
        // actually buying.
        let vm = try FakeVM()
        defer { vm.remove() }
        let pipeline = vm.pipeline()
        let descriptor = vm.descriptor(restorable: false)

        _ = try pipeline.patchComponents([descriptor], restoreDir: vm.restoreDir, plan: nil)
        #expect(!FileManager.default.fileExists(atPath: vm.stashURL.path))

        #expect(throws: PatcherError.self) {
            _ = try pipeline.patchComponents([descriptor], restoreDir: vm.restoreDir, plan: nil)
        }
    }

    @Test func `dropping the whole set puts the unpatched image back`() throws {
        let vm = try FakeVM()
        defer { vm.remove() }
        let pipeline = vm.pipeline()

        _ = try pipeline.patchComponents([vm.descriptor()], restoreDir: vm.restoreDir, plan: nil)
        #expect(vm.componentBytes == Data([0xAA, 0x11, 0x22]))

        // The preset no longer names this component's patch set, so it builds no
        // patchers at all. Before the originals existed this silently left the
        // previous run's patches in the firmware.
        let records = try pipeline.patchComponents(
            [vm.descriptor(patched: false)],
            restoreDir: vm.restoreDir,
            plan: nil,
        )
        #expect(records.isEmpty)
        #expect(vm.componentBytes == Data([0x00, 0x11, 0x22]))
    }

    @Test func `a VM patched by a build that kept no original says how to recover`() throws {
        let vm = try FakeVM()
        defer { vm.remove() }
        let pipeline = vm.pipeline()

        // What an older vphone-cli left behind: a patched file and no stash.
        try Data([0xAA, 0x11, 0x22]).write(to: vm.componentURL)

        let error = #expect(throws: PatcherError.self) {
            _ = try pipeline.patchComponents([vm.descriptor()], restoreDir: vm.restoreDir, plan: nil)
        }
        #expect(error?.description.contains("fw prepare") == true)

        // The patched bytes must not have been adopted as the original, or every
        // later run would patch from them and fail the same way for ever.
        #expect(!FileManager.default.fileExists(atPath: vm.stashURL.path))
        #expect(vm.componentBytes == Data([0xAA, 0x11, 0x22]))
    }

    @Test func `a less run leaves an already patched boot chain alone`() throws {
        let vm = try FakeVM()
        defer { vm.remove() }

        _ = try vm.pipeline().patchComponents([vm.descriptor()], restoreDir: vm.restoreDir, plan: nil)
        #expect(vm.componentBytes == Data([0xAA, 0x11, 0x22]))

        // `.less` gives every boot-chain component an empty factory list. That must
        // not read as "these patches are off, put the firmware back".
        let less = FirmwarePipeline(
            vmDirectory: vm.root,
            variant: .less,
            verbose: false,
            loader: RawFirmwareLoader(),
        )
        _ = try less.patchComponents([vm.descriptor(patched: false)], restoreDir: vm.restoreDir, plan: nil)
        #expect(vm.componentBytes == Data([0xAA, 0x11, 0x22]))
    }

    @Test func `the stash never claims a file outside the VM directory or itself`() throws {
        let vm = try FakeVM()
        defer { vm.remove() }
        let pipeline = vm.pipeline()

        #expect(pipeline.originalURL(for: vm.componentURL)?.path == vm.stashURL.path)
        #expect(pipeline.originalURL(for: URL(fileURLWithPath: "/tmp/elsewhere.im4p")) == nil)
        #expect(pipeline.originalURL(for: vm.root) == nil)
        #expect(pipeline.originalURL(for: vm.stashURL) == nil)
    }

    @Test func `only the two whole-tree components opt out of keeping an original`() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
        let pipeline = FirmwarePipeline(vmDirectory: root, variant: .less, verbose: false)
        let components = pipeline.buildComponentList(restoreDir: root, iOSBase: VPhoneVersion("26.6.2"))

        let notRestorable = components.filter { !$0.restorable }.map(\.name).sorted()
        #expect(notRestorable == ["Filesystem", "Manifest"])
    }
}
