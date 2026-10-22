#!/bin/zsh
set -euo pipefail

launchpad="${0:a:h:h}"
temporary="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$temporary"' EXIT

/usr/bin/xcrun swiftc -swift-version 6 -strict-concurrency=complete \
    -parse-as-library \
    "$launchpad/VPhoneLaunchpadShared/VPhoneLaunchpadBundleStore.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadMachine.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadTemplates.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadCreationPlan.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadDiskUsage.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadDiskExtents.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadDiskHolder.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadBundleChange.swift" \
    "$launchpad/Tests/TemplatesTests.swift" \
    -o "$temporary/templates-tests"
"$temporary/templates-tests" "$@"
