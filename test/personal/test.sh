#!/usr/bin/env bash
set -e

# Support dev-container-features-test-lib if present
if command -v check >/dev/null 2>&1; then
    echo "Using dev-container-features-test-lib..."
else
    # Minimal fallback test harness
    check() {
        local label="$1"
        shift
        echo -n "Testing: ${label}... "
        if "$@"; then
            echo "PASSED"
        else
            echo "FAILED"
            exit 1
        fi
    }
    reportResults() {
        echo "All tests passed successfully!"
    }
fi

echo "=========================================="
echo "Testing Personal Customizations Feature"
echo "=========================================="

# 1. Feature installation assertions
check "devcontainer-personal share directory exists" test -d /usr/local/share/devcontainer-personal
check "devcontainer-personal entrypoint exists and is executable" test -x /usr/local/share/devcontainer-personal/entrypoint.sh
check "config.env exists" test -f /usr/local/share/devcontainer-personal/config.env
check "profile.d environment script exists" test -f /etc/profile.d/devcontainer-personal.sh
check "staging directory /var/lib/devcontainer-personal exists" test -d /var/lib/devcontainer-personal

# 2. Verify entrypoint ran during container boot or runs in setup mode
if [ ! -d "${TARGET_HOME}/.pi/agent/history" ]; then
    if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        sudo /usr/local/share/devcontainer-personal/entrypoint.sh --setup-only
    else
        /usr/local/share/devcontainer-personal/entrypoint.sh --setup-only
    fi
fi

# 4. Target home verification
REMOTE_USER_HOME=$(grep '^REMOTE_USER_HOME=' /usr/local/share/devcontainer-personal/config.env | cut -d= -f2 | tr -d '"')
TARGET_HOME="${REMOTE_USER_HOME:-$HOME}"

check "user ~/.gemini exists" test -d "${TARGET_HOME}/.gemini"
check "user ~/.pi exists" test -d "${TARGET_HOME}/.pi"

# 5. Verify Gemini full writeability
GEMINI_TEST_FILE="${TARGET_HOME}/.gemini/test_gemini_write.txt"
touch "${GEMINI_TEST_FILE}"
echo "sample-gemini-cache" > "${GEMINI_TEST_FILE}"
check "writes to ~/.gemini succeed" test -f "${GEMINI_TEST_FILE}"
rm -f "${GEMINI_TEST_FILE}"

# 6. Verify Pi history and sessions writeability
check "user ~/.pi/agent/history exists" test -d "${TARGET_HOME}/.pi/agent/history"
PI_HIST_FILE="${TARGET_HOME}/.pi/agent/history/test_session.jsonl"
touch "${PI_HIST_FILE}"
echo '{"session": "test"}' > "${PI_HIST_FILE}"
check "writes to ~/.pi/agent/history succeed" test -f "${PI_HIST_FILE}"
check "history file persisted in named volume" test -f "/var/lib/devcontainer-personal/volume-pi/history/test_session.jsonl"
rm -f "${PI_HIST_FILE}"

# 7. Verify Pi settings protection (read allowed, write/delete blocked)
check "reading pi settings succeeds" test -f "${TARGET_HOME}/.pi/agent/settings.json"
check "pi settings contains host data" grep -q "model" "${TARGET_HOME}/.pi/agent/settings.json"

# Writing to settings or creating files in agent dir should fail for non-root users
if [ "$(id -u)" -ne 0 ]; then
    check "writing to pi settings is blocked" sh -c "! echo hack > '${TARGET_HOME}/.pi/agent/settings.json' 2>/dev/null"
    check "creating file in agent directory is blocked" sh -c "! touch '${TARGET_HOME}/.pi/agent/new_setting.json' 2>/dev/null"
fi

# 8. Validate that the antigravity CLI successfully runs a simple test prompt
AGY_BIN=""
if [ -x "${TARGET_HOME}/.gemini/bin/agy" ]; then
    AGY_BIN="${TARGET_HOME}/.gemini/bin/agy"
elif command -v agy >/dev/null 2>&1; then
    AGY_BIN="agy"
fi

if [ -n "${AGY_BIN}" ]; then
    echo "Testing Antigravity CLI (${AGY_BIN}) headless execution..."
    AGY_OUTPUT=$("${AGY_BIN}" -p "Respond with exactly and only the string 'Hello, World!' without any markdown or quotes." 2>&1 || true)
    echo "Antigravity CLI output: ${AGY_OUTPUT}"
    check "antigravity CLI emitted 'Hello, World!'" sh -c "echo \"${AGY_OUTPUT}\" | grep -q 'Hello, World!'"
else
    echo "Notice: agy binary not found in container ~/.gemini/bin/agy or PATH, skipping live prompt test."
fi

reportResults


