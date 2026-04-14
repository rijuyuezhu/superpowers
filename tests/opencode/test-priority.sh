#!/usr/bin/env bash
# Test: Agent Skill Permissions
# Verifies that the dedicated superpowers agent gets superpowers skills while built-in agents are denied
# NOTE: These tests require OpenCode to be installed and configured
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Test: Agent Skill Permissions ==="

# Source setup to create isolated environment
source "$SCRIPT_DIR/setup.sh"

# Trap to cleanup on exit
trap cleanup_test_env EXIT

# Test 1: Verify fixture setup
echo ""
echo "Test 1: Verifying test fixtures..."

if [ -f "$OPENCODE_CONFIG_DIR/agents/superpowers.md" ]; then
	echo "  [PASS] superpowers agent fixture exists"
else
	echo "  [FAIL] superpowers agent fixture missing"
	exit 1
fi

if [ -f "$OPENCODE_CONFIG_DIR/opencode.json" ]; then
	echo "  [PASS] OpenCode config fixture exists"
else
	echo "  [FAIL] OpenCode config fixture missing"
	exit 1
fi

# Check if opencode is available for integration tests
if ! command -v opencode &>/dev/null; then
	echo ""
	echo "  [SKIP] OpenCode not installed - skipping integration tests"
	echo "  To run these tests, install OpenCode: https://opencode.ai"
	echo ""
	echo "=== Agent permission fixture tests passed (integration tests skipped) ==="
	exit 0
fi

# Test 2: Verify agent permission output
echo ""
echo "Test 2: Verifying agent permissions..."

output=$(timeout 60s opencode agent list 2>&1) || {
	exit_code=$?
	if [ $exit_code -eq 124 ]; then
		echo "  [FAIL] OpenCode timed out after 60s"
		exit 1
	fi
}

build_block=$(printf '%s\n' "$output" | awk '/^build \(primary\)/{flag=1; print; next} /^[a-z].* \((primary|subagent)\)$/{if(flag){exit}} flag {print}')
superpowers_block=$(printf '%s\n' "$output" | awk '/^superpowers \(subagent\)/{flag=1; print; next} /^[a-z].* \((primary|subagent)\)$/{if(flag){exit}} flag {print}')

if printf '%s\n' "$build_block" | grep -A2 '"permission": "skill"' | grep -q '"action": "deny"'; then
	echo "  [PASS] build agent denies skill access"
else
	echo "  [FAIL] build agent does not deny skill access"
	exit 1
fi

if printf '%s\n' "$superpowers_block" | grep -A2 '"pattern": "brainstorming"' | grep -q '"action": "allow"'; then
	echo "  [PASS] superpowers agent allows superpowers skills"
else
	echo "  [FAIL] superpowers agent does not allow brainstorming"
	exit 1
fi

if printf '%s\n' "$superpowers_block" | grep -A2 '"permission": "skill"' | grep -q '"action": "deny"'; then
	echo "  [PASS] superpowers agent starts from skill deny-all"
else
	echo "  [FAIL] superpowers agent is missing the deny-all skill rule"
	exit 1
fi

echo ""
echo "=== All agent permission tests passed ==="
