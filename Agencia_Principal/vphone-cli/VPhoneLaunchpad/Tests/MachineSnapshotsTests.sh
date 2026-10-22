#!/bin/zsh
set -euo pipefail

launchpad="${0:a:h:h}"
temporary="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$temporary"' EXIT

/usr/bin/xcrun swiftc -swift-version 6 -strict-concurrency=complete \
    -parse-as-library \
    "$launchpad/VPhoneLaunchpadShared/VPhoneLaunchpadBundleStore.swift" \
    "$launchpad/VPhoneLaunchpadShared/VPhoneLaunchpadLineReader.swift" \
    "$launchpad/VPhoneLaunchpadShared/VPhoneLaunchpadLauncherPolicy.swift" \
    "$launchpad/VPhoneLaunchpad/Command/VPhoneLaunchpadChildProcess.swift" \
    "$launchpad/VPhoneLaunchpad/Command/VPhoneLaunchpadCommandLine.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadMachine.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadMachineBinding.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadMachineSnapshot.swift" \
    "$launchpad/Tests/MachineSnapshotsTests.swift" \
    -o "$temporary/machine-snapshots-tests"
"$temporary/machine-snapshots-tests" "$@"
