#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Clearbluejar Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# Based on: https://github.com/microsoft/vscode-dev-containers/blob/main/script-library/python-debian.sh
# Maintainer: Clearbluejar
#
# Syntax: ./ghidra-install.sh [Ghidra Version] [Ghidra Install Dir] [non-root user] [Update rc files flag]


GHIDRA_VERSION="${GHIDRA_VERSION:-"latest"}"
GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-"/ghidra"}"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
UPDATE_RC="${UPDATE_RC:-"true"}" #allows for custom env variables in login shell

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
        echo "Updating /etc/bash.bashrc and /etc/zsh/zshrc..."
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

set +e
# Download latest Ghidra, or specific version
if [ "${GHIDRA_VERSION}" == "latest" ]; then
    GHIDRA_DOWNLOAD_URL=$(curl -Ss https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest | jq -r ".assets[] | .browser_download_url")
    
    GHIDRA_VERSION="$(echo ${GHIDRA_DOWNLOAD_URL} | cut -d_ -f 2)"
else
    GHIDRA_DOWNLOAD_URL=$(curl -Ss https://api.github.com/repos/NationalSecurityAgency/ghidra/releases | jq -r ".[] | .assets[] | .browser_download_url" | fgrep "${GHIDRA_VERSION}")
fi
set -e

echo "GHIDRA_DOWNLOAD_URL: ${GHIDRA_DOWNLOAD_URL}"
echo "GHIDRA_VERSION: ${GHIDRA_VERSION}"
echo "GHIDRA_INSTALL_DIR: ${GHIDRA_INSTALL_DIR}"


# Ensure have valid versions
if [ -z "$GHIDRA_DOWNLOAD_URL" ] || [ -z "$GHIDRA_VERSION" ]; then
    echo "Error: Failed to get GHIDRA_DOWNLOAD_URL:${GHIDRA_DOWNLOAD_URL} and GHIDRA_VERSION:${GHIDRA_VERSION}" 
    exit 1 ## error out if they are empty
fi

echo "Installing Ghidra ${GHIDRA_VERSION} and dependencies to ${GHIDRA_INSTALL_DIR}..."

mkdir -p /tmp/ghidra-tmp
cd /tmp/ghidra-tmp

# Download Ghidra
curl -vLSO --remote-name $GHIDRA_DOWNLOAD_URL
unzip $(basename $GHIDRA_DOWNLOAD_URL)

# Move base ghidra_<version>_PUBLIC to $GHIDRA_INSTALL_DIR
mv "$(echo $(basename $GHIDRA_DOWNLOAD_URL) | cut -d_ -f 1-3)" $GHIDRA_INSTALL_DIR

# Ghidra doesn't provide arm64 native binaries
# build native to ensure performant Ghidra 
if uname -a | grep -q 'aarch64'; then
    # need grandle and Java to build
    if command -v java & command -v gradle; then
        $GHIDRA_INSTALL_DIR/support/buildNatives
    else
        echo "WARNING: Native binaries missing for arch: run $GHIDRA_INSTALL_DIR/support/buildNatives after installing java and gradle"
    fi
fi

# set permissions for user
chown -R ${USERNAME}:${USERNAME} ${GHIDRA_INSTALL_DIR}

# Clean up
rm -rf /tmp/ghidra-tmp

# Make GHIDRA ENV vars availble to bash and zsh shells
updaterc "$(cat << EOF
export GHIDRA_VERSION="${GHIDRA_VERSION}"
export GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR}"
EOF
)"