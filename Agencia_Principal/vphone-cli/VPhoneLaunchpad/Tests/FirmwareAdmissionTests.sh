#!/bin/zsh
set -euo pipefail

launchpad="${0:a:h:h}"
temporary="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$temporary"' EXIT

/usr/bin/xcrun swiftc -swift-version 6 -strict-concurrency=complete \
    -parse-as-library \
    "$launchpad/VPhoneLaunchpadHelper/VPhoneLaunchpadHelperFirmwareAdmission.swift" \
    "$launchpad/Tests/FirmwareAdmissionTests.swift" \
    -o "$temporary/firmware-admission-tests"
"$temporary/firmware-admission-tests" "$@"
