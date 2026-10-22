import Darwin

@main
struct FirmwareAdmissionTests {
    typealias Admission = VPhoneLaunchpadHelperFirmwareAdmission

    static let gib: Int64 = 1024 * 1024 * 1024

    static func machine(_ inode: ino_t, on device: dev_t = 1) -> Admission.MachineKey {
        Admission.MachineKey(device: device, inode: inode)
    }

    static func refusal(
        _ candidate: Admission.MachineKey,
        volumes: [dev_t: String],
        running: [Admission.MachineKey: Set<dev_t>],
        capacity: [String: Int64] = [:],
    ) -> String? {
        Admission.refusal(machine: candidate, volumes: volumes, running: running) { path in
            guard let free = capacity[path] else {
                fatalError("Unexpected capacity query for \(path)")
            }
            return free
        }
    }

    static func main() {
        let a = machine(10)
        let b = machine(11)
        let c = machine(12)

        // Nothing running: admitted without a capacity query, since
        // vphone-cli's own check reports a short volume precisely.
        precondition(refusal(a, volumes: [1: "/lib", 2: "/tmp"], running: [:]) == nil)

        // The same machine is refused whatever space there is.
        precondition(
            refusal(a, volumes: [1: "/lib"], running: [a: [1]], capacity: ["/lib": 1000 * gib])
                == Admission.machineBusy,
        )

        // A folder is the machine, not its name: an equal inode on another
        // device is another machine.
        precondition(refusal(machine(10, on: 9), volumes: [9: "/other"], running: [a: [1]]) == nil)

        // A volume no running operation writes to is not queried.
        precondition(refusal(b, volumes: [3: "/elsewhere"], running: [a: [1, 2]]) == nil)

        // A shared volume needs a share for each run, this one included.
        precondition(
            refusal(b, volumes: [1: "/lib"], running: [a: [1]], capacity: ["/lib": 100 * gib]) == nil,
        )
        precondition(
            refusal(b, volumes: [1: "/lib"], running: [a: [1]], capacity: ["/lib": 100 * gib - 1])
                == Admission.notEnoughSpace,
        )
        precondition(
            refusal(c, volumes: [1: "/lib"], running: [a: [1], b: [1]], capacity: ["/lib": 150 * gib]) == nil,
        )
        precondition(
            refusal(c, volumes: [1: "/lib"], running: [a: [1], b: [1]], capacity: ["/lib": 149 * gib])
                == Admission.notEnoughSpace,
        )

        // Each volume is counted on its own: the work folder's volume is
        // shared by both runs, the library's only by the new one.
        precondition(
            refusal(
                b,
                volumes: [1: "/lib", 2: "/tmp"],
                running: [machine(20, on: 5): [5, 2]],
                capacity: ["/tmp": 100 * gib],
            ) == nil,
        )
        precondition(
            refusal(
                b,
                volumes: [1: "/lib", 2: "/tmp"],
                running: [machine(20, on: 5): [5, 2]],
                capacity: ["/tmp": 60 * gib],
            ) == Admission.notEnoughSpace,
        )

        print("FirmwareAdmissionTests passed")
    }
}
