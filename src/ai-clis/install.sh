#!/usr/bin/env bash
set -euo pipefail

# Ensure consistent file creation permissions
umask 0022

echo "=================================================="
echo "Installing Devcontainer Feature: AI CLIs"
echo "=================================================="

# Options passed from devcontainer-feature.json
INSTALL_GEMINI="${GEMINI:-true}"
INSTALL_CLAUDE="${CLAUDE:-true}"
INSTALL_OPENCODE="${OPENCODE:-true}"
INSTALL_PI="${PI:-true}"

GEMINI_VERSION="${GEMINIVERSION:-${GEMINI_VERSION:-latest}}"
CLAUDE_VERSION="${CLAUDEVERSION:-${CLAUDE_VERSION:-latest}}"
OPENCODE_VERSION="${OPENCODEVERSION:-${OPENCODE_VERSION:-latest}}"
PI_VERSION="${PIVERSION:-${PI_VERSION:-latest}}"

echo "Configured settings:"
echo "  Install Gemini:   ${INSTALL_GEMINI} (version: ${GEMINI_VERSION})"
echo "  Install Claude:   ${INSTALL_CLAUDE} (version: ${CLAUDE_VERSION})"
echo "  Install OpenCode: ${INSTALL_OPENCODE} (version: ${OPENCODE_VERSION})"
echo "  Install Pi.dev:   ${INSTALL_PI} (version: ${PI_VERSION})"

# Ensure NVM / Node / npm are available in environment
export NVM_DIR="${NVM_DIR:-/usr/local/share/nvm}"
if [ -s "${NVM_DIR}/nvm.sh" ]; then
    # Sourcing nvm might use unbound variables internally, so temporarily disable set -u
    set +u
    . "${NVM_DIR}/nvm.sh"
    set -u
elif [ -s "${HOME}/.nvm/nvm.sh" ]; then
    set +u
    export NVM_DIR="${HOME}/.nvm"
    . "${NVM_DIR}/nvm.sh"
    set -u
fi

if [ -d "${NVM_DIR}/current/bin" ]; then
    export PATH="${NVM_DIR}/current/bin:${PATH}"
fi

# Fallback check for npm
if ! command -v npm >/dev/null 2>&1; then
    echo "ERROR: npm is required to install AI CLIs but was not found."
    echo "Please ensure the Node.js devcontainer feature (ghcr.io/devcontainers/features/node) is installed."
    exit 1
fi

echo "Using npm version: $(npm -v)"
echo "Using node version: $(node -v)"

symlink_to_usr_local_bin() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        local target_path
        target_path="$(command -v "$cmd")"
        if [ "$target_path" != "/usr/local/bin/$cmd" ]; then
            mkdir -p /usr/local/bin
            ln -sf "$target_path" "/usr/local/bin/$cmd"
            echo "Symlinked $target_path -> /usr/local/bin/$cmd"
        fi
    fi
}

resolve_pkg() {
    local pkg="$1"
    local ver="$2"
    if [ "$ver" = "latest" ] || [ -z "$ver" ]; then
        echo "$pkg"
    else
        echo "${pkg}@${ver}"
    fi
}

# 1. Gemini CLI
if [ "${INSTALL_GEMINI}" = "true" ]; then
    PKG="$(resolve_pkg "@google/gemini-cli" "${GEMINI_VERSION}")"
    echo "Installing Google Gemini CLI (${PKG})..."
    npm install -g "${PKG}"
    symlink_to_usr_local_bin gemini
fi

# 2. Claude Code CLI
if [ "${INSTALL_CLAUDE}" = "true" ]; then
    if command -v claude >/dev/null 2>&1; then
        echo "Claude CLI is already available at: $(command -v claude)"
    else
        PKG="$(resolve_pkg "@anthropic-ai/claude-code" "${CLAUDE_VERSION}")"
        echo "Installing Claude Code CLI (${PKG})..."
        npm install -g "${PKG}"
    fi
    symlink_to_usr_local_bin claude
fi

# 3. OpenCode CLI
if [ "${INSTALL_OPENCODE}" = "true" ]; then
    PKG="$(resolve_pkg "opencode-ai" "${OPENCODE_VERSION}")"
    echo "Installing OpenCode CLI (${PKG})..."
    npm install -g "${PKG}"
    symlink_to_usr_local_bin opencode
fi

# 4. Pi.dev CLI
if [ "${INSTALL_PI}" = "true" ]; then
    PKG="$(resolve_pkg "@earendil-works/pi-coding-agent" "${PI_VERSION}")"
    echo "Installing pi.dev CLI (${PKG})..."
    npm install -g --ignore-scripts "${PKG}"
    symlink_to_usr_local_bin pi
    if [ -f /usr/local/bin/pi ] && [ ! -e /usr/local/bin/pi.dev ]; then
        ln -sf /usr/local/bin/pi /usr/local/bin/pi.dev
    fi
fi

echo "=================================================="
echo "AI CLIs installation completed successfully!"
echo "=================================================="

