#!/usr/bin/env bash
# Test: Runtime Superpowers Agent Availability
# Verifies that OpenCode loads the dedicated superpowers agent and its runtime skill permissions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Test: Runtime Superpowers Agent Availability ==="

# Source setup to create isolated environment
source "$SCRIPT_DIR/setup.sh"

# Trap to cleanup on exit
trap cleanup_test_env EXIT

# Check if opencode is available
if ! command -v opencode &>/dev/null; then
	echo "  [SKIP] OpenCode not installed - skipping integration tests"
	echo "  To run these tests, install OpenCode: https://opencode.ai"
	exit 0
fi

echo "Test 1: Listing agents from OpenCode runtime..."
output=$(timeout 60s opencode agent list 2>&1) || {
	exit_code=$?
	if [ $exit_code -eq 124 ]; then
		echo "  [FAIL] OpenCode timed out after 60s"
		exit 1
	fi
	echo "  [WARN] OpenCode returned non-zero exit code: $exit_code"
}

if echo "$output" | grep -Fq 'superpowers (subagent)'; then
	echo "  [PASS] OpenCode exposes the superpowers subagent"
else
	echo "  [FAIL] OpenCode did not list the superpowers subagent"
	echo "  Output was:"
	echo "$output"
	exit 1
fi

echo ""
echo "Test 2: Checking runtime permission entries for superpowers..."

superpowers_block=$(printf '%s\n' "$output" | awk '/^superpowers \(subagent\)/{flag=1; print; next} /^[a-z].* \((primary|subagent)\)$/{if(flag){exit}} flag {print}')

if printf '%s\n' "$superpowers_block" | grep -A2 '"pattern": "using-superpowers"' | grep -q '"action": "allow"'; then
	echo "  [PASS] Runtime permissions include using-superpowers allow"
else
	echo "  [FAIL] Runtime permissions do not include using-superpowers allow"
	exit 1
fi

if printf '%s\n' "$superpowers_block" | grep -A2 '"pattern": "brainstorming"' | grep -q '"action": "allow"'; then
	echo "  [PASS] Runtime permissions include brainstorming allow"
else
	echo "  [FAIL] Runtime permissions do not include brainstorming allow"
	exit 1
fi

echo ""
echo "=== All runtime agent tests passed ==="
