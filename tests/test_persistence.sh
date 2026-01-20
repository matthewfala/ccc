#!/usr/bin/env bash
#
# Test suite for ccc configuration persistence
#
# This test verifies that configuration written inside the container
# persists across container restarts.
#
# Usage: ./tests/test_persistence.sh
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

# Get the image name for current test project
get_image_name() {
    echo "ccc-devcontainer-test-project"
}

# Test: Init creates entrypoint.sh
test_init_creates_entrypoint() {
    if ! check_docker_available; then
        skip "Init creates entrypoint.sh (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    if [[ -f "./ccc/entrypoint.sh" && -x "./ccc/entrypoint.sh" ]]; then
        pass "Init creates executable entrypoint.sh"
    else
        fail "Init does not create entrypoint.sh or it's not executable"
    fi
    teardown
}

# Test: Entrypoint contains permission fix commands
test_entrypoint_fixes_permissions() {
    if ! check_docker_available; then
        skip "Entrypoint fixes permissions (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local entrypoint="./ccc/entrypoint.sh"

    if grep -q "chown.*node:node" "${entrypoint}" && grep -q "/home/node/.claude" "${entrypoint}"; then
        pass "Entrypoint contains permission fix commands"
    else
        fail "Entrypoint missing permission fix commands"
    fi
    teardown
}

# Test: Dockerfile uses entrypoint
test_dockerfile_uses_entrypoint() {
    if ! check_docker_available; then
        skip "Dockerfile uses entrypoint (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local dockerfile="./ccc/Dockerfile.devcontainer"

    if grep -q "ENTRYPOINT.*entrypoint.sh" "${dockerfile}"; then
        pass "Dockerfile uses entrypoint.sh"
    else
        fail "Dockerfile does not use entrypoint.sh"
    fi
    teardown
}

# Test: Dockerfile installs gosu
test_dockerfile_installs_gosu() {
    if ! check_docker_available; then
        skip "Dockerfile installs gosu (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    local dockerfile="./ccc/Dockerfile.devcontainer"

    if grep -q "gosu" "${dockerfile}"; then
        pass "Dockerfile installs gosu"
    else
        fail "Dockerfile does not install gosu"
    fi
    teardown
}

# Test: Config directories are created on host
test_config_directories_created() {
    if ! check_docker_available; then
        skip "Config directories created (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true

    # Simulate what run_container does
    mkdir -p "${HOME}/.ccc-claude-config"
    mkdir -p "${HOME}/.ccc-nodejs-config"
    mkdir -p "${HOME}/.ccc-xdg-config"
    mkdir -p "${HOME}/.ccc-xdg-data"

    local all_exist=true
    [[ -d "${HOME}/.ccc-claude-config" ]] || all_exist=false
    [[ -d "${HOME}/.ccc-nodejs-config" ]] || all_exist=false
    [[ -d "${HOME}/.ccc-xdg-config" ]] || all_exist=false
    [[ -d "${HOME}/.ccc-xdg-data" ]] || all_exist=false

    if [[ "${all_exist}" == "true" ]]; then
        pass "All config directories can be created"
    else
        fail "Some config directories not created"
    fi
    teardown
}

# Test: Build image successfully
test_build_image() {
    if ! check_docker_available; then
        skip "Build image (Docker not available)"
        return
    fi

    setup
    info "Building test container (this may take a few minutes)..."

    if "${CCC_BIN}" build &> /dev/null; then
        pass "Container image builds successfully"
    else
        fail "Container image build failed"
    fi

    # Clean up image
    docker rmi "$(get_image_name)" &> /dev/null || true
    teardown
}

# Test: Configuration persists across container runs
test_config_persistence() {
    if ! check_docker_available; then
        skip "Configuration persistence (Docker not available)"
        return
    fi

    setup
    info "Testing configuration persistence..."

    # Initialize and build
    "${CCC_BIN}" init &> /dev/null || true
    "${CCC_BIN}" build &> /dev/null || true

    local image_name
    image_name=$(get_image_name)
    local config_dir="${HOME}/.ccc-claude-config"
    local xdg_config_dir="${HOME}/.ccc-xdg-config"

    mkdir -p "${config_dir}"
    mkdir -p "${xdg_config_dir}"

    # Run container and write a test file to the config directory
    info "Running first container to write test config..."
    docker run --rm \
        -v "${config_dir}:/home/node/.claude" \
        -v "${xdg_config_dir}:/home/node/.config" \
        "${image_name}" \
        /bin/bash -c "echo 'test-config-data' > /home/node/.claude/test-config && echo 'xdg-test-data' > /home/node/.config/test-xdg"

    # Check if files exist on host
    if [[ -f "${config_dir}/test-config" ]] && [[ -f "${xdg_config_dir}/test-xdg" ]]; then
        info "Config files written to host successfully"
    else
        fail "Config files not written to host"
        docker rmi "${image_name}" &> /dev/null || true
        teardown
        return
    fi

    # Run a second container and verify the files are readable
    info "Running second container to verify config persists..."
    local result
    result=$(docker run --rm \
        -v "${config_dir}:/home/node/.claude" \
        -v "${xdg_config_dir}:/home/node/.config" \
        "${image_name}" \
        /bin/bash -c "cat /home/node/.claude/test-config && cat /home/node/.config/test-xdg" 2>&1)

    if echo "${result}" | grep -q "test-config-data" && echo "${result}" | grep -q "xdg-test-data"; then
        pass "Configuration persists across container runs"
    else
        fail "Configuration does not persist" "Got: ${result}"
    fi

    # Clean up
    docker rmi "${image_name}" &> /dev/null || true
    teardown
}

# Test: Entrypoint runs as root and switches to node
test_entrypoint_user_switch() {
    if ! check_docker_available; then
        skip "Entrypoint user switch (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true
    "${CCC_BIN}" build &> /dev/null || true

    local image_name
    image_name=$(get_image_name)

    info "Testing entrypoint user switching..."

    # The entrypoint should start as root and switch to node
    local whoami_result
    whoami_result=$(docker run --rm "${image_name}" whoami 2>&1)

    if echo "${whoami_result}" | grep -q "node"; then
        pass "Entrypoint correctly switches to node user"
    else
        fail "Entrypoint does not switch to node user" "Got: ${whoami_result}"
    fi

    # Clean up
    docker rmi "${image_name}" &> /dev/null || true
    teardown
}

# Test: Config directories have correct ownership in container
test_config_ownership() {
    if ! check_docker_available; then
        skip "Config ownership (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true
    "${CCC_BIN}" build &> /dev/null || true

    local image_name
    image_name=$(get_image_name)
    local config_dir="${HOME}/.ccc-claude-config"

    mkdir -p "${config_dir}"

    info "Testing config directory ownership..."

    # Check ownership inside container
    local owner_result
    owner_result=$(docker run --rm \
        -v "${config_dir}:/home/node/.claude" \
        "${image_name}" \
        /bin/bash -c "ls -la /home/node/.claude && stat -c '%U:%G' /home/node/.claude" 2>&1)

    if echo "${owner_result}" | grep -q "node:node"; then
        pass "Config directories have correct ownership (node:node)"
    else
        fail "Config directories have wrong ownership" "Got: ${owner_result}"
    fi

    # Clean up
    docker rmi "${image_name}" &> /dev/null || true
    teardown
}

# Test: Node user can write to config directories
test_node_can_write_config() {
    if ! check_docker_available; then
        skip "Node can write config (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true
    "${CCC_BIN}" build &> /dev/null || true

    local image_name
    image_name=$(get_image_name)
    local config_dir="${HOME}/.ccc-claude-config"
    local xdg_config="${HOME}/.ccc-xdg-config"
    local xdg_data="${HOME}/.ccc-xdg-data"

    mkdir -p "${config_dir}" "${xdg_config}" "${xdg_data}"

    info "Testing that node user can write to all config directories..."

    # Try to write as node user
    local write_result
    write_result=$(docker run --rm \
        -v "${config_dir}:/home/node/.claude" \
        -v "${xdg_config}:/home/node/.config" \
        -v "${xdg_data}:/home/node/.local/share" \
        "${image_name}" \
        /bin/bash -c "
            touch /home/node/.claude/write-test && \
            touch /home/node/.config/write-test && \
            touch /home/node/.local/share/write-test && \
            echo 'write-success'
        " 2>&1)

    if echo "${write_result}" | grep -q "write-success"; then
        pass "Node user can write to all config directories"
    else
        fail "Node user cannot write to config directories" "Got: ${write_result}"
    fi

    # Clean up
    docker rmi "${image_name}" &> /dev/null || true
    teardown
}

# Test: Settings.json is auto-created with bypass permissions
test_settings_json_created() {
    if ! check_docker_available; then
        skip "Settings.json auto-creation (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true
    "${CCC_BIN}" build &> /dev/null || true

    local image_name
    image_name=$(get_image_name)
    local config_dir="${HOME}/.ccc-claude-config"

    # Use a fresh config directory
    rm -rf "${config_dir}"
    mkdir -p "${config_dir}"

    info "Testing that settings.json is auto-created..."

    # Run container to trigger settings.json creation
    local result
    result=$(docker run --rm \
        -v "${config_dir}:/home/node/.claude" \
        "${image_name}" \
        /bin/bash -c "cat /home/node/.claude/settings.json" 2>&1)

    if echo "${result}" | grep -q "bypassPermissions"; then
        pass "Settings.json is auto-created with bypassPermissions"
    else
        fail "Settings.json not created or missing bypassPermissions" "Got: ${result}"
    fi

    # Clean up
    docker rmi "${image_name}" &> /dev/null || true
    teardown
}

# Test: Settings.json persists across container restarts
test_settings_persistence() {
    if ! check_docker_available; then
        skip "Settings persistence (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true
    "${CCC_BIN}" build &> /dev/null || true

    local image_name
    image_name=$(get_image_name)
    local config_dir="${HOME}/.ccc-claude-config"

    # Use a fresh config directory
    rm -rf "${config_dir}"
    mkdir -p "${config_dir}"

    info "Testing settings.json persistence..."

    # Run first container to create settings
    docker run --rm \
        -v "${config_dir}:/home/node/.claude" \
        "${image_name}" \
        /bin/bash -c "cat /home/node/.claude/settings.json" &> /dev/null

    # Verify settings exist on host
    if [[ -f "${config_dir}/settings.json" ]]; then
        info "Settings.json created on host"
    else
        fail "Settings.json not found on host after first container"
        docker rmi "${image_name}" &> /dev/null || true
        teardown
        return
    fi

    # Run second container to verify settings persist
    local result
    result=$(docker run --rm \
        -v "${config_dir}:/home/node/.claude" \
        "${image_name}" \
        /bin/bash -c "cat /home/node/.claude/settings.json" 2>&1)

    if echo "${result}" | grep -q "bypassPermissions"; then
        pass "Settings.json persists across container restarts"
    else
        fail "Settings.json not readable in second container" "Got: ${result}"
    fi

    # Clean up
    docker rmi "${image_name}" &> /dev/null || true
    teardown
}

# Test: .claude.json (theme/preferences) is auto-created
test_claude_json_created() {
    if ! check_docker_available; then
        skip ".claude.json auto-creation (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true
    "${CCC_BIN}" build &> /dev/null || true

    local image_name
    image_name=$(get_image_name)
    local claude_json="${HOME}/.ccc-claude.json"

    # Use a fresh file
    rm -f "${claude_json}"
    echo '{}' > "${claude_json}"

    info "Testing that .claude.json is auto-created with theme..."

    # Run container to trigger .claude.json creation
    local result
    result=$(docker run --rm \
        -v "${claude_json}:/home/node/.claude.json" \
        "${image_name}" \
        /bin/bash -c "cat /home/node/.claude.json" 2>&1)

    if echo "${result}" | grep -q "hasCompletedOnboarding"; then
        pass ".claude.json is auto-created with onboarding flag"
    else
        fail ".claude.json not created or missing onboarding flag" "Got: ${result}"
    fi

    # Clean up
    docker rmi "${image_name}" &> /dev/null || true
    teardown
}

# Test: .claude.json persists theme across container restarts
test_claude_json_persistence() {
    if ! check_docker_available; then
        skip ".claude.json persistence (Docker not available)"
        return
    fi

    setup
    "${CCC_BIN}" init &> /dev/null || true
    "${CCC_BIN}" build &> /dev/null || true

    local image_name
    image_name=$(get_image_name)
    local claude_json="${HOME}/.ccc-claude.json"

    # Use a fresh file
    rm -f "${claude_json}"
    echo '{}' > "${claude_json}"

    info "Testing .claude.json persistence..."

    # Run first container to create .claude.json
    docker run --rm \
        -v "${claude_json}:/home/node/.claude.json" \
        "${image_name}" \
        /bin/bash -c "cat /home/node/.claude.json" &> /dev/null

    # Verify file exists on host with content
    if [[ -f "${claude_json}" ]] && grep -q "hasCompletedOnboarding" "${claude_json}"; then
        info ".claude.json created on host with onboarding flag"
    else
        fail ".claude.json not found or missing content on host"
        docker rmi "${image_name}" &> /dev/null || true
        teardown
        return
    fi

    # Run second container to verify .claude.json persists
    local result
    result=$(docker run --rm \
        -v "${claude_json}:/home/node/.claude.json" \
        "${image_name}" \
        /bin/bash -c "cat /home/node/.claude.json" 2>&1)

    if echo "${result}" | grep -q "hasCompletedOnboarding"; then
        pass ".claude.json persists across container restarts"
    else
        fail ".claude.json not readable in second container" "Got: ${result}"
    fi

    # Clean up
    docker rmi "${image_name}" &> /dev/null || true
    teardown
}

# Main test runner
run_tests() {
    echo ""
    echo "================================================"
    echo "  CCC Persistence Test Suite"
    echo "================================================"
    echo ""

    info "Running persistence tests..."
    echo ""

    # Basic file creation tests
    test_init_creates_entrypoint
    test_entrypoint_fixes_permissions
    test_dockerfile_uses_entrypoint
    test_dockerfile_installs_gosu
    test_config_directories_created

    # Container tests (slower)
    echo ""
    info "Running container integration tests (this may take a while)..."
    echo ""

    test_build_image
    test_entrypoint_user_switch
    test_config_ownership
    test_node_can_write_config
    test_settings_json_created
    test_settings_persistence
    test_claude_json_created
    test_claude_json_persistence
    test_config_persistence

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
