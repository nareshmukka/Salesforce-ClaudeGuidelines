---
name: salesforce-diagrams
description: Production Salesforce AI skill for Mermaid and visual diagrams of Salesforce architecture, data models, automations, integrations, and Agentforce subagent maps.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-18
  owner: Reusable Salesforce AI Skills Library
---

## TRIGGER when
- The task asks for architecture diagrams, sequence diagrams, ERDs, flow maps, automation maps, deployment diagrams, or Agentforce subagent maps.

## DO NOT TRIGGER when
- The user wants code or metadata changes only and no visual explanation is needed.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read the domain skill for the artifact being diagrammed.

## Purpose
Create useful, maintainable diagrams that reflect actual Salesforce source and behavior.

## Best Practices
- Inspect source before diagramming; do not invent components.
- Use Mermaid for repo-friendly diagrams unless the user requests another format.
- Prefer small focused diagrams over one unreadable mega-diagram.
- For Agentforce, show subagents, transitions, gates, variables, and actions.
- For integrations, show auth boundary, system of record, retry/idempotency, and failure paths.
- For data models, show key relationships and cardinality where known.

## Output contract
- Diagram purpose
- Files/artifacts inspected
- Diagram
- Assumptions
- Gaps / validation notes
