#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_DOC="$REPO_ROOT/.opencode/INSTALL.md"
README_DOC="$REPO_ROOT/docs/README.opencode.md"

echo "=== Test: OpenCode Docs ==="

for doc in "$INSTALL_DOC" "$README_DOC"; do
	if ! grep -q '@superpowers' "$doc"; then
		echo "  [FAIL] $doc does not mention the explicit @superpowers agent"
		exit 1
	fi

	if ! grep -q '"superpowers": true' "$doc"; then
		echo "  [FAIL] $doc does not show scoped bootstrap injection config"
		exit 1
	fi

	if ! grep -Eq '"skill": \{|permission:' "$doc"; then
		echo "  [FAIL] $doc does not show permission.skill configuration"
		exit 1
	fi

	if grep -q 'Tell me about your superpowers' "$doc"; then
		echo "  [FAIL] $doc still recommends global bootstrap verification"
		exit 1
	fi

	if grep -q 'every conversation' "$doc"; then
		echo "  [FAIL] $doc still claims bootstrap is injected into every conversation"
		exit 1
	fi
done

echo "  [PASS] OpenCode docs describe explicit superpowers-agent usage"
