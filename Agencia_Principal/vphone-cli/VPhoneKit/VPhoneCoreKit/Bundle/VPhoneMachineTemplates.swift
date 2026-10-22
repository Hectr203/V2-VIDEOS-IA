import Darwin
import Foundation

// MARK: - Build steps

/// What was done to a template's guest after `cfw install` and before it was
/// frozen. Each later stage records its own work here while the template is
/// still being built (see ``VPhoneMachineTemplates/recordSteps(inBundle:_:)``):
/// the offline trim after the CFW install sets `trimTier`, the setup boot sets
/// the rest. A template is frozen only when these match what its key promises.
public struct VPhoneMachineTemplateSteps: Codable, Equatable, Sendable {
    /// The guest's `orig-fs` APFS snapshot was deleted, so trimmed files free
    /// their space. Not part of the key: it changes what the template costs,
    /// not what a clone gets.
    public var snapshotDeleted: Bool
    /// The setup boot finished: Setup skipped, first-boot work settled, shut
    /// down cleanly.
    public var setupDone: Bool
    public var serviceProfile: String
    public var serviceGroups: [String]
    public var removedApps: [String]
    public var trimTier: String
    /// The removed apps vphoned had to unregister more than once, with the
    /// number of attempts. Not part of the key: a record of how the setup
    /// boot went, kept so the race with first-boot registration can be
    /// counted afterwards.
    public var unregisterAttempts: [String: Int]

    public init(
        snapshotDeleted: Bool = false,
        setupDone: Bool = false,
        serviceProfile: String = "none",
        serviceGroups: [String] = [],
        removedApps: [String] = [],
        trimTier: String = "none",
        unregisterAttempts: [String: Int] = [:],
    ) {
        self.snapshotDeleted = snapshotDeleted
        self.setupDone = setupDone
        self.serviceProfile = serviceProfile
        self.serviceGroups = Array(Set(serviceGroups)).sorted()
        self.removedApps = Array(Set(removedApps)).sorted()
        self.trimTier = trimTier
        self.unregisterAttempts = unregisterAttempts
    }

    /// Why a template with these steps must not be frozen, or nothing.
    ///
    /// A trim with the `orig-fs` snapshot still in place is refused rather
    /// than warned about: the snapshot keeps every deleted block, so such a
    /// template costs exactly what an untrimmed one does while its clones
    /// have lost the files, and its key would promise savings it never made.
    /// Refusing keeps every frozen template either trimmed and smaller, or
    /// untrimmed and whole.
    public var problems: [String] {
        var problems: [String] = []
        if trimTier != "none", !snapshotDeleted {
            problems.append(
                "trim \(trimTier) frees nothing while the guest's orig-fs snapshot exists; "
                    + "the setup boot deletes it (apfs.snapshot.delete)",
            )
        }
        return problems
    }

    /// The slimming these steps produced, as a key states it.
    public var slimming: VPhoneMachineTemplateSlimming {
        VPhoneMachineTemplateSlimming(
            trimTier: trimTier,
            setupBoot: setupDone,
            serviceProfile: serviceProfile,
            serviceGroups: serviceGroups,
            removedApps: removedApps,
        )
    }

    private enum CodingKeys: String, CodingKey {
        case snapshotDeleted = "SnapshotDeleted"
        case setupDone = "SetupDone"
        case serviceProfile = "ServiceProfile"
        case serviceGroups = "ServiceGroups"
        case removedApps = "RemovedApps"
        case trimTier = "TrimTier"
        case unregisterAttempts = "UnregisterAttempts"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snapshotDeleted = try container.decodeIfPresent(Bool.self, forKey: .snapshotDeleted) ?? false
        setupDone = try container.decodeIfPresent(Bool.self, forKey: .setupDone) ?? false
        serviceProfile = try container.decodeIfPresent(String.self, forKey: .serviceProfile) ?? "none"
        serviceGroups = try container.decodeIfPresent([String].self, forKey: .serviceGroups) ?? []
        removedApps = try container.decodeIfPresent([String].self, forKey: .removedApps) ?? []
        trimTier = try container.decodeIfPresent(String.self, forKey: .trimTier) ?? "none"
        unregisterAttempts = try container.decodeIfPresent([String: Int].self, forKey: .unregisterAttempts) ?? [:]
    }
}

// MARK: - Source

/// `TemplateSource.plist`, in a machine cloned from a template: which
/// template it shares blocks with.
///
/// The identifier names a key, and a key outlives any one template built for
/// it: a template deleted and built again gets the same identifier, but the
/// new one shares no block with machines cloned from the old one. `Build`
/// names the build, so only machines of the template that exists now count
/// as its users.
public struct VPhoneMachineTemplateSource: Codable, Equatable, Sendable {
    public var identifier: String
    /// The ``VPhoneMachineTemplateRecord/build`` of the template it was cloned
    /// from; nil in a record written before builds had one, or for a
    /// template without one.
    public var build: String?
    public var cloned: Date

    public init(identifier: String, build: String? = nil, cloned: Date = Date()) {
        self.identifier = identifier
        self.build = build
        self.cloned = VPhoneMachineTemplates.wholeSeconds(cloned)
    }

    /// Whether a machine with this record was cloned from the template
    /// `record` describes, and not from an earlier one with the same key.
    /// Both sides having a build decides it. Otherwise (a record written
    /// before builds were recorded, on either side) the dates do: a machine
    /// cloned before the template was frozen cannot have come from it.
    public func isClone(of record: VPhoneMachineTemplateRecord) -> Bool {
        guard identifier == record.identifier else { return false }
        if let build, let other = record.build {
            return build == other
        }
        return cloned >= (record.frozenAt ?? record.created)
    }

    private enum CodingKeys: String, CodingKey {
        case identifier = "Identifier"
        case build = "Build"
        case cloned = "Cloned"
    }
}

/// How a machine's ``VPhoneMachineTemplateSource`` stands to the template
/// that has its identifier in the library now. `vm list --json` and `vm info
/// --json` report it as `templateMatch`, and Launchpad's inspector shows it
/// from there, so the match is decided only here
/// (``VPhoneMachineTemplateSource/isClone(of:)``).
public enum VPhoneMachineTemplateMatch: String, Codable, Equatable, Sendable {
    /// Cloned from the template that has the identifier now.
    case current
    /// Cloned from an earlier build with the same key, since deleted.
    case earlierBuild
    /// No template has the identifier now (or its record cannot be read, so
    /// `vm template list` does not list it).
    case deleted
}

// MARK: - Sources

/// The IPSW sources a template was built from, as the create named them: a
/// URL or a local path for each. `vm template find` matches a request
/// against them, so a create finds its template after the IPSWs it came
/// from were deleted, without downloading them again to read their builds.
public struct VPhoneMachineTemplateSources: Codable, Equatable, Sendable {
    public var iPhone: String
    public var cloudOS: String

    public init(iPhone: String, cloudOS: String) {
        self.iPhone = iPhone
        self.cloudOS = cloudOS
    }

    private enum CodingKeys: String, CodingKey {
        case iPhone = "IPhone"
        case cloudOS = "CloudOS"
    }
}

/// The guest device and the two OS builds a request's key starts from, and
/// where they came from.
public struct VPhoneMachineTemplateBuilds: Equatable, Sendable {
    public enum Origin: String, Sendable {
        /// Read from the IPSWs: local files, or remote ones already cached.
        case ipsw
        /// Taken from the key of a template whose record names the same two
        /// sources (``VPhoneMachineTemplates/templates(builtFrom:device:in:)``).
        case template
    }

    public var device: String
    public var ios: VPhoneRestoreInfo.OSVersion
    public var cloudOS: VPhoneRestoreInfo.OSVersion
    public var origin: Origin
    /// The template the builds were taken from, for ``Origin/template``.
    public var template: String?

    public init(
        device: String,
        ios: VPhoneRestoreInfo.OSVersion,
        cloudOS: VPhoneRestoreInfo.OSVersion,
        origin: Origin,
        template: String? = nil,
    ) {
        self.device = device
        self.ios = ios
        self.cloudOS = cloudOS
        self.origin = origin
        self.template = template
    }
}

// MARK: - Record

/// `Template.plist`, in the template's machine folder.
public struct VPhoneMachineTemplateRecord: Codable, Equatable, Sendable {
    public var identifier: String
    public var key: VPhoneMachineTemplateKey
    public var created: Date
    /// The `VPhone.bundle` whose `vphone-cli` built or adopted the template.
    public var builtWithBundleVersion: String?
    /// The bundle that patched and restored the boot chain, when known.
    public var bootChainBundleVersion: String?
    /// The machine the template was adopted from, or the machine whose create
    /// built it. A clone's `--mdns on` name follows from it to the clone's.
    public var sourceMachine: String?
    /// Set once the template is complete. A frozen template is never booted.
    public var frozen: Bool
    public var frozenAt: Date?
    public var steps: VPhoneMachineTemplateSteps
    /// The IPSWs it was built from, when the build named them; nil for a
    /// template adopted without them. Not part of the key: two URLs of the
    /// same build make the same template.
    public var sources: VPhoneMachineTemplateSources?
    /// A UUID set each time a template is frozen or adopted, and copied into
    /// each clone's `TemplateSource.plist`. The identifier stays the same
    /// when a template is deleted and built again; this does not, so the
    /// clones of an earlier build are not counted as the new one's users.
    /// Nil for a template frozen before it was recorded.
    public var build: String?

    public init(
        key: VPhoneMachineTemplateKey,
        created: Date = Date(),
        builtWithBundleVersion: String? = nil,
        bootChainBundleVersion: String? = nil,
        sourceMachine: String? = nil,
        frozen: Bool = false,
        frozenAt: Date? = nil,
        steps: VPhoneMachineTemplateSteps = VPhoneMachineTemplateSteps(),
        sources: VPhoneMachineTemplateSources? = nil,
        build: String? = nil,
    ) {
        identifier = key.identifier
        self.key = key
        self.created = VPhoneMachineTemplates.wholeSeconds(created)
        self.builtWithBundleVersion = builtWithBundleVersion
        self.bootChainBundleVersion = bootChainBundleVersion
        self.sourceMachine = sourceMachine
        self.frozen = frozen
        self.frozenAt = frozenAt.map(VPhoneMachineTemplates.wholeSeconds)
        self.steps = steps
        self.sources = sources
        self.build = build
    }

    private enum CodingKeys: String, CodingKey {
        case identifier = "Identifier"
        case key = "Key"
        case created = "Created"
        case builtWithBundleVersion = "BuiltWithBundleVersion"
        case bootChainBundleVersion = "BootChainBundleVersion"
        case sourceMachine = "SourceMachine"
        case frozen = "Frozen"
        case frozenAt = "FrozenAt"
        case steps = "Steps"
        case sources = "Sources"
        case build = "Build"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        key = try container.decode(VPhoneMachineTemplateKey.self, forKey: .key)
        created = try container.decode(Date.self, forKey: .created)
        builtWithBundleVersion = try container.decodeIfPresent(String.self, forKey: .builtWithBundleVersion)
        bootChainBundleVersion = try container.decodeIfPresent(String.self, forKey: .bootChainBundleVersion)
        sourceMachine = try container.decodeIfPresent(String.self, forKey: .sourceMachine)
        frozen = try container.decodeIfPresent(Bool.self, forKey: .frozen) ?? false
        frozenAt = try container.decodeIfPresent(Date.self, forKey: .frozenAt)
        steps = try container.decodeIfPresent(VPhoneMachineTemplateSteps.self, forKey: .steps) ?? VPhoneMachineTemplateSteps()
        sources = try container.decodeIfPresent(VPhoneMachineTemplateSources.self, forKey: .sources)
        build = try container.decodeIfPresent(String.self, forKey: .build)
    }
}

// MARK: - Template

/// A frozen template in `<library>/.templates/<identifier>/`.
public struct VPhoneMachineTemplate: Sendable {
    public let url: URL
    public let record: VPhoneMachineTemplateRecord

    public var identifier: String {
        record.identifier
    }

    public var key: VPhoneMachineTemplateKey {
        record.key
    }

    public func bundle() throws -> VPhoneBundle {
        try VPhoneBundle.load(at: url)
    }

    /// Why a create with the same options would not use this template as it
    /// is, or nothing when it is current.
    ///
    /// - Parameters:
    ///   - currentSeries: This `vphone-cli`'s bundle series. Templates never
    ///     cross a series: a new series rebuilds them.
    ///   - freshKey: The key a create with this template's options resolves
    ///     to now, or nil when it cannot be resolved (an unknown preset).
    ///   - driftedPatches: Boot-chain patches the plan wants that the
    ///     template's receipt does not record as live, or the reverse.
    public func staleReasons(currentSeries: String?, freshKey: VPhoneMachineTemplateKey?, driftedPatches: [String] = []) -> [String] {
        var reasons: [String] = []
        if key.formatVersion != VPhoneMachineTemplateKey.currentFormatVersion {
            reasons.append("keyed by format \(key.formatVersion); this vphone-cli uses \(VPhoneMachineTemplateKey.currentFormatVersion)")
        }
        if let currentSeries, currentSeries != key.bundleSeries {
            reasons.append("built by bundle series \(key.bundleSeries); this vphone-cli is \(currentSeries)")
        }
        if let freshKey {
            let changed = key.differences(from: freshKey).filter { !$0.hasPrefix("bundle series") && !$0.hasPrefix("key format") }
            if !changed.isEmpty {
                reasons.append("a create with the same options now resolves differently (\(changed.joined(separator: "; ")))")
            }
        } else {
            reasons.append("its preset \(key.patchPreset) cannot be resolved by this vphone-cli")
        }
        if !driftedPatches.isEmpty {
            reasons.append("boot-chain patches differ from its receipt: \(driftedPatches.joined(separator: ", "))")
        }
        return reasons
    }
}

/// A build folder in `.templates`: `.building-<identifier>-<uuid>`. Its
/// machine folder is inside it, named by the identifier.
public struct VPhoneMachineTemplateStaging: Sendable {
    public let name: String
    public let url: URL
    public let identifier: String?
    /// Whether a build holds the identifier's lock now.
    public let isActive: Bool
}

public struct VPhoneMachineTemplateListing: Sendable {
    public var templates: [VPhoneMachineTemplate] = []
    public var staging: [VPhoneMachineTemplateStaging] = []
    /// Folders in `.templates` that look like templates but cannot be read.
    public var damaged: [VPhoneLibrarySkip] = []
}

// MARK: - Lock

/// `flock` on `.templates/.lock-<identifier>`, held while a template with
/// that key is being built, so a second create of the same key waits for the
/// first instead of restoring a second copy. Released on `release()` or when
/// the process exits.
public final class VPhoneMachineTemplateLock: @unchecked Sendable {
    private var descriptor: Int32

    fileprivate init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    public func release() {
        guard descriptor >= 0 else { return }
        flock(descriptor, LOCK_UN)
        close(descriptor)
        descriptor = -1
    }

    deinit {
        release()
    }
}

/// A template being built: the staging folder, and the machine folder in it.
public struct VPhoneMachineTemplateBuild: Sendable {
    public let identifier: String
    /// `.templates/.building-<identifier>-<uuid>`.
    public let stagingURL: URL

    public init(identifier: String, stagingURL: URL) {
        self.identifier = identifier
        self.stagingURL = stagingURL
    }

    /// The library the machine folder is created in: the staging folder.
    public var library: VPhoneLibrary {
        VPhoneLibrary(root: stagingURL)
    }

    /// `<staging>/<identifier>`, the machine folder the build fills.
    public var bundleURL: URL {
        stagingURL.appendingPathComponent(identifier, isDirectory: true)
    }
}

// MARK: - Templates

/// Machine templates: complete, never-booted machines that new machines are
/// cloned from with a new identity, sharing every unchanged block through
/// APFS. They live in `<library>/.templates/<identifier>/`, on the library's
/// volume so clones are `clonefile(2)` copies, in a hidden folder so
/// `vm list` and Launchpad never show them, and under a name `vm launch`
/// cannot resolve.
///
/// A template must never boot once it is frozen: a clone made before such a
/// boot would diverge from it in every block the boot wrote, and every clone
/// made after it would inherit that boot's state. `vphone-vm` and `vm launch`
/// refuse a frozen template.
public enum VPhoneMachineTemplates {
    public static let directoryName = ".templates"
    public static let recordFileName = "Template.plist"
    static let stagingPrefix = ".building-"
    static let lockPrefix = ".lock-"

    public static func directory(in library: VPhoneLibrary) -> URL {
        library.root.appendingPathComponent(directoryName, isDirectory: true)
    }

    public static func url(of identifier: String, in library: VPhoneLibrary) -> URL {
        directory(in: library).appendingPathComponent(identifier, isDirectory: true)
    }

    // MARK: Records

    /// The template record in a machine folder, or nil when there is none.
    public static func readRecord(inBundle url: URL) throws -> VPhoneMachineTemplateRecord? {
        let file = url.appendingPathComponent(recordFileName)
        guard VPhoneVirtualMachineManifest.fileKind(at: file) != .missing else { return nil }
        guard VPhoneVirtualMachineManifest.fileKind(at: file) == .regularFile else {
            throw VPhoneMachineTemplateError.damaged(name: url.lastPathComponent, reason: "\(recordFileName) is not a regular file")
        }
        do {
            return try PropertyListDecoder().decode(VPhoneMachineTemplateRecord.self, from: Data(contentsOf: file))
        } catch {
            throw VPhoneMachineTemplateError.damaged(name: url.lastPathComponent, reason: "\(recordFileName) is unreadable")
        }
    }

    /// Atomic: a link at `Template.plist` is replaced, not written through.
    public static func writeRecord(_ record: VPhoneMachineTemplateRecord, inBundle url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let file = url.appendingPathComponent(recordFileName)
        try encoder.encode(record).write(to: file, options: .atomic)
        try VPhoneHostFilePermissions.makeAccessible(at: file)
    }

    /// Changes the build steps of a template that is still being built. A
    /// frozen template is refused: it is shared by its clones, and nothing
    /// may change it.
    ///
    /// A machine without a record (one Launchpad is building in the library
    /// before it adopts it) gets the unfrozen record `creating` returns
    /// first; without `creating` it is refused.
    public static func recordSteps(
        inBundle url: URL,
        creating: (() throws -> VPhoneMachineTemplateRecord)? = nil,
        _ body: (inout VPhoneMachineTemplateSteps) -> Void,
    ) throws {
        var existing = try readRecord(inBundle: url)
        if existing == nil, let creating {
            existing = try creating()
            existing?.frozen = false
            existing?.frozenAt = nil
        }
        guard var record = existing else {
            throw VPhoneMachineTemplateError.notBeingBuilt(path: url.path)
        }
        guard !record.frozen else {
            throw VPhoneMachineTemplateError.frozen(identifier: record.identifier)
        }
        body(&record.steps)
        try writeRecord(record, inBundle: url)
    }

    // MARK: Booting

    /// Why the machine at `bundleURL` must not boot, or nil when it may: it
    /// is a frozen template, or a folder directly in `.templates`. A machine
    /// still being built in a staging folder may boot (the setup boot does).
    public static func bootRefusal(bundleURL: URL) -> VPhoneMachineTemplateError? {
        let url = bundleURL.absoluteURL.standardizedFileURL
        if url.deletingLastPathComponent().lastPathComponent == directoryName {
            return .notBootable(identifier: url.lastPathComponent)
        }
        switch Result(catching: { try readRecord(inBundle: url) }) {
        case let .success(record?) where record.frozen:
            return .notBootable(identifier: record.identifier)
        case .success:
            return nil
        case .failure:
            // A record that cannot be read may be a frozen one.
            return .notBootable(identifier: url.lastPathComponent)
        }
    }

    public static func requireBootable(bundleURL: URL) throws {
        if let refusal = bootRefusal(bundleURL: bundleURL) {
            throw refusal
        }
    }

    // MARK: List

    public static func list(in library: VPhoneLibrary) throws -> VPhoneMachineTemplateListing {
        let root = directory(in: library)
        let fm = FileManager.default
        var listing = VPhoneMachineTemplateListing()
        guard isDirectory(root) else { return listing }
        for name in try fm.contentsOfDirectory(atPath: root.path).sorted() {
            let url = root.appendingPathComponent(name, isDirectory: true)
            if name.hasPrefix(stagingPrefix), isDirectory(url) {
                let identifier = stagingIdentifier(name)
                listing.staging.append(VPhoneMachineTemplateStaging(
                    name: name,
                    url: url,
                    identifier: identifier,
                    isActive: identifier.map { isLocked($0, in: library) } ?? false,
                ))
                continue
            }
            guard !name.hasPrefix("."), isDirectory(url) else { continue }
            do {
                try listing.templates.append(load(url))
            } catch {
                listing.damaged.append(VPhoneLibrarySkip(name: name, reason: "\(error)"))
            }
        }
        listing.templates.sort { ($0.record.created, $0.identifier) < ($1.record.created, $1.identifier) }
        return listing
    }

    /// The frozen template with this identifier, or with this unique prefix
    /// of one (at least four digits).
    public static func template(_ identifier: String, in library: VPhoneLibrary) throws -> VPhoneMachineTemplate {
        if VPhoneMachineTemplateKey.isIdentifier(identifier) {
            let url = url(of: identifier, in: library)
            guard isDirectory(url) else { throw VPhoneMachineTemplateError.notFound(identifier) }
            return try load(url)
        }
        let lowered = identifier.lowercased()
        guard lowered.count >= 4, lowered.count < VPhoneMachineTemplateKey.identifierLength,
              lowered.utf8.allSatisfy({ ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66) })
        else {
            throw VPhoneMachineTemplateError.invalidIdentifier(identifier)
        }
        let matches = try list(in: library).templates.filter { $0.identifier.hasPrefix(lowered) }
        guard let only = matches.first else { throw VPhoneMachineTemplateError.notFound(identifier) }
        guard matches.count == 1 else {
            throw VPhoneMachineTemplateError.ambiguous(identifier, matches: matches.map(\.identifier))
        }
        return only
    }

    /// The frozen templates whose record says they were built from these two
    /// sources, newest first. Their keys give the builds those sources hold,
    /// so a request can be keyed without the IPSWs, which may have been
    /// deleted since. A template for another `device` is left out when one
    /// is named.
    public static func templates(
        builtFrom sources: VPhoneMachineTemplateSources,
        device: String? = nil,
        in library: VPhoneLibrary,
    ) -> [VPhoneMachineTemplate] {
        let templates = (try? list(in: library).templates) ?? []
        return templates
            .filter { $0.record.sources == sources && (device == nil || $0.key.device == device) }
            .sorted { $0.record.created > $1.record.created }
    }

    /// Why ``resolveBuilds(sources:device:in:local:)`` found nothing.
    public static let unresolvedBuildsReason = "the IPSWs are not downloaded and no template records these sources"

    /// The builds a request names, without downloading anything: first
    /// `local`, which reads the two IPSWs when both are local files or in
    /// the IPSW cache and returns nil otherwise (a local path that no longer
    /// exists included); then the newest template recorded with the same
    /// two sources (and `device`, when one is named). Nil when neither has
    /// them: only a download would tell. `vm template find` and `vm create`
    /// both resolve this way, so a create clones the template find reports
    /// and downloads only for a build.
    public static func resolveBuilds(
        sources: VPhoneMachineTemplateSources,
        device: String?,
        in library: VPhoneLibrary,
        local: () throws -> VPhoneMachineTemplateBuilds?,
    ) throws -> VPhoneMachineTemplateBuilds? {
        if let builds = try local() {
            return builds
        }
        guard let template = templates(builtFrom: sources, device: device, in: library).first else {
            return nil
        }
        let key = template.key
        return VPhoneMachineTemplateBuilds(
            device: key.device,
            ios: .init(version: key.iOSVersion, build: key.iOSBuild),
            cloudOS: .init(version: key.cloudOSVersion, build: key.cloudOSBuild),
            origin: .template,
            template: template.identifier,
        )
    }

    /// The template whose key this is, if one is frozen.
    public static func template(for key: VPhoneMachineTemplateKey, in library: VPhoneLibrary) throws -> VPhoneMachineTemplate? {
        let url = url(of: key.identifier, in: library)
        guard isDirectory(url) else { return nil }
        return try load(url)
    }

    /// Reads a template folder and checks it is what its name says: a frozen
    /// record whose key hashes to the folder's name, and a loadable machine.
    static func load(_ url: URL) throws -> VPhoneMachineTemplate {
        let name = url.lastPathComponent
        guard VPhoneMachineTemplateKey.isIdentifier(name) else {
            throw VPhoneMachineTemplateError.damaged(name: name, reason: "the folder name is not a template identifier")
        }
        guard let record = try readRecord(inBundle: url) else {
            throw VPhoneMachineTemplateError.damaged(name: name, reason: "it has no \(recordFileName)")
        }
        guard record.frozen else {
            throw VPhoneMachineTemplateError.damaged(name: name, reason: "it was never frozen")
        }
        guard record.identifier == name, record.key.identifier == name else {
            throw VPhoneMachineTemplateError.damaged(name: name, reason: "its key does not match its folder name")
        }
        _ = try VPhoneBundle.load(at: url)
        return VPhoneMachineTemplate(url: url, record: record)
    }

    // MARK: Lock

    /// Takes the build lock for `identifier`. `wait: false` throws
    /// `.busy` when another build holds it.
    public static func lock(_ identifier: String, in library: VPhoneLibrary, wait: Bool) throws -> VPhoneMachineTemplateLock {
        guard VPhoneMachineTemplateKey.isIdentifier(identifier) else {
            throw VPhoneMachineTemplateError.invalidIdentifier(identifier)
        }
        try ensureDirectory(in: library)
        let path = directory(in: library).appendingPathComponent(lockPrefix + identifier).path
        let fd = open(path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o666)
        guard fd >= 0 else {
            throw VPhoneMachineTemplateError.failed(path: path, reason: String(cString: strerror(errno)))
        }
        fchmod(fd, 0o777)
        if flock(fd, LOCK_EX | (wait ? 0 : LOCK_NB)) != 0 {
            let code = errno
            close(fd)
            if code == EWOULDBLOCK {
                throw VPhoneMachineTemplateError.busy(identifier: identifier)
            }
            throw VPhoneMachineTemplateError.failed(path: path, reason: String(cString: strerror(code)))
        }
        return VPhoneMachineTemplateLock(descriptor: fd)
    }

    static func isLocked(_ identifier: String, in library: VPhoneLibrary) -> Bool {
        let path = directory(in: library).appendingPathComponent(lockPrefix + identifier).path
        let fd = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            flock(fd, LOCK_UN)
            return false
        }
        return errno == EWOULDBLOCK
    }

    // MARK: Build

    /// Makes the staging folder a template with `key` is built in. The caller
    /// holds the key's lock, creates the machine in `build.library` named by
    /// the identifier, writes an unfrozen record into it, fills it, and ends
    /// with ``freeze(_:record:now:)`` or ``abandon(_:)``.
    public static func beginBuild(_ key: VPhoneMachineTemplateKey, in library: VPhoneLibrary) throws -> VPhoneMachineTemplateBuild {
        try ensureDirectory(in: library)
        let identifier = key.identifier
        if isDirectory(url(of: identifier, in: library)) {
            throw VPhoneMachineTemplateError.alreadyExists(identifier)
        }
        let staging = directory(in: library)
            .appendingPathComponent("\(stagingPrefix)\(identifier)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        try VPhoneHostFilePermissions.makeDirectoryAccessible(at: staging)
        return VPhoneMachineTemplateBuild(identifier: identifier, stagingURL: staging)
    }

    /// Marks the built machine frozen and moves it to `.templates/<identifier>`
    /// in one rename, so a listed template is always complete. Refused when
    /// its steps did not produce what its key promises or left a trim without
    /// its snapshot deletion (``VPhoneMachineTemplateSteps/problems``), or a
    /// template with the identifier appeared meanwhile; the build is then
    /// left in place. The restore tree is removed: templates never keep it.
    @discardableResult
    public static func freeze(_ build: VPhoneMachineTemplateBuild, now: Date = Date()) throws -> VPhoneMachineTemplate {
        guard var record = try readRecord(inBundle: build.bundleURL) else {
            throw VPhoneMachineTemplateError.notBeingBuilt(path: build.bundleURL.path)
        }
        guard record.identifier == build.identifier, record.key.identifier == build.identifier else {
            throw VPhoneMachineTemplateError.damaged(name: build.identifier, reason: "its record names another key")
        }
        guard record.steps.slimming == record.key.slimming else {
            throw VPhoneMachineTemplateError.stepsDoNotMatchKey(
                identifier: build.identifier,
                differences: record.key.slimmingDifferences(from: record.steps.slimming),
            )
        }
        guard record.steps.problems.isEmpty else {
            throw VPhoneMachineTemplateError.incomplete(identifier: build.identifier, problems: record.steps.problems)
        }
        let bundle = try VPhoneBundle.load(at: build.bundleURL)
        try VPhoneBundleActivity.requireStopped(bundle)
        try removeRestoreTree(of: bundle)
        record.frozen = true
        record.frozenAt = Self.wholeSeconds(now)
        record.build = UUID().uuidString
        try writeRecord(record, inBundle: build.bundleURL)
        let destination = url(of: build.identifier, in: build.libraryRoot)
        do {
            try removeIfPresent(build.bundleURL.appendingPathComponent("vphone.sock"))
            try renameExclusive(build.bundleURL, to: destination, identifier: build.identifier)
        } catch {
            record.frozen = false
            record.frozenAt = nil
            record.build = nil
            try? writeRecord(record, inBundle: build.bundleURL)
            throw error
        }
        rmdir(build.stagingURL.path)
        try VPhoneHostFilePermissions.makeDirectoryAccessible(at: destination)
        return VPhoneMachineTemplate(url: destination, record: record)
    }

    /// Removes a build's staging folder and everything in it.
    public static func abandon(_ build: VPhoneMachineTemplateBuild) throws {
        try FileManager.default.removeItem(at: build.stagingURL)
    }

    // MARK: Adopt

    /// Freezes a stopped machine of the library into the template `record`
    /// describes: writes the frozen record into its folder and renames the
    /// folder to `.templates/<identifier>`. The machine is gone from the
    /// library afterwards.
    ///
    /// Refused when the machine runs, has snapshots (a template carries no
    /// history, and they would keep their blocks for as long as it lives),
    /// its steps fall short of the key or have problems, or a template with
    /// that key exists. On a failure the machine is left as it was, except
    /// that a restore tree it kept is removed before the rename: templates
    /// never keep it.
    @discardableResult
    public static func adopt(
        machineNamed name: String,
        in library: VPhoneLibrary,
        record proposed: VPhoneMachineTemplateRecord,
        now: Date = Date(),
    ) throws -> VPhoneMachineTemplate {
        let bundle = try library.bundle(named: name)
        try VPhoneBundleActivity.requireStopped(bundle)
        if let snapshots = try? VPhoneMachineSnapshots.list(of: bundle), !snapshots.isEmpty {
            throw VPhoneMachineTemplateError.hasSnapshots(machine: name, count: snapshots.count)
        }
        if isDirectory(VPhoneMachineSnapshots.directory(of: bundle)) {
            // Unreadable snapshot folders hold blocks all the same.
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: VPhoneMachineSnapshots.directory(of: bundle).path)) ?? []
            if !entries.isEmpty {
                throw VPhoneMachineTemplateError.hasSnapshots(machine: name, count: entries.count)
            }
        }
        let previous = try readRecord(inBundle: bundle.url)
        if let previous, previous.frozen {
            throw VPhoneMachineTemplateError.damaged(name: name, reason: "it already carries a frozen \(recordFileName)")
        }
        var record = proposed
        record.identifier = record.key.identifier
        guard record.steps.slimming == record.key.slimming else {
            throw VPhoneMachineTemplateError.stepsDoNotMatchKey(
                identifier: record.identifier,
                differences: record.key.slimmingDifferences(from: record.steps.slimming),
            )
        }
        guard record.steps.problems.isEmpty else {
            throw VPhoneMachineTemplateError.incomplete(identifier: record.identifier, problems: record.steps.problems)
        }
        let destination = url(of: record.identifier, in: library)
        if isDirectory(destination) {
            throw VPhoneMachineTemplateError.alreadyExists(record.identifier)
        }
        try ensureDirectory(in: library)
        // Gone even if the rename below fails: it is only ever rebuilt from
        // the IPSW, and a template must not carry it.
        try removeRestoreTree(of: bundle)
        record.frozen = true
        record.frozenAt = Self.wholeSeconds(now)
        record.build = UUID().uuidString
        try writeRecord(record, inBundle: bundle.url)
        do {
            // Checked again just before the rename: nothing may have opened
            // the machine while the record was written.
            try VPhoneBundleActivity.requireStopped(bundle)
            try removeIfPresent(bundle.url.appendingPathComponent("vphone.sock"))
            try renameExclusive(bundle.url, to: destination, identifier: record.identifier)
        } catch {
            if let previous {
                try? writeRecord(previous, inBundle: bundle.url)
            } else {
                try? removeIfPresent(bundle.url.appendingPathComponent(recordFileName))
            }
            throw error
        }
        try VPhoneHostFilePermissions.makeDirectoryAccessible(at: destination)
        return VPhoneMachineTemplate(url: destination, record: record)
    }

    // MARK: Clone

    /// A new machine `newName` in the library, cloned from the template with a
    /// new identity: a new ECID, MAC address and UDID on its first start, the
    /// template's disk, SEP storage and NVRAM shared block for block until
    /// either side writes. The clone is an ordinary machine: it carries no
    /// `Template.plist` and boots normally.
    @discardableResult
    public static func cloneMachine(
        from template: VPhoneMachineTemplate,
        to newName: String,
        in library: VPhoneLibrary,
    ) throws -> VPhoneBundle {
        let source = try template.bundle()
        let clone = try VPhoneBundleOperations.clone(
            source,
            sourceName: template.record.sourceMachine ?? template.identifier,
            to: newName,
            in: library,
            newIdentity: true,
        )
        do {
            try writeSource(
                VPhoneMachineTemplateSource(identifier: template.identifier, build: template.record.build),
                inBundle: clone.url,
            )
        } catch {
            try? FileManager.default.removeItem(at: clone.url)
            throw error
        }
        return clone
    }

    // MARK: Source

    /// `TemplateSource.plist`, in a machine cloned from a template. A plain
    /// `vm clone` of such a machine keeps it (the copy shares the template's
    /// blocks too); an export leaves it out, since an imported machine
    /// shares nothing with any template.
    public static let sourceFileName = "TemplateSource.plist"

    /// The template a machine was cloned from, or nil for a machine that was
    /// not, or whose record cannot be read.
    public static func readSource(inBundle url: URL) -> VPhoneMachineTemplateSource? {
        let file = url.appendingPathComponent(sourceFileName)
        guard VPhoneVirtualMachineManifest.fileKind(at: file) == .regularFile,
              let data = try? Data(contentsOf: file),
              let source = try? PropertyListDecoder().decode(VPhoneMachineTemplateSource.self, from: data),
              VPhoneMachineTemplateKey.isIdentifier(source.identifier)
        else { return nil }
        return source
    }

    /// Whether the template `source` names is still in `library` and is the
    /// build the machine was cloned from.
    public static func match(of source: VPhoneMachineTemplateSource, in library: VPhoneLibrary) -> VPhoneMachineTemplateMatch {
        guard let template = try? template(source.identifier, in: library) else { return .deleted }
        return source.isClone(of: template.record) ? .current : .earlierBuild
    }

    static func writeSource(_ source: VPhoneMachineTemplateSource, inBundle url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let file = url.appendingPathComponent(sourceFileName)
        try encoder.encode(source).write(to: file, options: .atomic)
        try VPhoneHostFilePermissions.makeAccessible(at: file)
    }

    /// The machines of the library cloned from each template, by template
    /// identifier, sorted by name. Templates adopted from such a machine
    /// count too, under `.templates/<id>`: they share its blocks as well.
    ///
    /// A machine counts only for the template it was cloned from
    /// (``VPhoneMachineTemplateSource/isClone(of:)``): one cloned from an
    /// earlier template with the same key, since deleted and built again,
    /// shares nothing with the template that exists now and is left out. A
    /// machine whose template no longer exists is listed under its identifier.
    public static func usage(in library: VPhoneLibrary) -> [String: [String]] {
        let templates = (try? list(in: library).templates) ?? []
        var records: [String: VPhoneMachineTemplateRecord] = [:]
        for template in templates {
            records[template.identifier] = template.record
        }
        var users: [String: [String]] = [:]
        func count(_ source: VPhoneMachineTemplateSource, as user: String) {
            if let record = records[source.identifier], !source.isClone(of: record) {
                return
            }
            users[source.identifier, default: []].append(user)
        }
        for bundle in (try? library.bundles()) ?? [] {
            if let source = readSource(inBundle: bundle.url) {
                count(source, as: bundle.name)
            }
        }
        for template in templates {
            if let source = readSource(inBundle: template.url), source.identifier != template.identifier {
                count(source, as: "\(directoryName)/\(template.identifier)")
            }
        }
        return users.mapValues { $0.sorted() }
    }

    /// The template `source` names, when it still exists, the deleted machine
    /// was cloned from it (not from an earlier template with the same key),
    /// and nothing in the library uses it any more: what `vm delete` reports
    /// after deleting a machine cloned from it. Never deletes it.
    public static func unusedTemplate(after source: VPhoneMachineTemplateSource?, in library: VPhoneLibrary) -> VPhoneMachineTemplate? {
        guard let source,
              let template = try? Self.template(source.identifier, in: library),
              source.isClone(of: template.record),
              usage(in: library)[template.identifier, default: []].isEmpty
        else { return nil }
        return template
    }

    /// The bytes a folder's files take on disk (`st_blocks`), without
    /// following links: what deleting it would free once nothing shares it.
    public static func allocatedBytes(of url: URL) -> UInt64 {
        var total: UInt64 = 0
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isSymbolicLinkKey]
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: []) else {
            return 0
        }
        for case let file as URL in walker {
            guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isSymbolicLink != true else { continue }
            total += UInt64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: Restore tree

    /// Templates never keep the restore tree: the ~11 GB of prepared
    /// firmware a full `cfw install` reads would stay pinned for as long as
    /// the template lives, and no clone can use it. `freeze` and `adopt`
    /// remove it. Returns the folder's name, or nil when there was none.
    @discardableResult
    public static func removeRestoreTree(of bundle: VPhoneBundle) throws -> String? {
        try VPhoneRestoreInfo.removeBuiltFirmware(fromBundle: bundle)
    }

    /// The restore tree's name in a machine folder, or nil.
    public static func restoreTree(of bundle: VPhoneBundle) -> String? {
        (try? VPhoneConfinedDirectory(root: bundle.url.path)).flatMap(VPhoneRestoreInfo.findRestoreDirectory(in:))
    }

    // MARK: Delete

    /// What `vm template delete` says about the space it freed, from what is
    /// known. `machines` is what ``usage(in:)`` listed for the template before
    /// it was deleted: the machines that use it now. Machines cloned from it
    /// and deleted since are not among them, so the note never claims it was
    /// never cloned. With no user its blocks are freed, unless a local Time
    /// Machine snapshot taken while it existed keeps them; with users, the
    /// blocks they share stay allocated until they change them or are deleted.
    public static func deletionNote(machines: [String]) -> String {
        guard !machines.isEmpty else {
            return "no machine uses it now; deleting frees its blocks "
                + "(a local Time Machine snapshot may keep them until it expires)"
        }
        return "\(machines.count) machine(s) use it (\(machines.joined(separator: ", "))); "
            + "the blocks they share with it stay allocated until they change them or are deleted"
    }

    /// Removes a frozen template, by identifier or unique prefix, or a staging
    /// folder by its `.building-…` name that no build holds. Returns what was
    /// removed. Machines cloned from the template keep working: they share
    /// its blocks, they do not refer to it, and the shared blocks are freed
    /// only once no clone uses them either.
    @discardableResult
    public static func delete(_ name: String, in library: VPhoneLibrary) throws -> URL {
        if name.hasPrefix(stagingPrefix) {
            guard let staging = try list(in: library).staging.first(where: { $0.name == name }) else {
                throw VPhoneMachineTemplateError.notFound(name)
            }
            if staging.isActive {
                throw VPhoneMachineTemplateError.busy(identifier: staging.identifier ?? name)
            }
            try FileManager.default.removeItem(at: staging.url)
            return staging.url
        }
        let url: URL
        do {
            url = try template(name, in: library).url
        } catch VPhoneMachineTemplateError.damaged where VPhoneMachineTemplateKey.isIdentifier(name) {
            // A damaged template is deleted all the same, by its full name.
            url = self.url(of: name, in: library)
        }
        // The empty `.lock-<identifier>` file stays: removing a lock file
        // another process may be about to open would let two builds hold
        // "the" lock on different inodes.
        try FileManager.default.removeItem(at: url)
        return url
    }

    // MARK: - Files

    /// An XML property list keeps dates to the second; a record returned is
    /// the record read back.
    static func wholeSeconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    static func ensureDirectory(in library: VPhoneLibrary) throws {
        let root = directory(in: library)
        var info = stat()
        if lstat(root.path, &info) == 0 {
            guard info.st_mode & S_IFMT == S_IFDIR else {
                throw VPhoneMachineTemplateError.failed(path: root.path, reason: "not a directory")
            }
            return
        }
        try FileManager.default.createDirectory(at: library.root, withIntermediateDirectories: true)
        if mkdir(root.path, 0o777) != 0, errno != EEXIST {
            throw VPhoneMachineTemplateError.failed(path: root.path, reason: String(cString: strerror(errno)))
        }
        try VPhoneHostFilePermissions.makeDirectoryAccessible(at: root)
    }

    private static func stagingIdentifier(_ name: String) -> String? {
        let rest = name.dropFirst(stagingPrefix.count)
        let identifier = String(rest.prefix(VPhoneMachineTemplateKey.identifierLength))
        return VPhoneMachineTemplateKey.isIdentifier(identifier) ? identifier : nil
    }

    private static func renameExclusive(_ source: URL, to destination: URL, identifier: String) throws {
        guard renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EEXIST {
                throw VPhoneMachineTemplateError.alreadyExists(identifier)
            }
            throw VPhoneMachineTemplateError.failed(path: destination.path, reason: String(cString: strerror(errno)))
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR
    }

    private static func removeIfPresent(_ url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }
}

extension VPhoneMachineTemplateBuild {
    /// The library whose `.templates` holds the staging folder.
    var libraryRoot: VPhoneLibrary {
        VPhoneLibrary(root: stagingURL.deletingLastPathComponent().deletingLastPathComponent())
    }
}

extension VPhoneMachineTemplateKey {
    func slimmingDifferences(from done: VPhoneMachineTemplateSlimming) -> [String] {
        var copy = self
        copy.slimming = done
        return differences(from: copy)
    }
}

// MARK: - Error

public enum VPhoneMachineTemplateError: Error, Equatable {
    case invalidIdentifier(String)
    case notFound(String)
    case ambiguous(String, matches: [String])
    case alreadyExists(String)
    case busy(identifier: String)
    case damaged(name: String, reason: String)
    case notBootable(identifier: String)
    case frozen(identifier: String)
    case notBeingBuilt(path: String)
    case hasSnapshots(machine: String, count: Int)
    case stepsDoNotMatchKey(identifier: String, differences: [String])
    case incomplete(identifier: String, problems: [String])
    case conflicts(identifier: String, options: [String])
    case stale(identifier: String, reasons: [String])
    case failed(path: String, reason: String)
}

extension VPhoneMachineTemplateError: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case let .invalidIdentifier(text):
            "'\(text)' is not a template identifier. List them with vm template list."
        case let .notFound(text):
            "No template '\(text)'. List them with vm template list."
        case let .ambiguous(text, matches):
            "'\(text)' matches several templates (\(matches.joined(separator: ", "))). Give more of the identifier."
        case let .alreadyExists(identifier):
            "A template with key \(identifier) already exists. Create machines from it with vm create --template \(identifier), or delete it first with vm template delete \(identifier)."
        case let .busy(identifier):
            "Template \(identifier) is being built by another process. Wait for it to finish."
        case let .damaged(name, reason):
            "Template '\(name)' is damaged: \(reason). Delete it with vm template delete."
        case let .notBootable(identifier):
            "This is machine template \(identifier), which never boots: every machine cloned from it shares its disk. Create a machine from it with vm create <name> --template \(identifier), and boot that."
        case let .frozen(identifier):
            "Template \(identifier) is frozen and cannot change."
        case let .notBeingBuilt(path):
            "\(path) is not a template being built: it has no \(VPhoneMachineTemplates.recordFileName)."
        case let .hasSnapshots(machine, count):
            "VM '\(machine)' has \(count) snapshot(s). A template carries no history: delete them with vm snapshot delete, then adopt it."
        case let .stepsDoNotMatchKey(identifier, differences):
            "Template \(identifier) was not built as its key says (\(differences.joined(separator: "; "))). It was not frozen."
        case let .incomplete(identifier, problems):
            "Template \(identifier) is not finished: \(problems.joined(separator: "; ")). It was not frozen."
        case let .conflicts(identifier, options):
            "Template \(identifier) cannot give this machine what was asked: \(options.joined(separator: "; ")). Use another template, or create the machine without one (--no-template)."
        case let .stale(identifier, reasons):
            "Template \(identifier) is stale: \(reasons.joined(separator: "; ")). Delete it with vm template delete \(identifier) to build a new one, or pass --no-template."
        case let .failed(path, reason):
            "Template operation failed at \(path): \(reason)."
        }
    }

    public var errorDescription: String? {
        description
    }
}
