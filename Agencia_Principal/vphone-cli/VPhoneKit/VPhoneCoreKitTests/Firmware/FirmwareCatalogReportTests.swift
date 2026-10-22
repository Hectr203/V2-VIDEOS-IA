import Foundation
import Testing
@testable import VPhoneCoreKit

struct FirmwareCatalogReportTests {
    @Test func `maps every pairing`() {
        let report = VPhoneFirmwareCatalog.report
        #expect(report.device == VPhoneFirmwareCatalog.device)
        #expect(report.pairings.count == VPhoneFirmwareCatalog.pairings.count)

        for (entry, pairing) in zip(report.pairings, VPhoneFirmwareCatalog.pairings) {
            #expect(entry.ios.name == pairing.iosName)
            #expect(entry.ios.url == pairing.iosURL)
            #expect(entry.recommendedCloudOS.name == pairing.cloudosName)
            #expect(entry.recommendedCloudOS.url == pairing.cloudosURL)
        }
    }

    @Test func `lists every known guest device`() {
        let report = VPhoneFirmwareCatalog.report
        #expect(report.devices.map(\.productType) == VPhoneGuestDevice.known.map(\.productType))
        #expect(report.devices.first?.pairings == report.pairings)
        for device in report.devices.dropFirst() {
            #expect(device.family == VPhoneGuestDevice.named(device.productType)?.family.rawValue)
            #expect(!device.pairings.isEmpty)
            #expect(device.name == VPhoneGuestDevice.named(device.productType)?.productName)
        }
    }

    @Test func `i pad pairings come from an IPSW that covers the device`() {
        for guest in VPhoneGuestDevice.known where guest.isPad {
            let pairings = VPhoneFirmwareCatalog.pairings(for: guest.productType)
            #expect(pairings.map(\.iosName).first == "iPadOS 26.0" || guest.productType.hasPrefix("iPad17,"))
            #expect(pairings.map(\.iosName).last == "iPadOS 27.0.1")
            for p in pairings {
                #expect(p.device == guest.productType)
                #expect(p.iosURL.hasPrefix("https://updates.cdn-apple.com/"))
                #expect(p.iosURL.hasSuffix("_Restore.ipsw"))
                #expect(p.cloudosURL.contains("/private-cloud-compute/"))
                // The iPad Pro (M4) IPSWs are named iPad_Pro_M4_…; the rest name their models.
                let name = (p.iosURL as NSString).lastPathComponent
                #expect(name.hasPrefix("iPad_Pro_M4_") || name.split(separator: "_")[0].split(separator: ",").count >= 2)
                #expect(name.contains("_\(p.iosName.dropFirst("iPadOS ".count))_"))
            }
        }
    }

    @Test func `other i phones have pairings of their own`() {
        for guest in VPhoneGuestDevice.known where guest.family == .iPhone && guest.presentsBoard {
            let pairings = VPhoneFirmwareCatalog.pairings(for: guest.productType)
            #expect(pairings.map(\.iosName).first == (guest.productType == "iPhone18,5" ? "iOS 26.3.1" : "iOS 26.0"))
            #expect(pairings.map(\.iosName).last == "iOS 27.0.1")
            for p in pairings {
                #expect(p.device == guest.productType)
                #expect(p.iosURL.hasPrefix("https://updates.cdn-apple.com/"))
                let name = (p.iosURL as NSString).lastPathComponent
                #expect(name.hasPrefix("\(guest.productType)_\(p.iosName.dropFirst("iOS ".count))_"))
                #expect(name.hasSuffix("_Restore.ipsw"))
                #expect(p.cloudosURL == VPhoneFirmwareCatalog.recommendedCloudOS(forVersion: String(p.iosName.dropFirst("iOS ".count))).url)
            }
        }
        #expect(VPhoneFirmwareCatalog.pairings(for: "iPhone18,1") != VPhoneFirmwareCatalog.pairings)
    }

    @Test func `cellular i pad gets its wi fi model's pairings`() {
        #expect(VPhoneFirmwareCatalog.pairings(for: "iPad17,4") == VPhoneFirmwareCatalog.pairings(for: "iPad17,3"))
        #expect(VPhoneFirmwareCatalog.pairings(for: "iPad17,3").first?.device == "iPad17,3")
        #expect(VPhoneFirmwareCatalog.pairings(for: "iPad15,8").isEmpty)
        #expect(VPhoneFirmwareCatalog.pairings(for: "iPhone17,3") == VPhoneFirmwareCatalog.pairings)
    }

    @Test func `i pad cloud OS follows the i phone pairing of the same release`() {
        let iPhone = Dictionary(
            VPhoneFirmwareCatalog.pairings.map { ($0.iosName.replacingOccurrences(of: "iOS ", with: ""), $0.cloudosURL) },
            uniquingKeysWith: { first, _ in first },
        )
        for p in VPhoneFirmwareCatalog.pairings(for: "iPad16,1") {
            let version = p.iosName.replacingOccurrences(of: "iPadOS ", with: "")
            #expect(iPhone[version] == p.cloudosURL, "\(version)")
        }
    }

    @Test func `round trips JSON`() throws {
        let report = VPhoneFirmwareCatalog.report
        let back = try JSONDecoder().decode(VPhoneFirmwareCatalogReport.self, from: JSONEncoder().encode(report))
        #expect(back == report)
    }
}
