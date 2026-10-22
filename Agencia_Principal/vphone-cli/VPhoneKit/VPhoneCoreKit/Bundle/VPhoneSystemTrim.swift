import Darwin
import Foundation

// MARK: - Tier

/// How much of the guest's System volume a template build deletes offline,
/// after `cfw install`. Each tier removes everything the one before it does.
///
/// The files go for good: a clone cannot get them back, so the tier is part
/// of the template key. They also free nothing while the CFW-renamed
/// `orig-fs.disabled.rn-*` snapshot still references them, and only the guest
/// can delete that snapshot (vphoned `apfs.snapshot.delete`, during the
/// template's setup boot). A trimmed template is therefore frozen only once
/// its snapshot is gone; see ``VPhoneMachineTemplateSteps/problems``.
public enum VPhoneSystemTrimTier: String, CaseIterable, Comparable, Sendable {
    case none
    /// `usr/standalone/update`: the software-update ramdisk and baseband
    /// firmware. About 0.35 GB.
    case conservative
    /// Conservative, plus the AirPods/Beats pairing assets, the watch faces
    /// and the linguistic data of languages not kept. About 1.2 GB.
    case standard
    /// Reserved: other languages' `.lproj`, Health assets, some fonts. Not
    /// validated on a guest, so not offered.
    case aggressive

    /// Whether this version can apply the tier.
    public var isSupported: Bool {
        self != .aggressive
    }

    private var rank: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Parses a tier a user typed. `aggressive` is recognized and refused.
    public static func parse(_ text: String) throws -> Self {
        guard let tier = Self(rawValue: text.lowercased()) else {
            throw VPhoneSystemTrimError.unknownTier(text)
        }
        guard tier.isSupported else {
            throw VPhoneSystemTrimError.unsupportedTier(tier.rawValue)
        }
        return tier
    }
}

// MARK: - Entry

/// One place on the System volume a tier deletes from.
public struct VPhoneSystemTrimEntry: Equatable, Sendable {
    public enum Selection: Equatable, Sendable {
        /// The item at `path` itself.
        case item
        /// Everything inside the folder at `path`; the folder stays.
        case contents
        /// The children of the folder at `path` named `prefix + language +
        /// suffix` whose language is not in `keeping`. Other children stay.
        case languageBundles(prefix: String, suffix: String, keeping: [String])
    }

    /// Relative to the System volume's root.
    public let path: String
    public let selection: Selection
    /// The lowest tier that deletes it.
    public let tier: VPhoneSystemTrimTier
    /// Why it can go, for logs and docs.
    public let note: String

    /// Whether a direct child of the folder at `path`, by name, is deleted.
    /// Never for `.item`, which names its target itself.
    public func selects(child name: String) -> Bool {
        guard VPhoneSystemTrim.isSingleComponent(name) else { return false }
        switch selection {
        case .item:
            return false
        case .contents:
            return true
        case let .languageBundles(prefix, suffix, keeping):
            guard name.hasPrefix(prefix), name.hasSuffix(suffix), name.count > prefix.count + suffix.count else {
                return false
            }
            let language = String(name.dropFirst(prefix.count).dropLast(suffix.count))
            return !keeping.contains(language)
        }
    }
}

// MARK: - Spec

/// One trim: a tier, the version of the list it was taken from, and the
/// languages a language-removing tier keeps. ``keyValue`` is what a template
/// key and its recorded steps store as `trimTier`, so templates trimmed by a
/// different list or keeping other languages never match each other.
public struct VPhoneSystemTrimSpec: Equatable, Hashable, Sendable {
    public let tier: VPhoneSystemTrimTier
    public let listVersion: Int
    /// Sorted. Empty for a tier that removes no language data.
    public let keptLanguages: [String]

    public static let none = VPhoneSystemTrimSpec(uncheckedTier: .none, listVersion: VPhoneSystemTrim.listVersion, keptLanguages: [])

    /// The standard tier keeping ``VPhoneSystemTrim/defaultKeptLanguages``:
    /// the default for a template that gets its setup boot.
    public static let standard = VPhoneSystemTrimSpec(
        uncheckedTier: .standard,
        listVersion: VPhoneSystemTrim.listVersion,
        keptLanguages: Array(Set(VPhoneSystemTrim.defaultKeptLanguages + ["en"])).sorted(),
    )

    /// `--trim` and `--keep-languages` as typed: a tier name, and an optional
    /// comma-separated language list, which only a language-removing tier
    /// takes.
    public static func parse(tier text: String, keptLanguages list: String? = nil) throws -> Self {
        let tier = try VPhoneSystemTrimTier.parse(text)
        guard let list else { return try Self(tier: tier) }
        guard tier >= .standard else {
            throw VPhoneSystemTrimError.languagesUnused(tier.rawValue)
        }
        let languages = list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return try Self(tier: tier, keptLanguages: languages)
    }

    /// Validates the tier and languages. English is always kept.
    public init(tier: VPhoneSystemTrimTier, keptLanguages: [String] = VPhoneSystemTrim.defaultKeptLanguages) throws {
        guard tier.isSupported else {
            throw VPhoneSystemTrimError.unsupportedTier(tier.rawValue)
        }
        for language in keptLanguages where !VPhoneSystemTrim.isLanguageIdentifier(language) {
            throw VPhoneSystemTrimError.invalidLanguage(language)
        }
        let removesLanguages = tier >= .standard
        self.init(
            uncheckedTier: tier,
            listVersion: VPhoneSystemTrim.listVersion,
            keptLanguages: removesLanguages ? Array(Set(keptLanguages + ["en"])).sorted() : [],
        )
    }

    private init(uncheckedTier tier: VPhoneSystemTrimTier, listVersion: Int, keptLanguages: [String]) {
        self.tier = tier
        self.listVersion = listVersion
        self.keptLanguages = keptLanguages
    }

    /// `none`, `conservative/1`, `standard/1/en,zh,zh-Hans`.
    public var keyValue: String {
        guard tier != .none else { return "none" }
        var parts = [tier.rawValue, String(listVersion)]
        if !keptLanguages.isEmpty {
            parts.append(keptLanguages.joined(separator: ","))
        }
        return parts.joined(separator: "/")
    }

    /// Reads a ``keyValue`` back. Only the current list version can be
    /// applied; an older one is still a valid key, but no longer a trim.
    public init(keyValue: String) throws {
        let parts = keyValue.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard let tier = VPhoneSystemTrimTier(rawValue: parts[0]) else {
            throw VPhoneSystemTrimError.unknownTier(keyValue)
        }
        if tier == .none {
            guard parts.count == 1 else { throw VPhoneSystemTrimError.unknownTier(keyValue) }
            self = .none
            return
        }
        guard parts.count >= 2, let version = Int(parts[1]) else {
            throw VPhoneSystemTrimError.unknownTier(keyValue)
        }
        guard version == VPhoneSystemTrim.listVersion else {
            throw VPhoneSystemTrimError.unavailableListVersion(version)
        }
        let languages = parts.count > 2 ? parts[2].split(separator: ",").map(String.init) : []
        try self.init(tier: tier, keptLanguages: languages)
        guard self.keyValue == keyValue else {
            throw VPhoneSystemTrimError.unknownTier(keyValue)
        }
    }

    /// The tier named by a `trimTier` value, whatever its list version.
    public static func tier(ofKeyValue value: String) -> VPhoneSystemTrimTier? {
        value.split(separator: "/", maxSplits: 1).first.flatMap { VPhoneSystemTrimTier(rawValue: String($0)) }
    }

    /// Whether a machine whose steps record `recorded` may take this trim.
    /// A trim cannot be undone, so only `none` to anything, the same trim
    /// again (which deletes whatever is left), or conservative to a heavier
    /// tier, which contains it.
    public func canFollow(recorded: String) -> Bool {
        if recorded == "none" || recorded == keyValue {
            return true
        }
        guard let previous = Self.tier(ofKeyValue: recorded) else { return false }
        return previous == .conservative && tier > .conservative
    }

    /// The entries this trim deletes, in the order they are applied.
    public var entries: [VPhoneSystemTrimEntry] {
        VPhoneSystemTrim.entries(keptLanguages: keptLanguages).filter { tier != .none && $0.tier <= tier }
    }

    /// Whether deleting `relative` (a path on the System volume) is part of
    /// this trim: one of its `.item` paths, or a direct child its entry
    /// selects. Everything the trim deletes passes this check first.
    public func permits(_ relative: String) -> Bool {
        guard VPhoneSystemTrim.isSafeRelativePath(relative) else { return false }
        for entry in entries {
            switch entry.selection {
            case .item:
                if relative == entry.path {
                    return true
                }
            case .contents, .languageBundles:
                let prefix = entry.path + "/"
                guard relative.hasPrefix(prefix) else { continue }
                let child = String(relative.dropFirst(prefix.count))
                if entry.selects(child: child) {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Lists

public enum VPhoneSystemTrim {
    /// Raised whenever an entry is added, removed or changes what it
    /// selects. Part of ``VPhoneSystemTrimSpec/keyValue``.
    public static let listVersion = 1

    /// The languages the standard tier keeps by default: English, and the
    /// Simplified Chinese bundle with the `zh` bundle it shares data with.
    public static let defaultKeptLanguages = ["en", "zh-Hans", "zh"]

    /// List version 1, measured on iPhone17,3 iOS 27.0 (24A435) and booted
    /// after deletion (see `Research/Host/machine_templates.md`). Never on
    /// the list: the dyld shared cache and its `.symbols` (CFW's cache
    /// patcher resolves symbols from it), ML models, `/Applications`.
    static func entries(keptLanguages: [String]) -> [VPhoneSystemTrimEntry] {
        [
            VPhoneSystemTrimEntry(
                path: "usr/standalone/update",
                selection: .contents,
                tier: .conservative,
                note: "software-update ramdisk and baseband firmware; a VM has no baseband and OTA is blocked",
            ),
            VPhoneSystemTrimEntry(
                path: "System/Library/PreinstalledAssetsV2/RequiredByOs/com_apple_MobileAsset_SharingDeviceAssets",
                selection: .item,
                tier: .standard,
                note: "AirPods and Beats pairing artwork",
            ),
            VPhoneSystemTrimEntry(
                path: "System/Library/NanoTimeKit/FaceBundles",
                selection: .contents,
                tier: .standard,
                note: "Apple Watch faces; a VM pairs no watch",
            ),
            VPhoneSystemTrimEntry(
                path: "System/Library/LinguisticData",
                selection: .languageBundles(prefix: "RequiredAssets_", suffix: ".bundle", keeping: keptLanguages),
                tier: .standard,
                note: "linguistic data of languages not kept",
            ),
        ]
    }

    /// A file on the System volume that only an iOS System volume has,
    /// checked before anything is deleted.
    public static let systemVolumeMarker = "System/Library/CoreServices/SystemVersion.plist"

    // MARK: Path rules

    /// Non-empty, relative, no empty, `.` or `..` component, no NUL.
    public static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            isSingleComponent(String($0))
        }
    }

    static func isSingleComponent(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }

    /// `en`, `zh-Hans`, `pt_BR`: letters, digits, `-` and `_`, up to 16.
    public static func isLanguageIdentifier(_ text: String) -> Bool {
        (1 ... 16).contains(text.utf8.count) && text.utf8.allSatisfy { byte in
            (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A)
                || (byte >= 0x61 && byte <= 0x7A) || byte == 0x2D || byte == 0x5F
        }
    }
}

// MARK: - Applying

/// What a trim deleted from one entry.
public struct VPhoneSystemTrimEntryResult: Codable, Equatable, Sendable {
    public var path: String
    /// Names deleted: the item itself, or the selected children.
    public var removed: [String]
    /// Allocated bytes of what was deleted (`st_blocks`), counting a file
    /// with more than one hard link as nothing.
    public var bytes: UInt64
    /// The entry's path did not exist (already trimmed, or another release).
    public var absent: Bool
}

public struct VPhoneSystemTrimResult: Codable, Equatable, Sendable {
    public var trim: String
    public var entries: [VPhoneSystemTrimEntryResult]

    public var bytes: UInt64 {
        entries.reduce(0) { $0 + $1.bytes }
    }

    public init(trim: String, entries: [VPhoneSystemTrimEntryResult]) {
        self.trim = trim
        self.entries = entries
    }

    private enum CodingKeys: String, CodingKey {
        case trim, entries, bytes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trim = try container.decode(String.self, forKey: .trim)
        entries = try container.decode([VPhoneSystemTrimEntryResult].self, forKey: .entries)
    }

    /// With the total, for callers that read only that.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trim, forKey: .trim)
        try container.encode(entries, forKey: .entries)
        try container.encode(bytes, forKey: .bytes)
    }
}

public extension VPhoneSystemTrimSpec {
    /// Deletes this trim from a System volume opened at `root` (the mounted
    /// volume's root, by descriptor). Nothing is followed: every path is
    /// walked with `O_NOFOLLOW` and refused if it passes through a symbolic
    /// link or leaves the volume, a link is deleted as a link, and each
    /// deletion must be ``permits(_:)``-ed first. Refused outright when
    /// `root` is not an iOS System volume.
    func apply(to root: VPhoneConfinedDirectory, log: (String) -> Void = { _ in }) throws -> VPhoneSystemTrimResult {
        guard (try? root.isRegularFile(VPhoneSystemTrim.systemVolumeMarker)) == true else {
            throw VPhoneSystemTrimError.notSystemVolume
        }
        var results: [VPhoneSystemTrimEntryResult] = []
        for entry in entries {
            var result = VPhoneSystemTrimEntryResult(path: entry.path, removed: [], bytes: 0, absent: false)
            switch entry.selection {
            case .item:
                guard try root.exists(entry.path) else {
                    result.absent = true
                    break
                }
                guard permits(entry.path) else { throw VPhoneSystemTrimError.notPermitted(entry.path) }
                result.bytes = try root.removeItem(entry.path)
                result.removed = [(entry.path as NSString).lastPathComponent]
            case .contents, .languageBundles:
                let folder: VPhoneConfinedDirectory
                do {
                    folder = try root.directory(entry.path)
                } catch VPhoneConfinedDirectoryError.missing {
                    result.absent = true
                    break
                }
                for child in try folder.entries() where entry.selects(child: child) {
                    let relative = "\(entry.path)/\(child)"
                    guard permits(relative) else { throw VPhoneSystemTrimError.notPermitted(relative) }
                    result.bytes += try folder.removeItem(child)
                    result.removed.append(child)
                }
            }
            log(Self.describe(result))
            results.append(result)
        }
        return VPhoneSystemTrimResult(trim: keyValue, entries: results)
    }

    static func describe(_ result: VPhoneSystemTrimEntryResult) -> String {
        if result.absent {
            return "\(result.path): not present"
        }
        let count = result.removed.count
        return "\(result.path): removed \(count) item\(count == 1 ? "" : "s"), \(VPhoneSystemTrim.formatBytes(result.bytes))"
    }
}

public extension VPhoneSystemTrim {
    /// `353.2 MB`, decimal like the rest of the CLI's sizes.
    static func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_000_000_000 {
            return String(format: "%.2f GB", Double(bytes) / 1_000_000_000)
        }
        return String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }
}

// MARK: - Disk layout

/// Reading `diskutil image attach` and `diskutil` output to find a guest
/// image's System volume by its APFS role, not by slice number.
public enum VPhoneGuestDiskLayout {
    /// The attached image's whole disk and its APFS physical store, from
    /// `diskutil image attach -noMount` output: one `<device>\t<content>` line
    /// per device (`/dev/disk8  \tGUID_partition_scheme`,
    /// `/dev/disk8s1\tApple_APFS`), then the synthesized container's own
    /// lines (`Apple_APFS_Container`, `Apple_APFS_Volume`), which are neither
    /// and may also come first.
    public static func attachedDisks(fromAttachOutput output: String) -> (wholeDisk: String?, store: String?) {
        let devices = output.split(whereSeparator: \.isNewline).compactMap { line -> (device: String, type: String)? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, fields[0].hasPrefix("/dev/disk") else { return nil }
            return (String(fields[0].dropFirst("/dev/".count)), String(fields[1]))
        }
        let store = devices.first(where: { $0.type == "Apple_APFS" })?.device
        let whole = devices.first(where: { $0.type == "GUID_partition_scheme" })?.device
            ?? store.flatMap { device in
                device.range(of: "s", options: .backwards).map { String(device[..<$0.lowerBound]) }
            }
        return (whole, store)
    }

    /// The device of the one volume with the `System` role in `container`,
    /// from `diskutil apfs list -plist <container>`, after checking the
    /// container sits on `physicalStore` (the disk just attached, not
    /// another container that happens to have the same number).
    public static func systemVolume(fromAPFSList data: Data, container: String, physicalStore: String) throws -> String {
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let containers = plist["Containers"] as? [[String: Any]],
            let entry = containers.first(where: { $0["ContainerReference"] as? String == container }),
            let stores = entry["PhysicalStores"] as? [[String: Any]],
            stores.contains(where: { $0["DeviceIdentifier"] as? String == physicalStore }),
            let volumes = entry["Volumes"] as? [[String: Any]]
        else {
            throw VPhoneSystemTrimError.layout("the APFS container \(container) is not on the attached disk \(physicalStore)")
        }
        let systems = volumes.filter { ($0["Roles"] as? [String])?.contains("System") == true }
        guard systems.count == 1, let device = systems[0]["DeviceIdentifier"] as? String,
              device.hasPrefix("\(container)s"), isDeviceName(device)
        else {
            throw VPhoneSystemTrimError.layout("container \(container) has \(systems.count) System-role volumes, not one")
        }
        return device
    }

    /// `disk12s1`.
    public static func isDeviceName(_ text: String) -> Bool {
        text.range(of: #"^disk[0-9]+(s[0-9]+)?$"#, options: .regularExpression) != nil
    }
}

// MARK: - Error

public enum VPhoneSystemTrimError: Error, Equatable {
    case unknownTier(String)
    case unsupportedTier(String)
    case invalidLanguage(String)
    case languagesUnused(String)
    case unavailableListVersion(Int)
    case notSystemVolume
    case notPermitted(String)
    case layout(String)
    case downgrade(machine: String, recorded: String, requested: String)
    case clonedFromTemplate(machine: String, template: String)
}

extension VPhoneSystemTrimError: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case let .unknownTier(text):
            "'\(text)' is not a trim tier. Use none, conservative or standard."
        case let .unsupportedTier(tier):
            "Trim tier \(tier) is reserved and not supported yet: it has not been validated on a guest. Use none, conservative or standard."
        case let .invalidLanguage(text):
            "'\(text)' is not a language identifier (letters, digits, - and _, such as en or zh-Hans)."
        case let .languagesUnused(tier):
            "--keep-languages applies to the standard tier, which removes language data; \(tier) removes none."
        case let .unavailableListVersion(version):
            "Trim list version \(version) is not this vphone-cli's (\(VPhoneSystemTrim.listVersion)); it can no longer be applied."
        case .notSystemVolume:
            "The mounted volume is not an iOS System volume (no \(VPhoneSystemTrim.systemVolumeMarker)). Nothing was deleted."
        case let .notPermitted(path):
            "Refusing to delete \(path): it is not on the trim list."
        case let .layout(reason):
            "Cannot find the guest's System volume: \(reason)."
        case let .downgrade(machine, recorded, requested):
            "VM '\(machine)' is already trimmed (\(recorded)); a trim cannot be undone or narrowed, so it cannot take \(requested). Build another template for that."
        case let .clonedFromTemplate(machine, template):
            "VM '\(machine)' was cloned from template \(template) and shares its system files; trimming it would free nothing. Trim a template build instead."
        }
    }

    public var errorDescription: String? {
        description
    }
}
