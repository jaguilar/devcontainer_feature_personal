#!/usr/bin/env bash
set -e

CONFIG_FILE="/usr/local/share/devcontainer-personal/config.env"
if [ -f "${CONFIG_FILE}" ]; then
    . "${CONFIG_FILE}"
fi

VAR_DIR="${VAR_DIR:-/var/lib/devcontainer-personal}"
ENABLE_GEMINI="${ENABLE_GEMINI:-true}"
ENABLE_PI="${ENABLE_PI:-true}"
PI_PROTECT_SETTINGS="${PI_PROTECT_SETTINGS:-true}"
PI_WRITABLE_PATHS="${PI_WRITABLE_PATHS:-agent/history,agent/sessions}"

# Determine target user and target home directory
if [ -n "${_REMOTE_USER:-}" ] && [ "${_REMOTE_USER}" != "root" ]; then
    TARGET_USER="${_REMOTE_USER}"
    TARGET_HOME="${_REMOTE_USER_HOME:-/home/${_REMOTE_USER}}"
elif [ -n "${REMOTE_USER:-}" ] && [ "${REMOTE_USER}" != "root" ]; then
    TARGET_USER="${REMOTE_USER}"
    TARGET_HOME="${REMOTE_USER_HOME:-/home/${REMOTE_USER}}"
elif [ "$(id -u)" -ne 0 ]; then
    TARGET_USER="$(id -un)"
    TARGET_HOME="${HOME}"
else
    # Running as root: check for standard non-root user in /etc/passwd (e.g. vscode, ubuntu, node)
    NON_ROOT_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd 2>/dev/null || true)
    if [ -n "${NON_ROOT_USER}" ]; then
        TARGET_USER="${NON_ROOT_USER}"
        TARGET_HOME=$(getent passwd "${NON_ROOT_USER}" | cut -d: -f6)
    else
        TARGET_USER="root"
        TARGET_HOME="${HOME:-/root}"
    fi
fi

TARGET_UID=$(id -u "${TARGET_USER}" 2>/dev/null || echo 0)
TARGET_GID=$(id -g "${TARGET_USER}" 2>/dev/null || echo 0)

# Full overlay setup (used for ~/.gemini, and ~/.pi if PI_PROTECT_SETTINGS is false)
setup_overlay() {
    local NAME="$1"
    local RO_DIR="${VAR_DIR}/ro-${NAME}"
    local VOL_DIR="${VAR_DIR}/volume-${NAME}"
    local TARGET_DIR="${TARGET_HOME}/.${NAME}"

    echo "[personal-customizations] Configuring full overlay for ~/.${NAME}..."

    # Ensure persistent named volume structure exists
    mkdir -p "${VOL_DIR}/upper" "${VOL_DIR}/work"
    chown -R "${TARGET_UID}:${TARGET_GID}" "${VOL_DIR}" 2>/dev/null || true
    chmod -R 775 "${VOL_DIR}" 2>/dev/null || true

    # Enforce read-only on host bind mount
    if [ -d "${RO_DIR}" ]; then
        mount -o remount,bind,ro "${RO_DIR}" 2>/dev/null || mount -o remount,ro "${RO_DIR}" 2>/dev/null || true
    fi

    # Determine lower directory
    local LOWER_DIR="${RO_DIR}"
    if [ ! -d "${LOWER_DIR}" ] || [ -z "$(ls -A "${LOWER_DIR}" 2>/dev/null)" ]; then
        mkdir -p "${VAR_DIR}/empty"
        LOWER_DIR="${VAR_DIR}/empty"
    fi

    # Ensure target directory in user home exists
    mkdir -p "${TARGET_DIR}"
    chown "${TARGET_UID}:${TARGET_GID}" "${TARGET_DIR}" 2>/dev/null || true

    if ! mountpoint -q "${TARGET_DIR}" 2>/dev/null; then
        local MOUNTED=false

        # Attempt 1: Linux kernel OverlayFS
        if mount -t overlay overlay \
            -o lowerdir="${LOWER_DIR}",upperdir="${VOL_DIR}/upper",workdir="${VOL_DIR}/work" \
            "${TARGET_DIR}" 2>/dev/null; then
            echo "[personal-customizations] Mounted ~/.${NAME} using kernel OverlayFS."
            MOUNTED=true
        fi

        # Attempt 2: Userspace fuse-overlayfs
        if [ "${MOUNTED}" = "false" ] && command -v fuse-overlayfs >/dev/null 2>&1; then
            if fuse-overlayfs \
                -o lowerdir="${LOWER_DIR}",upperdir="${VOL_DIR}/upper",workdir="${VOL_DIR}/work" \
                "${TARGET_DIR}" 2>/dev/null; then
                echo "[personal-customizations] Mounted ~/.${NAME} using fuse-overlayfs."
                MOUNTED=true
            fi
        fi

        # Attempt 3: Persistent volume sync + bind mount or symlink fallback
        if [ "${MOUNTED}" = "false" ]; then
            echo "[personal-customizations] OverlayFS not available; synchronizing host credentials to persistent volume..."
            if [ -d "${RO_DIR}" ] && [ "${RO_DIR}" != "${VAR_DIR}/empty" ]; then
                cp -an "${RO_DIR}"/. "${VOL_DIR}/upper/" 2>/dev/null || true
            fi
            chown -R "${TARGET_UID}:${TARGET_GID}" "${VOL_DIR}/upper" 2>/dev/null || true

            if mount --bind "${VOL_DIR}/upper" "${TARGET_DIR}" 2>/dev/null; then
                echo "[personal-customizations] Bind-mounted persistent volume to ${TARGET_DIR}."
            else
                rmdir "${TARGET_DIR}" 2>/dev/null || rm -rf "${TARGET_DIR}" 2>/dev/null || true
                ln -sfn "${VOL_DIR}/upper" "${TARGET_DIR}"
                echo "[personal-customizations] Symlinked ${TARGET_DIR} -> ${VOL_DIR}/upper."
            fi
        fi
    else
        echo "[personal-customizations] ~/.${NAME} is already mounted."
    fi

    # Fix permissions for target user
    chown -R "${TARGET_UID}:${TARGET_GID}" "${VOL_DIR}/upper" "${TARGET_DIR}" 2>/dev/null || true

    # Mirror to /root if target user is not root
    if [ "${TARGET_HOME}" != "/root" ]; then
        mkdir -p /root
        if [ ! -e "/root/.${NAME}" ] && [ ! -L "/root/.${NAME}" ]; then
            ln -sf "${TARGET_DIR}" "/root/.${NAME}" 2>/dev/null || true
        fi
    fi
}

# Selective protection setup for ~/.pi (protects settings, only history/sessions writable)
setup_pi_protected() {
    local RO_DIR="${VAR_DIR}/ro-pi"
    local VOL_DIR="${VAR_DIR}/volume-pi"
    local TARGET_DIR="${TARGET_HOME}/.pi"

    echo "[personal-customizations] Configuring protected ~/.pi (read-only settings, writable history)..."

    # Enforce read-only on the host bind mount
    if [ -d "${RO_DIR}" ]; then
        mount -o remount,bind,ro "${RO_DIR}" 2>/dev/null || mount -o remount,ro "${RO_DIR}" 2>/dev/null || true
    fi

    # Temporarily ensure directories are writable for configuration
    chmod 755 "${TARGET_DIR}" "${TARGET_DIR}/agent" 2>/dev/null || true
    mkdir -p "${TARGET_DIR}/agent"
    mkdir -p "${VOL_DIR}/history" "${VOL_DIR}/sessions"

    # 1. Mirror top-level entries from host ro-pi
    if [ -d "${RO_DIR}" ]; then
        for item in "${RO_DIR}"/*; do
            [ -e "${item}" ] || continue
            local base="$(basename "${item}")"
            if [ "${base}" != "agent" ]; then
                ln -sfn "${item}" "${TARGET_DIR}/${base}"
            fi
        done

        # 2. Mirror agent entries (settings.json, bin, skills, extensions, etc.)
        if [ -d "${RO_DIR}/agent" ]; then
            for item in "${RO_DIR}/agent"/*; do
                [ -e "${item}" ] || continue
                local base="$(basename "${item}")"
                if [ "${base}" != "history" ] && [ "${base}" != "sessions" ]; then
                    if [ -e "${TARGET_DIR}/agent/${base}" ] && mountpoint -q "${TARGET_DIR}/agent/${base}" 2>/dev/null; then
                        continue
                    fi
                    ln -sfn "${item}" "${TARGET_DIR}/agent/${base}"
                fi
            done
        fi
    fi

    # Bind mount settings.json read-only so even root cannot write
    if [ -e "${TARGET_DIR}/agent/settings.json" ]; then
        if ! mountpoint -q "${TARGET_DIR}/agent/settings.json" 2>/dev/null; then
            mount --bind "${TARGET_DIR}/agent/settings.json" "${TARGET_DIR}/agent/settings.json" 2>/dev/null || true
            mount -o remount,bind,ro "${TARGET_DIR}/agent/settings.json" 2>/dev/null || true
        fi
    fi

    # 3. Setup persistent writable history
    if [ -d "${RO_DIR}/agent/history" ]; then
        cp -an "${RO_DIR}/agent/history"/. "${VOL_DIR}/history/" 2>/dev/null || true
    fi
    chown -R "${TARGET_UID}:${TARGET_GID}" "${VOL_DIR}/history" 2>/dev/null || true
    chmod -R 775 "${VOL_DIR}/history" 2>/dev/null || true
    ln -sfn "${VOL_DIR}/history" "${TARGET_DIR}/agent/history"

    # 4. Setup persistent writable sessions
    if [ -d "${RO_DIR}/agent/sessions" ]; then
        cp -an "${RO_DIR}/agent/sessions"/. "${VOL_DIR}/sessions/" 2>/dev/null || true
    fi
    chown -R "${TARGET_UID}:${TARGET_GID}" "${VOL_DIR}/sessions" 2>/dev/null || true
    chmod -R 775 "${VOL_DIR}/sessions" 2>/dev/null || true
    ln -sfn "${VOL_DIR}/sessions" "${TARGET_DIR}/agent/sessions"

    # 5. Lock down directory permissions on ~/.pi and ~/.pi/agent to prevent adding, deleting, or altering settings
    chown root:root "${TARGET_DIR}" "${TARGET_DIR}/agent" 2>/dev/null || true
    chmod 555 "${TARGET_DIR}" "${TARGET_DIR}/agent" 2>/dev/null || true

    # Mirror to /root if target user is not root
    if [ "${TARGET_HOME}" != "/root" ]; then
        mkdir -p /root
        if [ ! -e "/root/.pi" ] && [ ! -L "/root/.pi" ]; then
            ln -sf "${TARGET_DIR}" "/root/.pi" 2>/dev/null || true
        fi
    fi

    echo "[personal-customizations] Protected ~/.pi configured successfully."
}

# If running as non-root and sudo is available, elevate to perform mounts
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        sudo "$0" --setup-only || true
    fi
else
    # Running as root: perform mount setups
    if [ "${ENABLE_GEMINI}" = "true" ]; then
        setup_overlay "gemini"
    fi

    if [ "${ENABLE_PI}" = "true" ]; then
        if [ "${PI_PROTECT_SETTINGS}" = "true" ]; then
            setup_pi_protected
        else
            setup_overlay "pi"
        fi
    fi
fi

# Exit if internal helper invocation
if [ "${1:-}" = "--setup-only" ]; then
    exit 0
fi

# Hand over execution to container command
if [ $# -gt 0 ]; then
    exec "$@"
else
    exec /bin/sh
fi
