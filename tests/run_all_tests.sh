#!/usr/bin/env bash
#
# Run all ccc tests
#
# Usage: ./tests/run_all_tests.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
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
