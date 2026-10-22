// CustomFirmwareVirtualAudioMicrophoneChainsTests.swift — general microphone
// chains onto their measurement siblings, and the board microphone's gain out
// of a measurement strip.
//
// The fixtures mirror the D47 tuning set (AID8018) name for name: the
// configurations `graph_configurations.plist` pairs, and a measurement strip
// whose second AUNBandEQ carries +18 dB as parameter 0 of its saved state.

@testable import FirmwarePatcher
import Foundation
import Testing
import VPhonePatchKit

@Suite("CustomFirmwareVirtualAudioMicrophoneChains")
struct CustomFirmwareVirtualAudioMicrophoneChainsTests {
    typealias Patcher = CustomFirmwareVirtualAudioMicrophoneChains

    // MARK: - Fixtures

    static func configuration(_ tunings: String, properties: [[String: Any]] = []) -> [String: Any] {
        ["chainType": "dflt", "graph": tunings, "austrip": tunings, "propstrip": tunings,
         "busChannelCounts": [[4, 1]], "properties": properties]
    }

    static func tuningSet() -> [String: Any] {
        [
            "CommonData": ["tuningPath": "/Library/Audio/Tunings/AID8018/VAD"],
            "Configurations": [
                "bottom_mic_general": configuration("bottom_mic_general", properties: [["ID": "chsl"], ["ID": "cots"]]),
                "bottom_mic_measurement": configuration("bottom_mic_measurement", properties: [["ID": "chsl"]]),
                "bottom_mic2_general": configuration("bottom_mic2_general"),
                "bottom_mic2_measurement": configuration("bottom_mic2_measurement"),
                // Its tunings are not named after the configuration.
                "beamformed_mic_general": configuration("beam_mic_general"),
                "beamformed_mic_measurement": configuration("beam_mic_measurement"),
                // No measurement sibling.
                "bottom_mic_voice_messages": configuration("bottom_mic_voice_messages"),
                // A pair, but not a microphone.
                "speaker_general": configuration("speaker_general"),
                "speaker_measurement": configuration("speaker_measurement"),
            ],
        ]
    }

    /// An AU's saved parameters: one record of big-endian (ID, Float32) pairs.
    static func state(scope: UInt32 = 0, _ parameters: [(UInt32, Float)]) -> Data {
        var data = Data()
        func append(_ value: UInt32) {
            withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
        }
        append(scope)
        append(0)
        append(UInt32(parameters.count))
        for (identifier, value) in parameters {
            append(identifier)
            append(value.bitPattern)
        }
        return data
    }

    static func effect(_ name: String, subtype: UInt32, data: Data?) -> [String: Any] {
        var preset: [String: Any] = ["name": "preset", "subtype": NSNumber(value: subtype)]
        preset["data"] = data
        return ["displayname": name, "bypass": 0, "aupreset": preset, "unit": ["subtype": NSNumber(value: subtype)]]
    }

    static let selector: UInt32 = 0x636C_736C // 'clsl'

    static func strip(secondGain: Float = 18) -> [String: Any] {
        ["strips": [["effects": [
            effect("AUChannelSelector", subtype: selector, data: nil),
            effect("AUNBEQ_1", subtype: Patcher.bandEqualizerSubtype, data: state([(0, 0), (1000, 0), (3000, 80)])),
            effect("AUNBEQ_2", subtype: Patcher.bandEqualizerSubtype, data: state([(0, secondGain), (1000, 1), (3000, 1000)])),
        ]]]]
    }

    static func write(
        _ plist: [String: Any],
        format: PropertyListSerialization.PropertyListFormat = .binary,
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vphone-mic-\(UUID().uuidString).plist")
        try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0).write(to: url)
        return url
    }

    static func read(_ url: URL) throws -> [String: Any] {
        try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
    }

    static func configurations(_ url: URL) throws -> [String: [String: Any]] {
        try #require(try read(url)["Configurations"] as? [String: [String: Any]])
    }

    // MARK: - Chains

    @Test func `general microphone chains take their measurement sibling's tunings`() throws {
        let url = try Self.write(Self.tuningSet())
        defer { try? FileManager.default.removeItem(at: url) }

        let outcome = try Patcher.patch(at: url, verbose: false)
        #expect(outcome == .rewritten(changed: ["beamformed_mic_general", "bottom_mic2_general", "bottom_mic_general"]))

        let patched = try Self.configurations(url)
        for key in Patcher.tuningKeys {
            #expect(patched["bottom_mic_general"]?[key] as? String == "bottom_mic_measurement")
            #expect(patched["bottom_mic2_general"]?[key] as? String == "bottom_mic2_measurement")
            #expect(patched["beamformed_mic_general"]?[key] as? String == "beam_mic_measurement")
        }
        // The rest of the entry is the general configuration's own.
        #expect((patched["bottom_mic_general"]?["properties"] as? [[String: Any]])?.count == 2)
        #expect(patched["bottom_mic_general"]?["chainType"] as? String == "dflt")
    }

    @Test func `nothing but the paired microphone chains moves`() throws {
        let url = try Self.write(Self.tuningSet())
        defer { try? FileManager.default.removeItem(at: url) }
        try Patcher.patch(at: url, verbose: false)

        let patched = try Self.configurations(url)
        let original = try #require(Self.tuningSet()["Configurations"] as? [String: [String: Any]])
        for name in ["bottom_mic_measurement", "bottom_mic_voice_messages", "speaker_general", "speaker_measurement"] {
            #expect(try NSDictionary(dictionary: #require(patched[name])) == NSDictionary(dictionary: #require(original[name])))
        }
        #expect(try Self.read(url)["CommonData"] != nil)
    }

    @Test func `a tuning key the sibling lacks is removed`() throws {
        var set = Self.tuningSet()
        var configurations = try #require(set["Configurations"] as? [String: [String: Any]])
        configurations["bottom_mic_measurement"]?["propstrip"] = nil
        set["Configurations"] = configurations
        let url = try Self.write(set)
        defer { try? FileManager.default.removeItem(at: url) }

        try Patcher.patch(at: url, verbose: false)
        let patched = try Self.configurations(url)
        #expect(patched["bottom_mic_general"]?["propstrip"] == nil)
        #expect(patched["bottom_mic_general"]?["graph"] as? String == "bottom_mic_measurement")
    }

    @Test func `a second run writes nothing`() throws {
        let url = try Self.write(Self.tuningSet())
        defer { try? FileManager.default.removeItem(at: url) }
        try Patcher.patch(at: url, verbose: false)
        let once = try Data(contentsOf: url)

        let outcome = try Patcher.patch(at: url, verbose: false)
        #expect(outcome == .alreadyMeasurementChains(["beamformed_mic_general", "bottom_mic2_general", "bottom_mic_general"]))
        #expect(try Data(contentsOf: url) == once)
    }

    @Test func `a dry run reports and leaves the file alone`() throws {
        let url = try Self.write(Self.tuningSet())
        defer { try? FileManager.default.removeItem(at: url) }
        let before = try Data(contentsOf: url)

        let outcome = try Patcher.patch(at: url, dryRun: true, verbose: false)
        #expect(outcome == .dryRun(changed: ["beamformed_mic_general", "bottom_mic2_general", "bottom_mic_general"]))
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func `a set with no pairs is left alone`() throws {
        let set: [String: Any] = ["Configurations": [
            "speaker_general": Self.configuration("speaker_general"),
            "beamformed_mic_general": Self.configuration("placeholder"),
        ]]
        let url = try Self.write(set)
        defer { try? FileManager.default.removeItem(at: url) }
        let before = try Data(contentsOf: url)

        #expect(try Patcher.patch(at: url, verbose: false) == .noPairs)
        #expect(try Data(contentsOf: url) == before)
    }

    @Test(arguments: [PropertyListSerialization.PropertyListFormat.binary, .xml])
    func `the file keeps its format`(format: PropertyListSerialization.PropertyListFormat) throws {
        let url = try Self.write(Self.tuningSet(), format: format)
        defer { try? FileManager.default.removeItem(at: url) }
        try Patcher.patch(at: url, verbose: false)
        #expect(try CustomFirmwareBuildVersion.detectFormat(Data(contentsOf: url)) == format)
    }

    @Test func `a plist of another shape is refused`() throws {
        for plist in [["Configurations": "none"] as [String: Any], ["Other": [:] as [String: Any]],
                      ["Configurations": ["bottom_mic_general": "x", "bottom_mic_measurement": "y"]]]
        {
            let url = try Self.write(plist)
            defer { try? FileManager.default.removeItem(at: url) }
            let before = try Data(contentsOf: url)
            #expect(throws: PatcherError.self) { try Patcher.patch(at: url, verbose: false) }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    // MARK: - Gain

    static func effects(_ url: URL) throws -> [[String: Any]] {
        let strips = try #require(try read(url)["strips"] as? [[String: Any]])
        return try #require(strips.first?["effects"] as? [[String: Any]])
    }

    static func data(_ effect: [String: Any]) -> Data? {
        (effect["aupreset"] as? [String: Any])?["data"] as? Data
    }

    @Test func `the equalizer's gain goes to zero and nothing else moves`() throws {
        let url = try Self.write(Self.strip())
        defer { try? FileManager.default.removeItem(at: url) }

        let changes = try Patcher.neutralizeGain(at: url, verbose: false)
        #expect(changes == [Patcher.GainChange(effect: "AUNBEQ_2", before: 18)])

        let patched = try Self.effects(url)
        #expect(Self.data(patched[0]) == nil)
        #expect(Self.data(patched[1]) == Self.state([(0, 0), (1000, 0), (3000, 80)]))
        #expect(Self.data(patched[2]) == Self.state([(0, 0), (1000, 1), (3000, 1000)]))
        #expect(patched[2]["displayname"] as? String == "AUNBEQ_2")
    }

    @Test func `a strip with no gain is not rewritten`() throws {
        let url = try Self.write(Self.strip(secondGain: 0))
        defer { try? FileManager.default.removeItem(at: url) }
        let before = try Data(contentsOf: url)

        #expect(try Patcher.neutralizeGain(at: url, verbose: false).isEmpty)
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func `removing the gain twice changes nothing the second time`() throws {
        let url = try Self.write(Self.strip())
        defer { try? FileManager.default.removeItem(at: url) }
        try Patcher.neutralizeGain(at: url, verbose: false)
        let once = try Data(contentsOf: url)

        #expect(try Patcher.neutralizeGain(at: url, verbose: false).isEmpty)
        #expect(try Data(contentsOf: url) == once)
    }

    @Test func `a dry run reports the gain and leaves the strip alone`() throws {
        let url = try Self.write(Self.strip())
        defer { try? FileManager.default.removeItem(at: url) }
        let before = try Data(contentsOf: url)

        #expect(try Patcher.neutralizeGain(at: url, dryRun: true, verbose: false).map(\.before) == [18])
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func `only the global scope's parameter 0 is the gain`() throws {
        // Parameter 0 of another scope, and other parameters holding 18.
        let other = Self.state(scope: 1, [(0, 18)]) + Self.state([(4000, 18), (1000, 1)])
        #expect(try Patcher.withoutGlobalGain(other, effect: "eq", path: "strip") == nil)

        let both = Self.state(scope: 1, [(0, 18)]) + Self.state([(4000, 18), (0, -6)])
        let (patched, before) = try #require(try Patcher.withoutGlobalGain(both, effect: "eq", path: "strip"))
        #expect(before == -6)
        #expect(patched == Self.state(scope: 1, [(0, 18)]) + Self.state([(4000, 18), (0, 0)]))
    }

    @Test func `an effect that is not an equalizer keeps its data`() throws {
        var strip = Self.strip(secondGain: 0)
        let foreign = Self.state([(0, 18)])
        strip["strips"] = [["effects": [Self.effect("AUChannelSelector", subtype: Self.selector, data: foreign)]]]
        let url = try Self.write(strip)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try Patcher.neutralizeGain(at: url, verbose: false).isEmpty)
        #expect(try Self.data(Self.effects(url)[0]) == foreign)
    }

    @Test func `parameter data that is not whole records is refused`() throws {
        let whole = Self.state([(0, 18), (1000, 1)])
        for broken in [whole.dropLast(4), whole.prefix(10), whole + Data([0, 0, 0, 0])] {
            #expect(throws: PatcherError.self) {
                try Patcher.withoutGlobalGain(Data(broken), effect: "eq", path: "strip")
            }
        }
        let url = try Self.write(["effects": []])
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: PatcherError.self) { try Patcher.neutralizeGain(at: url, verbose: false) }
    }
}
