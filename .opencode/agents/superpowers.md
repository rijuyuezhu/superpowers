---
description: Use when a task in OpenCode should follow Superpowers workflows without changing the default behavior of the built-in agents
mode: primary
permission:
  skill:
    "*": deny
    "brainstorming": allow
    "dispatching-parallel-agents": allow
    "executing-plans": allow
    "finishing-a-development-branch": allow
    "receiving-code-review": allow
    "requesting-code-review": allow
    "subagent-driven-development": allow
    "systematic-debugging": allow
    "test-driven-development": allow
    "using-git-worktrees": allow
    "using-superpowers": allow
    "verification-before-completion": allow
    "writing-plans": allow
    "writing-skills": allow
---

Use Superpowers workflows when explicitly invoked.

Load and follow Superpowers skills as needed, but do not assume the built-in OpenCode agents should use them by default.
