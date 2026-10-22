#!/bin/zsh
set -euo pipefail

launchpad="${0:a:h:h}"
temporary="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$temporary"' EXIT

# The launcher as the Xcode target builds it: a usage error and a refusal
# end with their own statuses before anything is started.
/usr/bin/xcrun swiftc -swift-version 6 -strict-concurrency=complete \
    -module-name VPhoneLaunchpadLauncher \
    "$launchpad/VPhoneLaunchpadShared/VPhoneLaunchpadBundleStore.swift" \
    "$launchpad/VPhoneLaunchpadShared/VPhoneLaunchpadLauncherPolicy.swift" \
    "$launchpad/VPhoneLaunchpadLauncher/"*.swift \
    -o "$temporary/vphone-launchpad-launcher"
expect_status() {
    local expected=$1
    shift
    local actual=0
    "$temporary/vphone-launchpad-launcher" "$@" 2>/dev/null || actual=$?
    if (( actual != expected )); then
        print -u2 "vphone-launchpad-launcher $*: expected status $expected, got $actual"
        exit 1
    fi
}
expect_status 64
expect_status 77 /bin/sh vm launch research-01
expect_status 77 /bin/sh -c 'exit 0'
print "Launcher refusal tests passed: usage 64, refusal 77"

/usr/bin/xcrun swiftc -swift-version 6 -strict-concurrency=complete \
    -parse-as-library \
    "$launchpad/VPhoneLaunchpadLauncher/VPhoneLaunchpadLauncherProcess.swift" \
    "$launchpad/Tests/LauncherProcessTests.swift" \
    -o "$temporary/launcher-process-tests"
"$temporary/launcher-process-tests" "$@"
