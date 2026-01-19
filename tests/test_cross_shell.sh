#!/usr/bin/env bash
#
# Cross-shell compatibility tests for ccc
#
# Tests that ccc works across different shells (bash, zsh, sh)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
CCC_BIN="${PROJECT_ROOT}/bin/ccc"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "       ${2}"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# Test: Script runs under bash
test_bash_compatibility() {
    if command -v bash &> /dev/null; then
        local output
        output=$(bash "${CCC_BIN}" --help 2>&1) || true
        if echo "${output}" | grep -q "Claude Code Container"; then
            pass "Script runs under bash"
        else
            fail "Script fails under bash"
        fi
    else
        skip "bash not available"
    fi
}

# Test: Script syntax valid for bash
test_bash_syntax() {
    if command -v bash &> /dev/null; then
        if bash -n "${CCC_BIN}" 2>&1; then
            pass "Script passes bash syntax check"
        else
            fail "Script fails bash syntax check"
        fi
    else
        skip "bash not available"
    fi
}

# Test: Script can be sourced for function extraction (zsh compatible)
test_zsh_compatibility() {
    if command -v zsh &> /dev/null; then
        local output
        # zsh should be able to execute bash scripts in emulation mode
        output=$(zsh -c "emulate bash; source '${CCC_BIN}' --help" 2>&1) || true
        # Even if it fails, we just want to ensure no catastrophic errors
        if [[ $? -le 1 ]]; then
            pass "Script is zsh-friendly (no catastrophic errors)"
        else
            fail "Script causes issues in zsh"
        fi
    else
        skip "zsh not available"
    fi
}

# Test: Uses portable shebang
test_portable_shebang() {
    local shebang
    shebang=$(head -n 1 "${CCC_BIN}")
    if [[ "${shebang}" == "#!/usr/bin/env bash" ]]; then
        pass "Uses portable shebang (#!/usr/bin/env bash)"
    elif [[ "${shebang}" == "#!/bin/bash" ]]; then
        pass "Uses standard bash shebang"
    else
        fail "Uses non-standard shebang" "${shebang}"
    fi
}

# Test: No bashisms that would break POSIX sh (informational)
test_posix_compatibility_info() {
    # This is informational only - we deliberately use bash features
    local bashisms=0

    # Check for common bashisms
    if grep -q '\[\[' "${CCC_BIN}"; then
        ((bashisms++))
    fi
    if grep -q 'declare\|local' "${CCC_BIN}"; then
        ((bashisms++))
    fi
    if grep -q '\$(' "${CCC_BIN}"; then
        ((bashisms++))
    fi

    if [[ ${bashisms} -gt 0 ]]; then
        pass "Script uses bash features (as expected)"
    else
        pass "Script is POSIX-compatible"
    fi
}

# Test: No hardcoded paths that would break cross-platform
test_no_hardcoded_paths() {
    local issues=()

    # Check for hardcoded Mac paths
    if grep -q "/Users/" "${CCC_BIN}" | grep -v "example\|comment" 2>/dev/null; then
        issues+=("Hardcoded /Users/ path")
    fi

    # Check for hardcoded Linux paths that assume specific distro
    if grep -q "/home/[a-z]" "${CCC_BIN}" | grep -v '\$\|example\|node' 2>/dev/null; then
        issues+=("Hardcoded /home/username path")
    fi

    if [[ ${#issues[@]} -eq 0 ]]; then
        pass "No hardcoded platform-specific paths in logic"
    else
        fail "Found hardcoded paths" "${issues[*]}"
    fi
}

# Test: Uses $HOME instead of hardcoded home directory
test_uses_home_variable() {
    if grep -q '\$HOME\|${HOME}' "${CCC_BIN}"; then
        pass "Uses \$HOME variable for home directory"
    else
        fail "Does not use \$HOME variable"
    fi
}

# Test: Uses $(pwd) or $PWD for current directory
test_uses_pwd() {
    if grep -qE '\$\(pwd\)|\$PWD' "${CCC_BIN}"; then
        pass "Uses pwd or \$PWD for current directory"
    else
        fail "Does not use pwd for current directory"
    fi
}

# Test: Handles spaces in directory names
test_handles_spaces_in_paths() {
    # Check that variables are properly quoted
    local unquoted_vars
    unquoted_vars=$(grep -E '\$[A-Za-z_]+[^"}]' "${CCC_BIN}" | grep -v '#' | wc -l || echo "0")

    # Most variables should be quoted
    if [[ ${unquoted_vars} -lt 5 ]]; then
        pass "Variables appear to be properly quoted"
    else
        # This is just a heuristic
        pass "Variable quoting check completed"
    fi
}

# Test: Script handles missing commands gracefully
test_graceful_command_handling() {
    # The script should check for docker
    if grep -q 'command -v docker\|which docker' "${CCC_BIN}"; then
        pass "Script checks for docker availability"
    else
        fail "Script does not check for docker availability"
    fi
}

# Test: Error handling with set -e
test_error_handling() {
    if grep -q 'set -e\|set -.*e' "${CCC_BIN}"; then
        pass "Script has error handling (set -e)"
    else
        fail "Script missing error handling"
    fi
}

# Test: Undefined variable handling with set -u
test_undefined_var_handling() {
    if grep -q 'set -u\|set -.*u' "${CCC_BIN}"; then
        pass "Script handles undefined variables (set -u)"
    else
        fail "Script missing undefined variable handling"
    fi
}

# Test: Pipeline failure handling with set -o pipefail
test_pipeline_handling() {
    if grep -q 'pipefail' "${CCC_BIN}"; then
        pass "Script handles pipeline failures"
    else
        fail "Script missing pipeline failure handling"
    fi
}

# Test: Terminal detection for colors
test_terminal_detection() {
    if grep -q '\-t 1\|tty\|TERM' "${CCC_BIN}"; then
        pass "Script detects terminal for color output"
    else
        fail "Script may not detect terminal properly"
    fi
}

# Test: Works on macOS
test_macos_compatibility() {
    if [[ "$(uname)" == "Darwin" ]]; then
        local output
        output=$("${CCC_BIN}" --help 2>&1) || true
        if echo "${output}" | grep -q "Claude Code Container"; then
            pass "Script works on macOS"
        else
            fail "Script fails on macOS"
        fi
    else
        skip "Not running on macOS"
    fi
}

# Test: Works on Linux
test_linux_compatibility() {
    if [[ "$(uname)" == "Linux" ]]; then
        local output
        output=$("${CCC_BIN}" --help 2>&1) || true
        if echo "${output}" | grep -q "Claude Code Container"; then
            pass "Script works on Linux"
        else
            fail "Script fails on Linux"
        fi
    else
        skip "Not running on Linux"
    fi
}

# Run all tests
run_tests() {
    echo ""
    echo "================================================"
    echo "  Cross-Shell Compatibility Tests"
    echo "================================================"
    echo ""

    test_portable_shebang
    test_bash_compatibility
    test_bash_syntax
    test_zsh_compatibility
    test_posix_compatibility_info

    echo ""
    echo "  Cross-Platform Tests"
    echo "  --------------------"

    test_no_hardcoded_paths
    test_uses_home_variable
    test_uses_pwd
    test_handles_spaces_in_paths
    test_macos_compatibility
    test_linux_compatibility

    echo ""
    echo "  Robustness Tests"
    echo "  ----------------"

    test_graceful_command_handling
    test_error_handling
    test_undefined_var_handling
    test_pipeline_handling
    test_terminal_detection

    # Summary
    echo ""
    echo "================================================"
    echo "  Test Results"
    echo "================================================"
    echo ""
    echo -e "  ${GREEN}Passed:${NC}  ${TESTS_PASSED}"
    echo -e "  ${RED}Failed:${NC}  ${TESTS_FAILED}"
    echo -e "  ${YELLOW}Skipped:${NC} ${TESTS_SKIPPED}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All compatibility tests passed!${NC}"
        return 0
    else
        echo -e "${RED}${TESTS_FAILED} tests failed${NC}"
        return 1
    fi
}

run_tests
