# AGENTS.md

## Purpose
This repository is a reusable public Salesforce AI skills template for multiple Salesforce projects and AI tools. Keep shared guidance portable, tool-neutral, and free of consuming-project facts.

## Core loading order
1. Read `AGENTS.md`.
2. Read the relevant tool wrapper only when applicable: `CLAUDE.md`, `CODEX.md`, or `AMAZONQ.md`.
3. Read `salesforce-ai-skills/SKILL_INDEX.md`.
4. Read `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md` only for Salesforce implementation, review, troubleshooting, or design tasks.
5. Read only task-specific `SKILL.md` files selected from the index.
6. Read `LESSONS.md` when doing implementation/review work or updating reusable guidance.

Do not read all skills by default. The index is for routing; the skill files are the workflow knowledge layer.

## Public portability
Shared files must not contain company names, client names, person names, org aliases, instance URLs, record IDs, secrets, customer-specific process names, or private implementation details. Use placeholders such as `<target-env-alias>`, `<manifest-path>`, `<agent-api-name>`, `<object-api-name>`, and `<current-api-version>`.

Project-specific facts belong in consuming-project files, local working notes, or user-provided context outside this reusable template.

## Safety gates
Do not deploy, publish, activate, deactivate, delete metadata, run destructive changes, modify live data, rotate credentials, activate connectors, change auth settings, or send customer-facing messages without explicit approval.

Salesforce work must include security review for sharing, CRUD/FLS, least privilege, secrets, PII, bulk behavior, validation, deployment notes, and rollback notes.

## Agent teams
Use the smallest workflow that safely completes the task. Full Lead / Architect / Dev / QA pipelines are optional and should be reserved for non-trivial, high-risk, multi-metadata, security-sensitive, deployment-sensitive, Agentforce, Flow, integration, Data Cloud, or permission-sensitive work.

For team workflows, use `salesforce-ai-skills/agent-teams/TEAM_OPERATING_MODEL.md` and the relevant tool playbook. Do not make agents load all skills.

## Output contract
Final responses should include:
- Understanding
- Files inspected
- Changes made or findings
- Security review
- Validation / tests
- Deployment notes
- Rollback notes
- Risks / blockers
