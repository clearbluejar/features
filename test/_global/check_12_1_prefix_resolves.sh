#!/bin/bash
# A bare "12.1" must resolve to the 12.1 release, not to 12.1.2 / 12.1.3 / 12.1.4 as well.
set -e
source dev-container-features-test-lib

check "env GHIDRA_VERSION" bash -lc 'env | grep GHIDRA_VERSION=12.1$'
check "application.version" grep -q '^application.version=12.1$' /ghidra/Ghidra/application.properties

reportResults
