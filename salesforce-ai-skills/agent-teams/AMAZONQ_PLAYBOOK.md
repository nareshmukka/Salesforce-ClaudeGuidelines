# Amazon Q Developer Playbook

## Purpose
Guide Amazon Q Developer through the shared Salesforce Lead / Architect / Dev / QA model using project rules and prompt-based roles.

Amazon Q Developer uses project rules under `.amazonq/rules/`. Amazon Q does not need Claude-style static subagents. Do not create `.amazonq/agents`. Do not create `.amazonq/teams`.

Amazon Q should use prompt-based roles:
- Salesforce Lead
- Salesforce Architect
- Salesforce Developer
- Salesforce QA Reviewer

Use `.amazonq/rules/` for lightweight persistent behavior only. Keep detailed Salesforce domain guidance in `salesforce-ai-skills/skills/`. Do not paste huge skill content into Amazon Q rules.

Use a Context Packet for non-trivial work. Use Lead-only mode for simple tasks, Lead + QA for review-only, Lead + Dev + QA for small obvious changes, and Lead + Architect + Dev + QA for new or high-risk Salesforce work.

Amazon Q should inspect files before editing. It should not deploy, publish, activate, delete, modify live data, or rotate credentials without explicit approval. It should report files changed, validation, risks, and rollback.

## Example Amazon Q prompts

Review-only task:
```text
Act as Salesforce Lead + QA Reviewer. Follow .amazonq/rules and salesforce-ai-skills/agent-teams/TEAM_OPERATING_MODEL.md. Create or follow a Context Packet, inspect the target files, select only relevant skills, and report findings. Do not edit or deploy.
```

Small implementation:
```text
Act as Salesforce Lead + Developer + QA Reviewer. Inspect files first, create a Context Packet, select relevant skills, implement only the scoped local change, then review security, tests, deployment notes, rollback, and risks.
```

Full Salesforce feature:
```text
Act as Salesforce Lead, Architect, Developer, and QA Reviewer. Create a Context Packet. Architect plans only, Developer implements approved scoped files only, QA reviews before final response. Do not deploy, publish, activate, or modify live data.
```

Agentforce review:
```text
Act as Salesforce Lead + QA Reviewer. Select applicable Agentforce Script, Builder, Testing, or Service Assistant skills. Review guardrails, action contracts, grounding, permissions, testing, publish/activation safety, and rollback. Do not publish or activate.
```

Deployment package review:
```text
Act as Salesforce Lead + QA Reviewer. Select the Deployment skill and any metadata-specific skills. Review package contents, dependency order, validation plan, activation gates, rollback, and risks. Do not deploy.
```

Amazon Q rules review:
```text
Act as Salesforce Lead + QA Reviewer. Review .amazonq/rules and AMAZONQ.md for consistency with the shared operating model. Keep rules lightweight and avoid duplicating skill content.
```
