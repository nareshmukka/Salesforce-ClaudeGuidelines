---
name: salesforce-data-operations
description: Production Salesforce AI skill for Salesforce data query/import/export/update/delete, Bulk API, tree data, seed data, cleanup, and reversible experiments.
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
- The task involves `sf data`, data import/export, seed data, tree data, Bulk API, data cleanup, anonymous Apex for data repair, or sample/test records.

## DO NOT TRIGGER when
- The task is metadata deployment or source-code-only work.
- The user asks to update/delete/export live data without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: SOQL + Metadata + Deployment + Observability.

## Purpose
Make data operations safe, reversible, and auditable.

## Workflow
1. Identify target environment alias, object(s), volume, environment, and whether data is production/customer data.
2. Describe/query schema before acting; verify required fields, lookups, validation rules, and automation side effects.
3. Prefer read/export and dry-run planning before write/delete operations.
4. Choose mechanism: single-record `sf data`, tree import/export, Bulk API, or anonymous Apex.
5. Capture backup/export, record counts, success/failure rows, and cleanup/rollback plan.

## Best Practices
- Never run production data writes/deletes without explicit approval and a backup plan.
- Use external IDs or stable natural keys for upsert and cleanup.
- Use Bulk API for high-volume loads and capture failed result files.
- Keep seed/test data small, documented, and easy to remove.
- Avoid PII in files, logs, examples, and final summaries.

## Output contract
- Understanding
- Org/data inspected
- Operation plan or changes made
- Data/security review
- Validation
- Rollback/cleanup notes
