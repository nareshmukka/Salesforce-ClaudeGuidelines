# Salesforce-ClaudeGuidelines

Salesforce development and Agentforce guidance organized as reusable AI skill packages.

Start with:
- `CODEX.md` for Codex / ChatGPT inline chat usage.
- `CLAUDE.md` for Claude Code / Claude Agents usage.
- `salesforce-ai-skills/SKILL_INDEX.md` for the complete routing index.
- `LESSONS.md` for reusable mistake-prevention rules.
- `.vscode/settings.json` for VS Code Copilot skill/agent discovery.

## Skill Coverage

The local library now uses one self-contained `SKILL.md` per folder under `salesforce-ai-skills/skills/`.

There is one root `README.md`, one root `CLAUDE.md`, and one root `CODEX.md`. The skill library itself contains only `SKILL_INDEX.md` plus the `skills/` folders, so agents do not have competing entry points.

VS Code Copilot discovers these skills through `.vscode/settings.json`, which adds `salesforce-ai-skills/skills` to `chat.agentSkillsLocations`. Without that setting, VS Code only scans default folders like `.github/skills`, `.claude/skills`, and `.agents/skills`.

Reusable files must not contain company names, person names, target environment aliases, instance URLs, record IDs, secrets, or customer-specific process names. Use placeholders and keep project-specific facts in local working notes.

Coverage target: **100% practical coverage** against the Salesforce skill domains in `forcedotcom/sf-skills`, grouped into local domain skills instead of mirroring every upstream folder one-for-one.

Major covered domains:
- Core Salesforce: Apex, triggers, tests, Flow, LWC, metadata, validation rules, permissions, deployment, SOQL, data operations, docs research, diagrams.
- Agentforce: Script, authoring bundles, Builder metadata, Service Assistant, testing, prompt templates, AI prompt templates.
- Platform extensions: Data Cloud, OmniStudio, UI Bundle, Connected Apps, B2B Commerce, custom app/tabs/list views, custom Lightning types, media search.

## Agent Execution Contract

Every agent should follow this order:

1. Read `CLAUDE.md` or `CODEX.md`.
2. Read `salesforce-ai-skills/SKILL_INDEX.md`.
3. Read `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md`.
4. Read `LESSONS.md`.
5. Read every task-specific `SKILL.md` needed for the request.
6. Inspect source files before edits.
7. Make the smallest safe change.
8. Validate and report security, tests, deployment notes, and rollback notes.

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

## Validation

Run this after any skill-library update:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-salesforce-ai-skills.ps1
```
