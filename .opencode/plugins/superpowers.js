/**
 * Superpowers plugin for OpenCode.ai
 *
 * Registers the superpowers agent and skills directory via config hook.
 * Optionally injects bootstrap context into other configured agents.
 */

import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SUPERPOWERS_AGENT = 'superpowers';

const stripQuotes = (value) => value.replace(/^['"]|['"]$/g, '');

const parseScalar = (value) => {
  if (value === 'true') return true;
  if (value === 'false') return false;
  if (/^-?\d+(\.\d+)?$/.test(value)) return Number(value);
  return stripQuotes(value);
};

const isPlainObject = (value) => !!value && typeof value === 'object' && !Array.isArray(value);

const mergeObjects = (base, override) => {
  if (!isPlainObject(base)) return override === undefined ? base : override;
  if (!isPlainObject(override)) return override === undefined ? base : override;

  const merged = { ...base };
  for (const [key, value] of Object.entries(override)) {
    merged[key] = mergeObjects(base[key], value);
  }
  return merged;
};

// Simple frontmatter extraction (avoid dependency on skills-core for bootstrap)
const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content };

  const frontmatterStr = match[1];
  const body = match[2];
  const frontmatter = {};
  const stack = [{ indent: -1, value: frontmatter }];

  for (const line of frontmatterStr.split('\n')) {
    if (!line.trim() || line.trim().startsWith('#')) continue;

    const indent = line.match(/^\s*/)?.[0].length ?? 0;
    const trimmed = line.trim();
    const colonIdx = trimmed.indexOf(':');
    if (colonIdx <= 0) continue;

    const key = stripQuotes(trimmed.slice(0, colonIdx).trim());
    const value = trimmed.slice(colonIdx + 1).trim();

    while (stack.length > 1 && indent <= stack[stack.length - 1].indent) stack.pop();

    const parent = stack[stack.length - 1].value;
    if (!value) {
      parent[key] = {};
      stack.push({ indent, value: parent[key] });
      continue;
    }

    parent[key] = parseScalar(value);
  }

  return { frontmatter, content: body };
};

const readMarkdownEntry = (filepath) => {
  if (!fs.existsSync(filepath)) return null;
  return extractAndStripFrontmatter(fs.readFileSync(filepath, 'utf8'));
};

const shouldInjectForAgent = (options, agent) => {
  if (!agent) return false;
  if (agent === SUPERPOWERS_AGENT) return false;
  const inject = options?.oc?.inject;
  if (!inject || typeof inject !== 'object') return false;
  return inject[agent] === true;
};

export const SuperpowersPlugin = async ({ client, directory }, options = {}) => {
  const superpowersSkillsDir = path.resolve(__dirname, '../../skills');
  const superpowersAgentPath = path.resolve(__dirname, '../agents/superpowers.md');

  // Helper to generate bootstrap content
  const getBootstrapContent = () => {
    // Try to load using-superpowers skill
    const skillPath = path.join(superpowersSkillsDir, 'using-superpowers', 'SKILL.md');
    const skill = readMarkdownEntry(skillPath);
    if (!skill) return null;

    const toolMapping = `**Tool Mapping for OpenCode:**
When skills reference tools you don't have, substitute OpenCode equivalents:
- \`TodoWrite\` → \`todowrite\`
- \`Task\` tool with subagents → Use OpenCode's subagent system (@mention)
- \`Skill\` tool → OpenCode's native \`skill\` tool
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → Your native tools

Use OpenCode's native \`skill\` tool to list and load skills.`;

    return `<EXTREMELY_IMPORTANT>
You have superpowers.

**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED - you are currently following it. Do NOT use the skill tool to load "using-superpowers" again - that would be redundant.**

${skill.content}

${toolMapping}
</EXTREMELY_IMPORTANT>`;
  };

  const getSuperpowersAgent = () => {
    const agent = readMarkdownEntry(superpowersAgentPath);
    if (!agent) return null;

    return {
      ...agent.frontmatter,
      prompt: agent.content.trim(),
    };
  };

  return {
    // Inject skills path into live config so OpenCode discovers superpowers skills
    // without requiring manual symlinks or config file edits.
    // This works because Config.get() returns a cached singleton — modifications
    // here are visible when skills are lazily discovered later.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(superpowersSkillsDir)) {
        config.skills.paths.push(superpowersSkillsDir);
      }

      const bootstrap = getBootstrapContent();
      const superpowersAgent = getSuperpowersAgent();
      if (!superpowersAgent) return;

      config.agent = config.agent || {};
      const existing = isPlainObject(config.agent[SUPERPOWERS_AGENT]) ? config.agent[SUPERPOWERS_AGENT] : {};
      const extraPrompt = typeof existing.prompt === 'string' ? existing.prompt.trim() : '';

      config.agent[SUPERPOWERS_AGENT] = {
        ...superpowersAgent,
        ...existing,
        permission: mergeObjects(superpowersAgent.permission || {}, existing.permission || {}),
        options: mergeObjects(superpowersAgent.options || {}, existing.options || {}),
        prompt: [superpowersAgent.prompt, extraPrompt, bootstrap].filter(Boolean).join('\n\n'),
      };
    },

    // Inject bootstrap into configured non-superpowers agents.
    // The native @superpowers agent gets bootstrap through its prompt so the
    // first user message stays clean for OpenCode's automatic title generation.
    // Using a user message instead of a system message avoids:
    //   1. Token bloat from system messages repeated every turn (#750)
    //   2. Multiple system messages breaking Qwen and other models (#894)
    'experimental.chat.messages.transform': async (_input, output) => {
      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;
      if (!shouldInjectForAgent(options, firstUser.info.agent)) return;

      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;

      // Only inject once
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'))) return;
      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    }
  };
};
