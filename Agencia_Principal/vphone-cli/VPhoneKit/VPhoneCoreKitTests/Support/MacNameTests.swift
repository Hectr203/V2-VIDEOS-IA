import Foundation
import Testing
@testable import VPhoneCoreKit

/// This Mac's `.local` name in the guest: how it is turned off and stored.
/// Where it points in each mode is in `NetworkPlanTests`.
struct MacNameTests {
    typealias NetworkConfig = VPhoneVirtualMachineManifest.NetworkConfig

    private static let sharedSubnet = VPhoneIPv4Subnet(containing: VPhoneIPv4Address(192, 168, 64, 1), prefixLength: 24)!
    private let host = VPhoneNetworkHost(sharedNATSubnet: sharedSubnet, sharedNATHost: VPhoneIPv4Address(192, 168, 64, 1))

    /// On by default and stored as an absent key, so only `off` reaches the
    /// plist, and changing the mode keeps it.
    @Test func `the Mac's name can be turned off and stays off`() throws {
        let off = try VPhoneNetworking.merge(into: .default, mode: nil, bridgeInterface: nil, resolvesMacName: false)
        #expect(off.resolvesMacName == false)
        #expect(try VPhoneNetworking.macStaticNames(plan: VPhoneNetworking.plan(off, host: host), macName: "Lab-Mac").isEmpty)
        let tunnel = try VPhoneNetworking.merge(into: off, mode: .tunnel, bridgeInterface: nil)
        #expect(tunnel.resolvesMacName == false)
        let on = try VPhoneNetworking.merge(into: tunnel, mode: nil, bridgeInterface: nil, resolvesMacName: true)
        #expect(on.resolvesMacName == nil)
    }

    @Test func `configs without the key decode with the default`() throws {
        let plist = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>mode</key><string>nat</string><key>macAddress</key><string></string></dict></plist>
        """.utf8)
        let decoded = try PropertyListDecoder().decode(NetworkConfig.self, from: plist)
        #expect(decoded.resolvesMacName == nil)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        #expect(try !String(decoding: encoder.encode(decoded), as: UTF8.self).contains("resolvesMacName"))
    }
}
