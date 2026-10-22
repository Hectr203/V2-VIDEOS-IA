import Foundation
import Testing
@testable import VPhoneCoreKit

/// Which device's OS a VM runs, as `fw prepare` finds it in the IPSW and the
/// VM's `config.plist` keeps it.
@Suite("Guest device")
struct GuestDeviceTests {
    @Test
    func `a restore manifest names its device`() {
        #expect(VPhoneGuestDevice.detect(buildManifest: ["SupportedProductTypes": ["iPhone17,3"]]) == .iPhone17_3)
        #expect(VPhoneGuestDevice.detect(buildManifest: ["SupportedProductTypes": ["iPad16,1", "iPad16,2"]]) == .iPad16_1)
        // The cellular model shares the Wi-Fi one's IPSW and identity.
        #expect(VPhoneGuestDevice.detect(buildManifest: ["SupportedProductTypes": ["iPad16,2"]]) == .iPad16_1)
        #expect(VPhoneGuestDevice.detect(buildManifest: ["SupportedProductTypes": ["iPad13,1"]]) == nil)
        #expect(VPhoneGuestDevice.isPadManifest(["SupportedProductTypes": ["iPad13,1"]]))
    }

    @Test
    func `an iPad restore tree keeps the prefix every reader matches`() {
        let name = VPhoneGuestDevice.iPad16_1.restoreTreeName(version: "26.6.2", build: "23G90")
        #expect(name == "iPhoneOS_iPad16,1_26.6.2_23G90_Restore")
        #expect(name.hasPrefix("iPhone") && name.hasSuffix("_Restore"))
        #expect(VPhoneGuestDevice.iPhone17_3.restoreTreeName(version: "27.0", build: "24A435")
            == "iPhone17,3_27.0_24A435_Restore")
    }

    @Test
    func `a VM made before iPad guests is an iPhone17,3`() {
        let manifest = VPhoneVirtualMachineManifest.newVM()
        #expect(manifest.guestProductType == nil)
        #expect(manifest.guestDevice == .iPhone17_3)
    }

    @Test
    func `an iPad guest records its product and display`() throws {
        let manifest = VPhoneVirtualMachineManifest.newVM().updating(guestDevice: .iPad16_1)
        #expect(manifest.guestProductType == "iPad16,1")
        #expect(manifest.guestDevice == .iPad16_1)
        #expect(manifest.screenConfig == .init(width: 1488, height: 2266, pixelsPerInch: 326, scale: 2.0))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }
        try manifest.write(to: url)
        let loaded = try VPhoneVirtualMachineManifest.load(from: url)
        #expect(loaded.guestDevice == .iPad16_1)
        #expect(loaded.screenConfig == manifest.screenConfig)

        // Editing CPU or memory keeps the device.
        #expect(loaded.updating(cpuCount: 4).guestProductType == "iPad16,1")
    }

    @Test
    func `an iPhone17,3 guest writes no product, so older bundles read it unchanged`() {
        let manifest = VPhoneVirtualMachineManifest.newVM().updating(guestDevice: .iPhone17_3)
        #expect(manifest.guestProductType == nil)
        #expect(manifest.screenConfig == .default)
    }

    @Test
    func `an IPSW covering several iPads gives the one asked for`() {
        let air = ["SupportedProductTypes": ["iPad15,3", "iPad15,4", "iPad15,5", "iPad15,6"]]
        #expect(VPhoneGuestDevice.detect(buildManifest: air) == .iPad15_3)
        #expect(VPhoneGuestDevice.detect(buildManifest: air, preferring: "iPad15,5") == .iPad15_5)
        // A cellular model maps onto its Wi-Fi twin.
        #expect(VPhoneGuestDevice.detect(buildManifest: air, preferring: "iPad15,6") == .iPad15_5)
        // A model the IPSW does not cover is not invented.
        #expect(VPhoneGuestDevice.detect(buildManifest: air, preferring: "iPad17,3") == .iPad15_3)
        #expect(VPhoneGuestDevice.covered(by: air) == [.iPad15_3, .iPad15_5])
    }

    @Test
    func `every known iPad has a 2x panel and a board tree to read`() {
        for device in VPhoneGuestDevice.known where device.isPad {
            #expect(device.screen.scale == 2.0)
            #expect(device.screen.width < device.screen.height)
            #expect(device.boardDeviceTreePath == "Firmware/all_flash/DeviceTree.\(device.deviceClass).im4p")
        }
        #expect(VPhoneGuestDevice.iPad17_3.screen == .init(width: 2064, height: 2752, pixelsPerInch: 264, scale: 2.0))
    }

    @Test
    func `every other iPhone presents its own board at 3x`() {
        #expect(!VPhoneGuestDevice.iPhone17_3.presentsBoard)
        for device in VPhoneGuestDevice.known where device.family == .iPhone && device != .iPhone17_3 {
            #expect(device.presentsBoard)
            #expect(device.screen.scale == 3.0)
            #expect(device.screen.pixelsPerInch == 460)
            #expect(device.screen.width < device.screen.height)
            #expect(VPhoneGuestDevice.detect(buildManifest: ["SupportedProductTypes": [device.productType]]) == device)
            #expect(device.restoreTreeName(version: "27.0", build: "24A437") == "\(device.productType)_27.0_24A437_Restore")
        }
        for device in VPhoneGuestDevice.known where device.isPad {
            #expect(device.presentsBoard)
        }
        #expect(VPhoneGuestDevice.named("iPhone18,1") == .iPhone18_1)
        #expect(VPhoneGuestDevice.iPhone18_1.deviceClass == "v53ap")
        #expect(VPhoneGuestDevice.iPhone18_1.screen == .init(width: 1206, height: 2622, pixelsPerInch: 460, scale: 3.0))
    }
}
