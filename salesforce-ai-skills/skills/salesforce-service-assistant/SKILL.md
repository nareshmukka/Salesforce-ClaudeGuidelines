---
name: salesforce-service-assistant
description: Production Salesforce AI skill for Agentforce Service Assistant, ServicePlanner patterns, Case assistant UI, and service-agent troubleshooting.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 3.0.0
  last_updated: 2026-05-18
  owner: Reusable Salesforce AI Skills Library
---

## TRIGGER when
- The task involves Agentforce Service Assistant, ServicePlanner, Case assistant UI, service-channel routing, bot/user permissions, or service-agent troubleshooting.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe metadata or guidance with explicit security, testing, activation, and rollback notes.

## DO NOT TRIGGER when
- The task is unrelated to Service Assistant, ServicePlanner, service-channel routing, or Case-scoped assistant patterns.
- Agentforce `.agent` authoring bundles, Builder metadata, or prompt templates are the primary owner and Service Assistant is only incidental.
- The user asks for deploy, publish, activate, destructive change, or customer-facing send/write actions without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read `../salesforce-agentforce-script/SKILL.md` for agent instruction rules.
- Also read `../salesforce-agentforce-builder/SKILL.md` for Builder metadata.
- Also read `../salesforce-agentforce-authoring-bundle/SKILL.md` only when `.agent` bundles or publish behavior are involved.
- Also read `../salesforce-permissions/SKILL.md` for bot/user access, class access, flow access, and agent access.
- Also read `../salesforce-observability/SKILL.md` for logging and traceability patterns.

## Purpose
Provide reusable, project-neutral guidance for Service Assistant style Agentforce work without relying on company-specific metadata, target environments, or local implementation history.

## Pre-edit workflow (must follow)
1. Identify whether the assistant is ServicePlanner/Service Assistant, `.agent` authoring bundle, Builder metadata, or prompt-template driven.
2. Inspect existing metadata and permission files before proposing changes.
3. Identify the running user model: human rep, bot user, integration user, or server-invoked agent.
4. Capture channel, object, data-access, PII, and activation boundaries.
5. List validation checks before editing.

## Post-edit workflow (must follow)
1. Re-open changed files and self-review for metadata consistency.
2. Validate permissions for both visible users and background/bot execution users.
3. Verify no company names, person names, environment aliases, record IDs, secrets, or customer-specific process names were added to reusable files.
4. Document activation/publish gates separately from dry-run validation.
5. Stop short of deploy, publish, activate, destructive changes, or customer-facing actions unless explicitly approved.

## Service Assistant rules
- Treat ServicePlanner/Service Assistant and `.agent` DSL agents as different implementation models.
- Do not copy `.agent` reasoning blocks into ServicePlanner metadata.
- Do not assume the visible user and the background execution user share permissions.
- Verify object, field, Apex class, Flow, prompt-template, and agent access for every action surface.
- Keep customer-facing send/write actions behind explicit confirmation and approval gates.
- Never enable private-conversation logging for PII workloads unless the business explicitly approves and the retention policy is documented.

## Permission checklist
- [ ] Human user profile/permission set grants object and field access.
- [ ] Bot or background user grants object, field, class, flow, prompt-template, and agent access.
- [ ] Permission-set group and muting behavior is understood.
- [ ] Every action target has a matching access grant.
- [ ] Least privilege is preserved.

## Validation checklist
- [ ] Metadata validates in dry-run or equivalent local/static check.
- [ ] Assistant can retrieve required records under the intended user context.
- [ ] Assistant refuses or escalates when required data is missing.
- [ ] Write/send actions require explicit user confirmation.
- [ ] Logging/tracing works without exposing secrets or PII.
- [ ] Activation/publish remains a separate approval gate.

## Common AI Mistakes to Avoid
| Mistake | Why it is dangerous | Correct approach |
|---|---|---|
| Conflating ServicePlanner with `.agent` DSL agents | Produces invalid metadata and wrong troubleshooting paths | Identify assistant implementation model before editing |
| Checking only the visible rep permissions | Background execution can still fail | Verify both human and bot/background user access |
| Assuming activation is allowed after validation | Activation changes live assistant behavior | Require explicit approval for deploy/publish/activate |
| Hardcoding company or environment details into reusable examples | Makes the skill unsafe to share across projects | Use placeholders and keep project facts in local working notes |
| Ignoring private-conversation logging settings | PII can be stored unexpectedly | Review logging/retention behavior before publish or activation |
| Treating missing action results as model hallucination only | Planner may have silently dropped actions due to permissions | Audit action targets and permission grants first |

## Output contract
- Assistant model identified
- Files inspected
- Permissions reviewed
- Changes made or recommended
- Security and PII review
- Validation performed
- Activation/publish notes
- Rollback notes
