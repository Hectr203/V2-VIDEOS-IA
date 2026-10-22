#!/bin/zsh
set -euo pipefail

launchpad="${0:a:h:h}"
temporary="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$temporary"' EXIT

/usr/bin/xcrun swiftc -swift-version 6 -strict-concurrency=complete \
    -parse-as-library \
    "$launchpad/VPhoneLaunchpadShared/VPhoneLaunchpadLineReader.swift" \
    "$launchpad/VPhoneLaunchpad/Application/VPhoneLaunchpadNewlineTranslator.swift" \
    "$launchpad/VPhoneLaunchpad/Application/VPhoneLaunchpadLogWriter.swift" \
    "$launchpad/Tests/ConsoleOutputTests.swift" \
    -o "$temporary/console-output-tests"
"$temporary/console-output-tests" "$@"
