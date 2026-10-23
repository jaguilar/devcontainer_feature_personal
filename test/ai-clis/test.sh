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
echo "Testing AI CLIs Feature"
echo "=========================================="

# 1. Verify Node.js and npm are present
check "node is installed" command -v node
check "npm is installed" command -v npm

# 2. Verify all AI CLIs are installed and on PATH
check "gemini CLI is installed" command -v gemini
check "claude CLI is installed" command -v claude
check "opencode CLI is installed" command -v opencode
check "pi CLI is installed" command -v pi
check "pi.dev alias is installed" command -v pi.dev

# 3. Verify CLI execution (version or help check)
check "gemini CLI is executable" sh -c "gemini --version || gemini --help"
check "claude CLI is executable" sh -c "claude --version || claude --help"
check "opencode CLI is executable" sh -c "opencode --version || opencode --help"
check "pi CLI is executable" sh -c "pi --version || pi --help"

reportResults

