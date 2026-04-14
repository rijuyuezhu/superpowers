#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_FILE="$REPO_ROOT/.opencode/plugins/superpowers.js"

echo "=== Test: Bootstrap Transform Gating ==="

PLUGIN_FILE="$PLUGIN_FILE" node --input-type=module <<'NODE'
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';

const pluginUrl = pathToFileURL(process.env.PLUGIN_FILE).href;
const { SuperpowersPlugin } = await import(pluginUrl);

const makeOutput = (agent) => ({
  messages: [
    {
      info: { role: 'user', agent },
      parts: [{ type: 'text', text: 'hello' }],
    },
  ],
});

const noOptionsPlugin = await SuperpowersPlugin({ client: {}, directory: process.cwd() });
const noOptionsOutput = makeOutput('superpowers');
await noOptionsPlugin['experimental.chat.messages.transform']({}, noOptionsOutput);
assert.equal(noOptionsOutput.messages[0].parts[0].text, 'hello', 'bootstrap should not inject without opt-in');

const scopedPlugin = await SuperpowersPlugin(
  { client: {}, directory: process.cwd() },
  { oc: { inject: { superpowers: true } } },
);

const buildOutput = makeOutput('build');
await scopedPlugin['experimental.chat.messages.transform']({}, buildOutput);
assert.equal(buildOutput.messages[0].parts[0].text, 'hello', 'bootstrap should not inject into build');

const superpowersOutput = makeOutput('superpowers');
await scopedPlugin['experimental.chat.messages.transform']({}, superpowersOutput);
assert.notEqual(superpowersOutput.messages[0].parts[0].text, 'hello', 'bootstrap should inject into superpowers');
assert.match(superpowersOutput.messages[0].parts[0].text, /You have superpowers\./);
assert.match(superpowersOutput.messages[0].parts[0].text, /TodoWrite/);

console.log('  [PASS] bootstrap transform is correctly gated');
NODE
