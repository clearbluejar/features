#!/bin/bash
set -e
source dev-container-features-test-lib

check "default GHIDRA_INSTALL_DIR" bash -lc 'env | grep GHIDRA_INSTALL_DIR=/ghidra'
check "env GHIDRA_VERSION" bash -lc 'env | grep GHIDRA_VERSION=12.2'
check "release installed" test -f /ghidra/Ghidra/application.properties
check "application.version" grep -q '^application.version=12.2$' /ghidra/Ghidra/application.properties

reportResults
