#!/bin/bash
set -e
source dev-container-features-test-lib
G="${GHIDRA_INSTALL_DIR:-/ghidra}"
check "patch applied to source" grep -q 'numbered independently for each name base' $G/Ghidra/Features/Decompiler/src/decompile/cpp/database.cc
check "decompile rebuilt" bash -c "ls $G/Ghidra/Features/Decompiler/build/os/*/decompile"
check "sleigh rebuilt" bash -c "ls $G/Ghidra/Features/Decompiler/build/os/*/sleigh"
check "rebuilt binaries owned by install owner" bash -c "[ \"\$(stat -c %U $G)\" = \"\$(stat -c %U $G/Ghidra/Features/Decompiler/build/os/*/decompile)\" ]"
check "no leftover objects" bash -c "! find $G/Ghidra/Features/Decompiler/build -name '*.o' | grep -q ."
reportResults
