#!/usr/bin/env bash
# Patch the decompiler C++ source shipped inside a Ghidra release and rebuild the native
# binaries (decompile, sleigh, demanglers) so Ghidra runs the patched decompiler.
#
# Runs as a devcontainer feature (options arrive as env vars) or standalone, e.g. from a
# postCreateCommand:  curl -fsSL <raw url of this file> | sudo -E bash
#
# Env / options: PATCH (bundled patch name or "none"), PATCH_URL, GHIDRA_INSTALL_DIR
set -e

PATCH="${PATCH:-"diffstable-varnames"}"
PATCH_URL="${PATCH_URL:-""}"
GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-"$(. /etc/profile.d/ghidra.sh 2>/dev/null; echo "${GHIDRA_INSTALL_DIR:-/ghidra}")"}"
BUNDLED_BASE_URL="${BUNDLED_BASE_URL:-"https://raw.githubusercontent.com/clearbluejar/features/main/src/ghidra-decompiler-patch"}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

if [ ! -f "${GHIDRA_INSTALL_DIR}/Ghidra/application.properties" ]; then
    echo "ERROR: no Ghidra install at ${GHIDRA_INSTALL_DIR} (set GHIDRA_INSTALL_DIR / ghidra_install_dir)."
    exit 1
fi
DECOMP_SRC="${GHIDRA_INSTALL_DIR}/Ghidra/Features/Decompiler/src/decompile/cpp"
if [ ! -d "${DECOMP_SRC}" ]; then
    echo "ERROR: ${DECOMP_SRC} not found; this Ghidra install does not ship the decompiler source."
    exit 1
fi
# sudo resets PATH, so look in the usual JDK/gradle locations (SDKMAN as used by the devcontainer java feature)
for d in "${JAVA_HOME:+${JAVA_HOME}/bin}" /usr/local/sdkman/candidates/java/current/bin /usr/local/sdkman/candidates/gradle/current/bin \
         /usr/lib/jvm/default-java/bin /opt/gradle/bin; do
    [ -n "$d" ] && [ -d "$d" ] && case ":${PATH}:" in *":$d:"*) ;; *) PATH="${PATH}:$d";; esac
done
export PATH
if ! command -v java > /dev/null 2>&1 || ! command -v gradle > /dev/null 2>&1; then
    echo "ERROR: java and gradle are required to rebuild the Ghidra native binaries."
    echo "       Use an image that has them (e.g. ghcr.io/clearbluejar/ghidra-python) or install"
    echo "       ghcr.io/devcontainers/features/java with installGradle before this feature."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt_get_update() { if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then apt-get update -y; fi; }
check_packages() { if ! dpkg -s "$@" > /dev/null 2>&1; then apt_get_update; apt-get -y install --no-install-recommends "$@"; fi; }
check_packages patch curl ca-certificates gcc g++ make libc6-dev

OWNER="$(stat -c '%U:%G' "${GHIDRA_INSTALL_DIR}")"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
export GRADLE_USER_HOME="${TMP}/gradle"   # keep gradle's cache out of /root and the invoking user's home

apply_patch() {  # $1 = path to patch file, $2 = label
    echo "Applying decompiler patch: $2"
    pushd "${GHIDRA_INSTALL_DIR}" > /dev/null
    if patch -p1 -R --dry-run --silent < "$1" > /dev/null 2>&1; then
        echo "  already applied, skipping."
    else
        patch -p1 --forward --no-backup-if-mismatch < "$1"
    fi
    popd > /dev/null
}

APPLIED=0
if [ -n "${PATCH}" ] && [ "${PATCH}" != "none" ]; then
    if [ -n "${SCRIPT_DIR}" ] && [ -f "${SCRIPT_DIR}/${PATCH}.patch" ]; then
        apply_patch "${SCRIPT_DIR}/${PATCH}.patch" "${PATCH} (bundled)"
    else
        curl -fLSs -o "${TMP}/${PATCH}.patch" "${BUNDLED_BASE_URL}/${PATCH}.patch"
        apply_patch "${TMP}/${PATCH}.patch" "${PATCH} (${BUNDLED_BASE_URL})"
    fi
    APPLIED=1
fi
if [ -n "${PATCH_URL}" ]; then
    curl -fLSs -o "${TMP}/extra.patch" "${PATCH_URL}"
    apply_patch "${TMP}/extra.patch" "${PATCH_URL}"
    APPLIED=1
fi
if [ "${APPLIED}" = "0" ]; then
    echo "Nothing to apply (patch=none and no patch_url)."
    exit 0
fi

echo "Rebuilding Ghidra native binaries for $(uname -m)..."
if [ -e "${GHIDRA_INSTALL_DIR}/support/buildNatives" ]; then
    "${GHIDRA_INSTALL_DIR}/support/buildNatives"          # Ghidra < 11.2
else
    pushd "${GHIDRA_INSTALL_DIR}/support/gradle/" > /dev/null
    gradle buildNatives --no-daemon -q
    popd > /dev/null
fi

# Keep only the executables under build/os/<platform>/; drop objects, temp files and gradle caches.
find "${GHIDRA_INSTALL_DIR}" -type d -name build -exec sh -c 'rm -rf "$1/objs" "$1/tmp"' _ {} \;
rm -rf "${GHIDRA_INSTALL_DIR}/support/gradle/.gradle"
chown -R "${OWNER}" "${GHIDRA_INSTALL_DIR}"

echo "Patched decompiler installed:"
ls -1 "${GHIDRA_INSTALL_DIR}"/Ghidra/Features/Decompiler/build/os/*/decompile
