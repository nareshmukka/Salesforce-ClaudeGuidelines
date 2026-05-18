---
name: salesforce-datacloud
description: Production Salesforce AI skill for Data Cloud activation, connection, schema retrieval, harmonization, querying, orchestration, and segmentation.
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
- The task involves Data Cloud setup, activation, source connection, schema discovery, identity/harmonization, calculated insights, segments, activations, or Data Cloud code extensions.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe metadata/code guidance with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is generic SOQL, standard Salesforce data operations, or non-Data-Cloud integration work.
- Another specialized skill is the primary owner and Data Cloud is only a downstream dependency.
- The user asks for activation, connector changes, data load, or destructive changes without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Integration + Metadata + Permissions + Deployment + Observability.
- Use `salesforce-soql` for query syntax and `salesforce-data-operations` for data load/export mechanics.

## Purpose
Provide a single, practical local skill covering the Data Cloud domains represented upstream by activating, connecting, preparing, retrieving, querying, harmonizing, orchestrating, segmenting, and code-extension skills.

## Workflow
1. Identify the Data Cloud artifact type: data stream, data lake object, data model object, identity rule, calculated insight, segment, activation, connector, or code extension.
2. Confirm org/environment, license/prerequisites, and whether the work touches live customer data.
3. Read local metadata and existing naming conventions before proposing new objects/mappings.
4. Validate identity, consent, data classification, retention, and activation audience boundaries.
5. Plan the smallest reversible change and list validation/smoke checks before editing.
6. Do not activate, connect, load, export, or publish data without explicit approval.

## Best Practices
- Treat Data Cloud work as high-risk data movement: document source, target, data classification, consent basis, and retention.
- Prefer stable API names, explicit field mappings, and versioned mapping documentation.
- Validate schema before building harmonization or segmentation logic; do not infer field types from labels.
- Keep PII out of logs, examples, screenshots, test prompts, and activation payloads.
- For segments and activations, record inclusion/exclusion rules, expected counts, suppression rules, and rollback plan.
- For code extensions, use least privilege, Named Credentials or approved auth, structured logging, idempotency, and deterministic retry behavior.

## Review checklist
- [ ] Data source, object model, identity rules, and activation target are explicit.
- [ ] Consent, PII, retention, and sharing boundaries are documented.
- [ ] Schema/field mappings are verified against source metadata.
- [ ] No live activation/load/export occurs without approval.
- [ ] Validation and rollback steps are documented.

## Output contract
- Understanding
- Files/artifacts inspected
- Changes made or recommended
- Data/security review
- Validation
- Activation/deployment notes
- Rollback notes
