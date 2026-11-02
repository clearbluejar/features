#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Clearbluejar Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# Based on: https://github.com/microsoft/vscode-dev-containers/blob/main/script-library/python-debian.sh
# Maintainer: Clearbluejar
#
# Options are passed as environment variables by the devcontainer CLI:
#   GHIDRA_VERSION, GHIDRA_INSTALL_DIR, USERNAME, UPDATE_RC, BUILD_NATIVES


GHIDRA_VERSION="${GHIDRA_VERSION:-"latest"}"
GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-"/ghidra"}"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
UPDATE_RC="${UPDATE_RC:-"true"}" #allows for custom env variables in login shell
BUILD_NATIVES="${BUILD_NATIVES:-"false"}"

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# If none do nothing
if [ "${GHIDRA_VERSION}" = "none" ]; then
    echo "Skipping Ghidra Install... Version set to: ${GHIDRA_VERSION}"
    exit 0
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in ${POSSIBLE_USERS[@]}; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

updaterc() {
    if [ "${UPDATE_RC}" = "true" ]; then
        # /etc/bash.bashrc and zshrc only apply to interactive shells; profile.d also covers
        # login shells such as `bash -lc`, `su -` and the devcontainer CLI's environment probe.
        echo "Updating /etc/profile.d/ghidra.sh, /etc/bash.bashrc and /etc/zsh/zshrc..."
        mkdir -p /etc/profile.d
        echo -e "$1" > /etc/profile.d/ghidra.sh
        if [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/bash.bashrc
        fi
        if [ -f "/etc/zsh/zshrc" ] && [[ "$(cat /etc/zsh/zshrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/zsh/zshrc
        fi
    fi
}

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages ca-certificates curl jq unzip

# Resolve the release asset. The API is tried first (a GITHUB_TOKEN, if present, lifts the 60 req/h
# unauthenticated limit); if it fails, e.g. rate-limited when many images build in parallel from shared
# CI runner IPs, fall back to the release page on github.com, which has no API quota.
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
GHIDRA_REPO="NationalSecurityAgency/ghidra"
CURL_RETRY=(--retry 3 --retry-delay 2 --retry-all-errors)
github_api() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL "${CURL_RETRY[@]}" -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" "$1"
    else
        curl -fsSL "${CURL_RETRY[@]}" -H "Accept: application/vnd.github+json" "$1"
    fi
}
if [ "${GHIDRA_VERSION}" = "latest" ]; then
    RELEASE_TAG="latest"
    RELEASE_JSON="$(github_api "${GITHUB_API_URL}/repos/${GHIDRA_REPO}/releases/latest" 2>/dev/null)" || RELEASE_JSON=""
else
    # Exact match on the release tag: a bare "12.1" must not resolve to 12.1.2, 12.1.3, ...
    RELEASE_TAG="Ghidra_${GHIDRA_VERSION}_build"
    RELEASE_JSON="$(github_api "${GITHUB_API_URL}/repos/${GHIDRA_REPO}/releases/tags/${RELEASE_TAG}" 2>/dev/null)" || RELEASE_JSON=""
fi
GHIDRA_DOWNLOAD_URL="$(printf '%s' "${RELEASE_JSON}" | jq -r '[.assets[]? | .browser_download_url | select(test("/ghidra_.*_PUBLIC_.*\\.zip$"))] | first // empty' 2>/dev/null)"
if [ -z "${GHIDRA_DOWNLOAD_URL}" ]; then
    MSG="$(printf '%s' "${RELEASE_JSON}" | jq -r '.message // empty' 2>/dev/null)"
    echo "GitHub API lookup failed${MSG:+ (${MSG})}; resolving via the release page instead..."
    if [ "${RELEASE_TAG}" = "latest" ]; then
        RELEASE_TAG="$(curl -fsSI "${CURL_RETRY[@]}" -o /dev/null -w '%{redirect_url}' "https://github.com/${GHIDRA_REPO}/releases/latest" | sed -E 's#.*/tag/##')"
    fi
    if [ -n "${RELEASE_TAG}" ]; then
        GHIDRA_DOWNLOAD_URL="$(curl -fsSL "${CURL_RETRY[@]}" "https://github.com/${GHIDRA_REPO}/releases/expanded_assets/${RELEASE_TAG}" 2>/dev/null \
            | grep -oE 'href="[^"]*/ghidra_[^"]*_PUBLIC_[^"]*\.zip"' | head -n 1 | sed -E 's/^href="([^"]*)"$/\1/; s#^/#https://github.com/#')"
    fi
fi
if [ -z "${GHIDRA_DOWNLOAD_URL}" ]; then
    echo "Error: could not resolve a Ghidra release asset for version '${GHIDRA_VERSION}'."
    echo "Check https://github.com/${GHIDRA_REPO}/releases for valid versions (e.g. 12.2, 12.1.4)."
    exit 1
fi
# ghidra_<version>_PUBLIC_<date>.zip
GHIDRA_VERSION="$(basename "${GHIDRA_DOWNLOAD_URL}" | sed -E 's/^ghidra_([^_]+)_PUBLIC_.*$/\1/')"

echo "GHIDRA_DOWNLOAD_URL: ${GHIDRA_DOWNLOAD_URL}"
echo "GHIDRA_VERSION: ${GHIDRA_VERSION}"
echo "GHIDRA_INSTALL_DIR: ${GHIDRA_INSTALL_DIR}"

if [ -e "${GHIDRA_INSTALL_DIR}" ] && [ -n "$(ls -A "${GHIDRA_INSTALL_DIR}" 2>/dev/null)" ]; then
    echo "Error: ${GHIDRA_INSTALL_DIR} already exists and is not empty. Remove it or choose another ghidra_install_dir."
    exit 1
fi

echo "Installing Ghidra ${GHIDRA_VERSION} and dependencies to ${GHIDRA_INSTALL_DIR}..."

mkdir -p /tmp/ghidra-tmp
cd /tmp/ghidra-tmp

# Download Ghidra
curl -fLSs "${CURL_RETRY[@]}" --remote-name "$GHIDRA_DOWNLOAD_URL"
unzip -q "$(basename "$GHIDRA_DOWNLOAD_URL")"

# Move base ghidra_<version>_PUBLIC to $GHIDRA_INSTALL_DIR
mkdir -p "$(dirname "${GHIDRA_INSTALL_DIR}")"
mv ghidra_*_PUBLIC "${GHIDRA_INSTALL_DIR}"

# Ghidra refuses to start on a JDK older than application.java.min (12.2 moved it from 21 to 25), so an
# image with the wrong JDK would build fine and then fail at first use. Check now.
JAVA_MIN="$(sed -n 's/^application\.java\.min=//p' "${GHIDRA_INSTALL_DIR}/Ghidra/application.properties")"
JAVA_MAX="$(sed -n 's/^application\.java\.max=//p' "${GHIDRA_INSTALL_DIR}/Ghidra/application.properties")"
if command -v java > /dev/null 2>&1; then
    JAVA_MAJOR="$(java -version 2>&1 | sed -nE '1s/.*version "([0-9]+)(\.[0-9]+)*.*/\1/p')"
    [ "${JAVA_MAJOR}" = "1" ] && JAVA_MAJOR="$(java -version 2>&1 | sed -nE '1s/.*version "1\.([0-9]+).*/\1/p')"
    echo "Ghidra ${GHIDRA_VERSION} requires Java ${JAVA_MIN:-?}${JAVA_MAX:+..${JAVA_MAX}}; found Java ${JAVA_MAJOR:-?} ($(command -v java))"
    if [ -n "${JAVA_MIN}" ] && [ -n "${JAVA_MAJOR}" ] && [ "${JAVA_MAJOR}" -lt "${JAVA_MIN}" ]; then
        echo "Error: Java ${JAVA_MAJOR} is too old for Ghidra ${GHIDRA_VERSION} (needs >= ${JAVA_MIN})."
        echo "       e.g. \"ghcr.io/devcontainers/features/java:1\": { \"version\": \"${JAVA_MIN}\", \"installGradle\": true }"
        exit 1
    fi
    if [ -n "${JAVA_MAX}" ] && [ -n "${JAVA_MAJOR}" ] && [ "${JAVA_MAJOR}" -gt "${JAVA_MAX}" ]; then
        echo "Error: Java ${JAVA_MAJOR} is too new for Ghidra ${GHIDRA_VERSION} (max ${JAVA_MAX})."
        exit 1
    fi
else
    echo "WARNING: no java on PATH. Ghidra ${GHIDRA_VERSION} needs Java ${JAVA_MIN:-?}; install it before using Ghidra."
fi

# Ghidra releases ship no linux arm64 native binaries, so always build them there.
if uname -m | grep -qE 'aarch64|arm64'; then
    BUILD_NATIVES="true"
fi

build_natives() {
    if ! command -v java > /dev/null 2>&1 || ! command -v gradle > /dev/null 2>&1; then
        echo "WARNING: java and gradle are required to build Ghidra native binaries."
        echo "         Install them (e.g. ghcr.io/devcontainers/features/java with installGradle) before this feature,"
        echo "         or run: cd ${GHIDRA_INSTALL_DIR}/support/gradle && gradle buildNatives"
        return 0
    fi
    check_packages gcc g++ make libc6-dev
    echo "Building Ghidra native binaries for $(uname -m)..."
    if [ -e "${GHIDRA_INSTALL_DIR}/support/buildNatives" ]; then
        # Ghidra < 11.2
        "${GHIDRA_INSTALL_DIR}/support/buildNatives"
    else
        pushd "${GHIDRA_INSTALL_DIR}/support/gradle/" > /dev/null
        GRADLE_USER_HOME=/tmp/ghidra-tmp/gradle gradle buildNatives --no-daemon --no-watch-fs -q
        popd > /dev/null
    fi
    # Drop intermediate objects and gradle caches; only the executables under build/os/<platform>/ are needed.
    find "${GHIDRA_INSTALL_DIR}" -type d -name build -exec sh -c 'rm -rf "$1/objs" "$1/tmp"' _ {} \; || true
    rm -rf "${GHIDRA_INSTALL_DIR}/support/gradle/.gradle" /root/.gradle || true
}

if [ "${BUILD_NATIVES}" = "true" ]; then
    build_natives
fi

# set permissions for user
chown -R ${USERNAME}:${USERNAME} ${GHIDRA_INSTALL_DIR}

# Clean up. Gradle worker JVMs can outlive the build for a moment and keep writing to the cache, so a
# single rm -rf may fail with "Directory not empty" (seen under QEMU-emulated arm64 builds); retry, never fatal.
for _ in 1 2 3 4 5; do rm -rf /tmp/ghidra-tmp 2>/dev/null && break; sleep 3; done
rm -rf /tmp/ghidra-tmp 2>/dev/null || true

# Make GHIDRA ENV vars availble to bash and zsh shells
updaterc "$(cat << EOF
export GHIDRA_VERSION="${GHIDRA_VERSION}"
export GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR}"
EOF
)"