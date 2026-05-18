---
name: salesforce-validation-rules
description: Production Salesforce AI skill for Salesforce validation rule design, formulas, error messages, bypass strategy, and deployment review.
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
- The task involves validation rules, formula conditions, bypass permissions, error messages, record-type conditions, or validation deployment failures.

## DO NOT TRIGGER when
- The task is broad object/field metadata without validation logic.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Metadata + Permissions + Testing + Deployment.

## Best Practices
- Validation rule names do not use `__c`, cannot end with `_`, and cannot contain double underscores.
- Error messages must be user-friendly, actionable, and point to the field when possible.
- Use `DeveloperName`/metadata-safe references, not record type IDs.
- Include bypass strategy only when justified, usually Custom Permission based.
- Test insert/update paths, integrations, data loads, and automation side effects.
- Avoid rules that block system automation unexpectedly; document affected personas and entry points.

## Output contract
- Rule goal
- Formula/metadata inspected
- Changes made
- User/security impact
- Test/validation plan
- Rollback notes
