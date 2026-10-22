#!/bin/zsh
set -euo pipefail

launchpad="${0:a:h:h}"
temporary="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$temporary"' EXIT

/usr/bin/xcrun swiftc -swift-version 6 -strict-concurrency=complete \
    -parse-as-library \
    "$launchpad/VPhoneLaunchpadShared/VPhoneLaunchpadBundleStore.swift" \
    "$launchpad/VPhoneLaunchpad/Machines/VPhoneLaunchpadMachine.swift" \
    "$launchpad/Tests/MachineProductTypeTests.swift" \
    -o "$temporary/machine-product-type-tests"
"$temporary/machine-product-type-tests" "$@"
