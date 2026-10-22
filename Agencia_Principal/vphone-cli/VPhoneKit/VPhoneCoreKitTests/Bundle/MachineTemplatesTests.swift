import Darwin
import Foundation
import Testing
@testable import VPhoneCoreKit

/// Templates on disk: adopting a machine, building and freezing one, cloning
/// machines from it, and keeping it from ever booting. The temporary
/// directory is on the boot volume, which is APFS, so clones are real
/// `clonefile` copies.
struct MachineTemplatesTests {
    // MARK: - Fixtures

    private struct Fixture {
        let root: URL
        let library: VPhoneLibrary
        let rom: URL

        func cleanUp() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    private func makeFixture() throws -> Fixture {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let rom = root.appendingPathComponent("rom.bin")
        try Data([0xAA]).write(to: rom)
        return Fixture(root: root, library: VPhoneLibrary(root: root.appendingPathComponent("machines")), rom: rom)
    }

    /// A stopped machine with the files a created one has.
    @discardableResult
    private func makeMachine(_ name: String, in fixture: Fixture, library: VPhoneLibrary? = nil) throws -> VPhoneBundle {
        let bundle = try VPhoneBundleOperations.create(
            .init(name: name, cpuCount: 4, memoryMB: 4096, diskSizeGB: 1, romSource: fixture.rom, sepromSource: fixture.rom),
            in: library ?? fixture.library,
        )
        try Data([0xD1, 0x5C, 0x00, 0x01]).write(to: bundle.url.appendingPathComponent("Disk.img"))
        try Data([0x5E, 0x90]).write(to: bundle.url.appendingPathComponent("SEPStorage"))
        try Data([1, 2, 3]).write(to: bundle.url.appendingPathComponent("nvram.bin"))
        try Data([4]).write(to: bundle.url.appendingPathComponent("udid-prediction.txt"))
        try Data().write(to: bundle.url.appendingPathComponent("vphone.sock"))
        let manifest = bundle.manifest.updating(
            machineIdentifier: Data([9, 9]),
            networkConfig: bundle.manifest.networkConfig.with(
                macAddress: "aa:bb:cc:dd:ee:ff",
                localHostName: .some(VPhoneNetworking.localHostName(forVMName: name)),
            ),
        )
        try manifest.write(to: bundle.configURL)
        return VPhoneBundle(url: bundle.url, manifest: manifest)
    }

    private func record(
        _ key: VPhoneMachineTemplateKey = MachineTemplateKeyTests.key(),
        source: String? = "src",
        steps: VPhoneMachineTemplateSteps = VPhoneMachineTemplateSteps(),
    ) -> VPhoneMachineTemplateRecord {
        VPhoneMachineTemplateRecord(
            key: key,
            created: Date(timeIntervalSince1970: 1_800_000_000),
            builtWithBundleVersion: "2.8.0",
            sourceMachine: source,
            steps: steps,
        )
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Adopt

    @Test func `adopt moves a stopped machine out of the library and freezes it`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let source = try makeMachine("src", in: fixture)
        let disk = try Data(contentsOf: source.url.appendingPathComponent("Disk.img"))

        let template = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())

        let key = MachineTemplateKeyTests.key()
        #expect(template.identifier == key.identifier)
        #expect(template.url == VPhoneMachineTemplates.url(of: key.identifier, in: fixture.library))
        #expect(template.record.frozen)
        #expect(template.record.frozenAt != nil)
        #expect(!exists(source.url))
        #expect(try Data(contentsOf: template.url.appendingPathComponent("Disk.img")) == disk)
        // The stopped machine's stale socket does not travel.
        #expect(!exists(template.url.appendingPathComponent("vphone.sock")))

        // Gone from every listing of machines, present in the template listing.
        #expect(try fixture.library.bundles().isEmpty)
        let listing = try VPhoneMachineTemplates.list(in: fixture.library)
        #expect(listing.templates.map(\.identifier) == [key.identifier])
        #expect(listing.staging.isEmpty)
        #expect(listing.damaged.isEmpty)
        #expect(try VPhoneMachineTemplates.readRecord(inBundle: template.url) == template.record)
    }

    @Test func `adopt refuses a running machine and leaves it in place`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let source = try makeMachine("src", in: fixture)
        let fd = open(source.url.appendingPathComponent("Disk.img").path, O_RDONLY)
        #expect(fd >= 0)
        defer { close(fd) }

        #expect(throws: VPhoneBundleActivityError.running(name: "src", pids: [getpid()])) {
            try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())
        }
        #expect(exists(source.url))
        #expect(!exists(source.url.appendingPathComponent(VPhoneMachineTemplates.recordFileName)))
        #expect(try VPhoneMachineTemplates.list(in: fixture.library).templates.isEmpty)
    }

    @Test func `adopt refuses a key that already has a template`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("one", in: fixture)
        let other = try makeMachine("two", in: fixture)
        try VPhoneMachineTemplates.adopt(machineNamed: "one", in: fixture.library, record: record())

        let identifier = MachineTemplateKeyTests.key().identifier
        #expect(throws: VPhoneMachineTemplateError.alreadyExists(identifier)) {
            try VPhoneMachineTemplates.adopt(machineNamed: "two", in: fixture.library, record: record())
        }
        #expect(exists(other.url))
        #expect(!exists(other.url.appendingPathComponent(VPhoneMachineTemplates.recordFileName)))
    }

    @Test func `adopt refuses a machine with snapshots`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let source = try makeMachine("src", in: fixture)
        try VPhoneMachineSnapshots.create("clean", of: source)

        #expect(throws: VPhoneMachineTemplateError.hasSnapshots(machine: "src", count: 1)) {
            try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())
        }
        #expect(exists(source.url))
    }

    @Test func `adopt refuses steps that do not match the key`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let source = try makeMachine("src", in: fixture)

        #expect(throws: VPhoneMachineTemplateError.self) {
            try VPhoneMachineTemplates.adopt(
                machineNamed: "src",
                in: fixture.library,
                record: record(steps: .init(trimTier: "standard")),
            )
        }
        #expect(exists(source.url))
    }

    // MARK: - Build and freeze

    @Test func `a build is staged, records its steps, and freezes into place in one rename`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let key = MachineTemplateKeyTests.key(slimming: .init(trimTier: "standard"))
        let lock = try VPhoneMachineTemplates.lock(key.identifier, in: fixture.library, wait: false)
        defer { lock.release() }

        let build = try VPhoneMachineTemplates.beginBuild(key, in: fixture.library)
        #expect(build.stagingURL.lastPathComponent.hasPrefix(".building-\(key.identifier)-"))
        #expect(build.bundleURL.path == build.stagingURL.appendingPathComponent(key.identifier).path)
        try makeMachine(key.identifier, in: fixture, library: build.library)
        try VPhoneMachineTemplates.writeRecord(record(key, source: "phone"), inBundle: build.bundleURL)

        // Listed as a build in progress, never as a template or a machine.
        var listing = try VPhoneMachineTemplates.list(in: fixture.library)
        #expect(listing.templates.isEmpty)
        #expect(listing.staging.map(\.name) == [build.stagingURL.lastPathComponent])
        #expect(listing.staging.first?.identifier == key.identifier)
        #expect(listing.staging.first?.isActive == true)
        #expect(try fixture.library.bundles().isEmpty)
        // A machine still being built may boot: the setup boot does.
        #expect(VPhoneMachineTemplates.bootRefusal(bundleURL: build.bundleURL) == nil)

        // The key promises trimming that has not happened yet.
        #expect(throws: VPhoneMachineTemplateError.self) {
            try VPhoneMachineTemplates.freeze(build)
        }
        #expect(try VPhoneMachineTemplates.readRecord(inBundle: build.bundleURL)?.frozen == false)

        try VPhoneMachineTemplates.recordSteps(inBundle: build.bundleURL) { steps in
            steps.trimTier = "standard"
            steps.snapshotDeleted = true
        }
        let template = try VPhoneMachineTemplates.freeze(build)
        #expect(template.url == VPhoneMachineTemplates.url(of: key.identifier, in: fixture.library))
        #expect(template.record.frozen)
        #expect(template.record.steps.snapshotDeleted)
        #expect(!exists(build.stagingURL))
        #expect(!exists(template.url.appendingPathComponent("vphone.sock")))
        listing = try VPhoneMachineTemplates.list(in: fixture.library)
        #expect(listing.templates.map(\.identifier) == [key.identifier])
        #expect(listing.staging.isEmpty)

        // Frozen means unchanging.
        #expect(throws: VPhoneMachineTemplateError.frozen(identifier: key.identifier)) {
            try VPhoneMachineTemplates.recordSteps(inBundle: template.url) { $0.setupDone = true }
        }
        #expect(throws: VPhoneMachineTemplateError.alreadyExists(key.identifier)) {
            try VPhoneMachineTemplates.beginBuild(key, in: fixture.library)
        }
    }

    @Test func `freeze refuses when the template appeared meanwhile and leaves the build unfrozen`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let key = MachineTemplateKeyTests.key()
        let build = try VPhoneMachineTemplates.beginBuild(key, in: fixture.library)
        try makeMachine(key.identifier, in: fixture, library: build.library)
        try VPhoneMachineTemplates.writeRecord(record(key), inBundle: build.bundleURL)
        // Another create won the race.
        try makeMachine("other", in: fixture)
        try VPhoneMachineTemplates.adopt(machineNamed: "other", in: fixture.library, record: record(key))

        #expect(throws: VPhoneMachineTemplateError.alreadyExists(key.identifier)) {
            try VPhoneMachineTemplates.freeze(build)
        }
        #expect(exists(build.bundleURL))
        #expect(try VPhoneMachineTemplates.readRecord(inBundle: build.bundleURL)?.frozen == false)

        try VPhoneMachineTemplates.abandon(build)
        #expect(!exists(build.stagingURL))
    }

    @Test func `the build lock admits one holder and a leftover build can be deleted once it is released`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let key = MachineTemplateKeyTests.key()
        let lock = try VPhoneMachineTemplates.lock(key.identifier, in: fixture.library, wait: false)
        #expect(throws: VPhoneMachineTemplateError.busy(identifier: key.identifier)) {
            try VPhoneMachineTemplates.lock(key.identifier, in: fixture.library, wait: false)
        }
        let build = try VPhoneMachineTemplates.beginBuild(key, in: fixture.library)
        let name = build.stagingURL.lastPathComponent
        #expect(throws: VPhoneMachineTemplateError.busy(identifier: key.identifier)) {
            try VPhoneMachineTemplates.delete(name, in: fixture.library)
        }

        lock.release()
        #expect(try VPhoneMachineTemplates.list(in: fixture.library).staging.first?.isActive == false)
        try VPhoneMachineTemplates.delete(name, in: fixture.library)
        #expect(!exists(build.stagingURL))
        // And the lock can be taken again.
        try VPhoneMachineTemplates.lock(key.identifier, in: fixture.library, wait: false).release()
    }

    // MARK: - Never booting

    @Test func `a frozen template refuses to boot, by every route`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("src", in: fixture)
        let template = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())

        #expect(VPhoneMachineTemplates.bootRefusal(bundleURL: template.url) == .notBootable(identifier: template.identifier))
        #expect(throws: VPhoneMachineTemplateError.notBootable(identifier: template.identifier)) {
            var boot = VPhoneBootCommand(config: template.url.appendingPathComponent("config.plist"))
            try boot.validate()
        }
        #expect(throws: VPhoneMachineTemplateError.notBootable(identifier: template.identifier)) {
            var boot = VPhoneBootCommand(config: template.url.appendingPathComponent("config.plist"), dfu: true)
            try boot.validate()
        }
        // A machine name never reaches into `.templates`.
        for name in [".templates/\(template.identifier)", ".templates", "../machines/src"] {
            #expect(throws: VPhoneLibraryError.invalidName(name)) {
                try fixture.library.bundle(named: name)
            }
        }
        // The same machine copied out by hand still carries its frozen record.
        let copy = fixture.library.url(forName: "copy")
        try FileManager.default.copyItem(at: template.url, to: copy)
        #expect(VPhoneMachineTemplates.bootRefusal(bundleURL: copy) == .notBootable(identifier: template.identifier))
    }

    @Test func `a folder in templates without a record does not boot either, and an ordinary machine does`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let machine = try makeMachine("phone", in: fixture)
        #expect(VPhoneMachineTemplates.bootRefusal(bundleURL: machine.url) == nil)

        try VPhoneMachineTemplates.ensureDirectory(in: fixture.library)
        let stray = VPhoneMachineTemplates.url(of: "0123456789ab", in: fixture.library)
        try FileManager.default.copyItem(at: machine.url, to: stray)
        #expect(VPhoneMachineTemplates.bootRefusal(bundleURL: stray) == .notBootable(identifier: "0123456789ab"))
        // It is listed as damaged and can be deleted.
        let listing = try VPhoneMachineTemplates.list(in: fixture.library)
        #expect(listing.templates.isEmpty)
        #expect(listing.damaged.map(\.name) == ["0123456789ab"])
        try VPhoneMachineTemplates.delete("0123456789ab", in: fixture.library)
        #expect(!exists(stray))
    }

    // MARK: - Clone

    @Test func `a machine cloned from a template is ordinary, new, and takes config-only settings`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("src", in: fixture)
        let template = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())
        let templateConfig = try Data(contentsOf: template.url.appendingPathComponent("config.plist"))

        let clone = try VPhoneMachineTemplates.cloneMachine(from: template, to: "phone-a", in: fixture.library)
        #expect(clone.url == fixture.library.url(forName: "phone-a"))
        #expect(try fixture.library.bundles().map(\.name) == ["phone-a"])
        // A new identity, and no template record: it boots.
        #expect(clone.manifest.machineIdentifier.isEmpty)
        #expect(clone.manifest.networkConfig.macAddress.isEmpty)
        #expect(!exists(clone.url.appendingPathComponent(VPhoneMachineTemplates.recordFileName)))
        #expect(!exists(clone.url.appendingPathComponent("udid-prediction.txt")))
        #expect(VPhoneMachineTemplates.bootRefusal(bundleURL: clone.url) == nil)
        // The mDNS name derived from the machine the template came from follows to the clone.
        #expect(clone.manifest.networkConfig.localHostName == VPhoneNetworking.localHostName(forVMName: "phone-a"))
        // The state files made by the restore are the template's.
        for name in ["Disk.img", "SEPStorage", "nvram.bin"] {
            #expect(try Data(contentsOf: clone.url.appendingPathComponent(name))
                == Data(contentsOf: template.url.appendingPathComponent(name)), "\(name)")
        }

        // What `vm create --template` sets afterwards, through `vm config`'s path.
        let configured = try VPhoneBundleOperations.updateConfig(
            bundleNamed: "phone-a",
            in: fixture.library,
            cpuCount: 2,
            memoryMB: 3072,
            networkMode: .tunnel,
            unlocksAtStartup: true,
        )
        #expect(configured.manifest.cpuCount == 2)
        #expect(configured.manifest.memorySize == 3072 * 1024 * 1024)
        #expect(configured.manifest.networkConfig.mode == .tunnel)
        #expect(configured.manifest.unlocksScreenAtStartup)
        // The template is untouched.
        #expect(try Data(contentsOf: template.url.appendingPathComponent("config.plist")) == templateConfig)

        // A second clone beside the first, and both survive the template's deletion.
        let second = try VPhoneMachineTemplates.cloneMachine(from: template, to: "phone-b", in: fixture.library)
        #expect(throws: VPhoneLibraryError.alreadyExists(name: "phone-b")) {
            try VPhoneMachineTemplates.cloneMachine(from: template, to: "phone-b", in: fixture.library)
        }
        try VPhoneMachineTemplates.delete(template.identifier, in: fixture.library)
        #expect(!exists(template.url))
        #expect(try fixture.library.bundles().map(\.name) == ["phone-a", "phone-b"])
        #expect(try Data(contentsOf: second.url.appendingPathComponent("Disk.img")) == Data([0xD1, 0x5C, 0x00, 0x01]))
    }

    @Test func `a plain clone of a machine drops a template record`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let machine = try makeMachine("src", in: fixture)
        try VPhoneMachineTemplates.writeRecord(record(), inBundle: machine.url)

        let clone = try VPhoneBundleOperations.clone(bundleNamed: "src", to: "dst", in: fixture.library)
        #expect(!exists(clone.url.appendingPathComponent(VPhoneMachineTemplates.recordFileName)))
        #expect(clone.manifest.machineIdentifier == Data([9, 9]))
    }

    @Test func `a cloned template refuses to start while it is held open`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("src", in: fixture)
        let template = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())
        let fd = open(template.url.appendingPathComponent("SEPStorage").path, O_RDONLY)
        #expect(fd >= 0)
        defer { close(fd) }

        #expect(throws: VPhoneBundleActivityError.running(name: template.identifier, pids: [getpid()])) {
            try VPhoneMachineTemplates.cloneMachine(from: template, to: "phone", in: fixture.library)
        }
        #expect(!exists(fixture.library.url(forName: "phone")))
    }

    // MARK: - Lookup

    @Test func `templates are found by identifier, unique prefix, or key`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("one", in: fixture)
        try makeMachine("two", in: fixture)
        let first = try VPhoneMachineTemplates.adopt(machineNamed: "one", in: fixture.library, record: record())
        let otherKey = MachineTemplateKeyTests.key(disk: 128)
        let second = try VPhoneMachineTemplates.adopt(machineNamed: "two", in: fixture.library, record: record(otherKey))

        #expect(try VPhoneMachineTemplates.template(first.identifier, in: fixture.library).url == first.url)
        #expect(try VPhoneMachineTemplates.template(String(second.identifier.prefix(6)), in: fixture.library).url == second.url)
        #expect(try VPhoneMachineTemplates.template(for: otherKey, in: fixture.library)?.url == second.url)
        #expect(try VPhoneMachineTemplates.template(for: MachineTemplateKeyTests.key(disk: 32), in: fixture.library) == nil)
        #expect(throws: VPhoneMachineTemplateError.notFound("ffffffffffff")) {
            try VPhoneMachineTemplates.template("ffffffffffff", in: fixture.library)
        }
        for bad in ["abc", "../x", ".templates", "0123456789abcdef"] {
            #expect(throws: VPhoneMachineTemplateError.invalidIdentifier(bad)) {
                try VPhoneMachineTemplates.template(bad, in: fixture.library)
            }
        }
    }

    // MARK: - Staleness

    @Test func `stale reasons name the series, the resolution and the drift`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("src", in: fixture)
        let key = MachineTemplateKeyTests.key()
        let template = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record(key))

        #expect(template.staleReasons(currentSeries: "2.8", freshKey: key).isEmpty)
        // A fresh key for another series differs only in the series, which is reported once.
        #expect(template.staleReasons(currentSeries: "2.9", freshKey: key).count == 1)

        var changed = key
        changed.bootChainPlanDigest = "abd"
        let reasons = template.staleReasons(currentSeries: "2.8", freshKey: changed, driftedPatches: ["kernel-x"])
        #expect(reasons.count == 2)
        #expect(reasons[0].contains("boot-chain plan"))
        #expect(reasons[1].contains("kernel-x"))
        #expect(template.staleReasons(currentSeries: "2.8", freshKey: nil).count == 1)
    }

    // MARK: - Trim and the snapshot

    @Test func `a trim without its snapshot deletion is never frozen or adopted`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let trim = VPhoneSystemTrimSpec.standard.keyValue
        let key = MachineTemplateKeyTests.key(slimming: .init(trimTier: trim, setupBoot: true))
        let build = try VPhoneMachineTemplates.beginBuild(key, in: fixture.library)
        try makeMachine(key.identifier, in: fixture, library: build.library)
        try VPhoneMachineTemplates.writeRecord(record(key), inBundle: build.bundleURL)
        try VPhoneMachineTemplates.recordSteps(inBundle: build.bundleURL) {
            $0.trimTier = trim
            $0.setupDone = true
        }

        #expect(VPhoneMachineTemplateSteps(trimTier: trim).problems.count == 1)
        #expect(throws: VPhoneMachineTemplateError.self) {
            try VPhoneMachineTemplates.freeze(build)
        }
        #expect(try VPhoneMachineTemplates.readRecord(inBundle: build.bundleURL)?.frozen == false)

        try VPhoneMachineTemplates.recordSteps(inBundle: build.bundleURL) { $0.snapshotDeleted = true }
        #expect(try VPhoneMachineTemplates.freeze(build).record.steps.trimTier == trim)

        // Adopt follows the same rule.
        try makeMachine("src", in: fixture)
        let adoptKey = MachineTemplateKeyTests.key(bootChain: "other", slimming: .init(trimTier: trim, setupBoot: true))
        #expect(throws: VPhoneMachineTemplateError.self) {
            try VPhoneMachineTemplates.adopt(
                machineNamed: "src",
                in: fixture.library,
                record: record(adoptKey, steps: .init(setupDone: true, trimTier: trim)),
            )
        }
        #expect(exists(fixture.library.url(forName: "src")))
        #expect(VPhoneMachineTemplateSteps(snapshotDeleted: true, trimTier: trim).problems.isEmpty)
        #expect(VPhoneMachineTemplateSteps().problems.isEmpty)
    }

    @Test func `a key asking for a trim needs the setup boot`() {
        let trim = VPhoneSystemTrimSpec.standard.keyValue
        #expect(VPhoneMachineTemplateSlimming(trimTier: trim).problems.count == 1)
        #expect(VPhoneMachineTemplateSlimming(trimTier: trim, setupBoot: true).problems.isEmpty)
        #expect(VPhoneMachineTemplateSlimming.none.problems.isEmpty)
    }

    @Test func `steps can be recorded on a library machine that has no record yet`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let machine = try makeMachine("src", in: fixture)
        #expect(throws: VPhoneMachineTemplateError.notBeingBuilt(path: machine.url.path)) {
            try VPhoneMachineTemplates.recordSteps(inBundle: machine.url) { $0.trimTier = "conservative/1" }
        }
        var frozen = record()
        frozen.frozen = true
        try VPhoneMachineTemplates.recordSteps(inBundle: machine.url, creating: { frozen }) { $0.trimTier = "conservative/1" }
        let written = try #require(try VPhoneMachineTemplates.readRecord(inBundle: machine.url))
        #expect(!written.frozen)
        #expect(written.steps.trimTier == "conservative/1")
        // It still boots: only a frozen record refuses.
        #expect(VPhoneMachineTemplates.bootRefusal(bundleURL: machine.url) == nil)
    }

    // MARK: - Restore tree

    @Test func `a template never keeps the restore tree`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let machine = try makeMachine("src", in: fixture)
        let tree = machine.url.appendingPathComponent("iPhone17,3_27.0_24A435_Restore")
        try FileManager.default.createDirectory(at: tree, withIntermediateDirectories: true)
        try Data([1]).write(to: tree.appendingPathComponent("kernelcache"))
        #expect(VPhoneMachineTemplates.restoreTree(of: machine) == tree.lastPathComponent)

        let adopted = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())
        #expect(!exists(adopted.url.appendingPathComponent(tree.lastPathComponent)))
        #expect(exists(adopted.url.appendingPathComponent("Disk.img")))

        let key = MachineTemplateKeyTests.key(bootChain: "built")
        let build = try VPhoneMachineTemplates.beginBuild(key, in: fixture.library)
        let built = try makeMachine(key.identifier, in: fixture, library: build.library)
        try FileManager.default.createDirectory(at: built.url.appendingPathComponent("iPhone17,3_27.0_24A435_Restore"), withIntermediateDirectories: true)
        try VPhoneMachineTemplates.writeRecord(record(key), inBundle: build.bundleURL)
        let frozen = try VPhoneMachineTemplates.freeze(build)
        #expect(try VPhoneMachineTemplates.restoreTree(of: frozen.bundle()) == nil)
    }

    // MARK: - Source and usage

    @Test func `clones record their template, plain clones keep it, and the last one leaving is noticed`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("src", in: fixture)
        try makeMachine("own", in: fixture)
        let template = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())
        #expect(VPhoneMachineTemplates.readSource(inBundle: template.url) == nil)

        let a = try VPhoneMachineTemplates.cloneMachine(from: template, to: "phone-a", in: fixture.library)
        #expect(VPhoneMachineTemplates.readSource(inBundle: a.url)?.identifier == template.identifier)
        #expect(VPhoneBundleReport(bundle: a).template == template.identifier)
        #expect(try VPhoneBundleReport(bundle: fixture.library.bundle(named: "own")).template == nil)
        // A plain clone of a clone shares the template's blocks too.
        let b = try VPhoneBundleOperations.clone(bundleNamed: "phone-a", to: "phone-b", in: fixture.library, newIdentity: true)
        #expect(VPhoneMachineTemplates.readSource(inBundle: b.url)?.identifier == template.identifier)
        #expect(VPhoneMachineTemplates.usage(in: fixture.library) == [template.identifier: ["phone-a", "phone-b"]])
        // An export leaves it out: an import shares nothing.
        #expect(VPhoneBundleOperations.exportExcludePatterns.contains { fnmatch($0, VPhoneMachineTemplates.sourceFileName, 0) == 0 })

        // Deleting one of two: still used.
        let sourceA = VPhoneMachineTemplates.readSource(inBundle: a.url)
        try VPhoneBundleOperations.delete(bundleNamed: "phone-a", in: fixture.library)
        #expect(VPhoneMachineTemplates.unusedTemplate(after: sourceA, in: fixture.library) == nil)
        // Deleting the last: noticed, and the template is still there.
        let sourceB = VPhoneMachineTemplates.readSource(inBundle: b.url)
        try VPhoneBundleOperations.delete(bundleNamed: "phone-b", in: fixture.library)
        let unused = try #require(VPhoneMachineTemplates.unusedTemplate(after: sourceB, in: fixture.library))
        #expect(unused.identifier == template.identifier)
        #expect(exists(template.url))
        #expect(VPhoneMachineTemplates.allocatedBytes(of: template.url) > 0)
        // A machine that was never cloned, or a template already deleted: nothing to say.
        #expect(VPhoneMachineTemplates.unusedTemplate(after: nil, in: fixture.library) == nil)
        try VPhoneMachineTemplates.delete(template.identifier, in: fixture.library)
        #expect(VPhoneMachineTemplates.unusedTemplate(after: sourceB, in: fixture.library) == nil)
    }

    @Test func `an unreadable or foreign source record is ignored`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let machine = try makeMachine("m", in: fixture)
        let file = machine.url.appendingPathComponent(VPhoneMachineTemplates.sourceFileName)
        try Data("junk".utf8).write(to: file)
        #expect(VPhoneMachineTemplates.readSource(inBundle: machine.url) == nil)
        try VPhoneMachineTemplates.writeSource(VPhoneMachineTemplateSource(identifier: "../../etc"), inBundle: machine.url)
        #expect(VPhoneMachineTemplates.readSource(inBundle: machine.url) == nil)
        #expect(VPhoneMachineTemplates.usage(in: fixture.library).isEmpty)
    }

    // MARK: - Sources

    @Test func `a record keeps the IPSW sources it was built from, and an older record has none`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let machine = try makeMachine("src", in: fixture)
        var built = record()
        built.sources = VPhoneMachineTemplateSources(iPhone: "https://example.invalid/iPhone17,3_27.0_24A435_Restore.ipsw", cloudOS: "/tmp/cloudos.ipsw")
        try VPhoneMachineTemplates.writeRecord(built, inBundle: machine.url)
        #expect(try VPhoneMachineTemplates.readRecord(inBundle: machine.url)?.sources == built.sources)
        let plist = try String(contentsOf: machine.url.appendingPathComponent(VPhoneMachineTemplates.recordFileName), encoding: .utf8)
        #expect(plist.contains("<key>Sources</key>"))
        #expect(plist.contains("<key>IPhone</key>"))
        #expect(plist.contains("<key>CloudOS</key>"))

        // A record written before sources were kept reads as none.
        try VPhoneMachineTemplates.writeRecord(record(), inBundle: machine.url)
        #expect(try VPhoneMachineTemplates.readRecord(inBundle: machine.url)?.sources == nil)
    }

    @Test func `templates built from the same sources are found by them, newest first, per device`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let sources = VPhoneMachineTemplateSources(iPhone: "https://example.invalid/a.ipsw", cloudOS: "https://example.invalid/c")
        try makeMachine("one", in: fixture)
        try makeMachine("two", in: fixture)
        try makeMachine("three", in: fixture)
        var older = record()
        older.sources = sources
        let newer = VPhoneMachineTemplateRecord(
            key: MachineTemplateKeyTests.key(disk: 128),
            created: Date(timeIntervalSince1970: 1_900_000_000),
            sourceMachine: "two",
            sources: sources,
        )
        let other = VPhoneMachineTemplateRecord(key: MachineTemplateKeyTests.key(disk: 32), sourceMachine: "three")
        let first = try VPhoneMachineTemplates.adopt(machineNamed: "one", in: fixture.library, record: older)
        let second = try VPhoneMachineTemplates.adopt(machineNamed: "two", in: fixture.library, record: newer)
        try VPhoneMachineTemplates.adopt(machineNamed: "three", in: fixture.library, record: other)

        let found = VPhoneMachineTemplates.templates(builtFrom: sources, in: fixture.library)
        #expect(found.map(\.identifier) == [second.identifier, first.identifier])
        #expect(VPhoneMachineTemplates.templates(builtFrom: sources, device: "iPhone17,3", in: fixture.library).count == 2)
        #expect(VPhoneMachineTemplates.templates(builtFrom: sources, device: "iPad16,1", in: fixture.library).isEmpty)
        let elsewhere = VPhoneMachineTemplateSources(iPhone: "https://example.invalid/a.ipsw", cloudOS: "https://example.invalid/other")
        #expect(VPhoneMachineTemplates.templates(builtFrom: elsewhere, in: fixture.library).isEmpty)
    }

    @Test func `builds come from the IPSWs first, then from a template with the same sources, and never from a download`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let sources = VPhoneMachineTemplateSources(iPhone: "https://example.invalid/a.ipsw", cloudOS: "https://example.invalid/c")
        let fromIPSW = VPhoneMachineTemplateBuilds(
            device: "iPhone17,3",
            ios: .init(version: "27.0.1", build: "24A446"),
            cloudOS: .init(version: "26.4", build: "23E5207q"),
            origin: .ipsw,
        )

        // Nothing local, no template: unresolved, so only a build (which
        // downloads) can tell; the local reader is asked once.
        var looks = 0
        let none = try VPhoneMachineTemplates.resolveBuilds(sources: sources, device: nil, in: fixture.library) {
            looks += 1
            return nil
        }
        #expect(none == nil)
        #expect(looks == 1)

        try makeMachine("src", in: fixture)
        var built = record()
        built.sources = sources
        let template = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: built)

        // The IPSWs are here: they win over the template's record.
        let local = try VPhoneMachineTemplates.resolveBuilds(sources: sources, device: nil, in: fixture.library) { fromIPSW }
        #expect(local == fromIPSW)

        // Not here (deleted, or a local path that no longer exists): the
        // template recorded with the same sources gives the builds.
        let recorded = try #require(try VPhoneMachineTemplates.resolveBuilds(sources: sources, device: nil, in: fixture.library) { nil })
        #expect(recorded.origin == .template)
        #expect(recorded.template == template.identifier)
        #expect(recorded.device == template.key.device)
        #expect(recorded.ios == .init(version: template.key.iOSVersion, build: template.key.iOSBuild))
        #expect(recorded.cloudOS == .init(version: template.key.cloudOSVersion, build: template.key.cloudOSBuild))
        // ...for its device only, and only for the same two sources.
        #expect(try VPhoneMachineTemplates.resolveBuilds(sources: sources, device: "iPad16,1", in: fixture.library) { nil } == nil)
        let other = VPhoneMachineTemplateSources(iPhone: sources.iPhone, cloudOS: "https://example.invalid/other")
        #expect(try VPhoneMachineTemplates.resolveBuilds(sources: other, device: nil, in: fixture.library) { nil } == nil)

        // A local reader that fails (an IPSW that is there but unreadable)
        // fails the resolution rather than quietly using a template.
        struct Unreadable: Error {}
        #expect(throws: Unreadable.self) {
            try VPhoneMachineTemplates.resolveBuilds(sources: sources, device: nil, in: fixture.library) { throw Unreadable() }
        }
    }

    @Test func `deleting a template says its blocks are freed unless machines use it`() {
        let free = VPhoneMachineTemplates.deletionNote(machines: [])
        #expect(free.hasPrefix("no machine uses it now; deleting frees its blocks"))
        // Never claims it was never cloned, and does not promise free space a
        // local Time Machine snapshot may keep.
        #expect(!free.contains("cloned"))
        #expect(free.contains("Time Machine snapshot"))
        let shared = VPhoneMachineTemplates.deletionNote(machines: ["phone-a", "phone-b"])
        #expect(shared.hasPrefix("2 machine(s) use it (phone-a, phone-b); "))
        #expect(shared.contains("stay allocated until they change them or are deleted"))
    }

    // MARK: - Builds

    @Test func `a template rebuilt with the same key does not count the old build's clones`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("src", in: fixture)
        let first = try VPhoneMachineTemplates.adopt(
            machineNamed: "src", in: fixture.library, record: record(), now: Date(timeIntervalSince1970: 1_800_000_100),
        )
        let firstBuild = try #require(first.record.build)
        let old = try VPhoneMachineTemplates.cloneMachine(from: first, to: "old", in: fixture.library)
        #expect(VPhoneMachineTemplates.readSource(inBundle: old.url)?.build == firstBuild)
        #expect(VPhoneMachineTemplates.usage(in: fixture.library) == [first.identifier: ["old"]])
        // What `vm list --json` reports as `templateMatch`, and Launchpad shows.
        func match(_ machine: VPhoneBundle) -> VPhoneMachineTemplateMatch? {
            VPhoneBundleReport(bundle: machine).templateMatch
        }
        #expect(match(old) == .current)

        // Deleted and built again under the same identifier, with a new build.
        try VPhoneMachineTemplates.delete(first.identifier, in: fixture.library)
        #expect(VPhoneMachineTemplates.usage(in: fixture.library) == [first.identifier: ["old"]])
        #expect(match(old) == .deleted)
        try makeMachine("src2", in: fixture)
        let second = try VPhoneMachineTemplates.adopt(machineNamed: "src2", in: fixture.library, record: record(source: "src2"))
        #expect(second.identifier == first.identifier)
        #expect(second.record.build != nil && second.record.build != firstBuild)
        #expect(VPhoneMachineTemplates.usage(in: fixture.library)[second.identifier] == nil)

        let new = try VPhoneMachineTemplates.cloneMachine(from: second, to: "new", in: fixture.library)
        #expect(VPhoneMachineTemplates.usage(in: fixture.library) == [second.identifier: ["new"]])
        #expect(match(old) == .earlierBuild)
        // The spelling Launchpad decodes.
        let json = try String(decoding: JSONEncoder().encode(VPhoneBundleReport(bundle: old)), as: UTF8.self)
        #expect(json.contains(#""templateMatch":"earlierBuild""#))
        #expect(match(new) == .current)
        // Deleting the old build's clone says nothing about the new template;
        // deleting the new one's last clone does.
        let oldSource = VPhoneMachineTemplates.readSource(inBundle: old.url)
        try VPhoneBundleOperations.delete(bundleNamed: "old", in: fixture.library)
        #expect(VPhoneMachineTemplates.unusedTemplate(after: oldSource, in: fixture.library) == nil)
        let newSource = VPhoneMachineTemplates.readSource(inBundle: new.url)
        try VPhoneBundleOperations.delete(bundleNamed: "new", in: fixture.library)
        #expect(VPhoneMachineTemplates.unusedTemplate(after: newSource, in: fixture.library)?.identifier == second.identifier)
    }

    @Test func `a clone record without a build is matched by its clone date`() {
        let frozenAt = Date(timeIntervalSince1970: 1_800_000_100)
        var template = record()
        template.frozen = true
        template.frozenAt = frozenAt
        template.build = UUID().uuidString
        let id = template.identifier

        // Written before builds were recorded: the date decides.
        #expect(VPhoneMachineTemplateSource(identifier: id, cloned: frozenAt).isClone(of: template))
        #expect(VPhoneMachineTemplateSource(identifier: id, cloned: frozenAt + 60).isClone(of: template))
        #expect(!VPhoneMachineTemplateSource(identifier: id, cloned: frozenAt - 1).isClone(of: template))
        // A build on both sides decides, whatever the dates say.
        #expect(VPhoneMachineTemplateSource(identifier: id, build: template.build, cloned: frozenAt - 600).isClone(of: template))
        #expect(!VPhoneMachineTemplateSource(identifier: id, build: UUID().uuidString, cloned: frozenAt + 60).isClone(of: template))
        // A template frozen before builds were recorded: the date again.
        var legacy = template
        legacy.build = nil
        #expect(VPhoneMachineTemplateSource(identifier: id, build: UUID().uuidString, cloned: frozenAt + 60).isClone(of: legacy))
        #expect(!VPhoneMachineTemplateSource(identifier: id, build: UUID().uuidString, cloned: frozenAt - 60).isClone(of: legacy))
        // Without a freeze date, the creation date.
        legacy.frozenAt = nil
        #expect(VPhoneMachineTemplateSource(identifier: id, cloned: template.created).isClone(of: legacy))
        #expect(!VPhoneMachineTemplateSource(identifier: id, cloned: template.created - 1).isClone(of: legacy))
        // Another key never.
        #expect(!VPhoneMachineTemplateSource(identifier: "000000000000", build: template.build, cloned: frozenAt).isClone(of: template))
    }

    @Test func `a legacy clone record of a deleted template is left out by date`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        try makeMachine("src", in: fixture)
        let template = try VPhoneMachineTemplates.adopt(machineNamed: "src", in: fixture.library, record: record())
        let frozenAt = try #require(template.record.frozenAt)
        // Two clones whose records predate builds: one of an earlier template
        // with this key, one of this one.
        let earlier = try makeMachine("earlier", in: fixture)
        try VPhoneMachineTemplates.writeSource(
            VPhoneMachineTemplateSource(identifier: template.identifier, cloned: frozenAt - 3600), inBundle: earlier.url,
        )
        let current = try makeMachine("current", in: fixture)
        try VPhoneMachineTemplates.writeSource(
            VPhoneMachineTemplateSource(identifier: template.identifier, cloned: frozenAt + 1), inBundle: current.url,
        )
        #expect(VPhoneMachineTemplates.usage(in: fixture.library) == [template.identifier: ["current"]])
        #expect(VPhoneBundleReport(bundle: earlier).templateMatch == .earlierBuild)
        #expect(VPhoneBundleReport(bundle: current).templateMatch == .current)
    }

    @Test func `a record without a build reads, and a frozen one gets one`() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let machine = try makeMachine("src", in: fixture)
        // An older record: no Build key at all.
        try VPhoneMachineTemplates.writeRecord(record(), inBundle: machine.url)
        let raw = try Data(contentsOf: machine.url.appendingPathComponent(VPhoneMachineTemplates.recordFileName))
        #expect(!String(decoding: raw, as: UTF8.self).contains("<key>Build</key>"))
        #expect(try VPhoneMachineTemplates.readRecord(inBundle: machine.url)?.build == nil)
        let source = try PropertyListDecoder().decode(
            VPhoneMachineTemplateSource.self,
            from: PropertyListSerialization.data(
                fromPropertyList: ["Identifier": "52b1fcc75e0c", "Cloned": Date(timeIntervalSince1970: 1_800_000_000)],
                format: .xml, options: 0,
            ),
        )
        #expect(source.build == nil)

        let key = MachineTemplateKeyTests.key(bootChain: "built")
        let build = try VPhoneMachineTemplates.beginBuild(key, in: fixture.library)
        try makeMachine(key.identifier, in: fixture, library: build.library)
        try VPhoneMachineTemplates.writeRecord(record(key), inBundle: build.bundleURL)
        let frozen = try VPhoneMachineTemplates.freeze(build)
        #expect(frozen.record.build != nil)
        #expect(try VPhoneMachineTemplates.template(frozen.identifier, in: fixture.library).record.build == frozen.record.build)
    }
}
