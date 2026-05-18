# Salesforce Agent Team Operating Model

## Purpose
Provide one lightweight Lead / Architect / Dev / QA model for Salesforce work across Claude, Codex, and Amazon Q Developer without making every agent read everything.

## Default rule
Use the smallest workflow that can safely complete the task. Lead owns shared context, classification, selected skills, delegation, QA gate, synthesis, and final response.

## Tool-specific entry points
- Claude: default entry point is `claude-sf-lead` when `.claude/agents/` is available.
- Codex: default entry point is `codex-sf-lead` when `.codex/agents/` is available.
- Amazon Q: default behavior is guided by `.amazonq/rules/` and `AMAZONQ.md`; use prompt-based Lead / Architect / Dev / QA roles.

## Task-size routing
Lead only:
- Simple wording edits
- README cleanup
- Prompt rewrites
- Small documentation-only updates
- Small package.xml review
- Simple explanation tasks

Lead + QA:
- Review-only tasks
- Security review
- Deployment plan review
- Agent instruction review
- Skill quality review
- Amazon Q rule review

Lead + Dev + QA:
- Small implementation where architecture is obvious
- Test update
- Minor Apex/LWC/Flow metadata update
- Small docs automation update
- Small agent/rule documentation update

Lead + Architect + Dev + QA:
- New Salesforce feature
- Cross-metadata work
- Agentforce work
- Flow + Apex + LWC work
- Integration work
- Permission/security-sensitive work
- Deployment-sensitive changes
- Data Cloud / Service Assistant / Agentforce changes
- Any change that impacts production behavior or security posture

Do not use full team for:
- Trivial single-file text edits
- Simple explanation tasks
- Tasks where one agent already has enough context
- Same-file edits that would cause file conflicts
- Work where coordination cost is higher than value

## Context packet rules
Create a Context Packet for non-trivial delegated/team work before delegation. It defines the request, route, selected platform, execution mode, selected skills, files in scope, files out of scope, assignments, acceptance criteria, validation, rollback, assumptions, and blocking questions.

The Context Packet is the shared source of truth. Workers may ask for clarification when blocked, but they should not independently expand scope.

Context Packet is optional for direct single-stage scoped work and not required for trivial Lead-only work. Do not weaken the Context Packet requirement for Agentforce, Flow, integration, deployment-sensitive, permission/security-sensitive, Data Cloud, Service Assistant, or multi-metadata changes.

## Skill selection rules
Use `salesforce-ai-skills/SKILL_INDEX.md` to select only relevant skills. Always include `salesforce-global-development` for Salesforce implementation or review work. Add task-specific skills only when the task needs them.

Do not read all skills by default. Do not duplicate skill content into tool-specific rules or agents.

## File ownership rules
Assign one owner per file or metadata surface before editing. No two workers edit the same file at the same time. Workers must not edit files outside their assignment.

## Handoff rules
Each handoff must identify the Context Packet, owned files, files not to touch, required inputs, expected output, blockers, and next-stage dependency. Use `templates/handoff-record.md` when a written handoff is useful.

## QA gate rules
QA reviews after implementation and before final response for non-trivial work. QA can return pass, pass with risk, or block. Blocks require Lead synthesis and either a fix loop or a clear residual-risk report.

## Salesforce safety gates
Do not deploy, publish, activate, delete metadata, modify live data, rotate credentials, activate connectors, or change auth settings without explicit approval.

Enforce CRUD/FLS/sharing, bulkification, governor-limit safety, test coverage, deployment notes, and rollback notes.

## Token-efficiency rules
- Lead reads broad routing docs once, then narrows context.
- Architect, Dev, and QA read the Context Packet when provided or when working as part of a non-trivial delegated/team workflow. For direct single-stage scoped work, they may follow the user/lead instruction, selected skills, and assigned files without requiring a separate Context Packet.
- Architect designs only.
- Dev implements only scoped changes.
- QA reviews only the design, dev output, changed files, selected skills, and assigned scope.
- Avoid recursive fan-out and broad skill loading.

## Final response contract
Final responses should include understanding, files inspected, changes made or findings, security review, tests/validation, deployment notes, rollback notes, risks/blockers, and exact next commands when useful.

## What not to do
- Do not make every agent read every skill.
- Do not create `.claude/teams`, `.codex/teams`, `.amazonq/agents`, or `.amazonq/teams`.
- Do not duplicate skill folders.
- Do not let workers expand scope without Lead approval.
- Do not mix Amazon Q rules into Claude or Codex agent definitions.
- Do not add company, customer, person, environment, org URL, record ID, secret, token, or customer-specific process details to reusable files.
