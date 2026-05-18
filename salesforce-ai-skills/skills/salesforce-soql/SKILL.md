---
name: salesforce-soql
description: Production Salesforce AI skill for SOQL/SOSL query design, optimization, selectivity, relationship queries, and Salesforce data retrieval.
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
- The task involves SOQL, SOSL, relationship queries, aggregate queries, query selectivity, query debugging, or Salesforce record retrieval.

## DO NOT TRIGGER when
- The task is general Apex authoring and query design is incidental.
- The user asks to export sensitive data without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Apex + Data Operations + Metadata when queries depend on schema.

## Purpose
Design secure, selective, deterministic Salesforce queries.

## Best Practices
- Select explicit fields; SOQL has no `SELECT *`.
- Filter by indexed/selective fields when possible: Id, lookup/master-detail fields, OwnerId, ExternalId, and indexed custom fields.
- Use bind variables in Apex and validate dynamic field/operator names through describe allowlists.
- Add `ORDER BY` and `LIMIT` when result ordering or bounded volume matters.
- Use parent-to-child subqueries or child-to-parent relationship paths intentionally; document relationship names when non-obvious.
- Use `AggregateResult` for grouped counts/sums instead of querying records and counting in Apex.
- Use `WITH USER_MODE` when queries must enforce user CRUD/FLS.

## Review checklist
- [ ] Selected fields are minimal and required.
- [ ] Query is selective and bounded.
- [ ] Dynamic query inputs are allowlisted/bound.
- [ ] Relationship names are verified.
- [ ] Security mode is explicit.

## Output contract
- Query goal
- Schema assumptions
- Query/proposed change
- Security/performance review
- Validation notes
