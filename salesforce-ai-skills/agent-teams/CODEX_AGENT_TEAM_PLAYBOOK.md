# Codex Agent Team Playbook

## Purpose
Guide Codex project agents through the shared Salesforce Lead / Architect / Dev / QA model while keeping context narrow and useful.

Codex Lead remains the default entry point. `codex-sf-lead` must classify task size before delegating and must create a Context Packet for non-trivial work.

Codex workers should read only selected skills and assigned files. They should not independently expand scope. The Lead must avoid recursive fan-out, enforce file ownership, and merge worker outputs into one final response.

Codex should not use the full pipeline for trivial work. Use skills only when relevant.

Codex repo-scoped skills are normally discovered from `.agents/skills`. This repo may keep canonical skills under `salesforce-ai-skills/skills`. Do not duplicate skill content by default. Prefer a documented adapter, symlink, junction, or setup-script approach later if needed. If `.agents/skills` does not exist, do not copy all skills automatically unless explicitly requested.

## Example Codex prompts

Review-only:
```text
Use codex-sf-lead. Classify this as Lead + QA. Create a Context Packet, select only relevant Salesforce skills, inspect the target files, and ask QA to review. Do not edit files, deploy, publish, activate, or modify live data.
```

Small implementation:
```text
Use codex-sf-lead. Classify the task. If architecture is obvious, use Lead + Dev + QA. Create a Context Packet, assign file ownership, have Dev implement only scoped local changes, and have QA review before the final response.
```

Full Salesforce feature:
```text
Use codex-sf-lead with Lead + Architect + Dev + QA. Create a Context Packet from the request. Select only the relevant skills from SKILL_INDEX.md. Architect plans only, Dev implements scoped files only, QA reviews security, tests, deployment safety, and rollback.
```

Agentforce review:
```text
Use codex-sf-lead. Create a Context Packet and select the Agentforce Script, Builder, Testing, or Service Assistant skills only as applicable. Review instructions, grounding, permissions, publish/activation gates, and rollback. Do not publish or activate.
```

Deployment package review:
```text
Use codex-sf-lead. Classify as Lead + QA unless implementation changes are requested. Select the Deployment skill and any metadata-specific skills needed. Review package contents, dependency order, validation command, rollback, and activation gates. Do not deploy.
```

Skill-routing review:
```text
Use codex-sf-lead. Review SKILL_INDEX.md and selected agent instructions for routing quality. Do not read every skill unless the review explicitly requires inventory coverage. Report over-reading risks and missing routing links.
```
