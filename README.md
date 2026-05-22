# Salesforce-ClaudeGuidelines

Salesforce development and Agentforce guidance organized as reusable AI skill packages.

Start with:
- `AGENTS.md` for shared cross-tool behavior.
- `CODEX.md` for Codex / ChatGPT inline chat usage.
- `CLAUDE.md` for Claude Code / Claude Agents usage.
- `AMAZONQ.md` for Amazon Q Developer usage.
- `salesforce-ai-skills/SKILL_INDEX.md` for the complete routing index.
- `LESSONS.md` for reusable mistake-prevention rules.
- `.vscode/settings.json` for VS Code Copilot skill/agent discovery.

This repo is a reusable public Salesforce AI skills template. Keep project/client/org-specific facts outside shared files.

## Skill Coverage

The local library now uses one self-contained `SKILL.md` per folder under `salesforce-ai-skills/skills/`.

There is one root `AGENTS.md`, one root `README.md`, and one root wrapper for each supported tool: `CLAUDE.md`, `CODEX.md`, and `AMAZONQ.md`. The skill library itself contains only `SKILL_INDEX.md` plus the `skills/` folders, so agents do not have competing entry points.

VS Code Copilot discovers these skills through `.vscode/settings.json`, which adds `salesforce-ai-skills/skills` to `chat.agentSkillsLocations`. Without that setting, VS Code only scans default folders like `.github/skills`, `.claude/skills`, and `.agents/skills`.

Reusable files must not contain company names, person names, target environment aliases, instance URLs, record IDs, secrets, or customer-specific process names. Use placeholders and keep project-specific facts in local working notes.

Coverage target: **100% practical coverage** against the Salesforce skill domains in `forcedotcom/sf-skills`, grouped into local domain skills instead of mirroring every upstream folder one-for-one.

Major covered domains:
- Core Salesforce: Apex, triggers, tests, Flow, LWC, metadata, validation rules, permissions, deployment, SOQL, data operations, docs research, diagrams.
- Agentforce: Script, authoring bundles, Builder metadata, Service Assistant, testing, prompt templates, AI prompt templates.
- Platform extensions: Data Cloud, OmniStudio, UI Bundle, Connected Apps, B2B Commerce, custom app/tabs/list views, custom Lightning types, media search.

## Agent Execution Contract

Every agent should follow this order:

1. Read `AGENTS.md`.
2. Read the relevant tool wrapper when applicable: `CLAUDE.md`, `CODEX.md`, or `AMAZONQ.md`.
3. Read `salesforce-ai-skills/SKILL_INDEX.md`.
4. Read `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md` only for Salesforce implementation/review/design tasks.
5. Read `LESSONS.md` when doing implementation/review work or reusable guidance updates.
6. Read only task-specific `SKILL.md` files needed for the request.
7. Inspect source files before edits.
8. Make the smallest safe change.
9. Validate and report security, tests, deployment notes, and rollback notes.

## Agent Pipelines

Claude agents live in `.claude/agents/`:
- `claude-sf-lead` manages the Claude pipeline.
- `sf-architect` designs the solution.
- `sf-dev` implements the approved scope.
- `sf-qa` reviews quality, safety, tests, deployment, and lessons.

Codex agents live in `.codex/agents/`:
- `codex-sf-lead` manages the Codex pipeline.
- `codex-sf-architect` designs the solution.
- `codex-sf-dev` implements the approved scope.
- `codex-sf-qa` reviews quality, safety, tests, deployment, and lessons.

For non-trivial work, start with the relevant lead agent. The lead manages everyone else.

## Multi-Tool Agent Operating Model

This repo supports Claude, Codex, and Amazon Q Developer.

- Claude uses `.claude/agents/`.
- Codex uses `.codex/agents/`.
- Amazon Q uses `.amazonq/rules/`.
- Shared Salesforce skills live under `salesforce-ai-skills/skills/`.
- Shared operating model and templates live under `salesforce-ai-skills/agent-teams/`.
- Lead is the orchestrator.
- Context Packet is the shared scoped context.
- Use the full pipeline only for non-trivial or high-risk work.

References:
- [AGENTS.md](AGENTS.md)
- [CLAUDE.md](CLAUDE.md)
- [CODEX.md](CODEX.md)
- [AMAZONQ.md](AMAZONQ.md)
- [TEAM_OPERATING_MODEL.md](salesforce-ai-skills/agent-teams/TEAM_OPERATING_MODEL.md)
- [CODEX_AGENT_TEAM_PLAYBOOK.md](salesforce-ai-skills/agent-teams/CODEX_AGENT_TEAM_PLAYBOOK.md)
- [CLAUDE_AGENT_TEAM_PLAYBOOK.md](salesforce-ai-skills/agent-teams/CLAUDE_AGENT_TEAM_PLAYBOOK.md)
- [AMAZONQ_PLAYBOOK.md](salesforce-ai-skills/agent-teams/AMAZONQ_PLAYBOOK.md)

## Validation

Run this after any skill-library update:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-salesforce-ai-skills.ps1
```
