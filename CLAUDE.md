# CLAUDE.md

## Purpose
Claude-specific launcher for Claude Code and Claude agents working in this reusable Salesforce AI skills template.

Read `AGENTS.md` first. It is the shared public contract for loading order, portability, safety gates, agent-team use, and final response expectations.

## Claude loading
1. Read `AGENTS.md`.
2. Read this Claude wrapper.
3. Use `salesforce-ai-skills/SKILL_INDEX.md` to select relevant skills.
4. For Salesforce implementation, review, troubleshooting, or design tasks, read `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md`.
5. Read only the task-specific `SKILL.md` files needed for the request.
6. Read `LESSONS.md` for implementation/review work or reusable guidance updates.

Do not load all skills by default.

## Claude agent notes
- Use `.claude/agents/` only when task complexity justifies delegation.
- Default lead agent for non-trivial Claude work: `claude-sf-lead`.
- Do not create `.claude/teams` manually.
- Use a Context Packet only for non-trivial delegated or team work.
- Keep Amazon Q and Codex behavior out of Claude agent definitions.

## References
- `salesforce-ai-skills/SKILL_INDEX.md`
- `salesforce-ai-skills/agent-teams/TEAM_OPERATING_MODEL.md`
- `salesforce-ai-skills/agent-teams/CLAUDE_AGENT_TEAM_PLAYBOOK.md`
- `salesforce-ai-skills/agent-teams/templates/context-packet.md`
- `LESSONS.md`

## Safety and portability
Do not deploy, publish, activate, deactivate, delete metadata, run destructive changes, modify live data, rotate credentials, activate connectors, change auth settings, or send customer-facing messages without explicit approval.

Keep shared files free of company names, client names, person names, org aliases, instance URLs, record IDs, secrets, customer-specific process names, and private implementation details. Use placeholders for consuming-project values.

## Response format
- Understanding
- Files inspected
- Changes made or findings
- Security review
- Validation / tests
- Deployment notes
- Rollback notes
- Risks / blockers
