#!/bin/bash

# This test file will be executed against one of the scenarios devcontainer.json test that
# includes the 'color' feature with "favorite": "gold" option.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
env
check "default GHIDRA_INSTALL_DIR" env | grep 'GHIDRA_INSTALL_DIR=/ghidra'
check "env GHIDRA_VERSION" env | grep 'GHIDRA_VERSION=10.2.2'

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
