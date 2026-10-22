import Foundation
import Testing
@testable import VPhoneCoreKit

/// The slimming switches of `vm create` and `vm template setup`, mapped to
/// what a template key promises.
struct TemplateSlimmingRequestTests {
    private typealias Request = VPhoneTemplateSlimmingRequest

    @Test func `no switch asks for a setup boot, the trimmed profile and list C`() throws {
        let slimming = try Request().resolve()
        #expect(slimming.setupBoot)
        #expect(slimming.trimTier == Request.defaultTrimTier)
        #expect(slimming.serviceProfile == "trimmed")
        #expect(slimming.serviceGroups.isEmpty)
        #expect(slimming.removedApps == Request.defaultRemovedApps.sorted())
        #expect(slimming.removedApps.count == 10)
        #expect(slimming == Request.defaultSlimming)
        #expect(Request().isEmpty)
    }

    @Test func `Phone and Camera are never in the default list`() {
        #expect(!Request.defaultRemovedApps.contains("com.apple.mobilephone"))
        #expect(!Request.defaultRemovedApps.contains("com.apple.camera"))
        #expect(Set(Request.defaultRemovedApps).count == Request.defaultRemovedApps.count)
    }

    @Test func `slim off still boots once but slims nothing`() throws {
        let slimming = try Request(slim: false).resolve()
        #expect(slimming == VPhoneMachineTemplateSlimming(trimTier: "none", setupBoot: true, serviceProfile: "none"))
        // Saying the same thing twice is not a contradiction.
        #expect(try Request(slim: false, trimTier: "none", serviceProfile: "none", removeApps: false).resolve() == slimming)
    }

    @Test func `slim off refuses switches that slim`() {
        for request in [
            Request(slim: false, serviceProfile: "trimmed"),
            Request(slim: false, removeApps: true),
            Request(slim: false, keepApps: ["com.apple.news"]),
            Request(slim: false, accountsOff: true),
            Request(slim: false, trimTier: "standard"),
        ] {
            #expect(throws: VPhoneTemplateSlimmingError.self, "\(request)") { try request.resolve() }
        }
    }

    @Test func `the trim defaults to standard and is stored as its key value`() throws {
        #expect(Request.defaultTrimTier == VPhoneSystemTrimSpec.standard.keyValue)
        #expect(Request.defaultTrimTier == "standard/1/en,zh,zh-Hans")
        #expect(try Request(trimTier: "conservative").resolve().trimTier == "conservative/1")
        #expect(try Request(trimTier: "none").resolve().trimTier == "none")
        // --keep-languages alone means the standard tier keeping them.
        let japanese = try Request(keepLanguages: "ja").resolve()
        #expect(japanese.trimTier == "standard/1/en,ja")
        #expect(japanese.setupBoot)
        #expect(!Request(keepLanguages: "ja").isEmpty)
        #expect(Request.trimTiers == ["none", "conservative", "standard"])
    }

    @Test func `trim switches that cannot apply are refused`() {
        for request in [
            Request(trimTier: "aggressive"),
            Request(trimTier: "conservative", keepLanguages: "ja"),
            Request(trimTier: "standard", keepLanguages: "../x"),
            Request(slim: false, keepLanguages: "ja"),
        ] {
            #expect(throws: VPhoneTemplateSlimmingError.self, "\(request)") { try request.resolve() }
        }
    }

    @Test func `parts can be turned off on their own`() throws {
        let noProfile = try Request(serviceProfile: "none").resolve()
        #expect(noProfile.serviceProfile == "none")
        #expect(noProfile.removedApps.count == 10)

        let noApps = try Request(removeApps: false).resolve()
        #expect(noApps.serviceProfile == "trimmed")
        #expect(noApps.removedApps.isEmpty)
        #expect(noApps.setupBoot)
    }

    @Test func `keep-apps subtracts from the default list`() throws {
        let slimming = try Request(keepApps: ["com.apple.findmy", "com.apple.Passbook"]).resolve()
        #expect(slimming.removedApps.count == 8)
        #expect(!slimming.removedApps.contains("com.apple.findmy"))
        #expect(!slimming.removedApps.contains("com.apple.Passbook"))
        #expect(!Request(keepApps: ["com.apple.findmy"]).isEmpty)
    }

    @Test func `keep-apps refuses what is not removed by default`() {
        #expect(throws: VPhoneTemplateSlimmingError.self) {
            try Request(keepApps: ["com.apple.camera"]).resolve()
        }
        #expect(throws: VPhoneTemplateSlimmingError.self) {
            try Request(removeApps: false, keepApps: ["com.apple.news"]).resolve()
        }
    }

    @Test func `accounts-off adds the accounts group and needs the trimmed profile`() throws {
        let slimming = try Request(accountsOff: true).resolve()
        #expect(slimming.serviceGroups == ["accounts"])
        #expect(slimming.serviceProfile == "trimmed")
        #expect(throws: VPhoneTemplateSlimmingError.self) {
            try Request(serviceProfile: "none", accountsOff: true).resolve()
        }
    }

    @Test func `unknown values are refused, all at once`() {
        do {
            _ = try Request(trimTier: "max", serviceProfile: "lean").resolve()
            Issue.record("expected a refusal")
        } catch let error as VPhoneTemplateSlimmingError {
            #expect(error.problems.count == 2)
        } catch {
            Issue.record("\(error)")
        }
    }

    @Test func `every switch that changes the slimming changes the template key`() throws {
        let requests = [
            Request(),
            Request(slim: false),
            Request(serviceProfile: "none"),
            Request(removeApps: false),
            Request(keepApps: ["com.apple.games"]),
            Request(accountsOff: true),
            Request(trimTier: "conservative"),
            Request(keepLanguages: "ja"),
        ]
        let identifiers = try Set(requests.map { try MachineTemplateKeyTests.key(slimming: $0.resolve()).identifier })
        #expect(identifiers.count == requests.count)
    }

    @Test func `the trimmed profile stays on the iOS versions vphoned has a service list for`() throws {
        let slimming = try Request().resolve()
        #expect(VPhoneTemplateSlimmingRequest.trimmedServiceProfileMajors == [26, 27])
        for version in ["26.6.2", "26.0", "27.0", "27.0.1"] {
            #expect(try slimming.fitted(toIOSVersion: version) == slimming)
        }
        let accounts = try Request(accountsOff: true).resolve()
        #expect(try accounts.fitted(toIOSVersion: "26.6.2") == accounts)
        #expect(try accounts.fitted(toIOSVersion: "27.0") == accounts)
    }

    @Test func `an iOS 26 key keeps the trimmed profile and differs from its untrimmed one`() throws {
        let trimmed = try Request().resolve().fitted(toIOSVersion: "26.6.2")
        let none = try Request(serviceProfile: "none").resolve().fitted(toIOSVersion: "26.6.2")
        #expect(trimmed.serviceProfile == "trimmed")
        #expect(none.serviceProfile == "none")
        #expect(trimmed.trimTier == none.trimTier)
        #expect(trimmed.removedApps == none.removedApps)
        #expect(
            try MachineTemplateKeyTests.key(slimming: trimmed).identifier
                != MachineTemplateKeyTests.key(slimming: none).identifier,
        )
    }

    @Test func `the trimmed profile becomes none on an iOS vphoned has no service list for`() throws {
        let slimming = try Request().resolve()
        let on25 = try slimming.fitted(toIOSVersion: "25.4")
        #expect(on25.serviceProfile == "none")
        #expect(on25.serviceGroups.isEmpty)
        #expect(on25.trimTier == slimming.trimTier)
        #expect(on25.removedApps == slimming.removedApps)
        #expect(try on25.fitted(toIOSVersion: "25.4") == on25)
        let none = try Request(serviceProfile: "none").resolve()
        #expect(try none.fitted(toIOSVersion: "25.4") == none)
        #expect(try none.fitted(toIOSVersion: "26.6.2") == none)
    }

    @Test func `accounts-off is refused on an iOS without the trimmed service list`() throws {
        let slimming = try Request(accountsOff: true).resolve()
        #expect(throws: VPhoneTemplateSlimmingError.self) { try slimming.fitted(toIOSVersion: "25.4") }
        #expect(try slimming.fitted(toIOSVersion: "26.6.2") == slimming)
    }
}
