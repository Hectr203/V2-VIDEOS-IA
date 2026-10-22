#!/bin/zsh
set -euo pipefail

launchpad="${0:a:h:h}"
cache="$launchpad/VPhoneLaunchpad/IPSWCache"
temporary="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$temporary"' EXIT

/usr/bin/xcrun swiftc -swift-version 6 -strict-concurrency=complete \
    -parse-as-library \
    "$cache/VPhoneLaunchpadIPSW.swift" \
    "$cache/VPhoneLaunchpadIPSWCache.swift" \
    "$cache/VPhoneLaunchpadIPSWRows.swift" \
    "$launchpad/Tests/IPSWCacheTests.swift" \
    -o "$temporary/ipsw-cache-tests"
"$temporary/ipsw-cache-tests" "$@"
