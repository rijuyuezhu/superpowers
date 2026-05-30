#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_DOC="$REPO_ROOT/.opencode/INSTALL.md"
README_DOC="$REPO_ROOT/docs/README.opencode.md"

echo "=== Test: OpenCode Docs ==="

for doc in "$INSTALL_DOC" "$README_DOC"; do
	if ! grep -Eq 'superpowers.*agent|agent.*superpowers' "$doc"; then
		echo "  [FAIL] $doc does not mention the explicit superpowers agent"
		exit 1
	fi

	if ! grep -q 'built-in agents are not bootstrapped by default' "$doc"; then
		echo "  [FAIL] $doc does not explain that built-in agents are not bootstrapped by default"
		exit 1
	fi

	if ! grep -q '"inject"' "$doc"; then
		echo "  [FAIL] $doc does not show optional scoped bootstrap injection config"
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

echo "  [PASS] OpenCode docs describe explicit superpowers agent usage"
