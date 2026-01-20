#!/usr/bin/env bash
#
# Run all ccc tests
#
# Usage: ./tests/run_all_tests.sh [--all]
#
# Options:
#   --all    Run all tests including slow persistence tests (which build Docker images)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
RUN_ALL=false
for arg in "$@"; do
    case "$arg" in
        --all)
            RUN_ALL=true
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           CCC - Claude Code Container Test Suite           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

OVERALL_RESULT=0

# Run main tests
echo -e "${BLUE}Running main test suite...${NC}"
echo ""
if "${SCRIPT_DIR}/test_ccc.sh"; then
    echo ""
    echo -e "${GREEN}Main tests completed successfully${NC}"
else
    echo ""
    echo -e "${RED}Main tests had failures${NC}"
    OVERALL_RESULT=1
fi

echo ""
echo "────────────────────────────────────────────────────────────"
echo ""

# Run cross-shell tests
echo -e "${BLUE}Running cross-shell compatibility tests...${NC}"
echo ""
if "${SCRIPT_DIR}/test_cross_shell.sh"; then
    echo ""
    echo -e "${GREEN}Cross-shell tests completed successfully${NC}"
else
    echo ""
    echo -e "${RED}Cross-shell tests had failures${NC}"
    OVERALL_RESULT=1
fi

# Optionally run persistence tests (slow - builds Docker images)
if [[ "${RUN_ALL}" == "true" ]]; then
    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo ""

    echo -e "${BLUE}Running persistence tests (slow - builds Docker images)...${NC}"
    echo ""
    if "${SCRIPT_DIR}/test_persistence.sh"; then
        echo ""
        echo -e "${GREEN}Persistence tests completed successfully${NC}"
    else
        echo ""
        echo -e "${RED}Persistence tests had failures${NC}"
        OVERALL_RESULT=1
    fi
else
    echo ""
    echo -e "${YELLOW}Skipping persistence tests (use --all to include them)${NC}"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

if [[ ${OVERALL_RESULT} -eq 0 ]]; then
    echo -e "${GREEN}✓ All test suites passed!${NC}"
else
    echo -e "${RED}✗ Some test suites had failures${NC}"
fi

echo ""
exit ${OVERALL_RESULT}
