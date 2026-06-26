#!/usr/bin/env bash
# Run the test suites with the Command Line Tools toolchain.
#
# Why this wrapper exists (no Xcode on this machine):
#   * The CLT ship Swift Testing as a framework outside the default search paths,
#     plus its interop dylib in a sibling lib dir — so the compiler/linker need
#     explicit -F and -rpath flags to find them.
#   * The CLT have no XCTest runner, and `swift test` (without --disable-xctest)
#     tries XCTest first and exits without running the Swift Testing suites.
#
# Any extra arguments are forwarded to `swift test` (e.g. --filter Mediator).
set -euo pipefail

DEVELOPER="/Library/Developer/CommandLineTools/Library/Developer"
FRAMEWORKS="${DEVELOPER}/Frameworks"
INTEROP_LIB="${DEVELOPER}/usr/lib"

exec swift test --disable-xctest \
    -Xswiftc -F -Xswiftc "${FRAMEWORKS}" \
    -Xlinker -F -Xlinker "${FRAMEWORKS}" \
    -Xlinker -rpath -Xlinker "${FRAMEWORKS}" \
    -Xlinker -rpath -Xlinker "${INTEROP_LIB}" \
    "$@"
