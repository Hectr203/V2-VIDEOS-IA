#!/bin/zsh
set -euo pipefail

# Builds the guest-free rules of apps.remove_system, apps.restore_system and
# apfs.snapshot.delete, and the fs_snapshot_list batch parser, for the Mac and
# runs their checks. Nothing lists or deletes a snapshot and no guest is
# needed; the binaries live in a temporary directory.

daemon="${0:a:h:h}"
temporary="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/vphone-system-maintenance-tests.XXXXXX")"
trap '/bin/rm -rf "$temporary"' EXIT

/usr/bin/xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library \
    -module-name SystemMaintenanceTests \
    "$daemon/Daemon/GuestSystemAppPolicy.swift" \
    "$daemon/Daemon/GuestSnapshotPolicy.swift" \
    "$daemon/Tests/SystemMaintenanceTests.swift" \
    -o "$temporary/system-maintenance-tests"

"$temporary/system-maintenance-tests"

/usr/bin/xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
    -fsanitize=address,undefined \
    -framework Foundation \
    "$daemon/Tests/APFSSnapshotParseTests.m" "$daemon/Native/vphoned_apfs.m" \
    -o "$temporary/apfs-snapshot-parse-tests"

"$temporary/apfs-snapshot-parse-tests"
