import Darwin
import Foundation
import Testing
@testable import VPhoneCoreKit

// MARK: - Fake guest

/// A clock that only moves when the setup boot waits or the fake guest works.
private final class FakeClock: VPhoneTemplateSetupClock {
    var current = Date(timeIntervalSince1970: 1_800_000_000)

    func now() -> Date {
        current
    }

    func sleep(_ seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

/// A scripted guest with the state the setup boot reads and changes: the
/// orig-fs snapshot, Setup, installed apps, the service profile and the boot.
private final class FakeGuest: VPhoneTemplateSetupMachine {
    let clock: FakeClock
    var calls: [String] = []
    var started = false
    var stopped = false
    var killed = false

    // Scripted behavior.
    var exitsAfterStart = false
    var connectDelayPolls = 2
    var snapshotBusyAnswers = 0
    var skipFailures = 0
    /// vphoned of 2026-10-09 on: the first boot's data migration is still
    /// running, so `setup.skip` writes the keys and leaves SpringBoard alone.
    var migrationPending = false
    var skipFailureDetail: [String: Any] = ["code": "failed", "message": "Cannot allocate memory"]
    var unsettledAnswers = 1
    /// How long one refused `setup.skip` takes in the guest (2.9.0's
    /// vphoned waited 5 s for SpringBoard's pid to change).
    var skipFailureSeconds: TimeInterval = 0
    var unsettledReasons = ["staged_system_apps not empty"]
    var refusedApps: Set<String> = []
    /// Apps vphoned had to unregister more than once, as it reports them.
    var unregisterAttempts: [String: Int] = [:]
    var servicesKeepRunning = false
    var rebootNeverReturns = false
    var stopsCleanly = true
    /// vphoned still answers the first ping after `system.reboot`, then takes
    /// the `processes.list` that follows down with it, unanswered.
    var dyingVphonedTakesAList = false
    private var dyingVphoned = false

    // Guest state.
    var snapshots = ["orig-fs.disabled.rn-4EC2"]
    var setupDone = false
    var installed: Set<String> = Set(VPhoneTemplateSlimmingRequest.defaultRemovedApps + [
        "com.apple.mobilephone", "com.apple.camera", "com.apple.Preferences",
    ])
    var profile = "none"
    var groups: [String] = []
    var disabled: Set<String> = []
    var running: [String] = []
    var bootTime = 1000.0
    var downCalls = 0
    var pinnedName: String? = "p4-src"
    /// The restore's pre-CFW panic report, written at the first boot after
    /// CFW, and one daemon crash of the setup boot.
    var crashReports = [
        "/var/mobile/Library/Logs/CrashReporter/panic-full-2026-10-09-155009.000.ips",
        "/var/mobile/Library/Logs/CrashReporter/duetexpertd-2026-10-09-155011.ips",
    ]
    var undeletableReports: Set<String> = []
    var crashListRefused = false

    init(clock: FakeClock) {
        self.clock = clock
    }

    func start() throws {
        started = true
    }

    func failure() -> String? {
        exitsAfterStart && started ? "vphone-vm exited with status 1" : nil
    }

    func ping() -> Bool {
        clock.sleep(0.1)
        if dyingVphoned {
            return true
        }
        if connectDelayPolls > 0 {
            connectDelayPolls -= 1
            return false
        }
        if downCalls > 0 {
            if !rebootNeverReturns {
                downCalls -= 1
            }
            return false
        }
        return true
    }

    private func refused(_ message: String, _ detail: [String: Any]) -> VPhoneGuestCallError {
        VPhoneGuestCallError(kind: .refused, message: message, detail: detail)
    }

    func call(_ method: String, params: [String: Any], timeout: TimeInterval) throws -> [String: Any] {
        calls.append(method)
        clock.sleep(0.5)
        if dyingVphoned, method == "processes.list" {
            dyingVphoned = false
            clock.sleep(timeout)
            throw VPhoneGuestCallError(kind: .transport, message: "no answer from vphone.sock")
        }
        if downCalls > 0 {
            throw VPhoneGuestCallError(kind: .transport, message: "guest not connected")
        }
        switch method {
        case "apfs.snapshot.delete":
            if snapshotBusyAnswers > 0 {
                snapshotBusyAnswers -= 1
                throw refused("busy", ["code": "command_failed", "reason": "busy", "retryable": true, "errno": 16])
            }
            let deleted = snapshots
            snapshots = []
            return ["mount": "/", "before": deleted, "deleted": deleted, "already_deleted": [String](), "after": [String](), "remaining": [String]()]
        case "apfs.snapshots":
            return ["mount": "/", "snapshots": snapshots]
        case "setup.skip":
            #expect(params["force"] as? Bool == true)
            if skipFailures > 0 {
                skipFailures -= 1
                clock.sleep(skipFailureSeconds)
                throw refused(skipFailureDetail["message"] as? String ?? "", skipFailureDetail)
            }
            setupDone = true
            let respring: [String: Any] = migrationPending
                ? ["restarted": false, "reason": "data_migration_pending"]
                : ["restarted": true, "method": "frontboard_relaunch", "previous_pid": 36, "pid": 551]
            return ["setup_done": true, "setup_version": 11, "respring": respring]
        case "setup.settle":
            let wait = params["timeout_s"] as? Int ?? 90
            #expect(wait <= 30)
            if unsettledAnswers > 0 {
                unsettledAnswers -= 1
                clock.sleep(TimeInterval(wait))
                return ["settled": false, "reasons": unsettledReasons, "elapsed_s": wait]
            }
            return ["settled": true, "elapsed_s": 10.2, "reasons": [String]()]
        case "apps.remove_system":
            let ids = params["bundle_ids"] as? [String] ?? []
            var results: [[String: Any]] = []
            for id in ids {
                if refusedApps.contains(id) {
                    results.append(["bundle_id": id, "status": "failed", "removed": false, "error": "not in a bundle container"])
                } else if installed.remove(id) != nil {
                    var row: [String: Any] = ["bundle_id": id, "status": "removed", "removed": true]
                    row["unregister_attempts"] = unregisterAttempts[id]
                    results.append(row)
                } else {
                    results.append(["bundle_id": id, "status": "absent", "removed": false])
                }
            }
            let failed = results.count(where: { $0["status"] as? String == "failed" })
            if failed > 0 {
                throw refused("\(failed) of \(ids.count) apps were not removed; see results", [
                    "code": "command_failed", "error": "remove_incomplete", "results": results, "failed": failed,
                ])
            }
            return ["results": results, "removed": ids.count, "failed": 0]
        case "services.profile.apply":
            let wanted = params["profile"] as? String ?? ""
            profile = wanted
            if wanted == "trimmed" {
                groups = ["app_store", "base", "signin_followup"] + (params["groups"] as? [String] ?? [])
                let labels = ["com.apple.weatherd", "com.apple.followupd", "com.apple.appleidsetupd"]
                    + ((params["groups"] as? [String] ?? []).contains("accounts") ? ["com.apple.akd"] : [])
                disabled = Set(labels)
                running = ["com.apple.weatherd"]
            } else {
                groups = []
                disabled = []
                running = []
            }
            return ["profile": wanted, "disabled": Array(disabled), "enabled": [String](), "failed": [[String: Any]](), "owned": disabled.count]
        case "services.profile":
            let record: Any = profile == "none" ? NSNull() : ["profile": profile, "groups": groups, "labels": Array(disabled)]
            return ["profile": profile, "record": record, "disabled": Array(disabled), "running": running]
        case "processes.list":
            return ["processes": [["pid": 1, "start_time": bootTime], ["pid": 53, "start_time": bootTime + 4]], "count": 2]
        case "system.reboot":
            bootTime += 100
            downCalls = 3
            dyingVphoned = dyingVphonedTakesAList
            if !servicesKeepRunning {
                running = []
            }
            throw VPhoneGuestCallError(kind: .transport, message: "no answer from vphone.sock")
        case "setup.status":
            return ["setup_done": setupDone, "pending": !setupDone]
        case "apps.list":
            return ["apps": installed.map { ["bundle_id": $0] }]
        case "logs.crashes":
            if crashListRefused {
                throw refused("unknown method logs.crashes", ["code": "unknown_method"])
            }
            return ["crashes": crashReports.map { ["path": $0, "name": ($0 as NSString).lastPathComponent] }, "count": crashReports.count]
        case "files.remove":
            let path = params["path"] as? String ?? ""
            if undeletableReports.contains(path) {
                throw refused("Operation not permitted", ["code": "failed"])
            }
            crashReports.removeAll { $0 == path }
            return ["path": path, "removed": true]
        case "device.name.set":
            pinnedName = params["name"] as? String
            return ["name": NSNull(), "changed": true]
        default:
            throw refused("unknown method \(method)", ["code": "unknown_method"])
        }
    }

    func stop(timeout _: TimeInterval) -> Bool {
        stopped = true
        return stopsCleanly
    }

    func kill() {
        killed = true
    }
}

// MARK: - Tests

/// The setup boot as a state machine: step order, retries, deadlines and what
/// a failure leaves behind, against a scripted guest. No VM is started.
struct TemplateSetupBootTests {
    private func run(
        _ guest: FakeGuest,
        slimming: VPhoneMachineTemplateSlimming = VPhoneTemplateSlimmingRequest.defaultSlimming,
        requiresEveryApp: Bool = true,
    ) -> Result<VPhoneTemplateSetupOutcome, VPhoneTemplateSetupFailure> {
        let boot = VPhoneTemplateSetupBoot(
            machine: guest,
            plan: VPhoneTemplateSetupPlan(slimming: slimming, requiresEveryApp: requiresEveryApp),
            clock: guest.clock,
            log: { _ in },
        )
        do {
            return try .success(boot.run())
        } catch let failure as VPhoneTemplateSetupFailure {
            return .failure(failure)
        } catch {
            Issue.record("unexpected \(error)")
            return .failure(VPhoneTemplateSetupFailure(step: .boot, reason: "\(error)", outcome: .init()))
        }
    }

    /// Whether `expected` occurs in `calls` in this order (other calls may
    /// come in between).
    private func inOrder(_ calls: [String], _ expected: [String]) -> Bool {
        var index = calls.startIndex
        for method in expected {
            guard let found = calls[index...].firstIndex(of: method) else { return false }
            index = calls.index(after: found)
        }
        return true
    }

    @Test func `a full setup boot runs the steps in the fixed order and records the key's slimming`() throws {
        let guest = FakeGuest(clock: FakeClock())
        let outcome = try run(guest).get()

        #expect(inOrder(guest.calls, [
            "apfs.snapshot.delete", "setup.skip", "setup.settle", "setup.settle",
            "apps.remove_system", "services.profile.apply", "services.profile",
            "processes.list", "system.reboot", "processes.list",
            "apfs.snapshots", "setup.status", "services.profile", "apps.list",
            "logs.crashes", "files.remove", "files.remove", "device.name.set",
        ]))
        // Nothing slims before Setup is skipped and first-boot work settled.
        let firstRemoval = try #require(guest.calls.firstIndex(of: "apps.remove_system"))
        let lastSettle = try #require(guest.calls.lastIndex(of: "setup.settle"))
        #expect(lastSettle < firstRemoval)
        #expect(guest.calls.firstIndex(of: "apfs.snapshot.delete") == 0)

        #expect(outcome.isComplete)
        #expect(guest.stopped)
        #expect(!guest.killed)
        #expect(outcome.deletedSnapshots == ["orig-fs.disabled.rn-4EC2"])
        #expect(outcome.removedApps == VPhoneTemplateSlimmingRequest.defaultRemovedApps.sorted())
        #expect(guest.installed.contains("com.apple.mobilephone"))
        #expect(outcome.serviceProfile == "trimmed")
        #expect(outcome.deviceNameCleared)
        #expect(guest.pinnedName == nil)
        #expect(guest.crashReports.isEmpty)
        #expect(outcome.clearedCrashReports.count == 2)
        #expect(Set(outcome.durations.keys) == Set(VPhoneTemplateSetupStep.allCases))

        // The offline trim records its tier before the setup boot, which
        // leaves it alone.
        let trimmed = VPhoneMachineTemplateSteps(trimTier: VPhoneTemplateSlimmingRequest.defaultTrimTier)
        let steps = outcome.applying(to: trimmed)
        #expect(steps.trimTier == trimmed.trimTier)
        #expect(steps.setupDone)
        #expect(steps.snapshotDeleted)
        #expect(steps.slimming == VPhoneTemplateSlimmingRequest.defaultSlimming)
    }

    @Test func `slim off skips the setup but slims nothing`() throws {
        let guest = FakeGuest(clock: FakeClock())
        let slimming = try VPhoneTemplateSlimmingRequest(slim: false).resolve()
        let outcome = try run(guest, slimming: slimming).get()
        #expect(!guest.calls.contains("apps.remove_system"))
        #expect(!guest.calls.contains("services.profile.apply"))
        #expect(!guest.calls.contains("apps.list"))
        #expect(guest.calls.contains("setup.skip"))
        #expect(guest.calls.contains("apfs.snapshot.delete"))
        #expect(outcome.isComplete)
        #expect(outcome.applying(to: VPhoneMachineTemplateSteps()).slimming == slimming)
    }

    @Test func `accounts-off reaches the guest as an extra group`() throws {
        let guest = FakeGuest(clock: FakeClock())
        let slimming = try VPhoneTemplateSlimmingRequest(accountsOff: true).resolve()
        let outcome = try run(guest, slimming: slimming).get()
        #expect(guest.groups.contains("accounts"))
        #expect(outcome.applying(to: VPhoneMachineTemplateSteps(trimTier: slimming.trimTier)).slimming == slimming)
    }

    @Test func `a busy snapshot deletion is retried`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.snapshotBusyAnswers = 2
        let outcome = try run(guest).get()
        #expect(guest.calls.count(where: { $0 == "apfs.snapshot.delete" }) == 3)
        #expect(outcome.isComplete)
    }

    @Test func `setup skip that fails early in the boot is retried`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.skipFailures = 3
        let outcome = try run(guest).get()
        #expect(guest.calls.count(where: { $0 == "setup.skip" }) == 4)
        #expect(outcome.setupSkipped)
    }

    @Test func `setup skip during data migration leaves SpringBoard alone and says so`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.migrationPending = true
        var lines: [String] = []
        let boot = VPhoneTemplateSetupBoot(
            machine: guest,
            plan: VPhoneTemplateSetupPlan(slimming: VPhoneTemplateSlimmingRequest.defaultSlimming, requiresEveryApp: true),
            clock: guest.clock,
            log: { lines.append($0) },
        )
        let outcome = try boot.run()
        #expect(guest.calls.count(where: { $0 == "setup.skip" }) == 1)
        #expect(outcome.setupSkipped)
        #expect(outcome.isComplete)
        #expect(lines.contains { $0.contains("SpringBoard left alone: data_migration_pending") })
        // The settle step, which waits for migration, still comes before any slimming.
        #expect(inOrder(guest.calls, ["setup.skip", "setup.settle", "apps.remove_system"]))
    }

    @Test func `a SpringBoard restart vphoned reports as retryable is retried`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.skipFailures = 2
        guest.skipFailureDetail = [
            "code": "command_failed", "reason": "busy", "retryable": true,
            "message": "Setup Assistant's keys are written, but SpringBoard did not restart: relaunch action ignored",
        ]
        let outcome = try run(guest).get()
        #expect(guest.calls.count(where: { $0 == "setup.skip" }) == 3)
        #expect(outcome.setupSkipped)
    }

    @Test func `setup skip that keeps failing fails its step`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.skipFailures = 1000
        let failure = try #require(run(guest).failed)
        #expect(failure.step == .skipSetup)
        #expect(failure.reason.contains("Cannot allocate memory"))
    }

    @Test func `no snapshot left is not an error`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.snapshots = []
        let outcome = try run(guest).get()
        #expect(outcome.deletedSnapshots.isEmpty)
        #expect(outcome.snapshotsGone)
    }

    @Test func `settle is called again until it settles, each call within 30 s`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.unsettledAnswers = 4
        let outcome = try run(guest).get()
        #expect(guest.calls.count(where: { $0 == "setup.settle" }) == 5)
        #expect(outcome.settled)
    }

    @Test func `settle that never settles fails at its deadline and kills the VM`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.unsettledAnswers = 1000
        let failure = try #require(run(guest).failed)
        #expect(failure.step == .settle)
        #expect(failure.reason.contains("staged_system_apps"))
        #expect(guest.killed)
        #expect(!guest.stopped)
        #expect(!failure.outcome.isComplete)
        #expect(!guest.calls.contains("apps.remove_system"))
        // Bounded: 600 s of 30 s calls.
        #expect(guest.calls.count(where: { $0 == "setup.settle" }) <= 21)
    }

    /// The slower Mac of the 2.9.0 report: data migration ran past the old
    /// 120 s skip deadline. The skip now passes at once and the settle step
    /// waits, printing progress, well past 120 s.
    @Test func `a slow data migration is waited for in settle with progress, not failed`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.migrationPending = true
        guest.unsettledAnswers = 10
        guest.unsettledReasons = ["data migration has not finished"]
        var lines: [String] = []
        let boot = VPhoneTemplateSetupBoot(
            machine: guest,
            plan: VPhoneTemplateSetupPlan(slimming: VPhoneTemplateSlimmingRequest.defaultSlimming, requiresEveryApp: true),
            clock: guest.clock,
            log: { lines.append($0) },
        )
        let outcome = try boot.run()
        #expect(outcome.isComplete)
        #expect(try #require(outcome.durations[.settle]) > 300)
        #expect(try #require(outcome.durations[.skipSetup]) < 5)
        let progress = lines.filter { $0.hasPrefix("  waiting for the guest's first-boot data migration (") }
        #expect(progress.count == 10)
        #expect(progress.allSatisfy { !$0.contains(";") })
        #expect(lines.contains { $0.hasPrefix("  settled after ") })
    }

    @Test func `settle progress names data migration first`() {
        #expect(VPhoneTemplateSetupBoot.settleProgress(["data migration has not finished"], elapsed: 42)
            == "  waiting for the guest's first-boot data migration (42 s)")
        #expect(VPhoneTemplateSetupBoot.settleProgress(["staged_system_apps has 3 entries", "data migration has not finished"], elapsed: 12)
            == "  waiting for the guest's first-boot data migration (12 s); also staged_system_apps has 3 entries")
        #expect(VPhoneTemplateSetupBoot.settleProgress(["app count changed: 250 → 258"], elapsed: 70)
            == "  waiting for first-boot work (70 s): app count changed: 250 → 258")
    }

    /// 2.9.0's vphoned restarts SpringBoard in every skip and is refused
    /// until migration ends: 14 refusals (about 130 s) failed the step on the
    /// MacBook Air. Now the step outlasts them and reports the wait every 30 s
    /// instead of every refusal.
    @Test func `a 2_9_0 vphoned refused until migration ends passes the skip step`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.skipFailures = 30
        guest.skipFailureSeconds = 5.5
        guest.skipFailureDetail = [
            "code": "failed",
            "message": "relaunch action ignored and launchd stop failed: 144 Requestor lacks required entitlement",
        ]
        var lines: [String] = []
        let boot = VPhoneTemplateSetupBoot(
            machine: guest,
            plan: VPhoneTemplateSetupPlan(slimming: VPhoneTemplateSlimmingRequest.defaultSlimming, requiresEveryApp: true),
            clock: guest.clock,
            log: { lines.append($0) },
        )
        let outcome = try boot.run()
        #expect(outcome.isComplete)
        let skip = try #require(outcome.durations[.skipSetup])
        #expect(skip > 250 && skip < 600)
        #expect(!lines.contains { $0.contains("144") })
        let progress = lines.filter { $0.contains("waiting for the guest's first-boot data migration before SpringBoard can restart") }
        // The first refusal, then one line per 30 s at most.
        #expect(progress.count >= 2 && progress.count <= Int(skip / 30) + 1, "\(progress)")
        #expect(progress.first?.hasSuffix(" s)") == true, "\(progress)")
    }

    @Test func `a refused app fails a build whose key promises it`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.refusedApps = ["com.apple.findmy"]
        let failure = try #require(run(guest, requiresEveryApp: true).failed)
        #expect(failure.step == .removeApps)
        #expect(failure.reason.contains("com.apple.findmy"))
        #expect(guest.killed)
        #expect(failure.outcome.apps.count == 10)
        #expect(!guest.calls.contains("services.profile.apply"))
    }

    @Test func `a refused app is a warning for a machine to be adopted, and left out of its steps`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.refusedApps = ["com.apple.findmy"]
        let outcome = try run(guest, requiresEveryApp: false).get()
        #expect(outcome.isComplete)
        #expect(outcome.warnings.count == 1)
        #expect(!outcome.removedApps.contains("com.apple.findmy"))
        #expect(outcome.removedApps.count == 9)
        let steps = outcome.applying(to: VPhoneMachineTemplateSteps())
        #expect(steps.slimming != VPhoneTemplateSlimmingRequest.defaultSlimming)
    }

    @Test func `a strict setup boot of a machine fails where the lenient one warns`() throws {
        // vm template setup --strict: a machine Launchpad adopts under the
        // key vm template find gave must not lose an app from that key.
        let guest = FakeGuest(clock: FakeClock())
        guest.refusedApps = ["com.apple.findmy"]
        let failure = try #require(run(guest, requiresEveryApp: true).failed)
        #expect(failure.step == .removeApps)
        #expect(failure.reason.contains("com.apple.findmy"))
        // Nothing recorded: the outcome is incomplete.
        #expect(!failure.outcome.isComplete)
        #expect(!guest.calls.contains("system.reboot"))
    }

    @Test func `deviations name what fell short of the plan`() throws {
        let plan = VPhoneTemplateSetupPlan(slimming: VPhoneTemplateSlimmingRequest.defaultSlimming, requiresEveryApp: true)
        var outcome = VPhoneTemplateSetupOutcome()
        outcome.apps = plan.removedApps.map { VPhoneTemplateSetupAppResult(bundleID: $0, status: "removed") }
        outcome.serviceProfile = plan.serviceProfile
        outcome.serviceGroups = plan.serviceGroups
        #expect(outcome.deviations(from: plan).isEmpty)

        var short = outcome
        try short.apps[#require(short.apps.firstIndex { $0.bundleID == "com.apple.findmy" })] = VPhoneTemplateSetupAppResult(
            bundleID: "com.apple.findmy",
            status: "failed",
            error: "LaunchServices still lists the app after unregistration",
        )
        short.apps.removeAll { $0.bundleID == "com.apple.news" }
        let lines = short.deviations(from: plan)
        #expect(lines.count == 1)
        #expect(lines.first?.contains("com.apple.findmy (LaunchServices still lists") == true)
        #expect(lines.first?.contains("com.apple.news") == true)

        var profile = outcome
        profile.serviceProfile = "none"
        profile.serviceGroups = ["accounts"]
        #expect(profile.deviations(from: plan) == ["service profile none, not trimmed", "service groups accounts, not "])
    }

    @Test func `an app that is already gone counts as removed`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.installed.remove("com.apple.news")
        let outcome = try run(guest).get()
        #expect(outcome.apps.first(where: { $0.bundleID == "com.apple.news" })?.status == "absent")
        #expect(outcome.removedApps.contains("com.apple.news"))
    }

    @Test func `apps unregistered after more than one attempt are logged and recorded`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.unregisterAttempts = ["com.apple.findmy": 3, "com.apple.tv": 2]
        var lines: [String] = []
        let boot = VPhoneTemplateSetupBoot(
            machine: guest,
            plan: VPhoneTemplateSetupPlan(slimming: VPhoneTemplateSlimmingRequest.defaultSlimming, requiresEveryApp: true),
            clock: guest.clock,
            log: { lines.append($0) },
        )
        let outcome = try boot.run()

        #expect(outcome.apps.first(where: { $0.bundleID == "com.apple.findmy" })?.unregisterAttempts == 3)
        #expect(outcome.apps.first(where: { $0.bundleID == "com.apple.news" })?.unregisterAttempts == 1)
        #expect(outcome.retriedUnregistrations == ["com.apple.findmy": 3, "com.apple.tv": 2])
        #expect(lines.contains("  com.apple.findmy: unregistered after 3 attempts"))
        #expect(lines.contains("  com.apple.tv: unregistered after 2 attempts"))
        #expect(!lines.contains { $0.contains("com.apple.news: unregistered") })
        // Recorded with the steps, outside the key.
        let steps = outcome.applying(to: VPhoneMachineTemplateSteps())
        #expect(steps.unregisterAttempts == ["com.apple.findmy": 3, "com.apple.tv": 2])
        var without = steps
        without.unregisterAttempts = [:]
        #expect(without.slimming == steps.slimming)
        let encoded = try PropertyListEncoder().encode(steps)
        #expect(try PropertyListDecoder().decode(VPhoneMachineTemplateSteps.self, from: encoded) == steps)
    }

    @Test func `a VM that exits fails the step it was in`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.exitsAfterStart = true
        let failure = try #require(run(guest).failed)
        #expect(failure.step == .connect)
        #expect(failure.reason.contains("exited"))
        #expect(guest.calls.isEmpty)
    }

    @Test func `vphoned that never answers fails the connect step`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.connectDelayPolls = Int.max
        let failure = try #require(run(guest).failed)
        #expect(failure.step == .connect)
        #expect(guest.killed)
    }

    @Test func `a reboot that never comes back fails the reboot step`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.rebootNeverReturns = true
        let failure = try #require(run(guest).failed)
        #expect(failure.step == .reboot)
        #expect(guest.killed)
    }

    @Test func `a list the reboot leaves unanswered holds the step only for the poll timeout`() throws {
        let quick = try run(FakeGuest(clock: FakeClock())).get()
        let guest = FakeGuest(clock: FakeClock())
        guest.dyingVphonedTakesAList = true
        let outcome = try run(guest).get()
        let base = try #require(quick.durations[.reboot])
        let stalled = try #require(outcome.durations[.reboot])
        // One poll timeout more than an undisturbed reboot, not the 30 s that
        // made the live step take 33 s.
        #expect(stalled - base >= VPhoneTemplateSetupTimeouts.standard.rebootPoll)
        #expect(stalled - base < VPhoneTemplateSetupTimeouts.standard.rebootPoll + 5)
        #expect(VPhoneTemplateSetupTimeouts.standard.rebootPoll <= 10)
        #expect(outcome.isComplete)
    }

    @Test func `services still running after the reboot fail verification`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.servicesKeepRunning = true
        let failure = try #require(run(guest).failed)
        #expect(failure.step == .verify)
        #expect(failure.reason.contains("still running"))
        #expect(!failure.outcome.verified)
    }

    @Test func `an unclean shutdown fails the setup boot`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.stopsCleanly = false
        let failure = try #require(run(guest).failed)
        #expect(failure.step == .stop)
        #expect(failure.outcome.verified)
        #expect(!failure.outcome.isComplete)
        #expect(!failure.outcome.applying(to: VPhoneMachineTemplateSteps()).setupDone)
    }

    @Test func `retryable means unreachable, busy or marked so`() {
        #expect(VPhoneGuestCallError(kind: .transport, message: "x").isRetryable)
        #expect(VPhoneGuestCallError(kind: .refused, message: "x", detail: ["retryable": true]).isRetryable)
        #expect(VPhoneGuestCallError(kind: .refused, message: "x", detail: ["reason": "busy"]).isRetryable)
        #expect(!VPhoneGuestCallError(kind: .refused, message: "x", detail: ["code": "invalid_operation"]).isRetryable)
        #expect(!VPhoneGuestCallError(kind: .refused, message: "x").isRetryable)
        #expect(VPhoneGuestCallError(kind: .refused, message: "x", detail: ["code": "c"]).code == "c")
    }

    @Test func `launchd's start time tells boots apart`() {
        #expect(VPhoneTemplateSetupBoot.bootMarker(["processes": [["pid": 1, "start_time": 12.5]]]) == 12.5)
        #expect(VPhoneTemplateSetupBoot.bootMarker(["processes": [["pid": 2, "start_time": 12.5]]]) == nil)
        #expect(VPhoneTemplateSetupBoot.bootMarker([:]) == nil)
    }

    @Test func `the restore's panic report and the setup boot's crashes are cleared after the reboot`() throws {
        let guest = FakeGuest(clock: FakeClock())
        let outcome = try run(guest).get()
        #expect(guest.crashReports.isEmpty)
        #expect(outcome.clearedCrashReports == [
            "panic-full-2026-10-09-155009.000.ips", "duetexpertd-2026-10-09-155011.ips",
        ])
        // After the reboot, so the reports of both boots go; before the shutdown.
        let reboot = try #require(guest.calls.firstIndex(of: "system.reboot"))
        let listing = try #require(guest.calls.firstIndex(of: "logs.crashes"))
        #expect(reboot < listing)
        #expect(outcome.warnings.isEmpty)
    }

    @Test func `a crash report that cannot be cleared is a warning, not a failure`() throws {
        let guest = FakeGuest(clock: FakeClock())
        guest.undeletableReports = ["/var/mobile/Library/Logs/CrashReporter/duetexpertd-2026-10-09-155011.ips"]
        let outcome = try run(guest).get()
        #expect(outcome.isComplete)
        #expect(outcome.clearedCrashReports == ["panic-full-2026-10-09-155009.000.ips"])
        #expect(outcome.warnings.contains { $0.contains("could not delete 1 crash report(s)") })

        let unlisted = FakeGuest(clock: FakeClock())
        unlisted.crashListRefused = true
        let second = try run(unlisted).get()
        #expect(second.isComplete)
        #expect(second.warnings.contains { $0.contains("could not list the crash reports") })
        #expect(!unlisted.calls.contains("files.remove"))
    }

    @Test func `a setup boot told to keep the crash reports leaves them`() throws {
        let guest = FakeGuest(clock: FakeClock())
        let boot = VPhoneTemplateSetupBoot(
            machine: guest,
            plan: VPhoneTemplateSetupPlan(
                slimming: VPhoneTemplateSlimmingRequest.defaultSlimming,
                requiresEveryApp: true,
                clearsCrashReports: false,
            ),
            clock: guest.clock,
            log: { _ in },
        )
        let outcome = try boot.run()
        #expect(outcome.isComplete)
        #expect(guest.crashReports.count == 2)
        #expect(!guest.calls.contains("logs.crashes"))
    }

    @Test func `only report files in a CrashReporter folder are deleted`() {
        #expect(VPhoneTemplateSetupBoot.isCrashReport("/var/mobile/Library/Logs/CrashReporter/panic-full-2026-10-09-155009.000.ips"))
        #expect(VPhoneTemplateSetupBoot.isCrashReport("/private/var/mobile/Library/Logs/CrashReporter/Retired/x.ips"))
        #expect(!VPhoneTemplateSetupBoot.isCrashReport("/var/mobile/Library/Logs/CrashReporter/"))
        #expect(!VPhoneTemplateSetupBoot.isCrashReport("/var/mobile/Library/Logs/CrashReporter/../../Preferences/x.plist"))
        #expect(!VPhoneTemplateSetupBoot.isCrashReport("/var/mobile/Library/Preferences/com.apple.x.plist"))
        #expect(!VPhoneTemplateSetupBoot.isCrashReport("Logs/CrashReporter/x.ips"))
    }

    @Test func `cleared reports are summarized by process, most first`() {
        let names = [
            "duetexpertd-2026-10-09-155011.ips", "duetexpertd-2026-10-09-155020.ips",
            "panic-full-2026-10-09-155009.000.ips", "SiriSearchFeedback-2026-10-09-151008.ips",
        ]
        #expect(VPhoneTemplateSetupBoot.summarizeCrashReports(names)
            == "4 crash report(s): duetexpertd ×2, SiriSearchFeedback ×1, panic-full ×1")
    }
}

// MARK: - Recording

/// A setup boot's outcome in `Template.plist`: a complete one lets the build
/// freeze, a failed one is never recorded and the build stays unfrozen.
struct TemplateSetupRecordingTests {
    private func makeBuild(slimming: VPhoneMachineTemplateSlimming) throws -> (root: URL, build: VPhoneMachineTemplateBuild, lock: VPhoneMachineTemplateLock) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let rom = root.appendingPathComponent("rom.bin")
        try Data([0xAA]).write(to: rom)
        let library = VPhoneLibrary(root: root.appendingPathComponent("machines"))
        let key = MachineTemplateKeyTests.key(slimming: slimming)
        let lock = try VPhoneMachineTemplates.lock(key.identifier, in: library, wait: false)
        let build = try VPhoneMachineTemplates.beginBuild(key, in: library)
        let bundle = try VPhoneBundleOperations.create(
            .init(name: key.identifier, cpuCount: 4, memoryMB: 4096, diskSizeGB: 1, romSource: rom, sepromSource: rom),
            in: build.library,
        )
        try Data([0xD1]).write(to: bundle.url.appendingPathComponent("Disk.img"))
        try VPhoneMachineTemplates.writeRecord(VPhoneMachineTemplateRecord(key: key, sourceMachine: "p4-a"), inBundle: build.bundleURL)
        return (root, build, lock)
    }

    private func outcome(complete: Bool) throws -> VPhoneTemplateSetupOutcome {
        let guest = FakeGuest(clock: FakeClock())
        guest.stopsCleanly = complete
        let boot = VPhoneTemplateSetupBoot(
            machine: guest,
            plan: VPhoneTemplateSetupPlan(slimming: VPhoneTemplateSlimmingRequest.defaultSlimming, requiresEveryApp: true),
            clock: guest.clock,
            log: { _ in },
        )
        do {
            return try boot.run()
        } catch let failure as VPhoneTemplateSetupFailure {
            return failure.outcome
        }
    }

    @Test func `a complete setup boot is recorded and the build freezes`() throws {
        let (root, build, lock) = try makeBuild(slimming: VPhoneTemplateSlimmingRequest.defaultSlimming)
        defer {
            lock.release()
            try? FileManager.default.removeItem(at: root)
        }
        // Before the setup boot the key's promise is not kept.
        #expect(throws: VPhoneMachineTemplateError.self) { try VPhoneMachineTemplates.freeze(build) }
        // The default trim runs first and records its tier; its snapshot is
        // still there, so the build still does not freeze.
        try VPhoneMachineTemplates.recordSteps(inBundle: build.bundleURL) {
            $0.trimTier = VPhoneTemplateSlimmingRequest.defaultTrimTier
        }
        #expect(throws: VPhoneMachineTemplateError.self) { try VPhoneMachineTemplates.freeze(build) }

        try VPhoneMachineTemplates.recordSetupBoot(outcome(complete: true), inBundle: build.bundleURL)
        let record = try #require(try VPhoneMachineTemplates.readRecord(inBundle: build.bundleURL))
        #expect(record.steps.setupDone)
        #expect(record.steps.snapshotDeleted)
        #expect(record.steps.serviceProfile == "trimmed")
        #expect(record.steps.removedApps.count == 10)
        #expect(record.steps.trimTier == VPhoneTemplateSlimmingRequest.defaultTrimTier)

        let template = try VPhoneMachineTemplates.freeze(build)
        #expect(template.record.frozen)
        #expect(template.record.steps.slimming == template.key.slimming)
    }

    @Test func `a failed setup boot records nothing and the build never freezes`() throws {
        let (root, build, lock) = try makeBuild(slimming: VPhoneTemplateSlimmingRequest.defaultSlimming)
        defer {
            lock.release()
            try? FileManager.default.removeItem(at: root)
        }
        let failed = try outcome(complete: false)
        #expect(!failed.isComplete)
        #expect(throws: VPhoneMachineTemplateError.self) {
            try VPhoneMachineTemplates.recordSetupBoot(failed, inBundle: build.bundleURL)
        }
        let record = try #require(try VPhoneMachineTemplates.readRecord(inBundle: build.bundleURL))
        #expect(record.steps == VPhoneMachineTemplateSteps())
        #expect(throws: VPhoneMachineTemplateError.self) { try VPhoneMachineTemplates.freeze(build) }
        #expect(try VPhoneMachineTemplates.readRecord(inBundle: build.bundleURL)?.frozen == false)
    }

    @Test func `a file trim recorded before the setup boot survives it`() throws {
        var slimming = VPhoneTemplateSlimmingRequest.defaultSlimming
        slimming.trimTier = "conservative/1"
        let (root, build, lock) = try makeBuild(slimming: slimming)
        defer {
            lock.release()
            try? FileManager.default.removeItem(at: root)
        }
        try VPhoneMachineTemplates.recordSteps(inBundle: build.bundleURL) { $0.trimTier = "conservative/1" }
        try VPhoneMachineTemplates.recordSetupBoot(outcome(complete: true), inBundle: build.bundleURL)
        #expect(try VPhoneMachineTemplates.freeze(build).record.steps.trimTier == "conservative/1")
    }
}

// MARK: - Socket paths

/// A machine in a template build lives deeper than `sun_path` reaches; its
/// control socket is bound and reached through a short link.
struct UnixSocketLongPathTests {
    @Test func `a socket path longer than sun_path is bound and connected through a link`() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent(".templates-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(".building-0123456789ab-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("0123456789ab", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root.deletingLastPathComponent().deletingLastPathComponent()) }
        let path = root.appendingPathComponent("vphone.sock").path
        #expect(path.utf8CString.count > VPhoneUnixSocket.maximumPathLength)

        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        #expect(listener >= 0)
        defer { close(listener) }
        let bound = VPhoneUnixSocket.withAddressablePath(path) { short -> Int32 in
            #expect(short.utf8CString.count <= VPhoneUnixSocket.maximumPathLength)
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            withUnsafeMutableBytes(of: &address.sun_path) { buffer in
                for (index, byte) in short.utf8CString.enumerated() {
                    buffer[index] = UInt8(bitPattern: byte)
                }
            }
            return withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
        }
        #expect(bound == 0)
        #expect(listen(listener, 1) == 0)
        // The socket is where the long path says.
        var info = stat()
        #expect(lstat(path, &info) == 0 && info.st_mode & S_IFMT == S_IFSOCK)

        switch VPhoneUnixSocket.connect(to: path) {
        case let .success(fd):
            close(fd)
        case let .failure(error):
            Issue.record("connect failed: \(error)")
        }
        // A short path is used as it is.
        #expect(VPhoneUnixSocket.withAddressablePath("/tmp/x.sock") { $0 } == "/tmp/x.sock")
    }
}

private extension Result {
    var failed: Failure? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}
