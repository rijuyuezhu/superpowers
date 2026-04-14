#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT_FILE="$REPO_ROOT/.opencode/agents/superpowers.md"
USING_SUPERPOWERS="$REPO_ROOT/skills/using-superpowers/SKILL.md"

echo "=== Test: Superpowers Agent Boundaries ==="

if [ ! -f "$AGENT_FILE" ]; then
	echo "  [FAIL] Missing .opencode/agents/superpowers.md"
	exit 1
fi

if ! grep -Fq '"*": deny' "$AGENT_FILE"; then
	echo "  [FAIL] superpowers agent does not deny all skills by default"
	exit 1
fi

for skill_dir in "$REPO_ROOT"/skills/*; do
	skill_name="$(basename "$skill_dir")"
	if ! grep -q "\"$skill_name\": allow" "$AGENT_FILE"; then
		echo "  [FAIL] superpowers agent is missing allow entry for $skill_name"
		exit 1
	fi
done

if grep -q '## Tool Mapping for OpenCode' "$USING_SUPERPOWERS"; then
	echo "  [FAIL] using-superpowers still contains OpenCode tool mapping"
	exit 1
fi

if grep -q 'Now you are in SUPERPOWER mode' "$USING_SUPERPOWERS"; then
	echo "  [FAIL] using-superpowers still contains OpenCode-only bootstrap wording"
	exit 1
fi

if grep -R -q 'This skill should only be used when you are in SUPERPOWER mode' "$REPO_ROOT/skills"; then
	echo "  [FAIL] Shared skill descriptions still contain OpenCode-only prefaces"
	exit 1
fi

echo "  [PASS] Superpowers agent and shared skill boundaries look correct"
