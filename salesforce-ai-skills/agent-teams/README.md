# Salesforce Agent Teams

This folder defines the lightweight shared operating model for Salesforce AI work across Claude, Codex, and Amazon Q Developer.

Agents are roles: Lead, Architect, Dev, and QA. Skills are reusable Salesforce knowledge kept canonical under `salesforce-ai-skills/skills/`. Context packets are shared scoped context for non-trivial work so each role reads only what it needs.

The Lead is the only orchestrator. Full team orchestration is used only when the task is non-trivial or high-risk enough to justify Architect, Dev, and QA handoffs.

Claude, Codex, and Amazon Q use different repository mechanisms, but they share the same operating model:
- Claude uses standalone subagents in `.claude/agents/`.
- Codex uses standalone project agents in `.codex/agents/`.
- Amazon Q uses project rules in `.amazonq/rules/` and prompt-based roles.

Start here:
- [TEAM_OPERATING_MODEL.md](TEAM_OPERATING_MODEL.md)
- [CODEX_AGENT_TEAM_PLAYBOOK.md](CODEX_AGENT_TEAM_PLAYBOOK.md)
- [CLAUDE_AGENT_TEAM_PLAYBOOK.md](CLAUDE_AGENT_TEAM_PLAYBOOK.md)
- [AMAZONQ_PLAYBOOK.md](AMAZONQ_PLAYBOOK.md)
- [templates/context-packet.md](templates/context-packet.md)
