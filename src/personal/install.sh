#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "Installing Devcontainer Feature: Personal Customizations"
echo "=================================================="

# Options passed from devcontainer-feature.json
ENABLE_GEMINI="${ENABLEGEMINI:-${ENABLE_GEMINI:-true}}"
ENABLE_PI="${ENABLEPI:-${ENABLE_PI:-true}}"
PI_PROTECT_SETTINGS="${PIPROTECTSETTINGS:-${PI_PROTECT_SETTINGS:-true}}"
PI_WRITABLE_PATHS="${PIWRITABLEPATHS:-${PI_WRITABLE_PATHS:-agent/history,agent/sessions}}"
UPDATE_PATH="${UPDATEPATH:-${UPDATE_PATH:-true}}"

# Devcontainer spec variables
REMOTE_USER="${_REMOTE_USER:-root}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-/root}"

echo "Configured settings:"
echo "  Remote user:          ${REMOTE_USER}"
echo "  Remote user home:     ${REMOTE_USER_HOME}"
echo "  Enable ~/.gemini:     ${ENABLE_GEMINI}"
echo "  Enable ~/.pi:         ${ENABLE_PI}"
echo "  Protect pi settings:  ${PI_PROTECT_SETTINGS}"
echo "  Pi writable paths:    ${PI_WRITABLE_PATHS}"
echo "  Update PATH:          ${UPDATE_PATH}"

# Install utilities (fuse-overlayfs, util-linux) if package manager is available
install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "Detected apt-get. Updating and installing utilities..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y || true
        apt-get install -y --no-install-recommends util-linux coreutils fuse-overlayfs || \
            apt-get install -y --no-install-recommends util-linux coreutils || true
    elif command -v apk >/dev/null 2>&1; then
        echo "Detected apk. Installing utilities..."
        apk add --no-cache util-linux coreutils fuse-overlayfs || \
            apk add --no-cache util-linux coreutils || true
    elif command -v dnf >/dev/null 2>&1; then
        echo "Detected dnf. Installing utilities..."
        dnf install -y util-linux coreutils fuse-overlayfs || \
            dnf install -y util-linux coreutils || true
    elif command -v yum >/dev/null 2>&1; then
        echo "Detected yum. Installing utilities..."
        yum install -y util-linux coreutils fuse-overlayfs || \
            yum install -y util-linux coreutils || true
    fi
}
install_packages || echo "Warning: Package installation step encountered an issue; proceeding with existing utilities."

SHARE_DIR="/usr/local/share/devcontainer-personal"
VAR_DIR="/var/lib/devcontainer-personal"

mkdir -p "${SHARE_DIR}"
mkdir -p "${VAR_DIR}/ro-gemini"
mkdir -p "${VAR_DIR}/volume-gemini"
mkdir -p "${VAR_DIR}/ro-pi"
mkdir -p "${VAR_DIR}/volume-pi"
mkdir -p "${VAR_DIR}/empty"
chmod -R 777 "${VAR_DIR}"

# Write build-time config for runtime entrypoint
cat <<EOF > "${SHARE_DIR}/config.env"
# Devcontainer Personal Customizations Runtime Configuration
REMOTE_USER="${REMOTE_USER}"
REMOTE_USER_HOME="${REMOTE_USER_HOME}"
ENABLE_GEMINI="${ENABLE_GEMINI}"
ENABLE_PI="${ENABLE_PI}"
PI_PROTECT_SETTINGS="${PI_PROTECT_SETTINGS}"
PI_WRITABLE_PATHS="${PI_WRITABLE_PATHS}"
UPDATE_PATH="${UPDATE_PATH}"
SHARE_DIR="${SHARE_DIR}"
VAR_DIR="${VAR_DIR}"
EOF
chmod 644 "${SHARE_DIR}/config.env"

# Copy entrypoint script to system location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "${SCRIPT_DIR}/entrypoint.sh" "${SHARE_DIR}/entrypoint.sh"
chmod 755 "${SHARE_DIR}/entrypoint.sh"

# Shell environment configuration for PATH
if [ "${UPDATE_PATH}" = "true" ]; then
    PROFILE_SCRIPT="/etc/profile.d/devcontainer-personal.sh"
    mkdir -p /etc/profile.d
    cat <<'EOF' > "${PROFILE_SCRIPT}"
# Added by Devcontainer Personal Customizations Feature
for p in "$HOME/.gemini/bin" "$HOME/.gemini/antigravity/bin" "$HOME/.pi/bin" "$HOME/.pi/agent/bin"; do
    if [ -d "$p" ]; then
        case ":$PATH:" in
            *":$p:"*) ;;
            *) export PATH="$p:$PATH" ;;
        esac
    fi
done

if [ -x "$HOME/.gemini/bin/agy" ] && [ -z "${ANTIGRAVITY_AGENTAPI_EXE:-}" ]; then
    export ANTIGRAVITY_AGENTAPI_EXE="$HOME/.gemini/bin/agy"
fi
EOF
    chmod 644 "${PROFILE_SCRIPT}"

    # Also source in /etc/bash.bashrc if present for interactive non-login bash
    if [ -f /etc/bash.bashrc ]; then
        if ! grep -q "devcontainer-personal.sh" /etc/bash.bashrc; then
            echo '[ -f /etc/profile.d/devcontainer-personal.sh ] && . /etc/profile.d/devcontainer-personal.sh' >> /etc/bash.bashrc
        fi
    fi

    # Also source in /etc/zsh/zshrc if zsh is present
    if [ -d /etc/zsh ]; then
        touch /etc/zsh/zshrc
        if ! grep -q "devcontainer-personal.sh" /etc/zsh/zshrc; then
            echo '[ -f /etc/profile.d/devcontainer-personal.sh ] && . /etc/profile.d/devcontainer-personal.sh' >> /etc/zsh/zshrc
        fi
    fi
fi

# Set up sudoers rule if /etc/sudoers.d exists so non-root containers can execute entrypoint mount setup
if [ -d /etc/sudoers.d ]; then
    echo "ALL ALL=(ALL) NOPASSWD: ${SHARE_DIR}/entrypoint.sh" > /etc/sudoers.d/devcontainer-personal
    chmod 0440 /etc/sudoers.d/devcontainer-personal
fi

echo "Personal customizations feature installed successfully."
