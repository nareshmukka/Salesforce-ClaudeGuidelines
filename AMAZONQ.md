# AMAZONQ.md

## Purpose
Default operating contract for Amazon Q Developer in this reusable Salesforce AI-guidelines repository.

Read `AGENTS.md` first. It is the shared public contract for loading order, portability, safety gates, agent-team use, and final response expectations.

## How Amazon Q is configured
Amazon Q uses `.amazonq/rules/` as the project rules location. This setup does not use static repo-managed Amazon Q agents.

Shared Salesforce skills are under `salesforce-ai-skills/skills/`. Shared operating model, playbooks, and templates are under `salesforce-ai-skills/agent-teams/`.

Use `salesforce-ai-skills/agent-teams/AMAZONQ_PLAYBOOK.md` for the full prompt catalog. Use `salesforce-ai-skills/agent-teams/templates/context-packet.md` for non-trivial work.

Use `salesforce-ai-skills/SKILL_INDEX.md` to select relevant skills. Do not load all skills by default.

## Safety gates
- Follow `AGENTS.md` as the shared safety and portability contract.
- Do not deploy without explicit approval.
- Do not publish or activate Agentforce agents without explicit approval.
- Do not activate Flow changes without explicit approval.
- Do not delete metadata without explicit approval.
- Do not modify live data without explicit approval.
- Do not rotate credentials, activate connectors, or modify auth settings without explicit approval.
- Do not hardcode IDs, secrets, tokens, org URLs, environment aliases, customer names, or customer-specific values.

## Recommended Amazon Q prompts

Short examples:
- Review only: "Follow AMAZONQ.md and `.amazonq/rules`. Act as Salesforce Lead + QA Reviewer. Inspect files, select relevant skills, and report findings. Do not edit or deploy."
- Local change only: "Act as Salesforce Lead + Developer + QA Reviewer. Create a Context Packet for non-trivial work, inspect files first, implement only scoped local changes, then report validation, rollback, and risks."
- Full feature workflow: "Act as Salesforce Lead, Architect, Developer, and QA Reviewer. Architect plans only, Developer implements approved scoped files only, and QA reviews before final response."

## Response format
- Understanding
- Files inspected
- Plan / changes made
- Security review
- Tests / validation
- Deployment notes
- Rollback notes
- Risks / blockers
