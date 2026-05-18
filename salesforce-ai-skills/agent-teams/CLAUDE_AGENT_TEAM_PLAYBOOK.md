# Claude Agent Team Playbook

## Purpose
Guide Claude through the shared Salesforce Lead / Architect / Dev / QA model while preserving standalone project subagents.

Claude subagents and Claude agent teams are different. Standalone Claude subagents live under `.claude/agents/`. Keep existing Claude subagents as reusable role definitions.

Agent teams should be launched by prompt only when parallel collaboration adds value. Do not manually create `.claude/teams`. Do not manually create project-level Claude team runtime config. Claude agent team runtime files are not repo-managed.

Use subagents by default for normal Salesforce workflow. Use agent teams only for complex parallel research, review, debugging, or cross-layer work.

## When to use Claude subagents
- Normal Lead -> Architect -> Dev -> QA sequencing.
- Small or medium implementation work.
- Review-only work with Lead + QA.
- Work where file ownership must stay tightly controlled.

## When to use Claude agent teams
- Complex parallel research across independent metadata areas.
- Multi-layer debugging where logs, Apex, LWC, Flow, and permissions can be reviewed independently.
- Cross-layer feature design with clear non-overlapping ownership.
- Agentforce review where instruction quality, action contracts, testing, and permissions can be assessed in parallel.

## Rules
- Lead creates Context Packet first.
- One file owner per teammate.
- No two teammates edit the same file.
- QA reviews before final answer.
- No deploy, publish, activate, live-data, destructive, credential, connector, or auth action without explicit approval.

## Claude prompt examples

Normal subagent workflow:
```text
Use claude-sf-lead. Create a Context Packet, classify the task, select relevant Salesforce skills, then use sf-architect, sf-dev, and sf-qa only if the task route requires them.
```

Parallel review team:
```text
Use claude-sf-lead. Create a Context Packet and launch a prompt-based review team only if parallel review adds value. Assign separate file ownership and have QA consolidate pass, pass with risk, or block before final synthesis.
```

New feature team:
```text
Use claude-sf-lead with Lead + Architect + Dev + QA. Architect plans only. Dev implements approved scoped files only. QA reviews changed files, tests, security, deployment gates, and rollback before the final answer.
```

Debugging team:
```text
Use claude-sf-lead. Create a Context Packet with symptoms, logs, files in scope, and selected debugging skills. Split investigation only across independent areas. Do not make live data or destructive changes.
```

Agentforce review team:
```text
Use claude-sf-lead. Select Agentforce skills that apply. Review instructions, action contracts, grounding, PII handling, permissions, testing, publish/activation gates, and rollback. Do not publish or activate.
```
