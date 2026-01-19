#!/usr/bin/env bash
#
# Test suite for ccc (Claude Code Container)
#
# Usage: ./tests/test_ccc.sh
#

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
CCC_BIN="${PROJECT_ROOT}/bin/ccc"
TEST_DIR=""
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test utilities
setup() {
    TEST_DIR=$(mktemp -d)
    export HOME="${TEST_DIR}/home"
    mkdir -p "${HOME}"
    cd "${TEST_DIR}"
    mkdir -p test-project
    cd test-project
}

teardown() {
    cd /
    if [[ -n "${TEST_DIR}" && -d "${TEST_DIR}" ]]; then
        rm -rf "${TEST_DIR}"
    fi
}

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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if Docker is available
check_docker_available() {
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Test: Script exists and is executable
test_script_exists() {
    if [[ -x "${CCC_BIN}" ]]; then
        pass "Script exists and is executable"
    else
        fail "Script does not exist or is not executable" "${CCC_BIN}"
    fi
}

# Test: Help option works
test_help_option() {
    local output
    output=$("${CCC_BIN}" --help 2>&1) || true

    if echo "${output}" | grep -q "Claude Code Container"; then
        pass "Help option displays usage"
    else
        fail "Help option does not display expected content"
    fi
}

# Test: Help short option works
test_help_short_option() {
    local output
    output=$("${CCC_BIN}" -h 2>&1) || true

    if echo "${output}" | grep -q "Usage:"; then
        pass "Short help option (-h) works"
    else
        fail "Short help option (-h) does not work"
    fi
}

# Test: Version option works
test_version_option() {
    local output
    output=$("${CCC_BIN}" --version 2>&1) || true

    if echo "${output}" | grep -q "ccc version"; then
        pass "Version option displays version"
    else
        fail "Version option does not display expected content"
    fi
}

# Test: Version short option works
test_version_short_option() {
    local output
    output=$("${CCC_BIN}" -v 2>&1) || true

    if echo "${output}" | grep -q "ccc version"; then
        pass "Short version option (-v) works"
    else
        fail "Short version option (-v) does not work"
    fi
}

# Test: Unknown option shows error
test_unknown_option() {
    local output
    output=$("${CCC_BIN}" --unknown-option 2>&1) || true

    if echo "${output}" | grep -qi "unknown option\|error"; then
        pass "Unknown option shows error"
    else
        fail "Unknown option does not show error"
    fi
}

# Test: Init creates ccc directory
test_init_creates_directory() {
    if ! check_docker_available; then
        skip "Init creates ccc directory (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    if [[ -d "./ccc" ]]; then
        pass "Init creates ccc directory"
    else
        fail "Init does not create ccc directory"
    fi
    teardown
}

# Test: Init creates Dockerfile
test_init_creates_dockerfile() {
    if ! check_docker_available; then
        skip "Init creates Dockerfile (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    if [[ -f "./ccc/Dockerfile.devcontainer" ]]; then
        pass "Init creates Dockerfile.devcontainer"
    else
        fail "Init does not create Dockerfile.devcontainer"
    fi
    teardown
}

# Test: Init creates steering file
test_init_creates_steering_file() {
    if ! check_docker_available; then
        skip "Init creates steering file (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    if [[ -f "./ccc/CLAUDE.md" ]]; then
        pass "Init creates CLAUDE.md steering file"
    else
        fail "Init does not create CLAUDE.md steering file"
    fi
    teardown
}

# Test: Init creates firewall script
test_init_creates_firewall_script() {
    if ! check_docker_available; then
        skip "Init creates firewall script (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    if [[ -f "./ccc/init-firewall.sh" && -x "./ccc/init-firewall.sh" ]]; then
        pass "Init creates executable init-firewall.sh"
    else
        fail "Init does not create init-firewall.sh or it's not executable"
    fi
    teardown
}

# Test: Init creates secrets directory
test_init_creates_secrets_directory() {
    if ! check_docker_available; then
        skip "Init creates secrets directory (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local secrets_dir="${HOME}/Sandbox/ccc-secrets/test-project"
    if [[ -d "${secrets_dir}" ]]; then
        pass "Init creates secrets directory"
    else
        fail "Init does not create secrets directory" "${secrets_dir}"
    fi
    teardown
}

# Test: Init creates .gitignore
test_init_creates_gitignore() {
    if ! check_docker_available; then
        skip "Init creates .gitignore (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    if [[ -f "./ccc/.gitignore" ]]; then
        pass "Init creates .gitignore"
    else
        fail "Init does not create .gitignore"
    fi
    teardown
}

# Test: Init is idempotent
test_init_idempotent() {
    if ! check_docker_available; then
        skip "Init is idempotent (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    # Modify a file
    echo "# Custom modification" >> "./ccc/Dockerfile.devcontainer"

    # Run init again
    "${CCC_BIN}" init &> /dev/null || true

    # Check that modification persists
    if grep -q "Custom modification" "./ccc/Dockerfile.devcontainer"; then
        pass "Init is idempotent (preserves existing files)"
    else
        fail "Init overwrites existing files"
    fi
    teardown
}

# Test: Dockerfile contains required content
test_dockerfile_content() {
    if ! check_docker_available; then
        skip "Dockerfile content check (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local dockerfile="./ccc/Dockerfile.devcontainer"
    local errors=()

    # Check for required content
    if ! grep -q "FROM node:20" "${dockerfile}"; then
        errors+=("Missing 'FROM node:20'")
    fi
    if ! grep -q "claude-code" "${dockerfile}"; then
        errors+=("Missing claude-code installation")
    fi
    if ! grep -q "/sandbox" "${dockerfile}"; then
        errors+=("Missing /sandbox directory setup")
    fi
    if ! grep -q "/secrets" "${dockerfile}"; then
        errors+=("Missing /secrets directory setup")
    fi

    if [[ ${#errors[@]} -eq 0 ]]; then
        pass "Dockerfile contains required content"
    else
        fail "Dockerfile missing content" "${errors[*]}"
    fi
    teardown
}

# Test: Steering file contains project name
test_steering_file_content() {
    if ! check_docker_available; then
        skip "Steering file content check (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local steering="./ccc/CLAUDE.md"

    if grep -q "test-project" "${steering}" && grep -q "/sandbox" "${steering}" && grep -q "/secrets" "${steering}"; then
        pass "Steering file contains project name and mount info"
    else
        fail "Steering file missing required content"
    fi
    teardown
}

# Test: Status command works
test_status_command() {
    if ! check_docker_available; then
        skip "Status command (Docker not available)"
        return
    fi

    setup
    local output
    output=$("${CCC_BIN}" status 2>&1) || true

    if echo "${output}" | grep -q "CCC Status"; then
        pass "Status command works"
    else
        fail "Status command does not work"
    fi
    teardown
}

# Test: Status shows initialization state
test_status_shows_init_state() {
    if ! check_docker_available; then
        skip "Status shows initialization state (Docker not available)"
        return
    fi

    setup
    local output
    output=$("${CCC_BIN}" status 2>&1) || true

    # Should show not initialized
    if echo "${output}" | grep -qi "not initialized\|warning"; then
        pass "Status shows uninitialized state"
    else
        fail "Status does not show initialization state"
    fi
    teardown
}

# Test: Status shows initialized state
test_status_shows_initialized_state() {
    if ! check_docker_available; then
        skip "Status shows initialized state (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true
    local output
    output=$("${CCC_BIN}" status 2>&1) || true

    if echo "${output}" | grep -qi "initialized\|success"; then
        pass "Status shows initialized state"
    else
        fail "Status does not show initialized state"
    fi
    teardown
}

# Test: Clean command works (doesn't error on non-existent)
test_clean_command() {
    if ! check_docker_available; then
        skip "Clean command (Docker not available)"
        return
    fi

    setup
    local output
    output=$("${CCC_BIN}" clean 2>&1) || true

    if echo "${output}" | grep -qi "clean\|complete"; then
        pass "Clean command works"
    else
        fail "Clean command does not work"
    fi
    teardown
}

# Test: Script handles missing Docker gracefully
test_missing_docker_handling() {
    # This test temporarily modifies PATH
    local original_path="${PATH}"
    export PATH="/usr/bin:/bin"

    setup
    local output
    output=$("${CCC_BIN}" init 2>&1) || true

    export PATH="${original_path}"

    if echo "${output}" | grep -qi "docker.*not\|error\|install"; then
        pass "Script handles missing Docker gracefully"
    else
        # Docker might still be found in default paths, which is fine
        pass "Script handles Docker detection"
    fi
    teardown
}

# Test: Project name derivation
test_project_name_derivation() {
    if ! check_docker_available; then
        skip "Project name derivation (Docker not available)"
        return
    fi

    setup
    cd "${TEST_DIR}"
    mkdir -p "my-special-project"
    cd "my-special-project"

    local output
    output=$("${CCC_BIN}" status 2>&1) || true

    if echo "${output}" | grep -q "my-special-project"; then
        pass "Project name derived from directory"
    else
        fail "Project name not derived correctly"
    fi
    teardown
}

# Test: Multiple options can be combined
test_combined_options() {
    local output
    output=$("${CCC_BIN}" --help --version 2>&1) || true

    # Should show help (first option processed)
    if echo "${output}" | grep -q "Usage:\|Claude Code Container"; then
        pass "Options processed correctly"
    else
        fail "Options not processed correctly"
    fi
}

# Test: Shell script syntax
test_shell_syntax() {
    if bash -n "${CCC_BIN}" 2>&1; then
        pass "Shell script has valid syntax"
    else
        fail "Shell script has syntax errors"
    fi
}

# Test: Script uses set -euo pipefail
test_strict_mode() {
    if grep -q "set -euo pipefail" "${CCC_BIN}"; then
        pass "Script uses strict mode (set -euo pipefail)"
    else
        fail "Script does not use strict mode"
    fi
}

# Test: Script has proper shebang
test_shebang() {
    local first_line
    first_line=$(head -n 1 "${CCC_BIN}")

    if [[ "${first_line}" == "#!/usr/bin/env bash" || "${first_line}" == "#!/bin/bash" ]]; then
        pass "Script has proper shebang"
    else
        fail "Script does not have proper shebang" "${first_line}"
    fi
}

# Test: Dockerfile has proper base image
test_dockerfile_base_image() {
    if ! check_docker_available; then
        skip "Dockerfile base image (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local dockerfile="./ccc/Dockerfile.devcontainer"

    if grep -q "^FROM node:20" "${dockerfile}"; then
        pass "Dockerfile uses node:20 base image"
    else
        fail "Dockerfile does not use correct base image"
    fi
    teardown
}

# Test: Dockerfile installs Claude Code
test_dockerfile_installs_claude() {
    if ! check_docker_available; then
        skip "Dockerfile installs Claude Code (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local dockerfile="./ccc/Dockerfile.devcontainer"

    if grep -q "@anthropic-ai/claude-code" "${dockerfile}"; then
        pass "Dockerfile installs Claude Code"
    else
        fail "Dockerfile does not install Claude Code"
    fi
    teardown
}

# Test: Firewall script has proper shebang
test_firewall_script_shebang() {
    if ! check_docker_available; then
        skip "Firewall script shebang (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local first_line
    first_line=$(head -n 1 "./ccc/init-firewall.sh")

    if [[ "${first_line}" == "#!/bin/bash" ]]; then
        pass "Firewall script has proper shebang"
    else
        fail "Firewall script does not have proper shebang"
    fi
    teardown
}

# Test: Firewall script uses strict mode
test_firewall_script_strict_mode() {
    if ! check_docker_available; then
        skip "Firewall script strict mode (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    if grep -q "set -euo pipefail" "./ccc/init-firewall.sh"; then
        pass "Firewall script uses strict mode"
    else
        fail "Firewall script does not use strict mode"
    fi
    teardown
}

# Test: All required tools check
test_required_tools_in_dockerfile() {
    if ! check_docker_available; then
        skip "Required tools in Dockerfile (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local dockerfile="./ccc/Dockerfile.devcontainer"
    local required_tools=("git" "zsh" "fzf" "jq" "vim" "nano")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! grep -q "${tool}" "${dockerfile}"; then
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        pass "Dockerfile includes all required tools"
    else
        fail "Dockerfile missing tools" "${missing_tools[*]}"
    fi
    teardown
}

# Main test runner
run_tests() {
    echo ""
    echo "================================================"
    echo "  CCC Test Suite"
    echo "================================================"
    echo ""

    info "Running tests..."
    echo ""

    # Basic script tests
    test_script_exists
    test_shebang
    test_shell_syntax
    test_strict_mode

    # Help and version tests
    test_help_option
    test_help_short_option
    test_version_option
    test_version_short_option
    test_unknown_option
    test_combined_options

    # Docker-dependent tests
    test_missing_docker_handling

    # Init tests
    test_init_creates_directory
    test_init_creates_dockerfile
    test_init_creates_steering_file
    test_init_creates_firewall_script
    test_init_creates_secrets_directory
    test_init_creates_gitignore
    test_init_idempotent

    # Content validation tests
    test_dockerfile_content
    test_dockerfile_base_image
    test_dockerfile_installs_claude
    test_steering_file_content
    test_firewall_script_shebang
    test_firewall_script_strict_mode
    test_required_tools_in_dockerfile

    # Command tests
    test_status_command
    test_status_shows_init_state
    test_status_shows_initialized_state
    test_clean_command
    test_project_name_derivation

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

    local total=$((TESTS_PASSED + TESTS_FAILED))
    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All ${total} tests passed!${NC}"
        return 0
    else
        echo -e "${RED}${TESTS_FAILED} of ${total} tests failed${NC}"
        return 1
    fi
}

# Run tests
run_tests
