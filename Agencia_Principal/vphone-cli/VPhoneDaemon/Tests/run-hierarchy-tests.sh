#!/bin/zsh
set -euo pipefail

daemon="${0:a:h:h}"
temporary="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/vphone-hierarchy-tests.XXXXXX")"
trap '/bin/rm -rf "$temporary"' EXIT

source="$daemon/Native/vphoned_ax_hierarchy.m"
tests="$daemon/Tests/HierarchyTests.m"

/usr/bin/xcrun --sdk macosx clang -fobjc-arc \
    -fprofile-instr-generate -fcoverage-mapping \
    -framework Foundation -framework CoreGraphics \
    "$tests" "$source" -o "$temporary/hierarchy-tests"

VP_HIERARCHY_RECEIPTS="$temporary" \
    LLVM_PROFILE_FILE="$temporary/hierarchy.profraw" \
    "$temporary/hierarchy-tests"

/usr/bin/xcrun llvm-profdata merge -sparse "$temporary/hierarchy.profraw" \
    -o "$temporary/hierarchy.profdata"
/usr/bin/xcrun llvm-cov report "$temporary/hierarchy-tests" \
    -instr-profile="$temporary/hierarchy.profdata" "$source"
