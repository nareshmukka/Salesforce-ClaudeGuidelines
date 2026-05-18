---
name: salesforce-docs-research
description: Production Salesforce AI skill for fetching and verifying current Salesforce documentation, release notes, command syntax, and platform behavior before implementation.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-18
  owner: Naresh Salesforce AI Skills Library
---

## TRIGGER when
- The task depends on current Salesforce docs, release behavior, CLI syntax, API version support, metadata shape, feature availability, or official examples.

## DO NOT TRIGGER when
- The answer is stable and already documented in a local skill file.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read the component skill that owns the implementation.

## Purpose
Prevent stale-memory implementation by making docs verification an explicit workflow.

## Workflow
1. Identify exact feature, API version, command, or metadata type to verify.
2. Prefer official Salesforce docs, developer docs, release notes, and Salesforce-owned GitHub repos.
3. Use search before fetch when docs pages are JS-rendered or moved.
4. Capture source URL, date checked, and what was verified.
5. Distinguish documented behavior from local empirical findings.

## Best Practices
- Do not quote old API minimum versions from memory.
- For CLI syntax, verify against current `sf` command docs or `sf <command> --help` if available.
- For Agentforce, prefer official docs, `forcedotcom/sf-skills`, and `trailheadapps/agent-script-recipes`.
- If docs conflict with local metadata, document both and recommend a validation test.

## Output contract
- Question verified
- Sources checked
- Current finding
- Impact on implementation
- Remaining uncertainty
