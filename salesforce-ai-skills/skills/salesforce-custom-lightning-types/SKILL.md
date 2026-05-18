---
name: salesforce-custom-lightning-types
description: Production Salesforce AI skill for custom Lightning types, LightningTypeBundle metadata, Agentforce/Prompt Builder type contracts, and UI/action schema review.
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
- The task involves custom Lightning types, `LightningTypeBundle`, custom UI/action data types, Agentforce action schemas, or Prompt Builder type contracts.

## DO NOT TRIGGER when
- The task is a standard LWC or Apex DTO with no Lightning type metadata.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: LWC + Agentforce Builder + Prompt Template + Metadata.

## Best Practices
- Define type contracts before implementation: fields, labels, requiredness, nested structures, and consuming metadata.
- Keep type names stable; renames require updates to every consumer.
- Validate serialization/deserialization between Apex, LWC, Prompt Builder, and Agentforce where applicable.
- Avoid ambiguous field names such as `label`, `description`, or `model` when they conflict with platform/reserved semantics.
- Add examples and negative cases for complex/nested types.

## Output contract
- Type goal
- Consumers inspected
- Contract/design
- Changes made
- Validation
- Deployment notes
